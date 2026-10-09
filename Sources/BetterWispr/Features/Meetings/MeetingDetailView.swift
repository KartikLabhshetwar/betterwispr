import AppKit
import BetterWisprCore
import SwiftUI

struct MeetingDetailView: View {
    let model: AppModel
    let id: UUID
    @State private var tab = Tab.transcript
    @State private var transcriptQuery = ""
    @State private var showsSearch = false
    @State private var showsModelNote = true
    @State private var showsEchoes = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private enum Tab: String, CaseIterable {
        case thoughts = "My thoughts", transcript = "Transcript", summary = "Summary"

        var symbol: String {
            switch self {
            case .thoughts: "square.and.pencil"
            case .transcript: "waveform"
            case .summary: "sparkles"
            }
        }
    }

    var body: some View {
        if let meeting = meetings.meeting(id) {
            VStack(spacing: 0) {
                VStack(alignment: .leading, spacing: 26) {
                    header(meeting)
                    tabs
                }
                .padding(.horizontal, 32)
                .padding(.top, 30)
                .frame(maxWidth: 820, alignment: .leading)
                .frame(maxWidth: .infinity)
                Divider()
                ScrollViewReader { proxy in
                    ScrollView {
                        VStack(alignment: .leading, spacing: 24) {
                            switch tab {
                            case .thoughts: thoughts(meeting)
                            case .transcript: transcript(meeting)
                            case .summary: summary(meeting)
                            }
                        }
                        .padding(32)
                        .frame(maxWidth: 820, alignment: .leading)
                        .frame(maxWidth: .infinity)
                    }
                    .onChange(of: meeting.segments.count) {
                        guard tab == .transcript, isRecording, transcriptQuery.isEmpty else { return }
                        withAnimation(reduceMotion ? nil : .easeOut(duration: 0.25)) { proxy.scrollTo(Self.listeningAnchor, anchor: .bottom) }
                    }
                }
                footer(meeting)
            }
            .onAppear { tab = meetings.isActive(id) || meeting.summary == nil ? .transcript : .summary }
            .onChange(of: meeting.summary?.generatedAt) { if meeting.summary != nil { tab = .summary } }
        }
    }

    private var meetings: MeetingModel { model.meetings }
    private var isRecording: Bool { meetings.activity.capturingID == id }
    private var isActive: Bool { meetings.isActive(id) }

    private func header(_ meeting: Meeting) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            TextField("New note", text: text(\.title), axis: .vertical)
                .textFieldStyle(.plain)
                .font(.system(size: 38, weight: .regular, design: .serif))
                .accessibilityLabel("Meeting title")
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 12) {
                    dateLabel(meeting)
                    modelLabel(meeting)
                }
                VStack(alignment: .leading, spacing: 8) {
                    dateLabel(meeting)
                    modelLabel(meeting)
                }
            }
        }
    }

    private func dateLabel(_ meeting: Meeting) -> some View {
        Text(meeting.createdAt.noteDay)
            .font(.callout)
            .foregroundStyle(.secondary)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .overlay(RoundedRectangle(cornerRadius: 7).strokeBorder(.quaternary))
            .help(meeting.createdAt.formatted(date: .long, time: .shortened))
    }

    private func modelLabel(_ meeting: Meeting) -> some View {
        Label(meeting.modelName, systemImage: "waveform")
            .font(.callout)
            .foregroundStyle(.secondary)
    }

    private var tabs: some View {
        HStack(spacing: 26) {
            ForEach(Tab.allCases, id: \.self) { item in
                Button { tab = item } label: {
                    Label {
                        Text(item.rawValue)
                    } icon: {
                        if item != .thoughts {
                            Image(systemName: item.symbol)
                                .foregroundStyle(item == .transcript && isRecording ? Color.green : .secondary)
                        }
                    }
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(tab == item ? .primary : .secondary)
                    .padding(.vertical, 13)
                    .overlay(alignment: .bottom) {
                        Rectangle().fill(tab == item ? Color.primary : .clear).frame(height: 2)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(tab == item ? .isSelected : [])
            }
        }
    }

    private func footer(_ meeting: Meeting) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            if isActive, let issue = meetings.systemAudioIssue ?? (meetings.showsCallAudioHint ? Self.callAudioHint : nil) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Image(systemName: "speaker.slash").foregroundStyle(.secondary)
                    Text(issue).foregroundStyle(.secondary)
                    Spacer(minLength: 0)
                    Button("Open Settings") { NSWorkspace.shared.open(Self.audioSettings) }
                }
                .font(.callout)
            }
            switch meetings.activity {
            case .starting(let active) where active == id:
                HStack {
                    progress("Preparing \(meeting.modelName)…")
                    Spacer(minLength: 8)
                    Button("Cancel", action: meetings.stop)
                }
            case .recording(let active) where active == id:
                VStack(spacing: 12) {
                    Text("Always get consent when transcribing others.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                    HStack(spacing: 10) {
                        Button(action: meetings.stop) {
                            Label {
                                Text("Stop")
                            } icon: {
                                RoundedRectangle(cornerRadius: 3).fill(.green).frame(width: 12, height: 12)
                            }
                            .font(.system(size: 14, weight: .semibold))
                            .padding(.horizontal, 16)
                            .frame(height: 38)
                            .overlay(Capsule().strokeBorder(.quaternary))
                            .contentShape(Capsule())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Stop meeting")
                        HStack(spacing: 12) {
                            microphoneMenu
                            Spacer(minLength: 0)
                            LevelMeter(meetings: meetings, speaker: .me, reduceMotion: reduceMotion)
                            LevelMeter(meetings: meetings, speaker: .them, reduceMotion: reduceMotion)
                        }
                        .padding(.horizontal, 14)
                        .frame(height: 38)
                        .overlay(Capsule().strokeBorder(.quaternary))
                    }
                }
                .accessibilityElement(children: .contain)
            case .finishing(let active) where active == id:
                progress("Transcribing the last few seconds…")
            case .generating(let active) where active == id:
                HStack {
                    if let (step, total) = meetings.generationStep, total > 1 {
                        progress("Writing summary… part \(step) of \(total)")
                    } else {
                        progress("Writing summary with \(meetings.notesSettings.notesModelName)…")
                    }
                    Spacer(minLength: 8)
                    Button("Cancel", action: meetings.cancelNotes)
                }
            default:
                HStack {
                    Label("Notes stored on this Mac", systemImage: "internaldrive")
                    Spacer()
                    Text(durationLabel(meeting.duration)).monospacedDigit()
                }
                .font(.callout)
                .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 14)
        .background(.bar)
        .overlay(alignment: .top) { Divider() }
    }

    private var microphoneMenu: some View {
        Menu {
            MicrophonePicker(model: model) { Text("Microphone") }
                .pickerStyle(.inline)
        } label: {
            Label(meetings.microphone?.name ?? "No microphone", systemImage: meetings.microphone == nil ? "mic.slash" : "mic")
        }
        .menuStyle(.borderlessButton)
        .lineLimit(1)
        .help("Choose the microphone for this meeting")
        .accessibilityLabel("Microphone")
        .accessibilityValue(meetings.microphone?.name ?? "None")
    }

    private func progress(_ title: String) -> some View {
        HStack(spacing: 8) {
            ProgressView().controlSize(.small)
            Text(title).foregroundStyle(.secondary)
        }
    }

    private func thoughts(_ meeting: Meeting) -> some View {
        VStack(alignment: .leading, spacing: 18) {
            if meeting.summary != nil {
                HStack(spacing: 6) {
                    Text(meeting.summaryNeedsUpdate ? "Include your latest thoughts in the summary." : "Your summary includes these thoughts.")
                    Button("Update summary") { meetings.generateNotes(id) }
                        .disabled(meetings.activity != .idle || meetings.notesAvailability != .available)
                }
                .font(.callout)
                .foregroundStyle(.tertiary)
            } else {
                Text("Your thoughts, in your words.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            TextEditor(text: text(\.notes))
                .font(.system(size: 15))
                .lineSpacing(6)
                .scrollContentBackground(.hidden)
                .frame(minHeight: 300)
                .accessibilityLabel("My thoughts")
                .overlay(alignment: .topLeading) {
                    if meeting.notes.isEmpty {
                        Text("Jot down questions, ideas, or anything you want to remember. Your summary will take these into account.")
                            .font(.system(size: 15))
                            .foregroundStyle(.tertiary)
                            .lineSpacing(6)
                            .padding(.leading, 5)
                            .allowsHitTesting(false)
                    }
                }
        }
    }

    @ViewBuilder private func summary(_ meeting: Meeting) -> some View {
        if let summary = meeting.summary {
            VStack(alignment: .leading, spacing: 26) {
                HStack(alignment: .firstTextBaseline) {
                    if meeting.summaryNeedsUpdate {
                        Text("Update to include your latest thoughts and transcript.")
                            .font(.callout).foregroundStyle(.secondary)
                    }
                    Spacer(minLength: 0)
                    Button("Update summary") { meetings.generateNotes(id) }
                        .disabled(meetings.activity != .idle || meetings.notesAvailability != .available)
                        .help("Combine the full transcript and your current thoughts using \(meetings.notesSettings.notesModelName)")
                }
                if !summary.overview.isEmpty {
                    Text(summary.overview).font(.system(size: 16)).lineSpacing(6).textSelection(.enabled)
                }
                if !summary.keyPoints.isEmpty { section("Key points") { bullets(summary.keyPoints) } }
                if !summary.decisions.isEmpty { section("Decisions") { bullets(summary.decisions) } }
                if !summary.actionItems.isEmpty {
                    section("Action items") {
                        ForEach(summary.actionItems) { item in actionItem(item) }
                    }
                }
                Text(summary.modelName.map { "Generated with \($0)" } ?? "Generated summary")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        } else if isActive {
            VStack(alignment: .leading, spacing: 10) {
                Label("A summary when you’re done", systemImage: "sparkles").font(.headline)
                Text("Finish recording to turn your transcript and thoughts into key points, decisions, and action items.")
                    .foregroundStyle(.secondary)
                if case .unavailable(let reason) = meetings.notesAvailability {
                    Text(reason).font(.callout).foregroundStyle(.secondary)
                }
            }
        } else {
            writeNotesCard(meeting)
        }
    }

    private func section(_ title: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title).font(.headline)
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func bullets(_ items: [String]) -> some View {
        ForEach(Array(items.enumerated()), id: \.offset) { _, item in
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text("•").foregroundStyle(.secondary)
                Text(item).textSelection(.enabled)
            }
        }
    }

    private func actionItem(_ item: ActionItem) -> some View {
        Button { meetings.toggleActionItem(item.id, in: id) } label: {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Image(systemName: item.isDone ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(item.isDone ? Color.accentColor : .secondary)
                Text(item.text)
                    .strikethrough(item.isDone)
                    .foregroundStyle(item.isDone ? .secondary : .primary)
                    .multilineTextAlignment(.leading)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(item.text)
        .accessibilityValue(item.isDone ? "Done" : "Not done")
        .accessibilityAddTraits(.isToggle)
    }

    private func writeNotesCard(_ meeting: Meeting) -> some View {
        let unavailable: String? = switch meetings.notesAvailability {
        case .available: meeting.hasContent ? nil : MeetingNotesError.nothingToSummarize.localizedDescription
        case .unavailable(let reason): reason
        }
        return VStack(alignment: .leading, spacing: 12) {
            Text("Bring it all together").font(.system(size: 24, design: .serif))
            Text("\(meetings.notesSettings.notesModelName) turns your transcript and thoughts into a summary, key points, decisions, and action items.")
                .foregroundStyle(.secondary)
            Button { meetings.generateNotes(id) } label: {
                Label("Generate summary", systemImage: "sparkles")
            }
            .buttonStyle(.borderedProminent)
            .disabled(unavailable != nil || meetings.activity != .idle)
            if let unavailable { Text(unavailable).font(.callout).foregroundStyle(.secondary) }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.quaternary.opacity(0.35), in: RoundedRectangle(cornerRadius: 12))
    }

    @ViewBuilder private func transcript(_ meeting: Meeting) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 12) {
                MeetingClock(meetings: meetings, duration: meeting.duration, isRecording: isRecording)
                Spacer()
                Button { showsSearch.toggle(); transcriptQuery = "" } label: {
                    Image(systemName: "magnifyingglass")
                }
                .help("Find in transcript")
                .accessibilityLabel("Find in transcript")
                Button { meetings.copy(id, transcriptOnly: true) } label: { Image(systemName: "doc.on.doc") }
                    .disabled(meeting.segments.isEmpty)
                    .help("Copy transcript")
                    .accessibilityLabel("Copy transcript")
            }
            .buttonStyle(.borderless)
            .foregroundStyle(.secondary)
            .padding(14)
            if showsSearch {
                TextField("Find in transcript", text: $transcriptQuery)
                    .textFieldStyle(.roundedBorder)
                    .padding(.horizontal, 14)
                    .padding(.bottom, 14)
            }
            if isRecording, showsModelNote {
                HStack(spacing: 8) {
                    Text("Transcribing with \(meeting.modelName).")
                    Spacer(minLength: 0)
                    Button { showsModelNote = false } label: { Image(systemName: "xmark") }
                        .buttonStyle(.borderless)
                        .help("Dismiss")
                        .accessibilityLabel("Dismiss")
                }
                .font(.callout)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(.quaternary.opacity(0.4))
            }
        }
        .background(.quaternary.opacity(0.3), in: RoundedRectangle(cornerRadius: 12))
        .clipShape(RoundedRectangle(cornerRadius: 12))

        if meeting.segments.isEmpty, !isRecording {
            VStack(spacing: 10) {
                Text("No transcript yet")
                    .font(.system(size: 21, design: .serif)).italic()
                Text("Your own thoughts are saved in My thoughts.")
                    .font(.callout)
            }
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 44)
        } else {
            let cleaned = meeting.transcriptSegments
            if cleaned.count < meeting.segments.count {
                Toggle("Show repeated microphone audio", isOn: $showsEchoes)
                    .font(.caption).foregroundStyle(.secondary)
            }
            let segments = (showsEchoes ? meeting.segments : cleaned).filter { transcriptQuery.isEmpty || $0.text.localizedStandardContains(transcriptQuery) }
            if segments.isEmpty, !meeting.segments.isEmpty {
                Text("No matching words").foregroundStyle(.secondary)
            }
            LazyVStack(alignment: .leading, spacing: 18) {
                ForEach(segments) { segment in
                    SegmentRow(segment: segment).id(segment.id)
                }
            }
            if isRecording { listening(meeting) }
        }
        if isActive, !isRecording, meetings.pendingChunks > 0 { progress("Transcribing…") }
    }

    private func listening(_ meeting: Meeting) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Text("Listening…").font(.system(size: 14, weight: .semibold))
                if meetings.pendingChunks > 0 {
                    ProgressView().controlSize(.mini).accessibilityLabel("Transcribing")
                }
            }
            if meeting.segments.isEmpty {
                Text("Words appear here a few seconds after they’re spoken.")
                    .font(.system(size: 15))
                    .foregroundStyle(.tertiary)
                    .bubble()
            }
        }
        .id(Self.listeningAnchor)
    }

    private func text(_ field: WritableKeyPath<Meeting, String>) -> Binding<String> {
        Binding(
            get: { meetings.meeting(id)?[keyPath: field] ?? "" },
            set: { value in meetings.edit(id) { $0[keyPath: field] = value } }
        )
    }

    private static let listeningAnchor = "listening"
    private static let callAudioHint = "BetterWispr hasn’t heard the other side of the call yet. Allow it under Screen & System Audio Recording, and make sure call audio plays on this Mac."
    private static let audioSettings = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture")!
}

/// Reads the audio level in its own body so the meter's many updates a second don't rebuild the transcript.
private struct LevelMeter: View {
    let meetings: MeetingModel
    let speaker: Speaker
    let reduceMotion: Bool

    var body: some View {
        let level = min(1, max(0, speaker == .me ? meetings.levels.me : meetings.levels.them))
        HStack(spacing: 5) {
            Text(speaker.label).font(.caption).foregroundStyle(.secondary)
            Capsule()
                .fill(.quaternary)
                .frame(width: 30, height: 5)
                .overlay(alignment: .leading) {
                    Capsule()
                        .fill(speaker == .me ? Color.green : Color.blue)
                        .frame(width: 30 * CGFloat(level))
                }
                .animation(reduceMotion ? nil : .linear(duration: 0.1), value: level)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(speaker.label) level")
        .accessibilityValue("\(Int(level * 100)) percent")
    }
}

/// Reads the running time in its own body so each tick redraws only the clock.
private struct MeetingClock: View {
    let meetings: MeetingModel
    let duration: TimeInterval
    let isRecording: Bool

    var body: some View {
        Label(durationLabel(isRecording ? meetings.elapsed : duration), systemImage: "clock")
            .monospacedDigit()
    }
}

private struct SegmentRow: View {
    let segment: MeetingSegment

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Circle().fill(segment.speaker == .me ? Color.green : .blue).frame(width: 6, height: 6)
                    .accessibilityHidden(true)
                Text(segment.speaker.label).fontWeight(.semibold)
                Text(segment.timestamp).foregroundStyle(.secondary).monospacedDigit()
            }
            .font(.caption)
            Text(segment.text)
                .font(.system(size: 15))
                .lineSpacing(4)
                .textSelection(.enabled)
                .bubble()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private extension View {
    func bubble() -> some View {
        padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(.quaternary.opacity(0.35), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}
