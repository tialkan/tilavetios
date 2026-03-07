import Combine
import Foundation

@MainActor
final class TrackerViewModel: ObservableObject {
    enum PermissionState: String {
        case unknown
        case granted
        case denied
    }

    enum ModelState: Equatable {
        case idle
        case loading
        case ready
        case unavailable(String)
        case failed(String)

        var label: String {
            switch self {
            case .idle:
                return "Model idle"
            case .loading:
                return "Model loading"
            case .ready:
                return "Model ready"
            case let .unavailable(message):
                return message
            case let .failed(message):
                return message
            }
        }
    }

    @Published var surahs: [QuranSurahSummary]
    @Published var selectedSurahID: Int
    @Published var selectedAyahID: Int
    @Published var trackingState: TrackingState
    @Published var currentVerse: QuranVerse?
    @Published var previousVerse: QuranVerse?
    @Published var nextVerse: QuranVerse?
    @Published var sessions: [RecitationSession]
    @Published var permissionState: PermissionState = .unknown
    @Published var modelState: ModelState = .idle
    @Published var isTracking = false
    @Published var statusMessage = "Ready to start"
    @Published var lastTranscript = ""
    @Published var debugSnapshot = DebugSnapshot()
    @Published var errorMessage: String?

    let settingsStore: AppSettingsStore

    private let quranStore: QuranStoreProtocol
    private let sessionStore: SessionStore
    private let audioService: AudioStreamingServiceProtocol
    private let recitationEngine: RecitationEngineProtocol
    private let alignmentService: QuranAlignmentServiceProtocol

    private var transcriptionTask: Task<Void, Never>?
    private var sessionEventsTask: Task<Void, Never>?
    private var demoTask: Task<Void, Never>?
    private var sessionStartedAt: Date?
    private var confidenceSamples = [Double]()
    private var driftEvents = 0
    private var lastRecordedDriftState: DriftState = .idle
    private var modelPrepared = false

    init(
        quranStore: QuranStoreProtocol,
        sessionStore: SessionStore,
        audioService: AudioStreamingServiceProtocol,
        recitationEngine: RecitationEngineProtocol,
        settingsStore: AppSettingsStore
    ) {
        self.quranStore = quranStore
        self.sessionStore = sessionStore
        self.audioService = audioService
        self.recitationEngine = recitationEngine
        self.settingsStore = settingsStore

        surahs = quranStore.surahs
        let initialStartPoint = sessionStore.loadLastStartPoint()
            ?? quranStore.orderedVerses.first?.startPoint
            ?? QuranStartPoint(surahID: 1, ayahID: 1)
        selectedSurahID = initialStartPoint.surahID
        selectedAyahID = initialStartPoint.ayahID
        trackingState = .idle(at: initialStartPoint)
        alignmentService = QuranAlignmentService(quranStore: quranStore, initialStartPoint: initialStartPoint)
        sessions = sessionStore.loadSessions()

        updateVerseContext(for: initialStartPoint)
        debugSnapshot.modelLocation = recitationEngine.modelLocationDescription
    }

    var availableAyahs: [Int] {
        let count = quranStore.ayahCount(for: selectedSurahID)
        guard count > 0 else { return [1] }
        return Array(1...count)
    }

    var selectedStartPoint: QuranStartPoint {
        QuranStartPoint(surahID: selectedSurahID, ayahID: selectedAyahID)
    }

    func requestMicrophoneAccess() async {
        let granted = await audioService.requestPermission()
        permissionState = granted ? .granted : .denied
        if !granted {
            errorMessage = "Microphone permission is required for live tracking."
        }
    }

    func updateSelectedSurah(_ surahID: Int) {
        selectedSurahID = surahID
        let maxAyah = quranStore.ayahCount(for: surahID)
        if selectedAyahID > maxAyah {
            selectedAyahID = max(maxAyah, 1)
        }
        jumpToSelectedStartPoint()
    }

    func updateSelectedAyah(_ ayahID: Int) {
        selectedAyahID = ayahID
        jumpToSelectedStartPoint()
    }

    func jumpToSelectedStartPoint() {
        alignmentService.reset(to: selectedStartPoint)
        trackingState = .idle(at: selectedStartPoint)
        updateVerseContext(for: selectedStartPoint)
        sessionStore.saveLastStartPoint(selectedStartPoint)
        statusMessage = "Start point updated"
    }

    func jumpToPreviousAyah() {
        guard let previousVerse else { return }
        selectedSurahID = previousVerse.surahID
        selectedAyahID = previousVerse.ayahID
        jumpToSelectedStartPoint()
    }

    func jumpToNextAyah() {
        guard let nextVerse else { return }
        selectedSurahID = nextVerse.surahID
        selectedAyahID = nextVerse.ayahID
        jumpToSelectedStartPoint()
    }

    func startTracking() async {
        guard !isTracking else { return }
        errorMessage = nil
        statusMessage = settingsStore.useSimulatedRecitation ? "Simulation running" : "Preparing microphone"

        if !settingsStore.useSimulatedRecitation {
            if permissionState != .granted {
                await requestMicrophoneAccess()
            }
            guard permissionState == .granted else { return }
            await prepareModelIfNeeded()
            guard modelPrepared else { return }
        } else {
            modelState = .idle
        }

        beginSession()

        if settingsStore.useSimulatedRecitation {
            startDemoLoop()
            return
        }

        do {
            try audioService.start()
            observeAudioSessionEvents()
            let transcriptionStream = recitationEngine.startStreaming(frames: audioService.audioFrames)
            transcriptionTask = Task { [weak self] in
                guard let self else { return }
                do {
                    for try await chunk in transcriptionStream {
                        await MainActor.run {
                            self.handleTranscriptionChunk(chunk)
                        }
                    }
                } catch {
                    await MainActor.run {
                        self.handleRuntimeError(error)
                    }
                }
            }
            statusMessage = "Listening for recitation"
        } catch {
            handleRuntimeError(error)
            finishSession()
        }
    }

    func stopTracking() {
        transcriptionTask?.cancel()
        transcriptionTask = nil
        sessionEventsTask?.cancel()
        sessionEventsTask = nil
        demoTask?.cancel()
        demoTask = nil
        recitationEngine.stop()
        audioService.stop()
        finishSession()
    }

    private func prepareModelIfNeeded() async {
        guard !modelPrepared else { return }
        modelState = .loading
        do {
            try await recitationEngine.loadModel()
            try await recitationEngine.warmup()
            modelPrepared = true
            modelState = .ready
            debugSnapshot.modelLocation = recitationEngine.modelLocationDescription
        } catch let error as RecitationEngineError {
            modelState = .unavailable(error.localizedDescription)
            debugSnapshot.lastError = error.localizedDescription
            handleRuntimeError(error)
        } catch {
            modelState = .failed(error.localizedDescription)
            debugSnapshot.lastError = error.localizedDescription
            handleRuntimeError(error)
        }
    }

    private func observeAudioSessionEvents() {
        sessionEventsTask?.cancel()
        sessionEventsTask = Task { [weak self] in
            guard let self else { return }
            for await event in audioService.sessionEvents {
                await MainActor.run {
                    self.handleAudioSessionEvent(event)
                }
            }
        }
    }

    private func handleAudioSessionEvent(_ event: AudioSessionEvent) {
        switch event {
        case .interruptionBegan:
            statusMessage = "Audio interruption detected"
        case .interruptionEnded:
            statusMessage = "Audio interruption ended"
        case .routeChanged:
            statusMessage = "Audio route changed"
        }
    }

    private func beginSession() {
        alignmentService.reset(to: selectedStartPoint)
        trackingState = .idle(at: selectedStartPoint)
        updateVerseContext(for: selectedStartPoint)
        sessionStartedAt = .now
        confidenceSamples = []
        driftEvents = 0
        lastRecordedDriftState = .idle
        isTracking = true
        lastTranscript = ""
    }

    private func finishSession() {
        guard isTracking else { return }

        if let sessionStartedAt {
            let session = RecitationSession(
                id: UUID(),
                startedAt: sessionStartedAt,
                endedAt: .now,
                startedFrom: selectedStartPoint,
                endedAtPoint: trackingState.startPoint,
                averageConfidence: confidenceSamples.isEmpty ? 0 : confidenceSamples.reduce(0, +) / Double(confidenceSamples.count),
                driftEvents: driftEvents,
                mode: settingsStore.useSimulatedRecitation ? .simulated : .live
            )
            sessionStore.save(session: session)
            sessions = sessionStore.loadSessions()
        }

        sessionStartedAt = nil
        isTracking = false
        statusMessage = "Tracking stopped"
    }

    private func startDemoLoop() {
        demoTask?.cancel()
        demoTask = Task { [weak self] in
            guard let self else { return }
            var currentPoint = self.selectedStartPoint

            while !Task.isCancelled {
                guard let verse = self.quranStore.verse(for: currentPoint) else { break }

                for wordCount in 1...max(verse.words.count, 1) {
                    try? await Task.sleep(for: .milliseconds(600))
                    if Task.isCancelled { break }
                    let text = verse.words.prefix(wordCount).map(\.uthmani).joined(separator: " ")
                    let chunk = TranscriptionChunk(
                        text: text,
                        isFinal: wordCount == verse.words.count,
                        latency: 0.12,
                        audioDuration: Double(wordCount) * 0.35,
                        capturedAt: .now
                    )
                    await MainActor.run {
                        self.handleTranscriptionChunk(chunk)
                    }
                }

                guard let nextVerse = self.quranStore.nextVerse(after: currentPoint) else { break }
                currentPoint = nextVerse.startPoint
            }

            await MainActor.run {
                self.stopTracking()
            }
        }
    }

    private func handleTranscriptionChunk(_ chunk: TranscriptionChunk) {
        lastTranscript = chunk.text
        let updatedState = alignmentService.update(transcriptChunk: chunk)
        trackingState = updatedState
        confidenceSamples.append(updatedState.confidence)
        sessionStore.saveLastStartPoint(updatedState.startPoint)
        updateVerseContext(for: updatedState.startPoint)
        statusMessage = statusLine(for: updatedState)

        debugSnapshot.lastLatency = chunk.latency
        debugSnapshot.rollingWindowSeconds = chunk.audioDuration
        debugSnapshot.candidateSummary = alignmentService.lastCandidates.prefix(3).map {
            "\($0.verse.surahID):\($0.verse.ayahID) \($0.score.formatted(.number.precision(.fractionLength(2))))"
        }

        if lastRecordedDriftState != .resyncing && updatedState.driftState == .resyncing {
            driftEvents += 1
        }
        lastRecordedDriftState = updatedState.driftState
    }

    private func handleRuntimeError(_ error: Error) {
        errorMessage = error.localizedDescription
        debugSnapshot.lastError = error.localizedDescription
        if let engineError = error as? RecitationEngineError, case .modelBundleMissing = engineError {
            trackingState = TrackingState(
                surahID: trackingState.surahID,
                ayahID: trackingState.ayahID,
                wordIndex: trackingState.wordIndex,
                confidence: trackingState.confidence,
                driftState: .modelUnavailable,
                lastTranscript: trackingState.lastTranscript,
                updatedAt: .now
            )
        }
        statusMessage = "Runtime issue detected"
    }

    private func updateVerseContext(for startPoint: QuranStartPoint) {
        currentVerse = quranStore.verse(for: startPoint)
        previousVerse = quranStore.previousVerse(before: startPoint)
        nextVerse = quranStore.nextVerse(after: startPoint)
    }

    private func statusLine(for state: TrackingState) -> String {
        switch state.driftState {
        case .idle:
            return "Waiting for recitation"
        case .aligned:
            return "Tracking is locked"
        case .weakMatch:
            return "Tracking weakened"
        case .resyncing:
            return "Searching for re-sync"
        case .modelUnavailable:
            return "Bundled model missing"
        }
    }
}
