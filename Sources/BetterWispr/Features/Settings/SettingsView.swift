import AppKit
import BetterWisprCore
import Carbon.HIToolbox
import SwiftUI

struct SettingsView: View {
    @Bindable var model: AppModel

    private static let voiceCommands = [
        ("“comma”, “question mark”, “full stop”", ", ? ."),
        ("“add a period”, “add a colon”", ". :"),
        ("“new line”, “new paragraph”", "Line breaks"),
        ("“scratch that”, “sorry, remove that”", "Deletes the last sentence"),
        ("“at the rate KV”, “at sign KV”", "@KV"),
        ("“write an email to Sam saying …, best regards, Kartik”", "Hi Sam, body and sign-off"),
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                SettingsSection("Appearance") {
                    SettingRow("Theme") {
                        Picker("Theme", selection: setting(\.theme)) {
                            Text("System").tag(AppTheme.system)
                            Text("Light").tag(AppTheme.light)
                            Text("Dark").tag(AppTheme.dark)
                        }
                        .pickerStyle(.segmented)
                        .labelsHidden()
                        .fixedSize()
                    }
                }

                SettingsSection("Shortcut") {
                    ShortcutRecorder(model: model)
                    RowDivider()
                    SettingRow("Behavior", caption: model.settings.dictationMode == .hold
                        ? "Hold to speak and release to finish. A quick tap starts hands-free dictation."
                        : "Press once to speak. Press again or click ✓ to finish.") {
                        Picker("Behavior", selection: setting(\.dictationMode)) {
                            Text("Hold to talk").tag(DictationMode.hold)
                            Text("Press to toggle").tag(DictationMode.toggle)
                        }
                        .pickerStyle(.segmented)
                        .labelsHidden()
                        .fixedSize()
                        .disabled(model.isBusy)
                    }
                }

                SettingsSection("Microphone and language") {
                    SettingRow("Microphone", caption: (model.settings.microphone == nil ? "Follows your Sound settings." : "Used whenever it’s connected.")
                        + " Bluetooth headphones drop to call quality while recording.") {
                        MicrophonePicker(model: model) { Text("Microphone") }
                            .labelsHidden()
                            .frame(maxWidth: 240)
                    }
                    RowDivider()
                    SettingRow("Spoken language", caption: "A fixed language gives more consistent results.") {
                        Picker("Spoken language", selection: setting(\.language)) {
                            Text(model.selectedModel.engine == .apple ? "System language" : "Detect automatically").tag("auto")
                            ForEach(languageChoices, id: \.code) { Text($0.name).tag($0.code) }
                        }
                        .labelsHidden()
                        .fixedSize()
                    }
                    RowDivider()
                    SettingRow("Input sensitivity", caption: "Lower filters help quiet voices but let more background noise through.") {
                        Picker("Input sensitivity", selection: setting(\.silenceThreshold)) {
                            Text("Standard").tag(Float(0.002))
                            Text("Quiet voice").tag(Float(0.0005))
                            Text("No filter").tag(Float(0))
                        }
                        .pickerStyle(.segmented)
                        .labelsHidden()
                        .fixedSize()
                        .disabled(model.isBusy)
                    }
                }

                SettingsSection("After you speak") {
                    SettingToggle("Paste into the active app", caption: "Needs Accessibility. Otherwise, text is copied.", isOn: setting(\.autoPaste))
                    RowDivider()
                    SettingToggle("Copy to clipboard", caption: "Keep each dictation ready to paste again. When off, your clipboard is left as it was.", isOn: setting(\.copyToClipboard))
                    RowDivider()
                    SettingToggle("Learn from my corrections", caption: "Words you fix in History, or in the text field within 30 seconds of a paste, are added to Vocabulary.", isOn: setting(\.learnCorrections))
                }

                SettingsSection("App") {
                    SettingToggle("Dictation sounds", caption: "Soft cues when you finish, cancel or need attention. Quiet during meeting capture.", isOn: setting(\.soundEffects))
                    RowDivider()
                    SettingToggle("Floating recording capsule", caption: "A small voice control at the bottom of your screen.", isOn: setting(\.showCapsule))
                    RowDivider()
                    SettingToggle("Detect meetings", caption: "Offer the notetaker when Zoom, Google Meet, Teams, a Slack huddle or another call starts using the microphone. Calls in a browser need Accessibility.", isOn: setting(\.detectMeetings))
                    RowDivider()
                    SettingToggle("Open at login", caption: "Have BetterWispr ready when your Mac starts.", isOn: setting(\.launchAtLogin))
                    RowDivider()
                    SettingToggle("Save dictation history", caption: "Keep text on this Mac so you can find and reuse it.", isOn: setting(\.saveHistory))
                }

                SettingsSection("Permissions") {
                    PermissionStatusRow(title: "Microphone", caption: "Needed to hear your voice.", granted: model.microphoneGranted, action: model.requestMicrophone)
                    RowDivider()
                    PermissionStatusRow(title: "Accessibility", caption: "Needed for automatic paste and modifier-key shortcuts.", granted: model.accessibilityGranted, action: model.requestAccessibility)
                } footer: {
                    Label("Built-in models process speech on this Mac. A selected API connection sends audio to its endpoint. Temporary recordings are removed after processing; external providers control their own retention.", systemImage: "lock.shield")
                }

                SettingsSection("Voice commands") {
                    ForEach(Array(Self.voiceCommands.enumerated()), id: \.offset) { index, command in
                        if index > 0 { RowDivider() }
                        SettingRow(command.0) {
                            Text(command.1)
                                .font(.callout)
                                .foregroundStyle(.secondary)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 2)
                                .background(Color.primary.opacity(0.06), in: .capsule)
                        }
                        .accessibilityElement(children: .combine)
                    }
                } footer: {
                    Text("Say these while dictating in English or Auto language. Words like “the Oxford comma” stay as written.")
                }
            }
            .padding(.horizontal, 28)
            .padding(.vertical, 24)
            .frame(maxWidth: 680)
            .frame(maxWidth: .infinity)
        }
        .toggleStyle(.switch)
        .animation(.ui, value: model.microphoneGranted)
        .animation(.ui, value: model.accessibilityGranted)
    }

    static let spokenLanguages = [
        (code: "en", name: "English"), (code: "hi", name: "Hindi"), (code: "es", name: "Spanish"),
        (code: "fr", name: "French"), (code: "de", name: "German"), (code: "it", name: "Italian"),
        (code: "pt", name: "Portuguese"), (code: "ja", name: "Japanese"), (code: "ko", name: "Korean"),
        (code: "zh", name: "Chinese"), (code: "ar", name: "Arabic"),
    ]

    private var languageChoices: [(code: String, name: String)] {
        let selected = model.selectedModel
        let choices = selected.languages.map { codes in
            codes.map { (code: $0, name: Locale.current.localizedString(forLanguageCode: $0) ?? $0) }.sorted { $0.name < $1.name }
        } ?? Self.spokenLanguages
        let current = model.settings.language
        guard current != "auto", !choices.contains(where: { $0.code == current }) else { return choices }
        let name = Locale.current.localizedString(forLanguageCode: current) ?? current
        return choices + [(code: current, name: "\(name) (not supported by \(selected.name))")]
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
        SettingRow("Keyboard shortcut", caption: caption) {
            HStack(spacing: 6) {
                if shortcut != .optionSpace, !isCapturing {
                    Button("Reset to \(DictationShortcut.optionSpace.spokenName)", systemImage: "arrow.counterclockwise") {
                        stop()
                        model.changeShortcut(.optionSpace)
                    }
                    .labelStyle(.iconOnly)
                    .buttonStyle(.borderless)
                    .foregroundStyle(.secondary)
                    .help("Reset to \(DictationShortcut.optionSpace.displayName)")
                    .transition(.opacity)
                }
                recordButton
                    .accessibilityLabel(isCapturing ? "Keyboard shortcut, waiting for keys" : "Keyboard shortcut, \(shortcut.spokenName)")
                    .accessibilityHint("Click, then press a shortcut, or press and release a modifier key such as Option.")
            }
            .disabled(model.isBusy)
        }
        .animation(.ui, value: isCapturing)
        .onChange(of: feedback) { _, text in if let text { AccessibilityNotification.Announcement(text).post() } }
        .onDisappear(perform: stop)
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didResignActiveNotification)) { _ in stop() }
    }

    private var caption: String? {
        if isCapturing { return feedback ?? "Press and release ⌃, ⌥, ⇧ or ⌘ alone, use a key combination, or press an F-key. Esc cancels." }
        return shortcut.isModifierOnly ? "Needs Accessibility. Uses the left or right key you recorded." : "Starts dictation from any app."
    }

    @ViewBuilder private var recordButton: some View {
        let button = Button {
            if isCapturing { stop() } else { start() }
        } label: {
            Text(isCapturing ? (held.isEmpty ? "Type shortcut…" : held.symbols + " …") : shortcut.displayName)
                .frame(minWidth: 96)
                .contentTransition(.opacity)
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
            Text(model.automaticMicrophone.map { "Automatic (\($0.name))" } ?? "Automatic").tag(String?.none)
            ForEach(model.microphoneChoices) { device in
                Text(model.microphones.contains { $0.id == device.id } ? device.name : "\(device.name) (not connected)")
                    .tag(Optional(device.id))
            }
        } label: {
            label
        }
    }
}

struct SettingsSection<Content: View, Footer: View>: View {
    let title: String
    @ViewBuilder let content: Content
    @ViewBuilder let footer: Footer

    init(_ title: String, @ViewBuilder content: () -> Content, @ViewBuilder footer: () -> Footer) {
        self.title = title
        self.content = content()
        self.footer = footer()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionHeader(title)
            Card(padding: 0) {
                VStack(spacing: 0) { content }
            }
            footer
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 4)
        }
    }
}

extension SettingsSection where Footer == EmptyView {
    init(_ title: String, @ViewBuilder content: () -> Content) {
        self.init(title, content: content) { EmptyView() }
    }
}

struct SettingRow<Control: View>: View {
    let title: String
    var caption: String?
    @ViewBuilder let control: Control

    init(_ title: String, caption: String? = nil, @ViewBuilder control: () -> Control) {
        self.title = title
        self.caption = caption
        self.control = control()
    }

    var body: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                if let caption {
                    Text(caption)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .contentTransition(.opacity)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            control
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 11)
        .frame(minHeight: 44)
        .animation(.ui, value: caption)
    }
}

struct SettingToggle: View {
    let title: String
    let caption: String?
    @Binding var isOn: Bool

    init(_ title: String, caption: String? = nil, isOn: Binding<Bool>) {
        self.title = title
        self.caption = caption
        _isOn = isOn
    }

    var body: some View {
        SettingRow(title, caption: caption) {
            Toggle(title, isOn: $isOn)
                .labelsHidden()
                .controlSize(.small)
        }
    }
}

struct RowDivider: View {
    var body: some View {
        Divider().padding(.leading, 16)
    }
}

struct PermissionStatusRow: View {
    let title: String
    let caption: String
    let granted: Bool
    let action: () -> Void

    var body: some View {
        SettingRow(title, caption: caption) {
            if granted {
                Label("Allowed", systemImage: "checkmark.circle.fill")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .symbolRenderingMode(.multicolor)
                    .transition(.opacity)
            } else {
                Button("Allow…", action: action)
                    .transition(.opacity)
            }
        }
    }
}
