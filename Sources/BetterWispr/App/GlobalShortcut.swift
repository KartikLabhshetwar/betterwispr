import Carbon

@MainActor
final class GlobalShortcut {
    private var hotKey: EventHotKeyRef?
    private var handler: EventHandlerRef?
    var onPress: (() -> Void)?
    var onRelease: (() -> Void)?

    func register() throws {
        var specs = [EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed)),
                     EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyReleased))]
        let context = Unmanaged.passUnretained(self).toOpaque()
        let handlerStatus = InstallEventHandler(GetApplicationEventTarget(), { _, event, context in
            guard let event, let context else { return OSStatus(eventNotHandledErr) }
            let pressed = GetEventKind(event) == UInt32(kEventHotKeyPressed)
            MainActor.assumeIsolated {
                let shortcut = Unmanaged<GlobalShortcut>.fromOpaque(context).takeUnretainedValue()
                (pressed ? shortcut.onPress : shortcut.onRelease)?()
            }
            return noErr
        }, specs.count, &specs, context, &handler)
        guard handlerStatus == noErr else { throw ShortcutError.unavailable }
        let identifier = EventHotKeyID(signature: 0x42575350, id: 1)
        let status = RegisterEventHotKey(UInt32(kVK_Space), UInt32(optionKey), identifier,
                                         GetApplicationEventTarget(), 0, &hotKey)
        guard status == noErr else { unregister(); throw ShortcutError.unavailable }
    }

    func unregister() {
        if let hotKey { UnregisterEventHotKey(hotKey) }
        if let handler { RemoveEventHandler(handler) }
        hotKey = nil
        handler = nil
    }
}

enum ShortcutError: LocalizedError {
    case unavailable
    var errorDescription: String? { "⌥ Space is used by another app. Use the menu bar or Record button to dictate." }
}
