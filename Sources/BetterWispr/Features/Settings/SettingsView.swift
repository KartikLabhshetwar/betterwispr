import AppKit
import BetterWisprCore
import Carbon.HIToolbox
import SwiftUI

struct SettingsView: View {
    @Bindable var model: AppModel

    var body: some View {
        Form {
            Section("Dictation") {
                ShortcutRecorder(model: model)
                Picker(selection: setting(\.dictationMode)) {
                    Text("Hold to talk").tag(DictationMode.hold)
                    Text("Press to toggle").tag(DictationMode.toggle)
                } label: {
                    Text("Shortcut behavior")
                    Text("Hold \(model.settings.shortcut.displayName) while you speak, or press it once and click the capsule when you’re done.")
                }
                .disabled(model.isBusy)
                Picker(selection: setting(\.language)) {
                    Text(model.selectedModel.engine == .apple ? "System language" : "Detect automatically").tag("auto")
                    Text("English").tag("en")
                    Text("Hindi").tag("hi")
                    Text("Spanish").tag("es")
                    Text("French").tag("fr")
                    Text("German").tag("de")
                    Text("Italian").tag("it")
                    Text("Portuguese").tag("pt")
                    Text("Japanese").tag("ja")
                    Text("Korean").tag("ko")
                    Text("Chinese").tag("zh")
                    Text("Arabic").tag("ar")
                } label: {
                    Text("Spoken language")
                    Text("Choose a language for more consistent recognition.")
                }
                Picker(selection: setting(\.silenceThreshold)) {
                    Text("Standard").tag(Float(0.002))
                    Text("Quiet voice").tag(Float(0.0005))
                    Text("No silence filter").tag(Float(0))
                } label: {
                    Text("Input sensitivity")
                    Text("Quiet voices may need a lower filter. More background noise can pass through.")
                }
                .disabled(model.isBusy)
                Toggle(isOn: setting(\.autoPaste)) {
                    Text("Paste into the active app")
                    Text("Requires Accessibility permission. Otherwise, text is copied.")
                }
                Toggle(isOn: setting(\.copyToClipboard)) {
                    Text("Copy to clipboard")
                    Text("Keep each dictation ready to paste again. When off, your clipboard is left as it was.")
                }
            }

            Section("Workspace") {
                Toggle(isOn: setting(\.showCapsule)) {
                    Text("Floating recording capsule")
                    Text("Keep a small voice control at the bottom of your screen.")
                }
                Toggle(isOn: setting(\.launchAtLogin)) {
                    Text("Open at login")
                    Text("Have BetterWispr ready when your Mac starts.")
                }
                Toggle(isOn: setting(\.saveHistory)) {
                    Text("Save dictation history")
                    Text("Store text locally so you can find and reuse it later.")
                }
            }

            Section {
                PermissionRow(title: "Microphone", detail: "Needed to hear your voice.", granted: model.microphoneGranted, action: model.requestMicrophone)
                PermissionRow(title: "Accessibility", detail: "Optional. Lets BetterWispr paste text into other apps.", granted: model.accessibilityGranted, action: model.requestAccessibility)
            } header: {
                Text("Permissions")
            } footer: {
                Label("Speech is processed on this Mac. Audio is not kept after dictation. Downloading a model is the only time Whisper needs the internet.", systemImage: "lock.shield")
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .toggleStyle(.switch)
    }

    private func setting<Value>(_ keyPath: WritableKeyPath<AppSettings, Value>) -> Binding<Value> {
        Binding(
            get: { model.settings[keyPath: keyPath] },
            set: { model.settings[keyPath: keyPath] = $0; model.saveSettings() }
        )
    }
}

private struct ShortcutRecorder: View {
    let model: AppModel
    @State private var monitor: Any?
    @State private var held: ShortcutModifiers = []
    @State private var feedback: String?

    private var isCapturing: Bool { monitor != nil }
    private var shortcut: DictationShortcut { model.settings.shortcut }

    var body: some View {
        LabeledContent {
            HStack(spacing: 6) {
                if shortcut != .optionSpace {
                    Button("Reset to \(DictationShortcut.optionSpace.spokenName)", systemImage: "arrow.counterclockwise") {
                        stop()
                        model.changeShortcut(.optionSpace)
                    }
                    .labelStyle(.iconOnly)
                    .buttonStyle(.borderless)
                    .help("Reset to \(DictationShortcut.optionSpace.displayName)")
                }
                recordButton
                    .accessibilityLabel(isCapturing ? "Keyboard shortcut, waiting for keys" : "Keyboard shortcut, \(shortcut.spokenName)")
                    .accessibilityHint("Click, then press a new shortcut, like Option Space or F5.")
            }
            .disabled(model.isBusy)
        } label: {
            Text("Keyboard shortcut")
            if isCapturing {
                Text(feedback ?? "Hold ⌃, ⌥ or ⌘ and press a key, or press an F-key. Esc cancels.")
            } else {
                Text(model.settings.dictationMode == .hold ? "Hold to speak. Release to finish." : "Press once to speak. Press again or click the capsule to finish.")
            }
        }
        .onChange(of: feedback) { _, text in if let text { AccessibilityNotification.Announcement(text).post() } }
        .onDisappear(perform: stop)
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didResignActiveNotification)) { _ in stop() }
    }

    @ViewBuilder private var recordButton: some View {
        let button = Button {
            if isCapturing { stop() } else { start() }
        } label: {
            Text(isCapturing ? (held.isEmpty ? "Type shortcut…" : held.symbols + " …") : shortcut.displayName).frame(minWidth: 96)
        }
        if isCapturing { button.buttonStyle(.borderedProminent) } else { button.buttonStyle(.bordered) }
    }

    private func start() {
        held = []
        feedback = nil
        model.suspendShortcut()
        monitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .flagsChanged]) { event in
            MainActor.assumeIsolated { capture(event) }
            return nil
        }
    }

    private func stop() {
        guard let monitor else { return }
        NSEvent.removeMonitor(monitor)
        self.monitor = nil
        model.registerShortcut()
    }

    private func capture(_ event: NSEvent) {
        let flags = event.modifierFlags
        let modifiers = ShortcutModifiers(Self.modifierFlags.filter { flags.contains($0.flag) }.map(\.modifier))
        guard event.type == .keyDown else { return modifiersChanged(to: modifiers, keyCode: Int(event.keyCode)) }
        if Int(event.keyCode) == kVK_Escape, modifiers.isEmpty { return stop() }
        let key = Self.keyNames[Int(event.keyCode)] ?? event.characters(byApplyingModifiers: [])?.uppercased() ?? ""
        guard let shortcut = DictationShortcut(keyCode: UInt32(event.keyCode), modifiers: modifiers, key: key) else {
            let pressed = modifiers.isEmpty ? key : modifiers.symbols + " " + key
            feedback = key.isEmpty ? "That key can’t be a shortcut. Try another."
                                   : "\(pressed) is for typing, so it can’t start dictation. Hold ⌃, ⌥ or ⌘ with it."
            return NSSound.beep()
        }
        model.changeShortcut(shortcut)
        stop()
    }

    private func modifiersChanged(to modifiers: ShortcutModifiers, keyCode: Int) {
        if keyCode == kVK_Function {
            feedback = "Fn can’t be a shortcut. Hold ⌃, ⌥ or ⌘ and press a key."
        } else if held.isEmpty, !modifiers.isEmpty {
            feedback = nil
        } else if !modifiers.isSuperset(of: held), feedback == nil {
            feedback = "\(held.symbols) needs a key too. Hold it and press one, like \(held.symbols) Space."
        }
        held = modifiers
    }

    private static let modifierFlags: [(flag: NSEvent.ModifierFlags, modifier: ShortcutModifiers)] = [
        (.control, .control), (.option, .option), (.shift, .shift), (.command, .command)
    ]

    private static let keyNames: [Int: String] = [
        kVK_Space: "Space", kVK_Return: "Return", kVK_Tab: "Tab", kVK_Delete: "Delete", kVK_ForwardDelete: "Forward Delete",
        kVK_Escape: "Esc", kVK_Home: "Home", kVK_End: "End", kVK_PageUp: "Page Up", kVK_PageDown: "Page Down",
        kVK_LeftArrow: "←", kVK_RightArrow: "→", kVK_UpArrow: "↑", kVK_DownArrow: "↓",
        kVK_F1: "F1", kVK_F2: "F2", kVK_F3: "F3", kVK_F4: "F4", kVK_F5: "F5", kVK_F6: "F6", kVK_F7: "F7",
        kVK_F8: "F8", kVK_F9: "F9", kVK_F10: "F10", kVK_F11: "F11", kVK_F12: "F12", kVK_F13: "F13", kVK_F14: "F14",
        kVK_F15: "F15", kVK_F16: "F16", kVK_F17: "F17", kVK_F18: "F18", kVK_F19: "F19", kVK_F20: "F20"
    ]
}
