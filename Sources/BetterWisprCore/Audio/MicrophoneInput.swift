@preconcurrency import AVFoundation
import AudioToolbox
import Foundation
import OSLog

/// A subscription to the one input stream per device that dictation and meetings share without stopping each other.
@MainActor
final class MicrophoneInput {
    private static var sources: [String: WeakSource] = [:]
    private let source: Source
    private let id = UUID()
    private var attached = false

    var device: AudioInputDevice { source.hardware.device }
    var deviceID: AudioDeviceID { source.hardware.deviceID }
    var format: AVAudioFormat { source.hardware.format }
    var isRunning: Bool { attached && source.hardware.isRunning }
    var error: (any Error)? { source.hardware.error }

    init(choice: AudioInputDevice?) throws {
        guard let device = AudioInputs.resolve(choice) else { throw AudioRecordingError.unavailable }
        Self.sources = Self.sources.filter { $0.value.value != nil }
        if let existing = Self.sources[device.id]?.value, existing.canReuse {
            source = existing
        } else {
            source = Source(hardware: try AudioQueueMicrophone(choice: device))
            Self.sources[device.id] = WeakSource(value: source)
        }
    }

    isolated deinit { stop() }

    func start(receive: @escaping MicrophoneDelivery.Receiver) async throws {
        guard !attached else { throw AudioRecordingError.alreadyRecording }
        attached = true
        do {
            try await source.start(id: id, receive: receive)
            try Task.checkCancellation()
        } catch {
            stop()
            throw error
        }
    }

    func stop() {
        guard attached else { return }
        attached = false
        source.remove(id)
    }

    private struct WeakSource { weak var value: Source? }

    @MainActor
    private final class Source {
        let hardware: AudioQueueMicrophone
        private let delivery = MicrophoneDelivery()
        private var preparation: Task<Void, any Error>?
        private var subscribers: Set<UUID> = []
        private var started = false
        private var stopped = false

        var canReuse: Bool { !stopped && (!started || hardware.isRunning) && hardware.error == nil }

        init(hardware: AudioQueueMicrophone) { self.hardware = hardware }

        func start(id: UUID, receive: @escaping MicrophoneDelivery.Receiver) async throws {
            guard !stopped else { throw AudioRecordingError.inputStalled }
            subscribers.insert(id)
            delivery.add(id, receive: receive)
            if preparation == nil {
                let hardware = hardware, delivery = delivery
                preparation = Task { try await hardware.start { delivery.receive($0, at: $1) } }
            }
            do {
                try await preparation!.value
                started = true
                guard !subscribers.isEmpty else { hardware.stop(); throw CancellationError() }
                Logger(subsystem: "org.betterwispr.app", category: "MicrophoneCapture").notice("Attached to shared input: subscribers=\(self.subscribers.count)")
            } catch {
                stopped = true
                throw error
            }
        }

        func remove(_ id: UUID) {
            delivery.remove(id)
            subscribers.remove(id)
            if subscribers.isEmpty {
                stopped = true
                if started { hardware.stop() }
            }
        }
    }
}

/// Unchecked because a lock serializes receivers with capture-worker callbacks, so removal waits for the last call and no buffer is kept.
final class MicrophoneDelivery: @unchecked Sendable {
    typealias Receiver = @Sendable (AVAudioPCMBuffer, AVAudioTime) -> Void
    private let lock = NSLock()
    private var receivers: [UUID: (since: TimeInterval, receive: Receiver)] = [:]

    func add(_ id: UUID, since: TimeInterval = ProcessInfo.processInfo.systemUptime, receive: @escaping Receiver) {
        lock.withLock { receivers[id] = (since, receive) }
    }
    func remove(_ id: UUID) { _ = lock.withLock { receivers.removeValue(forKey: id) } }
    /// Trims each buffer to audio at or after a subscriber joined, so a shared stream never replays earlier sound.
    func receive(_ buffer: AVAudioPCMBuffer, at time: AVAudioTime) {
        lock.withLock {
            for subscriber in receivers.values {
                guard time.isHostTimeValid else { subscriber.receive(buffer, time); continue }
                let start = AVAudioTime.seconds(forHostTime: time.hostTime)
                let skip = min(Double(buffer.frameLength), max(0, ((subscriber.since - start) * buffer.format.sampleRate).rounded(.up)))
                guard skip < Double(buffer.frameLength) else { continue }
                guard skip > 0 else { subscriber.receive(buffer, time); continue }
                let frames = buffer.frameLength - AVAudioFrameCount(skip)
                guard let trimmed = AVAudioPCMBuffer(pcmFormat: buffer.format, frameCapacity: frames) else { continue }
                trimmed.frameLength = frames
                let input = UnsafeMutableAudioBufferListPointer(buffer.mutableAudioBufferList)
                let output = UnsafeMutableAudioBufferListPointer(trimmed.mutableAudioBufferList)
                for index in input.indices {
                    let stride = Int(input[index].mDataByteSize) / Int(buffer.frameLength)
                    output[index].mData?.copyMemory(from: input[index].mData!.advanced(by: Int(skip) * stride), byteCount: Int(frames) * stride)
                }
                subscriber.receive(trimmed, AVAudioTime(hostTime: AVAudioTime.hostTime(forSeconds: start + skip / buffer.format.sampleRate)))
            }
        }
    }
}

/// Unchecked because awaiting start hands the queue to one caller, and only the locked Delivery crosses into Audio Queue callbacks.
private final class AudioQueueMicrophone: @unchecked Sendable {
    let device: AudioInputDevice
    let deviceID: AudioDeviceID
    let format: AVAudioFormat
    private var queue: AudioQueueRef?
    private let worker = DispatchQueue(label: "org.betterwispr.microphone", qos: .userInitiated)
    private let delivery = Delivery()

    init(choice: AudioInputDevice?) throws {
        (device, deviceID, format) = try AudioInputs.captureDevice(choice)
    }

    var isRunning: Bool {
        guard let queue else { return false }
        var running: UInt32 = 0
        var size = UInt32(MemoryLayout<UInt32>.size)
        return AudioQueueGetProperty(queue, kAudioQueueProperty_IsRunning, &running, &size) == noErr && running != 0
    }

    /// The callback is explicitly Sendable so it never inherits MainActor isolation on the capture worker.
    @concurrent
    func start(receive: @escaping @Sendable (AVAudioPCMBuffer, AVAudioTime) -> Void) async throws {
        try Task.checkCancellation()
        let format = format
        let delivery = delivery
        let started = ProcessInfo.processInfo.systemUptime
        var created: AudioQueueRef?
        try check(AudioQueueNewInputWithDispatchQueue(&created, format.streamDescription, 0, worker) { @Sendable queue, buffer, time, _, _ in
            var list = AudioBufferList(mNumberBuffers: 1, mBuffers: AudioBuffer(
                mNumberChannels: format.channelCount, mDataByteSize: buffer.pointee.mAudioDataByteSize,
                mData: buffer.pointee.mAudioData))
            if let pcm = AVAudioPCMBuffer(pcmFormat: format, bufferListNoCopy: &list, deallocator: nil), pcm.frameLength > 0 {
                let timestamp = AVAudioTime(audioTimeStamp: time, sampleRate: format.sampleRate)
                delivery.report(pcm, time: timestamp, since: started)
                receive(pcm, timestamp)
            }
            if delivery.acceptsBuffers {
                delivery.failed(AudioQueueEnqueueBuffer(queue, buffer, 0, nil))
            }
        })
        guard let created else { throw AudioRecordingError.unavailable }
        queue = created
        do {
            var uid = device.id as CFString
            try check(withUnsafePointer(to: &uid) {
                AudioQueueSetProperty(created, kAudioQueueProperty_CurrentDevice, $0, UInt32(MemoryLayout<CFString>.size))
            })
            let bytes = UInt32((format.sampleRate * 0.02).rounded(.up)) * format.streamDescription.pointee.mBytesPerFrame
            for _ in 0..<4 {
                var buffer: AudioQueueBufferRef?
                try check(AudioQueueAllocateBuffer(created, bytes, &buffer))
                guard let buffer else { throw AudioRecordingError.unavailable }
                try check(AudioQueueEnqueueBuffer(created, buffer, 0, nil))
            }
            try check(AudioQueueStart(created, nil))
            try Task.checkCancellation()
            Self.logger.notice("Started input queue: rate=\(format.sampleRate) channels=\(format.channelCount) setup=\(ProcessInfo.processInfo.systemUptime - started)s")
        } catch {
            stop()
            throw error
        }
    }

    /// Synchronous dispose guarantees no callback runs after stop returns.
    func stop() {
        guard let queue else { return }
        delivery.stop()
        AudioQueueStop(queue, true)
        AudioQueueDispose(queue, true)
        self.queue = nil
    }

    var error: (any Error)? { delivery.error }

    private func check(_ status: OSStatus) throws {
        guard status == noErr else { throw NSError(domain: NSOSStatusErrorDomain, code: Int(status)) }
    }

    private nonisolated static let logger = Logger(subsystem: "org.betterwispr.app", category: "MicrophoneCapture")

    /// Unchecked because a lock guards the stop and error flags, while metering flags belong to the capture worker.
    private final class Delivery: @unchecked Sendable {
        private let lock = NSLock()
        private var stopped = false
        private var failure: OSStatus = noErr
        private var firstBuffer = true
        private var firstSignal = true

        var acceptsBuffers: Bool { lock.withLock { !stopped && failure == noErr } }
        var error: (any Error)? {
            lock.withLock { failure == noErr ? nil : NSError(domain: NSOSStatusErrorDomain, code: Int(failure)) }
        }
        func stop() { lock.withLock { stopped = true } }
        func failed(_ status: OSStatus) {
            guard status != noErr else { return }
            lock.withLock { if !stopped { failure = status } }
        }
        func report(_ buffer: AVAudioPCMBuffer, time: AVAudioTime, since started: TimeInterval) {
            guard firstBuffer || firstSignal else { return }
            let level = VoiceLevelMeter.slices(of: buffer).map(\.rms).max() ?? 0
            if firstBuffer || level > 0.00001 {
                let age = time.isHostTimeValid ? ProcessInfo.processInfo.systemUptime - AVAudioTime.seconds(forHostTime: time.hostTime) : -1
                AudioQueueMicrophone.logger.notice("Input delivery: first=\(self.firstBuffer) elapsed=\(ProcessInfo.processInfo.systemUptime - started)s frames=\(buffer.frameLength) age=\(age)s rms=\(level)")
                firstBuffer = false
                if level > 0.00001 { firstSignal = false }
            }
        }
    }
}
