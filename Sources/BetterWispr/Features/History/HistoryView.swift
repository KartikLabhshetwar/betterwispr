import BetterWisprCore
import SwiftUI

struct HistoryView: View {
    @Bindable var model: AppModel
    @State private var query = ""
    @State private var transcriptToDelete: Transcript?

    private var filteredHistory: [Transcript] {
        query.isEmpty ? model.history : model.history.filter { $0.text.localizedStandardContains(query) }
    }

    var body: some View {
        Group {
            if filteredHistory.isEmpty {
                if query.isEmpty {
                    ContentUnavailableView(
                        "No Dictations",
                        systemImage: "clock",
                        description: Text("Your saved dictations will appear here. Start speaking with Option Space.")
                    )
                } else {
                    ContentUnavailableView.search(text: query)
                }
            } else {
                Form {
                    Section("^[\(filteredHistory.count) dictation](inflect: true)") {
                        ForEach(filteredHistory) { transcript in
                            TranscriptRow(
                                transcript: transcript,
                                onCopy: { model.copyTranscript(transcript) },
                                onDelete: { transcriptToDelete = transcript },
                                expanded: true
                            )
                        }
                    }
                }
                .formStyle(.grouped)
            }
        }
        .searchable(text: $query, prompt: "Search dictations")
        .alert("Delete this dictation?", isPresented: Binding(
            get: { transcriptToDelete != nil },
            set: { if !$0 { transcriptToDelete = nil } }
        )) {
            Button("Cancel", role: .cancel) { transcriptToDelete = nil }
            Button("Delete", role: .destructive) {
                if let transcriptToDelete { model.deleteTranscript(transcriptToDelete) }
                transcriptToDelete = nil
            }
        } message: {
            Text("This removes the saved text from this Mac. It cannot be undone.")
        }
    }
}

struct TranscriptRow: View {
    let transcript: Transcript
    let onCopy: () -> Void
    var onDelete: (() -> Void)?
    var expanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Text(transcript.createdAt, format: .dateTime.month(.abbreviated).day().hour().minute())
                Text("·")
                Text(durationLabel(transcript.duration)).monospacedDigit()
                if expanded {
                    Text("·")
                    Text(transcript.modelName)
                    Text("·")
                    Text(transcript.language == "auto" ? "Auto language" : transcript.language.uppercased())
                }
                Spacer()
                Button(action: onCopy) { Image(systemName: "doc.on.doc") }
                    .help("Copy dictation")
                    .accessibilityLabel("Copy dictation")
                if let onDelete {
                    Button(action: onDelete) { Image(systemName: "trash") }
                        .help("Delete dictation")
                        .accessibilityLabel("Delete dictation")
                }
            }
            .font(.caption)
            .foregroundStyle(.secondary)
            .buttonStyle(.borderless)
            Text(transcript.text)
                .lineLimit(expanded ? nil : 3)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
            if expanded && transcript.text != transcript.rawText {
                DisclosureGroup("Original transcription") {
                    Text(transcript.rawText)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}
