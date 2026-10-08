@preconcurrency import AVFoundation
import CoreAudio
import Foundation

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

    /// The chosen microphone while it is connected, otherwise the macOS default input.
    public static func resolve(_ choice: AudioInputDevice?, available: [AudioInputDevice], systemDefault: AudioInputDevice?) -> AudioInputDevice? {
        choice.flatMap { choice in available.first { $0.id == choice.id } } ?? systemDefault
    }

    public static func resolve(_ choice: AudioInputDevice?) -> AudioInputDevice? {
        resolve(choice, available: available(), systemDefault: systemDefault())
    }

    /// Binds the engine's input to the resolved microphone before its format is read and returns that microphone.
    @discardableResult
    static func route(_ engine: AVAudioEngine, to choice: AudioInputDevice?) throws -> AudioInputDevice? {
        let inputs = inputs()
        guard let device = resolve(choice, available: inputs.map(\.device), systemDefault: systemDefault()),
              let id = inputs.first(where: { $0.device == device })?.id else { return nil }
        try engine.inputNode.auAudioUnit.setDeviceID(id)
        return device
    }

    private static let system = AudioObjectID(kAudioObjectSystemObject)

    fileprivate static func address(_ selector: AudioObjectPropertySelector,
                                    scope: AudioObjectPropertyScope = kAudioObjectPropertyScopeGlobal) -> AudioObjectPropertyAddress {
        AudioObjectPropertyAddress(mSelector: selector, mScope: scope, mElement: kAudioObjectPropertyElementMain)
    }

    private static func inputs() -> [(id: AudioDeviceID, device: AudioInputDevice)] {
        var property = address(kAudioHardwarePropertyDevices)
        var size: UInt32 = 0
        guard AudioObjectGetPropertyDataSize(system, &property, 0, nil, &size) == noErr else { return [] }
        var ids = [AudioDeviceID](repeating: 0, count: Int(size) / MemoryLayout<AudioDeviceID>.size)
        guard AudioObjectGetPropertyData(system, &property, 0, nil, &size, &ids) == noErr else { return [] }
        return ids.compactMap { id in device(id).map { (id, $0) } }
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

/// Calls `onChange` on the main actor once microphones stop connecting, disconnecting or changing the macOS default.
@MainActor
public final class AudioInputObserver {
    private static let selectors = [kAudioHardwarePropertyDevices, kAudioHardwarePropertyDefaultInputDevice]
    private let onChange: @MainActor () -> Void
    private var listener: AudioObjectPropertyListenerBlock?
    private var settling: Task<Void, Never>?

    public init(onChange: @escaping @MainActor () -> Void) {
        self.onChange = onChange
        let listener: AudioObjectPropertyListenerBlock = { [weak self] _, _ in
            MainActor.assumeIsolated { self?.settle() }
        }
        for selector in Self.selectors {
            var property = AudioInputs.address(selector)
            AudioObjectAddPropertyListenerBlock(AudioObjectID(kAudioObjectSystemObject), &property, .main, listener)
        }
        self.listener = listener
    }

    public func cancel() {
        settling?.cancel()
        guard let listener else { return }
        for selector in Self.selectors {
            var property = AudioInputs.address(selector)
            AudioObjectRemovePropertyListenerBlock(AudioObjectID(kAudioObjectSystemObject), &property, .main, listener)
        }
        self.listener = nil
    }

    private func settle() {
        settling?.cancel()
        settling = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(300))
            guard !Task.isCancelled else { return }
            self?.onChange()
        }
    }
}
