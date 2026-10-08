@preconcurrency import AVFoundation
import AppKit
import CoreAudio
import Foundation
import IOKit.pwr_mgt

/// A microphone keyed by its Core Audio UID, so a saved choice survives unplugging and reconnecting.
public struct AudioInputDevice: Codable, Hashable, Identifiable, Sendable {
    public let id: String
    public let name: String

    public init(id: String, name: String) {
        self.id = id
        self.name = name
    }
}

public enum AudioInputs {
    /// Every connected device with an input stream, excluding private aggregates such as BetterWispr's system audio tap.
    public static func available() -> [AudioInputDevice] { inputs().map(\.device) }

    public static func systemDefault() -> AudioInputDevice? {
        var property = address(kAudioHardwarePropertyDefaultInputDevice)
        var id = AudioDeviceID(kAudioObjectUnknown)
        var size = UInt32(MemoryLayout<AudioDeviceID>.size)
        guard AudioObjectGetPropertyData(system, &property, 0, nil, &size, &id) == noErr else { return nil }
        return device(id)
    }

    /// The microphone Automatic records from right now.
    public static func automatic() -> AudioInputDevice? { resolve(nil) }

    /// The chosen microphone while it is connected, otherwise Automatic.
    public static func resolve(_ choice: AudioInputDevice?) -> AudioInputDevice? {
        resolve(choice, inputs: inputs(), systemDefault: systemDefault(), lidClosed: isLidClosed())
    }

    /// Recording from a Bluetooth headset drops its playback to call quality, so Automatic uses the Mac's own mic while the lid is open.
    static func resolve(_ choice: AudioInputDevice?, inputs: [Input], systemDefault: AudioInputDevice?, lidClosed: Bool) -> AudioInputDevice? {
        if let choice, let chosen = inputs.first(where: { $0.device.id == choice.id }) { return chosen.device }
        guard !lidClosed, inputs.first(where: { $0.device.id == systemDefault?.id })?.connection == .bluetooth,
              let builtIn = inputs.first(where: { $0.connection == .builtIn }) else { return systemDefault }
        return builtIn.device
    }

    struct Input {
        enum Connection { case builtIn, bluetooth, other }
        var id = AudioDeviceID(kAudioObjectUnknown)
        let device: AudioInputDevice
        let connection: Connection
    }

    static func captureDevice(_ choice: AudioInputDevice?) throws -> (AudioInputDevice, AudioDeviceID, AVAudioFormat) {
        let inputs = inputs()
        guard let device = resolve(choice, inputs: inputs, systemDefault: systemDefault(), lidClosed: isLidClosed()),
              let id = inputs.first(where: { $0.device.id == device.id })?.id else { throw AudioRecordingError.unavailable }
        var property = address(kAudioDevicePropertyStreamFormat, scope: kAudioObjectPropertyScopeInput)
        var stream = AudioStreamBasicDescription()
        var size = UInt32(MemoryLayout<AudioStreamBasicDescription>.size)
        guard AudioObjectGetPropertyData(id, &property, 0, nil, &size, &stream) == noErr,
              stream.mSampleRate > 0, stream.mChannelsPerFrame > 0,
              let format = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: stream.mSampleRate,
                                         channels: stream.mChannelsPerFrame, interleaved: true) else { throw AudioRecordingError.unavailable }
        return (device, id, format)
    }

    private static let system = AudioObjectID(kAudioObjectSystemObject)

    fileprivate static func address(_ selector: AudioObjectPropertySelector,
                                    scope: AudioObjectPropertyScope = kAudioObjectPropertyScopeGlobal) -> AudioObjectPropertyAddress {
        AudioObjectPropertyAddress(mSelector: selector, mScope: scope, mElement: kAudioObjectPropertyElementMain)
    }

    private static func inputs() -> [Input] {
        var property = address(kAudioHardwarePropertyDevices)
        var size: UInt32 = 0
        guard AudioObjectGetPropertyDataSize(system, &property, 0, nil, &size) == noErr else { return [] }
        var ids = [AudioDeviceID](repeating: 0, count: Int(size) / MemoryLayout<AudioDeviceID>.size)
        guard AudioObjectGetPropertyData(system, &property, 0, nil, &size, &ids) == noErr else { return [] }
        return ids.compactMap { id in device(id).map { Input(id: id, device: $0, connection: connection(id)) } }
    }

    private static func connection(_ id: AudioDeviceID) -> Input.Connection {
        var property = address(kAudioDevicePropertyTransportType)
        var transport: UInt32 = 0
        var size = UInt32(MemoryLayout<UInt32>.size)
        guard AudioObjectGetPropertyData(id, &property, 0, nil, &size, &transport) == noErr else { return .other }
        switch transport {
        case kAudioDeviceTransportTypeBuiltIn: return .builtIn
        case kAudioDeviceTransportTypeBluetooth, kAudioDeviceTransportTypeBluetoothLE: return .bluetooth
        default: return .other
        }
    }

    /// A closed MacBook lid disconnects the built-in microphone, which then records only silence.
    private static func isLidClosed() -> Bool {
        let root = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("IOPMrootDomain"))
        defer { IOObjectRelease(root) }
        return IORegistryEntryCreateCFProperty(root, kAppleClamshellStateKey as CFString, kCFAllocatorDefault, 0)?
            .takeRetainedValue() as? Bool ?? false
    }

    private static func device(_ id: AudioDeviceID) -> AudioInputDevice? {
        var streams = address(kAudioDevicePropertyStreams, scope: kAudioObjectPropertyScopeInput)
        var size: UInt32 = 0
        guard AudioObjectGetPropertyDataSize(id, &streams, 0, nil, &size) == noErr, size > 0,
              !isPrivateAggregate(id),
              let uid = string(kAudioDevicePropertyDeviceUID, of: id),
              let name = string(kAudioObjectPropertyName, of: id) else { return nil }
        return AudioInputDevice(id: uid, name: name)
    }

    /// Core Audio's per-process default aggregate and BetterWispr's tap are private and can't be recorded from directly.
    private static func isPrivateAggregate(_ id: AudioDeviceID) -> Bool {
        var property = address(kAudioAggregateDevicePropertyComposition)
        var value: Unmanaged<CFDictionary>?
        var size = UInt32(MemoryLayout<Unmanaged<CFDictionary>?>.size)
        guard AudioObjectGetPropertyData(id, &property, 0, nil, &size, &value) == noErr,
              let composition = value?.takeRetainedValue() as? [String: Any] else { return false }
        return composition[kAudioAggregateDeviceIsPrivateKey] as? Bool ?? false
    }

    private static func string(_ selector: AudioObjectPropertySelector, of id: AudioObjectID) -> String? {
        var property = address(selector)
        var value: Unmanaged<CFString>?
        var size = UInt32(MemoryLayout<Unmanaged<CFString>?>.size)
        guard AudioObjectGetPropertyData(id, &property, 0, nil, &size, &value) == noErr else { return nil }
        return value?.takeRetainedValue() as String?
    }
}

/// Tracks delivered audio on the main actor, rather than treating hardware startup as proof of capture.
@MainActor
final class AudioCaptureProgress {
    private(set) var generation = UUID()
    private var latestEnd: TimeInterval?
    private var cancelled = false

    @discardableResult
    func begin() -> UUID {
        generation = UUID()
        latestEnd = nil
        return generation
    }

    func receive(through end: TimeInterval, generation: UUID) {
        guard !cancelled, self.generation == generation, end.isFinite else { return }
        latestEnd = max(latestEnd ?? end, end)
    }

    func cancel() { cancelled = true }

    /// Waits for the first buffer (silence counts), or for the buffer covering a stop boundary, never a fixed tail delay.
    func wait(through boundary: TimeInterval? = nil) async throws {
        let deadline = ContinuousClock.now + (boundary == nil ? .seconds(3) : .milliseconds(500))
        while true {
            try Task.checkCancellation()
            guard !cancelled else { throw CancellationError() }
            if let latestEnd, latestEnd >= (boundary ?? -.infinity) { return }
            guard ContinuousClock.now < deadline else { throw AudioRecordingError.inputStalled }
            try await Task.sleep(for: .milliseconds(10))
        }
    }

    nonisolated static func endTime(_ time: AVAudioTime, frames: AVAudioFrameCount, sampleRate: Double) -> TimeInterval {
        time.isHostTimeValid
            ? AVAudioTime.seconds(forHostTime: time.hostTime) + Double(frames) / sampleRate
            : ProcessInfo.processInfo.systemUptime
    }
}

/// Calls `onChange` on the main actor once microphones, the macOS default input or the displays (as when a lid closes) settle.
@MainActor
public final class AudioInputObserver {
    private static let selectors = [kAudioHardwarePropertyDevices, kAudioHardwarePropertyDefaultInputDevice]
    private let onChange: @MainActor () -> Void
    private var listener: AudioObjectPropertyListenerBlock?
    private var screens: (any NSObjectProtocol)?
    private var deviceID: AudioDeviceID?
    private static var deviceProperties: [AudioObjectPropertyAddress] {
        [AudioInputs.address(kAudioDevicePropertyNominalSampleRate),
         AudioInputs.address(kAudioDevicePropertyDeviceIsAlive),
         AudioInputs.address(kAudioDevicePropertyStreamFormat, scope: kAudioObjectPropertyScopeInput)]
    }
    private var settling: Task<Void, Never>?

    public init(onChange: @escaping @MainActor () -> Void) {
        self.onChange = onChange
        let listener: AudioObjectPropertyListenerBlock = { [weak self] _, _ in
            MainActor.assumeIsolated { self?.scheduleCheck() }
        }
        for selector in Self.selectors {
            var property = AudioInputs.address(selector)
            AudioObjectAddPropertyListenerBlock(AudioObjectID(kAudioObjectSystemObject), &property, .main, listener)
        }
        self.listener = listener
        screens = NotificationCenter.default.addObserver(forName: NSApplication.didChangeScreenParametersNotification, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.scheduleCheck() }
        }
    }

    public func cancel() {
        settling?.cancel()
        observeDevice(nil)
        screens.map(NotificationCenter.default.removeObserver)
        screens = nil
        guard let listener else { return }
        for selector in Self.selectors {
            var property = AudioInputs.address(selector)
            AudioObjectRemovePropertyListenerBlock(AudioObjectID(kAudioObjectSystemObject), &property, .main, listener)
        }
        self.listener = nil
    }

    /// Watches same-UID Bluetooth profile changes as well as disconnection.
    func observeDevice(_ id: AudioDeviceID?) {
        guard id != deviceID, let listener else { return }
        if let deviceID {
            for var property in Self.deviceProperties {
                AudioObjectRemovePropertyListenerBlock(deviceID, &property, .main, listener)
            }
        }
        deviceID = id
        if let id {
            for var property in Self.deviceProperties {
                AudioObjectAddPropertyListenerBlock(id, &property, .main, listener)
            }
        }
    }

    /// Coalesces notifications and retries while a newly connected device settles.
    func scheduleCheck() {
        guard listener != nil else { return }
        settling?.cancel()
        settling = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(300))
            guard !Task.isCancelled else { return }
            self?.onChange()
        }
    }
}
