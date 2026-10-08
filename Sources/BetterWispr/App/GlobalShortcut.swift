import AppKit
import BetterWisprCore
import Carbon
import IOKit.hidsystem

@MainActor
final class GlobalShortcut {
    private var hotKey: EventHotKeyRef?
    private var handler: EventHandlerRef?
    private var localMonitor: Any?
    private var globalMonitor: Any?
    private var modifierPressed = false
    var onPress: (() -> Void)?
    var onRelease: (() -> Void)?

    func register(_ shortcut: DictationShortcut) throws {
        unregister()
        if shortcut.isModifierOnly {
            guard AXIsProcessTrusted() else { throw ShortcutError.accessibilityRequired }
            localMonitor = NSEvent.addLocalMonitorForEvents(matching: .flagsChanged) { [weak self] event in
                MainActor.assumeIsolated { self?.handleModifierEvent(event, shortcut: shortcut) }
                return event
            }
            globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: .flagsChanged) { [weak self] event in
                MainActor.assumeIsolated { self?.handleModifierEvent(event, shortcut: shortcut) }
            }
            guard localMonitor != nil, globalMonitor != nil else {
                unregister()
                throw ShortcutError.monitorUnavailable
            }
            return
        }
        guard installHandler() else { throw ShortcutError.unavailable(shortcut) }
        let identifier = EventHotKeyID(signature: 0x42575350, id: 1)
        let status = RegisterEventHotKey(shortcut.keyCode, shortcut.modifiers.rawValue, identifier,
                                         GetApplicationEventTarget(), 0, &hotKey)
        guard status == noErr else { hotKey = nil; throw ShortcutError.unavailable(shortcut) }
    }

    func unregister() {
        if let hotKey { UnregisterEventHotKey(hotKey) }
        hotKey = nil
        if let localMonitor { NSEvent.removeMonitor(localMonitor) }
        if let globalMonitor { NSEvent.removeMonitor(globalMonitor) }
        localMonitor = nil
        globalMonitor = nil
        modifierPressed = false
    }

    func handleModifierEvent(_ event: NSEvent, shortcut: DictationShortcut) {
        guard event.type == .flagsChanged, event.keyCode == shortcut.keyCode,
              let mask = Self.modifierMasks[Int(shortcut.keyCode)] else { return }
        let pressed = event.modifierFlags.rawValue & UInt(mask) != 0
        guard pressed != modifierPressed else { return }
        // Only start with this modifier alone; always deliver its matching release.
        if pressed {
            let flags = event.modifierFlags.intersection([.control, .option, .shift, .command, .function])
            let ownFlag: NSEvent.ModifierFlags = switch DictationShortcut.modifier(for: shortcut.keyCode) {
            case .control: .control
            case .option: .option
            case .shift: .shift
            case .command: .command
            default: []
            }
            guard flags == ownFlag else { return }
        }
        modifierPressed = pressed
        (pressed ? onPress : onRelease)?()
    }

    private static let modifierMasks: [Int: Int32] = [
        kVK_Control: NX_DEVICELCTLKEYMASK, kVK_RightControl: NX_DEVICERCTLKEYMASK,
        kVK_Option: NX_DEVICELALTKEYMASK, kVK_RightOption: NX_DEVICERALTKEYMASK,
        kVK_Shift: NX_DEVICELSHIFTKEYMASK, kVK_RightShift: NX_DEVICERSHIFTKEYMASK,
        kVK_Command: NX_DEVICELCMDKEYMASK, kVK_RightCommand: NX_DEVICERCMDKEYMASK
    ]

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
    case accessibilityRequired
    case monitorUnavailable
    var errorDescription: String? {
        switch self {
        case .unavailable(let shortcut): "\(shortcut.displayName) is used by another app."
        case .accessibilityRequired: "Allow Accessibility in Settings to use a modifier key by itself."
        case .monitorUnavailable: "Couldn’t listen for the modifier key. Try choosing the shortcut again."
        }
    }
}
