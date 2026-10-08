import AppKit
import BetterWisprCore
import SwiftUI

struct MeetingDetailView: View {
    @Bindable var meetings: MeetingModel
    let id: UUID
    @State private var tab = Tab.transcript
    @State private var transcriptQuery = ""
    @State private var showsSearch = false
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
                        guard tab == .transcript, isRecording, transcriptQuery.isEmpty,
                              let last = meetings.meeting(id)?.segments.last?.id else { return }
                        withAnimation(reduceMotion ? nil : .easeOut(duration: 0.25)) { proxy.scrollTo(last, anchor: .bottom) }
                    }
                }
                footer(meeting)
            }
            .onAppear {
                meetings.notesAvailability = MeetingNotesGenerator.availability
                tab = meetings.isActive(id) || meeting.summary == nil ? .transcript : .summary
            }
        }
    }

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
        Text(Calendar.current.isDateInToday(meeting.createdAt) ? "Today" : meeting.createdAt.formatted(date: .abbreviated, time: .omitted))
            .font(.callout)
            .foregroundStyle(.secondary)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(.quaternary.opacity(0.35), in: RoundedRectangle(cornerRadius: 7))
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
                HStack(spacing: 12) {
                    Image(systemName: "circle.fill")
                        .font(.system(size: 8))
                        .foregroundStyle(.red)
                        .accessibilityHidden(true)
                    Text(durationLabel(meetings.elapsed)).monospacedDigit()
                        .accessibilityLabel("Recording time")
                    Spacer(minLength: 4)
                    LevelMeter(label: "Me", level: meetings.levels.me, reduceMotion: reduceMotion)
                    LevelMeter(label: "Them", level: meetings.levels.them, reduceMotion: reduceMotion)
                    Button(action: meetings.stop) { Label("Stop", systemImage: "stop.fill") }
                        .buttonStyle(.borderedProminent)
                        .tint(.red)
                }
                .accessibilityElement(children: .contain)
            case .finishing(let active) where active == id:
                progress("Transcribing the last few seconds…")
            case .generating(let active) where active == id:
                if let (step, total) = meetings.generationStep, total > 1 {
                    progress("Writing summary… part \(step) of \(total)")
                } else {
                    progress("Writing summary on this Mac…")
                }
            default:
                HStack {
                    Label("On this Mac", systemImage: "lock")
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

    private func progress(_ title: String) -> some View {
        HStack(spacing: 8) {
            ProgressView().controlSize(.small)
            Text(title).foregroundStyle(.secondary)
        }
    }

    private func thoughts(_ meeting: Meeting) -> some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Your thoughts, in your words.")
                .font(.callout)
                .foregroundStyle(.secondary)
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
                Text("Generated on this Mac with Apple Intelligence")
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
            Text("Apple Intelligence turns your transcript and thoughts into a summary, key points, decisions, and action items.")
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
                Label(durationLabel(isRecording ? meetings.elapsed : meeting.duration), systemImage: "clock")
                    .monospacedDigit()
                Spacer()
                Button { showsSearch.toggle(); transcriptQuery = "" } label: {
                    Image(systemName: "magnifyingglass")
                }
                .help("Find in transcript")
                .accessibilityLabel("Find in transcript")
                Button { meetings.copyTranscript(id) } label: { Image(systemName: "doc.on.doc") }
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
            if isRecording {
                Text("Transcribed on this Mac with \(meeting.modelName).")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(.quaternary.opacity(0.4))
            }
        }
        .background(.quaternary.opacity(0.3), in: RoundedRectangle(cornerRadius: 12))
        .clipShape(RoundedRectangle(cornerRadius: 12))

        if meeting.segments.isEmpty {
            VStack(spacing: 10) {
                Text(isRecording ? "Listening…" : "No transcript yet")
                    .font(.system(size: 21, design: .serif)).italic()
                Text(isRecording ? "Words appear as each audio segment is transcribed." : "Your own thoughts are saved in My thoughts.")
                    .font(.callout)
            }
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 44)
        } else {
            let segments = meeting.segments.filter { transcriptQuery.isEmpty || $0.text.localizedStandardContains(transcriptQuery) }
            if segments.isEmpty {
                Text("No matching words").foregroundStyle(.secondary)
            }
            LazyVStack(alignment: .leading, spacing: 24) {
                ForEach(segments) { segment in
                    SegmentRow(segment: segment).id(segment.id)
                }
            }
        }
        if isActive, meetings.pendingChunks > 0 { progress("Transcribing…") }
    }

    private func text(_ field: WritableKeyPath<Meeting, String>) -> Binding<String> {
        Binding(
            get: { meetings.meeting(id)?[keyPath: field] ?? "" },
            set: { value in meetings.edit(id) { $0[keyPath: field] = value } }
        )
    }

    private static let callAudioHint = "BetterWispr hasn’t heard the other side of the call yet. Allow it under Screen & System Audio Recording, and make sure call audio plays on this Mac."
    private static let audioSettings = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture")!
}

private struct LevelMeter: View {
    let label: String
    let level: Float
    let reduceMotion: Bool

    var body: some View {
        HStack(spacing: 5) {
            Text(label).font(.caption).foregroundStyle(.secondary)
            Capsule()
                .fill(.quaternary)
                .frame(width: 30, height: 5)
                .overlay(alignment: .leading) {
                    Capsule()
                        .fill(label == "Me" ? Color.green : Color.blue)
                        .frame(width: 30 * CGFloat(min(1, max(0, level))))
                }
                .animation(reduceMotion ? nil : .linear(duration: 0.1), value: level)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(label) level")
        .accessibilityValue("\(Int(min(1, max(0, level)) * 100)) percent")
    }
}

private struct SegmentRow: View {
    let segment: MeetingSegment

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Circle().fill(segment.speaker == .me ? Color.green : .blue).frame(width: 6, height: 6)
                    .accessibilityHidden(true)
                Text(segment.speaker.label).fontWeight(.semibold)
                Text(segment.timestamp).foregroundStyle(.secondary).monospacedDigit()
            }
            .font(.callout)
            Text(segment.text)
                .font(.system(size: 15))
                .lineSpacing(5)
                .textSelection(.enabled)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
