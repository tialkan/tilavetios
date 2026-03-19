import Foundation

#if canImport(WhisperKit)
import WhisperKit
#endif

protocol RecitationEngineProtocol {
    var modelLocationDescription: String { get }
    func loadModel() async throws
    func warmup() async throws
    func startStreaming(frames: AsyncStream<AudioFrame>) -> AsyncThrowingStream<TranscriptionChunk, Error>
    func stop()
}

enum RecitationEngineError: LocalizedError {
    case whisperKitUnavailable
    case modelBundleMissing
    case notLoaded
    case transcriptionFailed(String)

    var errorDescription: String? {
        switch self {
        case .whisperKitUnavailable:
            return "Bu build icine WhisperKit henuz baglanmadi."
        case .modelBundleMissing:
            return "Donusturulmus Kuran modeli uygulama kaynaklarinda bulunamadi."
        case .notLoaded:
            return "Tilavet motoru henuz bir model yuklemedi."
        case let .transcriptionFailed(message):
            return message
        }
    }
}

final class WhisperRecitationEngine: RecitationEngineProtocol {
    private let bundle: Bundle
    private let locator: ModelBundleLocator

    private var streamTask: Task<Void, Never>?
    private var lastText = ""

    #if canImport(WhisperKit)
    private var whisperKit: WhisperKit?
    #endif

    init(bundle: Bundle = .main) {
        self.bundle = bundle
        locator = ModelBundleLocator(bundle: bundle)
    }

    var modelLocationDescription: String {
        (try? locator.locate().path) ?? "Model klasoru bulunamadi"
    }

    func loadModel() async throws {
        lastText = ""
        let modelURL = try locator.locate()

        #if canImport(WhisperKit)
        let config = WhisperKitConfig(
            modelFolder: modelURL.path,
            prewarm: false,
            load: true,
            download: false
        )
        whisperKit = try await WhisperKit(config)
        #else
        throw RecitationEngineError.whisperKitUnavailable
        #endif
    }

    func warmup() async throws {
        #if canImport(WhisperKit)
        guard let whisperKit else {
            throw RecitationEngineError.notLoaded
        }
        try await whisperKit.prewarmModels()
        #else
        throw RecitationEngineError.whisperKitUnavailable
        #endif
    }

    func startStreaming(frames: AsyncStream<AudioFrame>) -> AsyncThrowingStream<TranscriptionChunk, Error> {
        lastText = ""
        return AsyncThrowingStream { continuation in
            streamTask?.cancel()
            streamTask = Task {
                do {
                    try await runStreamingLoop(frames: frames, continuation: continuation)
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }

    func stop() {
        streamTask?.cancel()
        streamTask = nil
        lastText = ""
    }

    private func runStreamingLoop(
        frames: AsyncStream<AudioFrame>,
        continuation: AsyncThrowingStream<TranscriptionChunk, Error>.Continuation
    ) async throws {
        #if canImport(WhisperKit)
        guard let whisperKit else {
            throw RecitationEngineError.notLoaded
        }

        let maxWindowSamples = 80_000
        let minimumWindowSamples = 16_000
        let hopSamples = 8_000

        var rollingBuffer = [Float]()
        var newlyBufferedSamples = 0

        for await frame in frames {
            if Task.isCancelled {
                break
            }

            rollingBuffer.append(contentsOf: frame.samples)
            if rollingBuffer.count > maxWindowSamples {
                rollingBuffer.removeFirst(rollingBuffer.count - maxWindowSamples)
            }
            newlyBufferedSamples += frame.samples.count

            guard rollingBuffer.count >= minimumWindowSamples, newlyBufferedSamples >= hopSamples else {
                continue
            }

            let startedAt = Date()
            let results = try await whisperKit.transcribe(
                audioArray: rollingBuffer,
                decodeOptions: DecodingOptions(
                    verbose: false,
                    language: "ar",
                    temperature: 0,
                    usePrefillPrompt: true,
                    withoutTimestamps: true,
                    wordTimestamps: false
                )
            )

            newlyBufferedSamples = 0
            let text = results
                .map(\.text)
                .joined(separator: " ")
                .trimmingCharacters(in: .whitespacesAndNewlines)

            guard !text.isEmpty, text != lastText else {
                continue
            }

            lastText = text
            continuation.yield(
                TranscriptionChunk(
                    text: text,
                    isFinal: false,
                    latency: Date().timeIntervalSince(startedAt),
                    audioDuration: Double(rollingBuffer.count) / 16_000,
                    capturedAt: frame.timestamp
                )
            )
        }
        #else
        throw RecitationEngineError.whisperKitUnavailable
        #endif
    }
}

private final class ModelBundleLocator {
    private let bundle: Bundle
    private(set) var cachedPath: String?
    private let requiredArtifacts = [
        "AudioEncoder.mlmodelc",
        "TextDecoder.mlmodelc",
        "MelSpectrogram.mlmodelc",
        "config.json",
        "tokenizer.json"
    ]

    init(bundle: Bundle) {
        self.bundle = bundle
    }

    func locate() throws -> URL {
        if let cachedPath {
            return URL(fileURLWithPath: cachedPath, isDirectory: true)
        }

        let fileManager = FileManager.default
        let candidateRoots = [
            bundle.resourceURL,
            bundle.bundleURL
        ].compactMap { $0 }

        for root in candidateRoots {
            if isModelRoot(root, fileManager: fileManager) {
                cachedPath = root.path
                return root
            }

            let directCandidates = [
                root.appendingPathComponent("whisper-turbo-quran", isDirectory: true),
                root.appendingPathComponent("Models/whisper-turbo-quran", isDirectory: true),
                root.appendingPathComponent("Resources/Models/whisper-turbo-quran", isDirectory: true)
            ]

            for candidate in directCandidates where isModelRoot(candidate, fileManager: fileManager) {
                cachedPath = candidate.path
                return candidate
            }

            if let enumerator = fileManager.enumerator(at: root, includingPropertiesForKeys: nil) {
                for case let url as URL in enumerator {
                    if url.lastPathComponent == "whisper-turbo-quran", isModelRoot(url, fileManager: fileManager) {
                        cachedPath = url.path
                        return url
                    }
                }
            }
        }

        throw RecitationEngineError.modelBundleMissing
    }

    private func isModelRoot(_ url: URL, fileManager: FileManager) -> Bool {
        requiredArtifacts.allSatisfy { artifact in
            fileManager.fileExists(atPath: url.appendingPathComponent(artifact).path)
        }
    }
}
