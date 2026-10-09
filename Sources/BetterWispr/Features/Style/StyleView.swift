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

    var symbol: String {
        switch self {
        case .personal: "bubble.left.and.bubble.right"
        case .work: "briefcase"
        case .email: "envelope"
        case .other: "square.grid.2x2"
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
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private static let spokenSample = "um hey Sam are we are we still on for lunch? I think uh we should leave early to beat the traffic."

    var body: some View {
        let recentApps = recentAppsByContext
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                SettingsSection("Cleanup in every app") {
                    SettingRow("Auto cleanup", caption: model.settings.cleanup.detail) {
                        Picker("Auto cleanup", selection: setting(\.cleanup).animation(reveal)) {
                            ForEach(CleanupLevel.allCases, id: \.self) { Text($0.title).tag($0) }
                        }
                        .pickerStyle(.segmented)
                        .labelsHidden()
                        .fixedSize()
                    }
                    VStack(alignment: .leading, spacing: 10) {
                        example("You say", Self.spokenSample, emphasized: false)
                        Image(systemName: "arrow.down")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.tertiary)
                            .accessibilityHidden(true)
                        example("BetterWispr types", cleanedSample, emphasized: true)
                    }
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.primary.opacity(0.04), in: .rect(cornerRadius: 8, style: .continuous))
                    .padding([.horizontal, .bottom], 16)
                    if model.settings.cleanup == .medium {
                        RowDivider()
                        VStack(alignment: .leading, spacing: 8) {
                            NotesModelPicker(model: model)
                                .disabled(!model.canEditConnections)
                            if case .unavailable(let reason) = MeetingNotesGenerator.availability(settings: model.settings) {
                                Label("\(reason) Until then, Medium dictations get Light cleanup.", systemImage: "exclamationmark.triangle")
                                    .font(.callout)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 11)
                        .transition(.opacity)
                    }
                } footer: {
                    Text(cleanupFooter)
                }

                VStack(alignment: .leading, spacing: 8) {
                    SectionHeader("Tone by app")
                    VStack(spacing: 12) {
                        ForEach(StyleContext.allCases, id: \.self) { context in
                            toneCard(context, recentApps: recentApps[context])
                        }
                    }
                }
            }
            .padding(.horizontal, 28)
            .padding(.vertical, 24)
            .frame(maxWidth: 680)
            .frame(maxWidth: .infinity)
        }
        .task { await model.meetings.refreshOllamaModels() }
    }

    private func toneCard(_ context: StyleContext, recentApps: String?) -> some View {
        let selected = model.settings.tone(for: context)
        return Card {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: context.symbol)
                        .foregroundStyle(.secondary)
                        .frame(width: 30, height: 30)
                        .background(Color.primary.opacity(0.06), in: .rect(cornerRadius: 8, style: .continuous))
                        .accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(context.title)
                            .font(.body.weight(.medium))
                        Text(selected.detail)
                            .font(.callout)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    Picker("\(context.title) tone", selection: tone(context).animation(reveal)) {
                        ForEach(context.tones, id: \.self) { Text($0.title).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                    .fixedSize()
                }
                Text(StyleFormatter.apply(selected, to: context.sample))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(12)
                    .background(Color.primary.opacity(0.04), in: .rect(cornerRadius: 8, style: .continuous))
                    .accessibilityLabel("Example: \(StyleFormatter.apply(selected, to: context.sample))")
                Text([context.apps, recentApps].compactMap { $0 }.joined(separator: " "))
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var reveal: Animation? { reduceMotion ? nil : .smooth(duration: 0.25) }

    private var recentAppsByContext: [StyleContext: String] {
        Dictionary(grouping: Set(model.history.compactMap(\.appBundleID)), by: { AppCategory(bundleID: $0).style }).compactMapValues { ids in
            let names = ids.compactMap { NSWorkspace.shared.urlForApplication(withBundleIdentifier: $0)?.deletingPathExtension().lastPathComponent }.sorted()
            return names.isEmpty ? nil : "Your recent dictations here went to \(ListFormatter.localizedString(byJoining: names))."
        }
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

    private func example(_ title: String, _ text: String, emphasized: Bool) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(.callout)
                .foregroundStyle(.secondary)
            Text(text)
                .foregroundStyle(emphasized ? .primary : .secondary)
                .fixedSize(horizontal: false, vertical: true)
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
