import AppKit
import BetterWisprCore
import Carbon.HIToolbox
import SwiftUI

struct SettingsView: View {
    @Bindable var model: AppModel

    var body: some View {
        Form {
            Section("Dictation") {
                MicrophonePicker(model: model) {
                    Text("Microphone")
                    Text("Used for dictation and meeting notes. A chosen mic is used whenever it’s connected; otherwise BetterWispr follows Sound settings.")
                }
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
                Toggle(isOn: setting(\.learnCorrections)) {
                    Text("Learn from my corrections")
                    Text("When you fix a misheard word in History, or in the text field within 30 seconds of a paste, it is added to Vocabulary.")
                }
            }

            Section {
                LabeledContent("“comma”, “question mark”, “full stop”", value: ", ? .")
                LabeledContent("“add a period”, “add a colon”", value: ". :")
                LabeledContent("“new line”, “new paragraph”", value: "Line breaks")
                LabeledContent("“scratch that”, “sorry, remove that”", value: "Deletes the last sentence")
                LabeledContent("“at the rate KV”, “at sign KV”", value: "@KV")
            } header: {
                Text("Voice Commands")
            } footer: {
                Text("Say these while dictating in English or Auto language. Words like “the Oxford comma” stay as written.")
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
                PermissionRow(title: "Accessibility", detail: "Needed for automatic paste and modifier-only shortcuts.", granted: model.accessibilityGranted, action: model.requestAccessibility)
            } header: {
                Text("Permissions")
            } footer: {
                Label("Built-in models process speech on this Mac. A selected API connection sends audio to its endpoint. Temporary recordings are removed after processing; external providers control their own retention.", systemImage: "lock.shield")
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
    @State private var modifierCandidate: DictationShortcut?
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
                    .accessibilityHint("Click, then press a shortcut, or press and release a modifier key such as Option.")
            }
            .disabled(model.isBusy)
        } label: {
            Text("Keyboard shortcut")
            if isCapturing {
                Text(feedback ?? "Press and release ⌃, ⌥, ⇧ or ⌘ alone, use a key combination, or press an F-key. Esc cancels.")
            } else {
                Text(model.settings.dictationMode == .hold ? "Hold to speak. Release to finish." : "Press once to speak. Press again or click the capsule to finish.")
                if shortcut.isModifierOnly { Text("Requires Accessibility permission. Uses the left or right key you recorded.") }
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
        modifierCandidate = nil
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
        modifierCandidate = nil
        model.registerShortcut()
    }

    private func capture(_ event: NSEvent) {
        let flags = event.modifierFlags
        let modifiers = ShortcutModifiers(Self.modifierFlags.filter { flags.contains($0.flag) }.map(\.modifier))
        guard event.type == .keyDown else { return modifiersChanged(to: modifiers, keyCode: Int(event.keyCode)) }
        modifierCandidate = nil
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
        if let candidate = modifierCandidate, candidate.keyCode == UInt32(keyCode), modifiers.isEmpty {
            model.changeShortcut(candidate)
            return stop()
        }
        modifierCandidate = nil
        if keyCode == kVK_Function {
            feedback = "Fn can’t be a shortcut. Try ⌥ alone or an F-key such as F5."
        } else if held.isEmpty, !modifiers.isEmpty {
            feedback = nil
            if modifiers == DictationShortcut.modifier(for: UInt32(keyCode)), let key = Self.keyNames[keyCode] {
                modifierCandidate = DictationShortcut(keyCode: UInt32(keyCode), modifiers: [], key: key)
            }
        } else if !modifiers.isSuperset(of: held), feedback == nil {
            feedback = "Press and release one modifier alone, or hold the modifiers and press another key."
        }
        held = modifiers
    }

    private static let modifierFlags: [(flag: NSEvent.ModifierFlags, modifier: ShortcutModifiers)] = [
        (.control, .control), (.option, .option), (.shift, .shift), (.command, .command)
    ]

    private static let keyNames: [Int: String] = [
        kVK_Control: "Left Control", kVK_RightControl: "Right Control", kVK_Option: "Left Option", kVK_RightOption: "Right Option",
        kVK_Shift: "Left Shift", kVK_RightShift: "Right Shift", kVK_Command: "Left Command", kVK_RightCommand: "Right Command",
        kVK_Space: "Space", kVK_Return: "Return", kVK_Tab: "Tab", kVK_Delete: "Delete", kVK_ForwardDelete: "Forward Delete",
        kVK_Escape: "Esc", kVK_Home: "Home", kVK_End: "End", kVK_PageUp: "Page Up", kVK_PageDown: "Page Down",
        kVK_LeftArrow: "←", kVK_RightArrow: "→", kVK_UpArrow: "↑", kVK_DownArrow: "↓",
        kVK_F1: "F1", kVK_F2: "F2", kVK_F3: "F3", kVK_F4: "F4", kVK_F5: "F5", kVK_F6: "F6", kVK_F7: "F7",
        kVK_F8: "F8", kVK_F9: "F9", kVK_F10: "F10", kVK_F11: "F11", kVK_F12: "F12", kVK_F13: "F13", kVK_F14: "F14",
        kVK_F15: "F15", kVK_F16: "F16", kVK_F17: "F17", kVK_F18: "F18", kVK_F19: "F19", kVK_F20: "F20"
    ]
}

/// Picks the input for dictation and meetings; switching applies to a running meeting immediately.
struct MicrophonePicker<Label: View>: View {
    let model: AppModel
    @ViewBuilder let label: Label

    var body: some View {
        Picker(selection: Binding(get: { model.settings.microphone?.id },
                                  set: { id in model.selectMicrophone(model.microphoneChoices.first { $0.id == id }) })) {
            Text(model.defaultMicrophone.map { "Automatic (\($0.name))" } ?? "Automatic").tag(String?.none)
            ForEach(model.microphoneChoices) { device in
                Text(model.microphones.contains { $0.id == device.id } ? device.name : "\(device.name) (not connected)")
                    .tag(Optional(device.id))
            }
        } label: {
            label
        }
    }
}
