import BetterWisprCore
import SwiftUI

struct SettingsView: View {
    @Bindable var model: AppModel

    var body: some View {
        Form {
            Section("Dictation") {
                LabeledContent {
                    KeyboardHint()
                } label: {
                    Text("Keyboard shortcut")
                    Text(model.settings.dictationMode == .hold ? "Hold to speak. Release to finish." : "Press once to speak. Press again or click the capsule to finish.")
                }
                Picker(selection: setting(\.dictationMode)) {
                    Text("Hold to talk").tag(DictationMode.hold)
                    Text("Press to toggle").tag(DictationMode.toggle)
                } label: {
                    Text("Shortcut behavior")
                    Text("Hold ⌥ Space while you speak, or press it once and click the capsule when you’re done.")
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

            UpdatesSection(updater: model.updater)
            AboutSection()
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

private struct UpdatesSection: View {
    @Bindable var updater: AppUpdater

    var body: some View {
        Section {
            Toggle(isOn: $updater.automaticallyChecksForUpdates) {
                Text("Check for updates automatically")
                Text("Looks for a new release on GitHub once a day.")
            }
            Toggle(isOn: $updater.automaticallyDownloadsUpdates) {
                Text("Download and install automatically")
                Text("New versions install the next time BetterWispr quits.")
            }
            .disabled(!updater.automaticallyChecksForUpdates)
            Button("Check for Updates…", action: updater.checkForUpdates)
                .disabled(!updater.canCheckForUpdates)
                .frame(maxWidth: .infinity, alignment: .trailing)
        } header: {
            Text("Updates")
        } footer: {
            Text("Update checks contact GitHub only. They never include your audio or text.")
                .foregroundStyle(.secondary)
        }
    }
}

private struct AboutSection: View {
    private let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "Development"

    var body: some View {
        Section("About") {
            HStack(spacing: 14) {
                BrandMark(size: 52)
                VStack(alignment: .leading, spacing: 3) {
                    Text("BetterWispr").font(.title2.weight(.semibold))
                    Text("Version \(version)").foregroundStyle(.secondary)
                }
            }
            .padding(.vertical, 6)
            LabeledContent("Source code") {
                Link("GitHub", destination: URL(string: "https://github.com/KartikLabhshetwar/betterwispr")!)
            }
            LabeledContent("Made by") {
                Link("@code_kartik on X", destination: URL(string: "https://x.com/code_kartik")!)
            }
        }
    }
}
