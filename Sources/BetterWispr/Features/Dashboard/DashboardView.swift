import BetterWisprCore
import SwiftUI

enum AppPage: String, CaseIterable, Identifiable {
    case overview, history, models, vocabulary, settings

    var id: String { rawValue }
    var title: String { rawValue.capitalized }
    var symbol: String {
        switch self {
        case .overview: "square.grid.2x2.fill"
        case .history: "clock.fill"
        case .models: "cpu.fill"
        case .vocabulary: "character.book.closed.fill"
        case .settings: "gearshape.fill"
        }
    }
    var color: Color {
        switch self {
        case .overview: .blue
        case .history: .orange
        case .models: .purple
        case .vocabulary: .green
        case .settings: .gray
        }
    }
}

struct DashboardView: View {
    @Bindable var model: AppModel

    var body: some View {
        NavigationSplitView {
            List(selection: Binding<AppPage?>(
                get: { model.selectedPage },
                set: { if let page = $0 { model.selectedPage = page } }
            )) {
                ForEach(AppPage.allCases) { page in
                    Label {
                        Text(page.title)
                    } icon: {
                        SymbolTile(symbol: page.symbol, color: page.color)
                    }
                    .badge(page == .history ? model.history.count : 0)
                    .tag(page)
                }
            }
            .navigationSplitViewColumnWidth(215)
        } detail: {
            Group {
                switch model.selectedPage {
                case .overview: OverviewView(model: model)
                case .history: HistoryView(model: model)
                case .models: ModelsView(model: model)
                case .vocabulary: VocabularyView(model: model)
                case .settings: SettingsView(model: model)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .navigationTitle(model.selectedPage.title)
            .safeAreaInset(edge: .bottom, spacing: 0) {
                if !model.statusMessage.isEmpty { statusBar }
            }
        }
        .frame(minWidth: 760, minHeight: 520)
    }

    private var statusBar: some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            Image(systemName: model.failure != nil ? "exclamationmark.triangle.fill" : "info.circle")
                .foregroundStyle(model.failure != nil ? Color.red : Color.secondary)
            Text(model.statusMessage)
                .textSelection(.enabled)
            Spacer(minLength: 0)
        }
        .font(.callout)
        .padding(.horizontal, 20)
        .padding(.vertical, 8)
        .background(.bar)
        .overlay(alignment: .top) { Divider() }
    }
}

private struct OverviewView: View {
    @Bindable var model: AppModel

    var body: some View {
        Form {
            Section {
                HStack(spacing: 14) {
                    BrandMark(size: 52)
                    VStack(alignment: .leading, spacing: 3) {
                        Text("BetterWispr").font(.title2.weight(.semibold))
                        Text("Press ⌥ Space in any app to turn your voice into text.")
                            .foregroundStyle(.secondary)
                    }
                    Spacer(minLength: 12)
                    Button(action: model.toggleRecording) {
                        Label(
                            model.phase == .recording ? "Finish Dictation" : "Start Dictating",
                            systemImage: model.phase == .recording ? "stop.fill" : "mic.fill"
                        )
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .disabled(model.phase == .preparing || model.phase == .transcribing)
                }
                .padding(.vertical, 6)
            }

            if !model.partialTranscript.isEmpty && !model.isBusy && !model.settings.saveHistory {
                Section {
                    Text(model.partialTranscript)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                } header: {
                    HStack {
                        Text("Latest Dictation")
                        Spacer()
                        Button("Copy", action: model.copyLatestTranscript)
                    }
                } footer: {
                    Text("History is off. Copy these words before starting another dictation.")
                        .foregroundStyle(.secondary)
                }
            }

            Section("Usage") {
                LabeledContent("Saved words", value: model.totalWords.formatted())
                LabeledContent("Dictation time", value: durationLabel(model.totalDuration))
                LabeledContent("Saved dictations", value: model.history.count.formatted())
            }

            Section("Setup") {
                PermissionRow(title: "Microphone", detail: "Captures your voice.", granted: model.microphoneGranted, action: model.requestMicrophone)
                PermissionRow(title: "Paste into apps", detail: "Optional Accessibility access.", granted: model.accessibilityGranted, action: model.requestAccessibility)
                LabeledContent {
                    Button("Change…") { model.selectedPage = .models }
                } label: {
                    Text("Speech model")
                    Text(model.selectedModel.name)
                }
            }

            Section {
                if model.history.isEmpty {
                    Text("Start a dictation and your words will appear here, ready to copy or use again.")
                        .foregroundStyle(.secondary)
                }
                ForEach(model.history.prefix(3)) { transcript in
                    TranscriptRow(transcript: transcript, onCopy: { model.copyTranscript(transcript) })
                }
            } header: {
                HStack {
                    Text("Recent Dictations")
                    Spacer()
                    if !model.history.isEmpty {
                        Button("Show All") { model.selectedPage = .history }
                            .buttonStyle(.link)
                    }
                }
            }
        }
        .formStyle(.grouped)
    }
}
