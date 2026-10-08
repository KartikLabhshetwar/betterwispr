import Accelerate
@preconcurrency import AVFoundation
import Foundation

public struct ChunkPolicy: Sendable {
    public var minimum: TimeInterval
    public var maximum: TimeInterval
    public var pause: TimeInterval

    public init(minimum: TimeInterval = 10, maximum: TimeInterval = 30, pause: TimeInterval = 0.6) {
        self.minimum = minimum
        self.maximum = maximum
        self.pause = pause
    }

    public func shouldRotate(duration: TimeInterval, trailingSilence: TimeInterval) -> Bool {
        duration >= maximum || (duration >= minimum && trailingSilence >= pause)
    }
}

public struct MeetingAudioChunk: Sendable {
    public let url: URL
    public let speaker: Speaker
    public let start: TimeInterval
    public let duration: TimeInterval
    public let hasSpeech: Bool
}

/// Records the microphone as Me and other apps' audio as Them, handing off rotating chunk files for transcription.
@MainActor
public final class MeetingRecorder {
    public var onChunk: (@MainActor (MeetingAudioChunk) -> Void)?
    public var onLevels: (@MainActor ((me: Float, them: Float)) -> Void)?
    public var onError: (@MainActor (any Error) -> Void)?
    public private(set) var systemAudioIssue: String?
    private let policy: ChunkPolicy
    private var session: UUID?
    private var origin = Date()
    private var engine: AVAudioEngine?
    private var microphoneObserver: (any NSObjectProtocol)?
    private var writers: [Speaker: MeetingChunkWriter] = [:]
    private var stopSystemAudio: (() -> Void)?
    private var meters: [Speaker: VoiceLevelMeter] = [:]
    private var levels: (me: Float, them: Float) = (0, 0)

    public init(policy: ChunkPolicy = ChunkPolicy()) {
        self.policy = policy
    }

    public func start(silenceThreshold: Float) async throws {
        guard session == nil else { throw AudioRecordingError.alreadyRecording }
        let id = UUID()
        session = id
        systemAudioIssue = nil
        do {
            try await startMicrophone(session: id, threshold: silenceThreshold)
            await startSystemAudio(session: id, threshold: silenceThreshold)
            guard session == id else { throw CancellationError() }
        } catch {
            if session == id { cancel() }
            throw error
        }
    }

    public func stop() {
        guard session != nil else { return }
        haltInputs()
        for speaker in [Speaker.me, .them] {
            guard let writer = writers[speaker] else { continue }
            writer.finish()
            hand(writer.takeReady())
        }
        reset()
    }

    public func cancel() {
        haltInputs()
        for writer in writers.values {
            writer.cancel()
            for chunk in writer.takeReady().chunks { try? FileManager.default.removeItem(at: chunk.url) }
        }
        reset()
    }

    private func startMicrophone(session id: UUID, threshold: Float) async throws {
        let allowed: Bool
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized: allowed = true
        case .notDetermined: allowed = await AVCaptureDevice.requestAccess(for: .audio)
        default: allowed = false
        }
        try Task.checkCancellation()
        guard session == id else { throw CancellationError() }
        guard allowed else { throw AudioRecordingError.permissionDenied }
        let engine = AVAudioEngine()
        try installMicrophone(on: engine, session: id, threshold: threshold, startOffset: 0)
        self.engine = engine
        origin = Date()
        microphoneObserver = NotificationCenter.default.addObserver(forName: .AVAudioEngineConfigurationChange, object: engine,
                                                                    queue: .main) { @Sendable [weak self] _ in
            Task { @MainActor [weak self] in self?.restartMicrophone(session: id, threshold: threshold) }
        }
    }

    private func installMicrophone(on engine: AVAudioEngine, session id: UUID, threshold: Float, startOffset: TimeInterval) throws {
        let input = engine.inputNode
        let format = input.outputFormat(forBus: 0)
        guard format.sampleRate > 0, format.channelCount > 0 else { throw AudioRecordingError.unavailable }
        let writer = try MeetingChunkWriter(speaker: .me, format: format, threshold: threshold, policy: policy, startOffset: startOffset)
        input.installTap(onBus: 0, bufferSize: 1024, format: format) { @Sendable [weak self] buffer, _ in
            let level = writer.write(buffer)
            Task { @MainActor [weak self] in self?.receive(level, from: .me, session: id) }
        }
        do {
            engine.prepare()
            try engine.start()
        } catch {
            input.removeTap(onBus: 0)
            engine.stop()
            writer.cancel()
            throw error
        }
        writers[.me] = writer
    }

    /// Picks the microphone back up after AVAudioEngine stops itself for an input device or format change.
    private func restartMicrophone(session id: UUID, threshold: Float) {
        guard session == id, let engine else { return }
        engine.inputNode.removeTap(onBus: 0)
        if let writer = writers.removeValue(forKey: .me) {
            writer.finish()
            hand(writer.takeReady())
        }
        do {
            try installMicrophone(on: engine, session: id, threshold: threshold, startOffset: Date().timeIntervalSince(origin))
        } catch {
            onError?(error)
        }
    }

    private func startSystemAudio(session id: UUID, threshold: Float) async {
        guard #available(macOS 14.2, *) else {
            systemAudioIssue = "System audio needs macOS 14.2 or later."
            return
        }
        let tap = SystemAudioTap()
        var writer: MeetingChunkWriter?
        do {
            let format = try await tap.prepare()
            guard session == id else { return tap.stop() }
            let created = try MeetingChunkWriter(speaker: .them, format: format, threshold: threshold, policy: policy,
                                                 startOffset: Date().timeIntervalSince(origin))
            writer = created
            try tap.start { [weak self] buffers in
                let level = created.write(buffers)
                Task { @MainActor [weak self] in self?.receive(level, from: .them, session: id) }
            }
            writers[.them] = created
            stopSystemAudio = { tap.stop() }
        } catch {
            tap.stop()
            writer?.cancel()
            if session == id { systemAudioIssue = "Recording your microphone only. \(error.localizedDescription)" }
        }
    }

    private func receive(_ sample: (rms: Float, duration: TimeInterval), from speaker: Speaker, session id: UUID) {
        guard session == id, let writer = writers[speaker] else { return }
        let level = meters[speaker, default: VoiceLevelMeter()].update(rms: sample.rms, over: sample.duration)
        if speaker == .me { levels.me = level } else { levels.them = level }
        onLevels?(levels)
        hand(writer.takeReady())
    }

    private func hand(_ ready: (chunks: [MeetingAudioChunk], error: (any Error)?)) {
        if let error = ready.error { onError?(error) }
        for chunk in ready.chunks {
            if let onChunk { onChunk(chunk) } else { try? FileManager.default.removeItem(at: chunk.url) }
        }
    }

    private func haltInputs() {
        if let microphoneObserver { NotificationCenter.default.removeObserver(microphoneObserver) }
        microphoneObserver = nil
        engine?.stop()
        engine?.inputNode.removeTap(onBus: 0)
        stopSystemAudio?()
    }

    private func reset() {
        engine = nil
        writers = [:]
        stopSystemAudio = nil
        session = nil
        meters = [:]
        levels = (0, 0)
        onLevels?(levels)
    }
}

/// AVAudioEngine and the Core Audio IOProc call write on their own threads. The lock protects the open file,
/// counters and finished chunks against rotation, stop and cancel; no AVAudioPCMBuffer escapes the call.
final class MeetingChunkWriter: @unchecked Sendable {
    private let lock = NSLock()
    private let speaker: Speaker
    private let format: AVAudioFormat
    private let policy: ChunkPolicy
    private let threshold: Float
    private let startOffset: TimeInterval
    private var file: AVAudioFile?
    private var url: URL?
    private var elapsedFrames: AVAudioFramePosition = 0
    private var frames: AVAudioFramePosition = 0
    private var activeFrames: AVAudioFramePosition = 0
    private var silentFrames: AVAudioFramePosition = 0
    private var ready: [MeetingAudioChunk] = []
    private var error: (any Error)?

    init(speaker: Speaker, format: AVAudioFormat, threshold: Float, policy: ChunkPolicy, startOffset: TimeInterval) throws {
        self.speaker = speaker
        self.format = format
        self.policy = policy
        self.threshold = threshold.isFinite ? max(0, threshold) : 0.002
        self.startOffset = startOffset
        try open()
    }

    func write(_ list: UnsafePointer<AudioBufferList>) -> (rms: Float, duration: TimeInterval) {
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, bufferListNoCopy: list, deallocator: nil) else { return (0, 0) }
        return write(buffer)
    }

    func write(_ buffer: AVAudioPCMBuffer) -> (rms: Float, duration: TimeInterval) {
        lock.lock()
        defer { lock.unlock() }
        let count = AVAudioFramePosition(buffer.frameLength)
        guard let file, count > 0 else { return (0, seconds(count)) }
        do {
            try file.write(from: buffer)
        } catch {
            self.error = error
            closeChunk()
            return (0, seconds(count))
        }
        let rms = Self.rms(of: buffer)
        frames += count
        if rms >= threshold {
            activeFrames += count
            silentFrames = 0
        } else {
            silentFrames += count
        }
        if policy.shouldRotate(duration: seconds(frames), trailingSilence: seconds(silentFrames)) {
            closeChunk()
            do { try open() } catch { self.error = error }
        }
        return (rms, seconds(count))
    }

    func finish() {
        lock.lock()
        defer { lock.unlock() }
        closeChunk()
    }

    func cancel() {
        lock.lock()
        defer { lock.unlock() }
        file = nil
        if let url { try? FileManager.default.removeItem(at: url) }
        url = nil
    }

    func takeReady() -> (chunks: [MeetingAudioChunk], error: (any Error)?) {
        lock.lock()
        defer {
            ready = []
            error = nil
            lock.unlock()
        }
        return (ready, error)
    }

    private func open() throws {
        let url = FileManager.default.temporaryDirectory.appending(path: "betterwispr-meeting-\(UUID().uuidString).caf")
        do {
            file = try AVAudioFile(forWriting: url, settings: format.settings, commonFormat: format.commonFormat, interleaved: format.isInterleaved)
            self.url = url
        } catch {
            try? FileManager.default.removeItem(at: url)
            throw error
        }
    }

    private func closeChunk() {
        guard let url else { return }
        file = nil
        self.url = nil
        let duration = seconds(frames)
        if frames > 0 {
            // ponytail: an amplitude gate decides speech; use a learned VAD if room noise floods transcription.
            ready.append(MeetingAudioChunk(url: url, speaker: speaker, start: startOffset + seconds(elapsedFrames), duration: duration,
                                           hasSpeech: seconds(activeFrames) >= 0.3 && duration >= 0.5))
        } else {
            try? FileManager.default.removeItem(at: url)
        }
        elapsedFrames += frames
        frames = 0
        activeFrames = 0
        silentFrames = 0
    }

    private func seconds(_ frames: AVAudioFramePosition) -> TimeInterval {
        Double(frames) / format.sampleRate
    }

    private static func rms(of buffer: AVAudioPCMBuffer) -> Float {
        guard let channels = buffer.floatChannelData else { return 0 }
        let count = Int(buffer.format.channelCount)
        let interleaved = buffer.format.isInterleaved
        return (0..<count).reduce(0) { loudest, channel in
            var value: Float = 0
            vDSP_rmsqv(interleaved ? channels[0].advanced(by: channel) : channels[channel], vDSP_Stride(interleaved ? count : 1),
                       &value, vDSP_Length(buffer.frameLength))
            return max(loudest, value)
        }
    }
}
