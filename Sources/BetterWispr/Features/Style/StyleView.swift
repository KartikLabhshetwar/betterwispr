import BetterWisprCore
import SwiftUI

private extension StyleContext {
    var title: String {
        switch self {
        case .personal: "Personal messages"
        case .work: "Work messages"
        case .email: "Email"
        case .other: "Other apps"
        }
    }

    var apps: String {
        switch self {
        case .personal: "WhatsApp, Telegram, Discord, Messages, Signal and Messenger."
        case .work: "Slack, Microsoft Teams, Zoom, Webex and Mattermost."
        case .email: "Mail, Outlook, Superhuman, Spark, Mimestream, Airmail and Thunderbird."
        case .other: "ChatGPT, Claude, Cursor, Notes, Notion, browsers and every other app. Browsers use this tone because BetterWispr can’t see which website is open. Tones only change English dictation."
        }
    }

    var sample: String {
        switch self {
        case .personal: "Hey, are you around for dinner tonight? Let's do 7 if that works for you."
        case .work: "Hey, when you have a minute, let's go over the launch numbers."
        case .email: "Hi Sam,\n\nThanks for the quick call today. Looking forward to working together.\n\nBest,\nAlex"
        case .other: "So far, the new plan is working well.\n\nTomorrow I want to finish the draft, especially the summary."
        }
    }
}

private extension StyleTone {
    var title: String {
        switch self {
        case .formal: "Formal"
        case .casual: "Casual"
        case .veryCasual: "Very casual"
        case .excited: "Excited"
        }
    }

    var detail: String {
        switch self {
        case .formal: "Caps and punctuation, exactly as cleaned up."
        case .casual: "Caps, fewer commas and no final period."
        case .veryCasual: "No caps, fewer commas and no final period."
        case .excited: "Ends on an exclamation mark."
        }
    }
}

private extension CleanupLevel {
    var title: String { rawValue.capitalized }

    var detail: String {
        switch self {
        case .none: "Keeps exactly what you said, including filler words."
        case .light: "Removes filler words like “um” and “you know”, stutters like “we we”, and corrections like “at 5, no, at 6”."
        case .medium: "Also edits English dictation for clarity and conciseness with your notes model."
        }
    }
}

struct StyleView: View {
    @Bindable var model: AppModel

    private static let spokenSample = "um hey Sam are we are we still on for lunch? I think uh we should leave early to beat the traffic."

    var body: some View {
        Form {
            Section {
                Picker(selection: setting(\.cleanup)) {
                    ForEach(CleanupLevel.allCases, id: \.self) { Text($0.title).tag($0) }
                } label: {
                    Text("Auto cleanup")
                    Text(model.settings.cleanup.detail)
                }
                .pickerStyle(.segmented)
                example("You say", Self.spokenSample)
                example("BetterWispr types", cleanedSample)
                if model.settings.cleanup == .medium {
                    NotesModelPicker(model: model)
                        .disabled(!model.canEditConnections)
                    if case .unavailable(let reason) = MeetingNotesGenerator.availability(settings: model.settings) {
                        Label("\(reason) Until then, Medium dictations get Light cleanup.", systemImage: "exclamationmark.triangle")
                            .foregroundStyle(.secondary)
                    }
                }
            } header: {
                Text("Every app")
            } footer: {
                Text(cleanupFooter).foregroundStyle(.secondary)
            }

            ForEach(StyleContext.allCases, id: \.self) { context in
                Section {
                    Picker(selection: tone(context)) {
                        ForEach(context.tones, id: \.self) { Text($0.title).tag($0) }
                    } label: {
                        Text("Tone")
                        Text(model.settings.tone(for: context).detail)
                    }
                    .pickerStyle(.segmented)
                    example("Example", StyleFormatter.apply(model.settings.tone(for: context), to: context.sample))
                } header: {
                    Text(context.title)
                } footer: {
                    Text(context.apps).foregroundStyle(.secondary)
                }
            }
        }
        .formStyle(.grouped)
        .task { await model.meetings.refreshOllamaModels() }
    }

    private var cleanedSample: String {
        switch model.settings.cleanup {
        case .none: Self.spokenSample
        case .light: TranscriptCleaner.clean(Self.spokenSample, language: "en")
        case .medium: "Hey Sam, are we still on for lunch? We should leave early to beat the traffic."
        }
    }

    private var cleanupFooter: String {
        let original = "Your original words are never lost. In History, open Original transcription and choose Use Original."
        guard model.settings.cleanup == .medium else { return original }
        let destination = switch model.settings.notesSelection {
        case .apple: "Medium edits with Apple Intelligence on this Mac."
        case .ollama: "Medium edits with Ollama on this Mac."
        case .cli(let cli): "Medium sends English dictation to \(cli.name) through your subscription, which adds a few seconds."
        case .connection: "Medium sends English dictation to \(model.settings.notesModelName) with your API key."
        }
        return "\(destination) It uses the same model as meeting notes, and results vary by model. Other languages, very short dictations and edits that fail, take too long or rewrite too much get Light cleanup. \(original)"
    }

    private func example(_ title: String, _ text: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
            Text(text).foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .combine)
    }

    private func tone(_ context: StyleContext) -> Binding<StyleTone> {
        Binding(get: { model.settings.tone(for: context) },
                set: { model.settings.styles[context] = $0; model.saveSettings() })
    }

    private func setting<Value>(_ keyPath: WritableKeyPath<AppSettings, Value>) -> Binding<Value> {
        Binding(get: { model.settings[keyPath: keyPath] },
                set: { model.settings[keyPath: keyPath] = $0; model.saveSettings() })
    }
}
