import Accelerate
@preconcurrency import AVFoundation
import Foundation

public struct RecordedAudio: Sendable {
    public let url: URL
    public let duration: TimeInterval
    public let hasSpeech: Bool
}

public enum AudioRecordingError: LocalizedError {
    case permissionDenied, unavailable, alreadyRecording, notRecording

    public var errorDescription: String? {
        switch self {
        case .permissionDenied: "Allow Microphone access for BetterWispr in System Settings → Privacy & Security."
        case .unavailable: "No microphone input is available. Check your input device in Sound settings."
        case .alreadyRecording: "A recording is already running."
        case .notRecording: "No recording is running."
        }
    }
}

@MainActor
public final class AudioRecorder {
    public var onLevel: (@MainActor @Sendable (Float) -> Void)?
    /// RMS amplitude gate, not a semantic speech detector. Lower this for quiet microphones.
    public var silenceThreshold: Float = 0.002
    private var engine: AVAudioEngine?
    private var writer: RecordingWriter?
    private var recordingURL: URL?
    private var starting = false
    private var recordingID: UUID?
    private var meter = VoiceLevelMeter()

    public init() {}

    public func start() async throws {
        guard engine == nil, !starting else { throw AudioRecordingError.alreadyRecording }
        starting = true
        defer { starting = false }
        let allowed: Bool
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized: allowed = true
        case .notDetermined: allowed = await AVCaptureDevice.requestAccess(for: .audio)
        default: allowed = false
        }
        try Task.checkCancellation()
        guard allowed else { throw AudioRecordingError.permissionDenied }
        let engine = AVAudioEngine()
        let input = engine.inputNode
        let format = input.outputFormat(forBus: 0)
        guard format.sampleRate > 0, format.channelCount > 0 else { throw AudioRecordingError.unavailable }
        let url = FileManager.default.temporaryDirectory.appending(path: "betterwispr-\(UUID().uuidString).caf")
        let writer = try RecordingWriter(url: url, format: format, threshold: silenceThreshold)
        let id = UUID()
        recordingID = id
        meter = VoiceLevelMeter()
        input.installTap(onBus: 0, bufferSize: 1024, format: format) { @Sendable [weak self] buffer, _ in
            let rms = writer.write(buffer)
            Task { @MainActor [weak self] in
                guard let self, self.recordingID == id else { return }
                self.onLevel?(self.meter.update(rms: rms))
            }
        }
        do {
            engine.prepare()
            try engine.start()
            self.engine = engine
            self.writer = writer
            recordingURL = url
        } catch {
            input.removeTap(onBus: 0)
            engine.stop()
            _ = writer.finish()
            try? FileManager.default.removeItem(at: url)
            recordingID = nil
            throw error
        }
    }

    public func stop() throws -> RecordedAudio {
        guard let engine, let writer, let url = recordingURL else { throw AudioRecordingError.notRecording }
        engine.stop()
        engine.inputNode.removeTap(onBus: 0)
        let result = writer.finish()
        self.engine = nil
        self.writer = nil
        recordingURL = nil
        recordingID = nil
        onLevel?(0)
        if let error = result.error {
            try? FileManager.default.removeItem(at: url)
            throw error
        }
        guard result.duration > 0 else {
            try? FileManager.default.removeItem(at: url)
            throw SpeechError.emptyAudio
        }
        return RecordedAudio(url: url, duration: result.duration, hasSpeech: result.hasSpeech)
    }

    public func cancel() {
        engine?.stop()
        engine?.inputNode.removeTap(onBus: 0)
        _ = writer?.finish()
        if let recordingURL { try? FileManager.default.removeItem(at: recordingURL) }
        engine = nil
        writer = nil
        recordingURL = nil
        recordingID = nil
        onLevel?(0)
    }
}

/// Maps per-buffer RMS to a 0...1 waveform level relative to the room's noise floor and the speaker's recent peak.
public struct VoiceLevelMeter: Sendable {
    public private(set) var level: Float = 0
    private var floor: Float?
    private var peak: Float = -60

    public init() {}

    public mutating func update(rms: Float) -> Float {
        var target: Float = 0
        if rms.isFinite, rms > 0 {
            let decibels = max(-60, 20 * log10(rms))
            let floor = min((self.floor ?? decibels) + Self.floorRise, decibels)
            peak = max(decibels, peak - Self.peakFall, floor + Self.minimumRange)
            let span = peak - floor - Self.gate - Self.headroom
            target = pow(min(1, max(0, (decibels - floor - Self.gate) / span)), Self.curve)
            self.floor = floor
        }
        level += (target - level) * (target > level ? Self.attack : Self.release)
        return level
    }

    private static let floorRise: Float = 0.1
    private static let peakFall: Float = 0.12
    private static let minimumRange: Float = 15
    private static let gate: Float = 3
    private static let headroom: Float = 3
    private static let curve: Float = 0.7
    private static let attack: Float = 0.6
    private static let release: Float = 0.18
}

/// AVAudioEngine invokes its tap on the audio thread. The lock protects writes and
/// file finalization against stop/cancel; no AVAudioPCMBuffer escapes the callback.
private final class RecordingWriter: @unchecked Sendable {
    private let lock = NSLock()
    private var file: AVAudioFile?
    private var frames: AVAudioFramePosition = 0
    private var activeFrames: AVAudioFramePosition = 0
    private var error: (any Error)?
    private let sampleRate: Double
    private let threshold: Float

    init(url: URL, format: AVAudioFormat, threshold: Float) throws {
        file = try AVAudioFile(forWriting: url, settings: format.settings, commonFormat: format.commonFormat, interleaved: format.isInterleaved)
        sampleRate = format.sampleRate
        self.threshold = threshold.isFinite ? max(0, threshold) : 0.002
    }

    func write(_ buffer: AVAudioPCMBuffer) -> Float {
        lock.lock()
        defer { lock.unlock() }
        guard let file, error == nil, buffer.frameLength > 0 else { return 0 }
        do {
            try file.write(from: buffer)
        } catch {
            self.error = error
            return 0
        }
        frames += AVAudioFramePosition(buffer.frameLength)
        var rms: Float = 0
        if let channels = buffer.floatChannelData {
            for channel in 0..<Int(buffer.format.channelCount) {
                var channelRMS: Float = 0
                let interleaved = buffer.format.isInterleaved
                let samples = interleaved ? channels[0].advanced(by: channel) : channels[channel]
                let stride = interleaved ? Int(buffer.format.channelCount) : 1
                vDSP_rmsqv(samples, vDSP_Stride(stride), &channelRMS, vDSP_Length(buffer.frameLength))
                rms = max(rms, channelRMS)
            }
        }
        if rms >= threshold { activeFrames += AVAudioFramePosition(buffer.frameLength) }
        return rms
    }

    func finish() -> (duration: TimeInterval, hasSpeech: Bool, error: (any Error)?) {
        lock.lock()
        defer { lock.unlock() }
        file = nil
        // ponytail: an amplitude gate rejects silence; use a learned VAD if noise rejection is needed.
        return (Double(frames) / sampleRate, Double(activeFrames) / sampleRate >= 0.12, error)
    }
}
