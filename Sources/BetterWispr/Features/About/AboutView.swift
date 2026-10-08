import BetterWisprCore
import SwiftUI

struct AboutView: View {
    @Bindable var updater: AppUpdater
    let shortcut: DictationShortcut
    private let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "Development"
    private let repository = URL(string: "https://github.com/KartikLabhshetwar/betterwispr")!

    var body: some View {
        Form {
            Section {
                VStack(spacing: 10) {
                    BrandMark(size: 72)
                    Text("BetterWispr").font(.title.weight(.semibold))
                    Text("Version \(version)")
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                    Text("Private dictation for your Mac. Press \(shortcut.displayName) in any app, speak, and your words appear where you’re typing. Speech is processed on this Mac.")
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: 480)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
            }

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

            Section {
                LabeledContent {
                    Link("View on GitHub", destination: repository)
                } label: {
                    Text("Source code")
                    Text("Browse the code and every release.")
                }
                LabeledContent {
                    Link("Open an Issue", destination: repository.appending(path: "issues"))
                } label: {
                    Text("Feedback")
                    Text("Report a bug or suggest a feature.")
                }
            } header: {
                Text("Open Source")
            } footer: {
                Text("BetterWispr is free and open source under the Apache 2.0 license. If it saves you some typing, a star on GitHub helps others find it.")
                    .foregroundStyle(.secondary)
            }

            Section("Credits") {
                LabeledContent("Created by", value: "Kartik Labhshetwar")
                LabeledContent("Follow along") {
                    Link("@code_kartik on X", destination: URL(string: "https://x.com/code_kartik")!)
                }
            }
        }
        .formStyle(.grouped)
        .toggleStyle(.switch)
    }
}
