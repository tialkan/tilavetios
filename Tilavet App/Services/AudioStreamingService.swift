import Foundation
@preconcurrency import AVFAudio

protocol AudioStreamingServiceProtocol {
    var audioFrames: AsyncStream<AudioFrame> { get }
    var sessionEvents: AsyncStream<AudioSessionEvent> { get }
    func requestPermission() async -> Bool
    func start() throws
    func stop()
}

enum AudioStreamingError: LocalizedError {
    case microphonePermissionDenied
    case noInputDevice
    case converterUnavailable

    var errorDescription: String? {
        switch self {
        case .microphonePermissionDenied:
            return "Microphone access is required to follow recitation."
        case .noInputDevice:
            return "No microphone input is available on this device."
        case .converterUnavailable:
            return "Audio conversion to 16 kHz failed."
        }
    }
}

final class AudioStreamingService: NSObject, AudioStreamingServiceProtocol {
    let audioFrames: AsyncStream<AudioFrame>
    let sessionEvents: AsyncStream<AudioSessionEvent>

    private let audioSession = AVAudioSession.sharedInstance()
    private let engine = AVAudioEngine()
    private let targetFormat = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: 16_000, channels: 1, interleaved: false)!

    private var frameContinuation: AsyncStream<AudioFrame>.Continuation?
    private var eventContinuation: AsyncStream<AudioSessionEvent>.Continuation?
    private var converter: AVAudioConverter?
    private var observers = [NSObjectProtocol]()

    override init() {
        var frameContinuation: AsyncStream<AudioFrame>.Continuation?
        audioFrames = AsyncStream { continuation in
            frameContinuation = continuation
        }

        var eventContinuation: AsyncStream<AudioSessionEvent>.Continuation?
        sessionEvents = AsyncStream { continuation in
            eventContinuation = continuation
        }

        self.frameContinuation = frameContinuation
        self.eventContinuation = eventContinuation

        super.init()
        installObservers()
    }

    deinit {
        observers.forEach(NotificationCenter.default.removeObserver)
    }

    func requestPermission() async -> Bool {
        if #available(iOS 17.0, *) {
            return await withCheckedContinuation { continuation in
                AVAudioApplication.requestRecordPermission { granted in
                    continuation.resume(returning: granted)
                }
            }
        } else {
            return await withCheckedContinuation { continuation in
                audioSession.requestRecordPermission { granted in
                    continuation.resume(returning: granted)
                }
            }
        }
    }

    func start() throws {
        let permissionGranted: Bool
        if #available(iOS 17.0, *) {
            permissionGranted = AVAudioApplication.shared.recordPermission == .granted
        } else {
            permissionGranted = audioSession.recordPermission == .granted
        }

        guard permissionGranted else {
            throw AudioStreamingError.microphonePermissionDenied
        }

        let inputNode = engine.inputNode
        let inputFormat = inputNode.inputFormat(forBus: 0)
        guard inputFormat.channelCount > 0 else {
            throw AudioStreamingError.noInputDevice
        }

        converter = AVAudioConverter(from: inputFormat, to: targetFormat)
        guard converter != nil else {
            throw AudioStreamingError.converterUnavailable
        }

        try audioSession.setCategory(.playAndRecord, mode: .measurement, options: [.defaultToSpeaker, .allowBluetoothHFP])
        try audioSession.setPreferredSampleRate(16_000)
        try audioSession.setPreferredIOBufferDuration(0.023)
        try audioSession.setActive(true, options: [])

        inputNode.removeTap(onBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 4096, format: inputFormat) { [weak self] buffer, _ in
            self?.handleInputBuffer(buffer)
        }

        if !engine.isRunning {
            engine.prepare()
            try engine.start()
        }
    }

    func stop() {
        engine.inputNode.removeTap(onBus: 0)
        engine.stop()
        try? audioSession.setActive(false, options: [.notifyOthersOnDeactivation])
    }

    private func handleInputBuffer(_ buffer: AVAudioPCMBuffer) {
        guard let converted = convert(buffer: buffer) else { return }
        let samples = converted.samples
        guard !samples.isEmpty else { return }

        frameContinuation?.yield(
            AudioFrame(
                samples: samples,
                sampleRate: Int(targetFormat.sampleRate),
                timestamp: .now,
                inputLevel: rms(samples: samples)
            )
        )
    }

    private func convert(buffer: AVAudioPCMBuffer) -> (samples: [Float], frameLength: Int)? {
        guard let converter else { return nil }
        let ratio = targetFormat.sampleRate / buffer.format.sampleRate
        let capacity = AVAudioFrameCount(Double(buffer.frameLength) * ratio) + 32
        guard let output = AVAudioPCMBuffer(pcmFormat: targetFormat, frameCapacity: capacity) else {
            return nil
        }

        var error: NSError?
        var providedInput = false
        let status = converter.convert(to: output, error: &error) { _, outStatus in
            if providedInput {
                outStatus.pointee = .noDataNow
                return nil
            }
            providedInput = true
            outStatus.pointee = .haveData
            return buffer
        }

        guard status != .error, error == nil, output.frameLength > 0, let channelData = output.floatChannelData?.pointee else {
            return nil
        }

        let samples = Array(UnsafeBufferPointer(start: channelData, count: Int(output.frameLength)))
        return (samples, Int(output.frameLength))
    }

    private func rms(samples: [Float]) -> Float {
        guard !samples.isEmpty else { return 0 }
        let mean = samples.reduce(0) { $0 + ($1 * $1) } / Float(samples.count)
        return sqrtf(mean)
    }

    private func installObservers() {
        let center = NotificationCenter.default
        observers.append(
            center.addObserver(
                forName: AVAudioSession.interruptionNotification,
                object: nil,
                queue: .main
            ) { [weak self] notification in
                guard
                    let typeValue = notification.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt,
                    let type = AVAudioSession.InterruptionType(rawValue: typeValue)
                else { return }

                switch type {
                case .began:
                    self?.eventContinuation?.yield(.interruptionBegan)
                case .ended:
                    self?.eventContinuation?.yield(.interruptionEnded)
                @unknown default:
                    break
                }
            }
        )

        observers.append(
            center.addObserver(
                forName: AVAudioSession.routeChangeNotification,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                self?.eventContinuation?.yield(.routeChanged)
            }
        )
    }
}
