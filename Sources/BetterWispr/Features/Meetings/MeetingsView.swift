import BetterWisprCore
import SwiftUI

struct MeetingsView: View {
    @Bindable var model: AppModel
    @State private var meetingToDelete: UUID?

    private var meetings: MeetingModel { model.meetings }

    var body: some View {
        VStack(spacing: 0) {
            if let message = meetings.message {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.orange)
                    Text(message).textSelection(.enabled)
                    Spacer(minLength: 0)
                    Button { meetings.message = nil } label: { Image(systemName: "xmark") }
                        .buttonStyle(.borderless)
                        .accessibilityLabel("Dismiss meeting message")
                }
                .font(.callout)
                .padding(12)
                .background(.orange.opacity(0.1))
            }
            if let id = meetings.selectedID, meetings.meeting(id) != nil {
                MeetingDetailView(meetings: meetings, id: id).id(id)
            } else {
                emptyState
            }
        }
        .background(Color(nsColor: .textBackgroundColor))
        .toolbar { toolbar }
        .alert("Delete this meeting?", isPresented: Binding(
            get: { meetingToDelete != nil },
            set: { if !$0 { meetingToDelete = nil } }
        )) {
            Button("Cancel", role: .cancel) { meetingToDelete = nil }
            Button("Delete", role: .destructive) {
                if let meetingToDelete { meetings.delete(meetingToDelete) }
                meetingToDelete = nil
            }
        } message: {
            Text("This removes the meeting, its notes and transcript from this Mac. It cannot be undone.")
        }
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 20) {
            Image(systemName: "note.text")
                .font(.system(size: 32, weight: .light))
                .foregroundStyle(.secondary)
            Text("Be in the conversation.")
                .font(.system(size: 36, weight: .regular, design: .serif))
            Text("Keep your thoughts, follow the transcript, and leave with a summary.")
                .font(.body)
                .foregroundStyle(.secondary)
                .lineSpacing(4)
            Button(action: model.startMeeting) {
                Label("Start meeting", systemImage: "mic.fill")
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(meetings.activity != .idle || model.isBusy)
            Label(model.selectedModel.name, systemImage: "waveform")
                .font(.callout)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: 420, alignment: .leading)
        .padding(40)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    @ToolbarContentBuilder private var toolbar: some ToolbarContent {
        ToolbarItemGroup {
            if meetings.activity.capturingID != nil {
                Button(action: meetings.stop) {
                    Label("Stop meeting", systemImage: "stop.fill")
                }
                .help("Stop recording")
            }
            Button(action: model.startMeeting) {
                Label("New meeting", systemImage: "square.and.pencil")
            }
            .help("Start a new meeting")
            .disabled(meetings.activity != .idle || model.isBusy)
            if let meeting = meetings.selected {
                Button { meetings.copy(meeting.id) } label: {
                    Label("Copy", systemImage: "doc.on.doc")
                }
                .help("Copy notes and transcript")
                Menu {
                    Button { meetings.generateNotes(meeting.id) } label: {
                        Label(meeting.summary == nil ? "Generate summary" : "Regenerate summary", systemImage: "sparkles")
                    }
                    .disabled(!meeting.hasContent || meetings.activity != .idle || meetings.notesAvailability != .available)
                    Divider()
                    Button(role: .destructive) { meetingToDelete = meeting.id } label: {
                        Label("Delete meeting…", systemImage: "trash")
                    }
                    .disabled(meetings.isActive(meeting.id))
                } label: {
                    Label("More", systemImage: "ellipsis")
                }
                .help("More meeting actions")
            }
        }
    }
}

struct MeetingsSidebar: View {
    @Bindable var model: AppModel
    @State private var query = ""

    private var meetings: MeetingModel { model.meetings }
    private var filtered: [Meeting] {
        query.isEmpty ? meetings.meetings : meetings.meetings.filter { $0.matches(query) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 18) {
                Button { model.selectedPage = .overview } label: {
                    Label("Back to dictation", systemImage: "chevron.left")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                HStack {
                    Text("Meeting notes").font(.title2.weight(.semibold))
                    Spacer()
                    Button(action: model.startMeeting) {
                        Image(systemName: "square.and.pencil")
                    }
                    .buttonStyle(.borderless)
                    .help("Start a new meeting")
                    .accessibilityLabel("Start a new meeting")
                    .disabled(meetings.activity != .idle || model.isBusy)
                }
                HStack(spacing: 6) {
                    Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                    TextField("Search notes", text: $query)
                        .textFieldStyle(.plain)
                        .accessibilityLabel("Search meeting notes")
                    if !query.isEmpty {
                        Button { query = "" } label: { Image(systemName: "xmark.circle.fill") }
                            .buttonStyle(.borderless)
                            .accessibilityLabel("Clear search")
                    }
                }
                .padding(8)
                .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 8))
            }
            .padding(16)

            if filtered.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text(query.isEmpty ? "A little space for every conversation." : "No matching notes")
                        .fontWeight(.medium)
                    Text(query.isEmpty ? "Your meetings will appear here." : "Try another title or phrase.")
                        .foregroundStyle(.secondary)
                }
                .font(.callout)
                .padding(16)
                Spacer()
            } else {
                MeetingList(meetings: meetings, filtered: filtered)
            }

            Divider()
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Transcription model").font(.caption.weight(.medium)).foregroundStyle(.secondary)
                    Spacer()
                    Button("Manage…") { model.selectedPage = .models }
                        .buttonStyle(.link)
                        .font(.caption)
                }
                Picker("Transcription model", selection: Binding(
                    get: { model.selectedModel.id },
                    set: { id in
                        if let speechModel = model.models.first(where: { $0.id == id }) {
                            model.selectModel(speechModel)
                        }
                    }
                )) {
                    ForEach(model.models) { speechModel in
                        Text(speechModel.name + (model.isModelInstalled(speechModel) ? "" : " · Download in Models"))
                            .tag(speechModel.id)
                            .disabled(!model.isModelInstalled(speechModel))
                    }
                }
                .labelsHidden()
                .disabled(model.isBusy || meetings.activity != .idle)
                Text("Used for dictation and new meetings.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Label(model.selectedModel.engine == .api ? "Audio sent to your selected endpoint" : "On-device transcription",
                      systemImage: model.selectedModel.engine == .api ? "network" : "lock")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(16)
        }
    }
}

private struct MeetingList: View {
    @Bindable var meetings: MeetingModel
    let filtered: [Meeting]

    var body: some View {
        List(selection: $meetings.selectedID) {
            ForEach(MeetingSection.group(filtered), id: \.title) { section in
                Section(section.title) {
                    ForEach(section.meetings) { meeting in
                        MeetingRow(meeting: meeting, activity: meetings.activity).tag(meeting.id)
                    }
                }
            }
        }
        .listStyle(.sidebar)
    }
}

private struct MeetingRow: View {
    let meeting: Meeting
    let activity: MeetingActivity

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(spacing: 6) {
                Text(meeting.displayTitle).fontWeight(.medium).lineLimit(1)
                if activity.meetingID == meeting.id {
                    Image(systemName: activity.capturingID == meeting.id ? "waveform" : "hourglass")
                        .foregroundStyle(activity.capturingID == meeting.id ? .red : .secondary)
                        .accessibilityLabel(activity.capturingID == meeting.id ? "Recording" : "Processing")
                }
            }
            Text(meeting.snippet.isEmpty ? "No transcript yet" : meeting.snippet)
                .font(.callout)
                .foregroundStyle(.secondary)
                .lineLimit(2)
            Text(meeting.createdAt.formatted(date: .omitted, time: .shortened))
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 6)
    }
}

private extension Meeting {
    func matches(_ query: String) -> Bool {
        let summaryText = summary.map { [$0.overview] + $0.keyPoints + $0.decisions + $0.actionItems.map(\.text) } ?? []
        return ([title, notes] + summaryText + segments.map(\.text)).contains { $0.localizedStandardContains(query) }
    }
}

extension AppModel {
    func startMeeting() {
        guard !isBusy, meetings.activity == .idle else { return }
        let speechModel = selectedModel
        guard isModelInstalled(speechModel) else {
            selectedPage = .models
            statusMessage = "Download \(speechModel.name) in Models before starting meeting notes."
            return
        }
        selectedPage = .meetings
        meetings.start(model: speechModel, language: settings.language == "auto" ? nil : settings.language,
                       vocabulary: vocabulary, silenceThreshold: settings.silenceThreshold)
    }
}
