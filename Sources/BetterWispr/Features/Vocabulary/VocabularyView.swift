import BetterWisprCore
import SwiftUI

struct VocabularyView: View {
    @Bindable var model: AppModel
    @State private var phrase = ""
    @State private var replacement = ""

    private var canAdd: Bool { !phrase.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

    var body: some View {
        Form {
            Section {
                TextField("Spoken phrase", text: $phrase, prompt: Text("better whisper"))
                TextField("Write as", text: $replacement, prompt: Text("Optional, e.g. BetterWispr"))
            } header: {
                Text("Add a Word")
            } footer: {
                HStack(alignment: .top) {
                    Text("Leave “Write as” empty to add a spelling hint. Replacements apply to whole phrases, so unrelated words stay intact.")
                        .foregroundStyle(.secondary)
                    Spacer(minLength: 20)
                    Button("Add Word", action: addEntry)
                        .disabled(!canAdd)
                }
            }
            .onSubmit { if canAdd { addEntry() } }

            if model.selectedModel.engine == .parakeet {
                phraseBoosterSection
            }

            Section {
                if model.vocabulary.isEmpty {
                    Text("Add a name that often gets misspelled, a technical term or a phrase you use every day.")
                        .foregroundStyle(.secondary)
                }
                ForEach(model.vocabulary) { entry in
                    LabeledContent(entry.phrase) {
                        HStack(spacing: 10) {
                            Text(entry.replacement.isEmpty ? entry.phrase : entry.replacement)
                                .foregroundStyle(.primary)
                            Button { model.deleteVocabulary(entry) } label: {
                                Image(systemName: "minus.circle.fill")
                            }
                            .buttonStyle(.borderless)
                            .foregroundStyle(.secondary)
                            .help("Remove \(entry.phrase)")
                            .accessibilityLabel("Remove \(entry.phrase)")
                        }
                    }
                }
            } header: {
                if model.vocabulary.isEmpty {
                    Text("Your Vocabulary")
                } else {
                    Text("^[\(model.vocabulary.count) entry](inflect: true)")
                }
            }
        }
        .formStyle(.grouped)
    }

    private var phraseBoosterSection: some View {
        Section {
            if model.phraseBoosterInstalled {
                Label("Phrase booster is on. Parakeet checks the spelling of these words on this Mac.", systemImage: "checkmark.circle")
                    .foregroundStyle(.secondary)
            } else {
                LabeledContent {
                    if !model.isInstallingPhraseBooster {
                        Button("Download") { model.installPhraseBooster() }
                            .disabled(model.isBusy)
                    }
                } label: {
                    Text("Phrase booster")
                    Text("Helps Parakeet spell the words in this list. About 100 MB, downloads once and runs on this Mac.")
                }
                if model.isInstallingPhraseBooster {
                    ProgressView().progressViewStyle(.linear)
                    Text("Downloading the phrase booster…")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private func addEntry() {
        guard canAdd else { return }
        model.addVocabulary(phrase: phrase, replacement: replacement)
        phrase = ""
        replacement = ""
    }
}
