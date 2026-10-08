import BetterWisprCore
import SwiftUI

struct MeetingsView: View {
    @Bindable var model: AppModel
    @State private var query = ""
    @State private var meetingToDelete: UUID?

    private var meetings: MeetingModel { model.meetings }

    private var filtered: [Meeting] {
        query.isEmpty ? meetings.meetings : meetings.meetings.filter { $0.matches(query) }
    }

    var body: some View {
        Group {
            if meetings.meetings.isEmpty {
                ContentUnavailableView {
                    Label("No Meetings", systemImage: "note.text")
                } description: {
                    Text("Record your microphone and the other side of a call, follow a live transcript, then turn it into notes. Audio never leaves this Mac.")
                    if let message = meetings.message { Text(message).foregroundStyle(.orange) }
                } actions: {
                    Button("Start Meeting", action: model.startMeeting)
                        .buttonStyle(.borderedProminent)
                        .disabled(meetings.activity != .idle)
                }
            } else {
                HStack(spacing: 0) {
                    MeetingList(meetings: meetings, filtered: filtered, query: query)
                        .frame(width: 240)
                    Divider()
                    Group {
                        if let id = meetings.selectedID, meetings.meeting(id) != nil {
                            MeetingDetailView(meetings: meetings, id: id).id(id)
                        } else {
                            ContentUnavailableView("No Meeting Selected", systemImage: "note.text")
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
        }
        .searchable(text: $query, prompt: "Search meetings")
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

    @ToolbarContentBuilder private var toolbar: some ToolbarContent {
        ToolbarItemGroup {
            if meetings.activity.capturingID != nil {
                Button(action: meetings.stop) {
                    Label("Stop", systemImage: "stop.fill")
                }
                .help("Stop recording")
            }
            Button(action: model.startMeeting) {
                Label("New Meeting", systemImage: "square.and.pencil")
            }
            .help("Start a new meeting")
            .disabled(meetings.activity != .idle)
            if let meeting = meetings.selected {
                Button { meetings.copy(meeting.id) } label: {
                    Label("Copy", systemImage: "doc.on.doc")
                }
                .help("Copy notes and transcript")
                if meeting.summary != nil {
                    Button { meetings.generateNotes(meeting.id) } label: {
                        Label("Write Notes Again", systemImage: "sparkles")
                    }
                    .help("Write the notes again")
                    .disabled(meetings.activity != .idle || meetings.notesAvailability != .available)
                }
                Button { meetingToDelete = meeting.id } label: {
                    Label("Delete", systemImage: "trash")
                }
                .help("Delete meeting")
                .disabled(meetings.isActive(meeting.id))
            }
        }
    }
}

private struct MeetingList: View {
    @Bindable var meetings: MeetingModel
    let filtered: [Meeting]
    let query: String

    var body: some View {
        if filtered.isEmpty {
            ContentUnavailableView.search(text: query)
        } else {
            List(selection: $meetings.selectedID) {
                ForEach(MeetingSection.group(filtered), id: \.title) { section in
                    Section(section.title) {
                        ForEach(section.meetings) { meeting in
                            MeetingRow(meeting: meeting, isLive: isLive(meeting.id)).tag(meeting.id)
                        }
                    }
                }
            }
        }
    }

    private func isLive(_ id: UUID) -> Bool {
        switch meetings.activity {
        case .starting(let active), .recording(let active), .finishing(let active): active == id
        default: false
        }
    }
}

private struct MeetingRow: View {
    let meeting: Meeting
    let isLive: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 4) {
                Text(meeting.displayTitle).fontWeight(.semibold).lineLimit(1)
                if isLive {
                    Image(systemName: "record.circle.fill")
                        .foregroundStyle(.red)
                        .accessibilityLabel("Recording")
                }
            }
            HStack(spacing: 6) {
                Text(Calendar.current.isDateInToday(meeting.createdAt)
                     ? meeting.createdAt.formatted(date: .omitted, time: .shortened)
                     : meeting.createdAt.formatted(date: .numeric, time: .omitted))
                Text(meeting.snippet.isEmpty ? "No transcript yet" : meeting.snippet).lineLimit(1)
            }
            .font(.callout)
            .foregroundStyle(.secondary)
        }
        .padding(.vertical, 3)
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
