import AppKit
import BetterWisprCore
import SwiftUI

struct MeetingDetailView: View {
    @Bindable var meetings: MeetingModel
    let id: UUID
    @State private var tab = Tab.notes
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private enum Tab { case notes, transcript }

    var body: some View {
        if let meeting = meetings.meeting(id) {
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        header(meeting)
                        banner
                        Picker("View", selection: $tab) {
                            Text("Notes").tag(Tab.notes)
                            Text("Transcript").tag(Tab.transcript)
                        }
                        .pickerStyle(.segmented)
                        .labelsHidden()
                        .frame(width: 220)
                        .frame(maxWidth: .infinity)
                        switch tab {
                        case .notes: notes(meeting)
                        case .transcript: transcript(meeting)
                        }
                    }
                    .padding(.horizontal, 32)
                    .padding(.vertical, 24)
                    .frame(maxWidth: 720)
                    .frame(maxWidth: .infinity)
                }
                .onChange(of: meeting.segments.count) {
                    guard tab == .transcript, isRecording, let last = meetings.meeting(id)?.segments.last?.id else { return }
                    withAnimation(reduceMotion ? nil : .easeOut(duration: 0.25)) { proxy.scrollTo(last, anchor: .bottom) }
                }
            }
            .onAppear { meetings.notesAvailability = MeetingNotesGenerator.availability }
        }
    }

    private var isRecording: Bool { meetings.activity.capturingID == id }

    private func header(_ meeting: Meeting) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(meeting.createdAt.formatted(date: .long, time: .shortened))
                .font(.callout)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity)
            TextField("New Meeting", text: text(\.title), axis: .vertical)
                .textFieldStyle(.plain)
                .font(.system(size: 26, weight: .bold))
            Text([durationLabel(isRecording ? meetings.elapsed : meeting.duration), meeting.modelName, "On this Mac"].joined(separator: " · "))
                .font(.callout)
                .foregroundStyle(.secondary)
                .monospacedDigit()
        }
    }

    @ViewBuilder private var banner: some View {
        switch meetings.activity {
        case .starting(let active) where active == id:
            HStack {
                progress("Getting ready to record…")
                Spacer(minLength: 8)
                Button("Cancel", action: meetings.stop)
            }
        case .recording(let active) where active == id:
            recordingBanner
        case .finishing(let active) where active == id:
            progress("Transcribing the last few seconds…")
        case .generating(let active) where active == id:
            if let (step, total) = meetings.generationStep, total > 1 {
                progress("Writing notes on this Mac… part \(step) of \(total)")
            } else {
                progress("Writing notes on this Mac…")
            }
        default:
            EmptyView()
        }
        if let message = meetings.message {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.orange)
                Text(message).textSelection(.enabled)
                Spacer(minLength: 0)
                Button {
                    meetings.message = nil
                } label: {
                    Image(systemName: "xmark")
                }
                .buttonStyle(.borderless)
                .accessibilityLabel("Dismiss")
            }
            .font(.callout)
            .padding(10)
            .background(.orange.opacity(0.1), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
    }

    private var recordingBanner: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 12) {
                Image(systemName: "circle.fill")
                    .font(.system(size: 9))
                    .foregroundStyle(.red)
                    .symbolEffect(.pulse, isActive: !reduceMotion)
                    .accessibilityHidden(true)
                Text("Recording").fontWeight(.semibold)
                Text(durationLabel(meetings.elapsed)).monospacedDigit().foregroundStyle(.secondary)
                Spacer(minLength: 8)
                LevelMeter(label: "Me", level: meetings.levels.me, reduceMotion: reduceMotion)
                LevelMeter(label: "Them", level: meetings.levels.them, reduceMotion: reduceMotion)
                Button(action: meetings.stop) {
                    Label("Stop", systemImage: "stop.fill")
                }
                .buttonStyle(.borderedProminent)
                .tint(.red)
            }
            if let issue = meetings.systemAudioIssue ?? (meetings.showsCallAudioHint ? Self.callAudioHint : nil) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Image(systemName: "speaker.slash").foregroundStyle(.secondary)
                    Text(issue).foregroundStyle(.secondary)
                    Spacer(minLength: 0)
                    Button("Open Settings") { NSWorkspace.shared.open(Self.audioSettings) }
                }
                .font(.callout)
            }
        }
        .padding(12)
        .background(.red.opacity(0.08), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private func progress(_ title: String) -> some View {
        HStack(spacing: 8) {
            ProgressView().controlSize(.small)
            Text(title).foregroundStyle(.secondary)
        }
    }

    @ViewBuilder private func notes(_ meeting: Meeting) -> some View {
        VStack(alignment: .leading, spacing: 22) {
            if let summary = meeting.summary {
                if !summary.overview.isEmpty {
                    section("Summary") { Text(summary.overview).textSelection(.enabled) }
                }
                if !summary.keyPoints.isEmpty { section("Key Points") { bullets(summary.keyPoints) } }
                if !summary.decisions.isEmpty { section("Decisions") { bullets(summary.decisions) } }
                if !summary.actionItems.isEmpty {
                    section("Action Items") {
                        ForEach(summary.actionItems) { item in actionItem(item) }
                    }
                }
            } else if meetings.activity.meetingID != id {
                writeNotesCard(meeting)
            }
            section("My Notes") {
                TextEditor(text: text(\.notes))
                    .font(.body)
                    .scrollContentBackground(.hidden)
                    .frame(minHeight: 180)
                    .overlay(alignment: .topLeading) {
                        if meeting.notes.isEmpty {
                            Text("Type your own notes. The summary will follow them.")
                                .foregroundStyle(.tertiary)
                                .padding(.leading, 5)
                                .allowsHitTesting(false)
                        }
                    }
            }
        }
    }

    private func section(_ title: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(.title3.weight(.semibold))
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
        Button {
            meetings.toggleActionItem(item.id, in: id)
        } label: {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Image(systemName: item.isDone ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(item.isDone ? Color.yellow : Color.secondary)
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
        return VStack(alignment: .leading, spacing: 10) {
            Text("Turn this meeting into notes").font(.headline)
            Text("Apple Intelligence writes a summary, key points, decisions and action items on this Mac.")
                .foregroundStyle(.secondary)
            Button {
                meetings.generateNotes(id)
            } label: {
                Label("Write Notes", systemImage: "sparkles")
            }
            .buttonStyle(.borderedProminent)
            .disabled(unavailable != nil || meetings.activity != .idle)
            if let unavailable {
                Text(unavailable).font(.callout).foregroundStyle(.secondary)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    @ViewBuilder private func transcript(_ meeting: Meeting) -> some View {
        if meeting.segments.isEmpty {
            Text("The transcript appears here as people speak.")
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 40)
        }
        LazyVStack(spacing: 12) {
            ForEach(meeting.segments) { segment in
                SegmentBubble(segment: segment).id(segment.id)
            }
        }
        if meetings.activity.meetingID == id, meetings.pendingChunks > 0 {
            progress("Transcribing…")
        }
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
                .frame(width: 44, height: 5)
                .overlay(alignment: .leading) {
                    Capsule()
                        .fill(label == "Me" ? Color.yellow : Color.blue)
                        .frame(width: 44 * CGFloat(min(1, max(0, level))))
                }
                .animation(reduceMotion ? nil : .linear(duration: 0.1), value: level)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(label) level")
        .accessibilityValue("\(Int(min(1, max(0, level)) * 100)) percent")
    }
}

private struct SegmentBubble: View {
    let segment: MeetingSegment

    var body: some View {
        let mine = segment.speaker == .me
        VStack(alignment: mine ? .trailing : .leading, spacing: 3) {
            Text("\(segment.speaker.label) · \(segment.timestamp)")
                .font(.caption)
                .foregroundStyle(.secondary)
                .monospacedDigit()
            Text(segment.text)
                .textSelection(.enabled)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(mine ? AnyShapeStyle(Color.yellow.opacity(0.22)) : AnyShapeStyle(.quaternary),
                            in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .frame(maxWidth: 520, alignment: mine ? .trailing : .leading)
        .frame(maxWidth: .infinity, alignment: mine ? .trailing : .leading)
    }
}
