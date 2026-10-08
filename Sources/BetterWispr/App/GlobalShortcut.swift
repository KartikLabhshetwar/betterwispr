import BetterWisprCore
import Carbon

@MainActor
final class GlobalShortcut {
    private var hotKey: EventHotKeyRef?
    private var handler: EventHandlerRef?
    var onPress: (() -> Void)?
    var onRelease: (() -> Void)?

    func register(_ shortcut: DictationShortcut) throws {
        unregister()
        guard installHandler() else { throw ShortcutError.unavailable(shortcut) }
        let identifier = EventHotKeyID(signature: 0x42575350, id: 1)
        let status = RegisterEventHotKey(shortcut.keyCode, shortcut.modifiers.rawValue, identifier,
                                         GetApplicationEventTarget(), 0, &hotKey)
        guard status == noErr else { hotKey = nil; throw ShortcutError.unavailable(shortcut) }
    }

    func unregister() {
        if let hotKey { UnregisterEventHotKey(hotKey) }
        hotKey = nil
    }

    private func installHandler() -> Bool {
        guard handler == nil else { return true }
        var specs = [EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed)),
                     EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyReleased))]
        let context = Unmanaged.passUnretained(self).toOpaque()
        return InstallEventHandler(GetApplicationEventTarget(), { _, event, context in
            guard let event, let context else { return OSStatus(eventNotHandledErr) }
            let pressed = GetEventKind(event) == UInt32(kEventHotKeyPressed)
            MainActor.assumeIsolated {
                let shortcut = Unmanaged<GlobalShortcut>.fromOpaque(context).takeUnretainedValue()
                (pressed ? shortcut.onPress : shortcut.onRelease)?()
            }
            return noErr
        }, specs.count, &specs, context, &handler) == noErr
    }
}

enum ShortcutError: LocalizedError {
    case unavailable(DictationShortcut)
    var errorDescription: String? {
        switch self {
        case .unavailable(let shortcut): "\(shortcut.displayName) is used by another app."
        }
    }
}
