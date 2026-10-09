import AppKit
import BetterWisprCore
import SwiftUI

struct MeetingDetailView: View {
    let model: AppModel
    let id: UUID
    @State private var tab = Tab.transcript
    @State private var transcriptQuery = ""
    @State private var showsSearch = false
    @State private var showsEchoes = false
    @Namespace private var tabUnderline
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private enum Tab: String, CaseIterable {
        case thoughts = "My thoughts", transcript = "Transcript", summary = "Summary"
    }

    var body: some View {
        if let meeting = meetings.meeting(id) {
            VStack(spacing: 0) {
                VStack(alignment: .leading, spacing: 20) {
                    header(meeting)
                    tabs
                }
                .padding(.horizontal, 32)
                .padding(.top, 26)
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
                        .padding(.horizontal, 32)
                        .padding(.vertical, 24)
                        .frame(maxWidth: 820, alignment: .leading)
                        .frame(maxWidth: .infinity)
                    }
                    .mask {
                        VStack(spacing: 0) {
                            Color.black
                            LinearGradient(colors: [.black, .clear], startPoint: .top, endPoint: .bottom).frame(height: 24)
                        }
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
        VStack(alignment: .leading, spacing: 8) {
            TextField("New note", text: text(\.title), axis: .vertical)
                .textFieldStyle(.plain)
                .font(.system(size: 34, weight: .regular, design: .serif))
                .accessibilityLabel("Meeting title")
            Text("\(meeting.createdAt.noteDay) · \(meeting.modelName)")
                .font(.callout)
                .foregroundStyle(.secondary)
                .help(meeting.createdAt.formatted(date: .long, time: .shortened))
        }
    }

    private var tabs: some View {
        HStack(spacing: 24) {
            ForEach(Tab.allCases, id: \.self) { item in
                Button { tab = item } label: {
                    Text(item.rawValue)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(tab == item ? .primary : .secondary)
                        .padding(.vertical, 10)
                        .overlay(alignment: .bottom) {
                            if tab == item {
                                Capsule().fill(.primary).frame(height: 2)
                                    .matchedGeometryEffect(id: "underline", in: tabUnderline)
                            }
                        }
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(tab == item ? .isSelected : [])
            }
        }
        .animation(reduceMotion ? nil : .ui, value: tab)
    }

    private func footer(_ meeting: Meeting) -> some View {
        VStack(spacing: 8) {
            if isActive, let issue = meetings.systemAudioIssue ?? (meetings.showsCallAudioHint ? Self.callAudioHint : nil) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Image(systemName: "speaker.slash")
                    Text(issue).fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 0)
                    Button("Open Settings") { NSWorkspace.shared.open(Self.audioSettings) }
                }
                .font(.callout)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 4)
            }
            switch meetings.activity {
            case .starting(let active) where active == id:
                controlBar {
                    progress("Preparing \(meeting.modelName)…")
                    Spacer(minLength: 8)
                    Button("Cancel", action: meetings.stop)
                }
            case .recording(let active) where active == id:
                controlBar {
                    MeetingClock(meetings: meetings, reduceMotion: reduceMotion)
                    VStack(alignment: .leading, spacing: 4) {
                        LevelMeter(meetings: meetings, speaker: .me, reduceMotion: reduceMotion)
                        LevelMeter(meetings: meetings, speaker: .them, reduceMotion: reduceMotion)
                    }
                    Spacer(minLength: 0)
                    microphoneMenu
                    stopButton
                }
                Text("Always get consent when transcribing others.")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            case .finishing(let active) where active == id:
                controlBar {
                    progress("Transcribing the last few seconds…")
                    Spacer(minLength: 0)
                }
            case .generating(let active) where active == id:
                controlBar {
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
                .padding(.horizontal, 4)
                .padding(.vertical, 6)
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 4)
        .padding(.bottom, 14)
        .animation(reduceMotion ? nil : .ui, value: meetings.activity)
    }

    private func controlBar(@ViewBuilder _ content: () -> some View) -> some View {
        HStack(spacing: 12) { content() }
            .padding(.leading, 14)
            .padding(.trailing, 8)
            .frame(minHeight: 48)
            .background(Color.cardFill, in: .rect(cornerRadius: 14, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(Color.cardStroke))
            .shadow(color: .black.opacity(0.06), radius: 10, y: 3)
            .accessibilityElement(children: .contain)
    }

    private var stopButton: some View {
        Button(action: meetings.stop) {
            Label {
                Text("Stop")
            } icon: {
                RoundedRectangle(cornerRadius: 2.5).fill(.white).frame(width: 9, height: 9)
            }
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, 14)
            .frame(height: 32)
            .background(Color.red, in: Capsule())
            .contentShape(Capsule())
        }
        .buttonStyle(PressableButtonStyle())
        .accessibilityLabel("Stop meeting")
    }

    private var microphoneMenu: some View {
        Menu {
            MicrophonePicker(model: model) { Text("Microphone") }
                .pickerStyle(.inline)
        } label: {
            Image(systemName: meetings.microphone == nil ? "mic.slash" : "mic")
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
        .help(meetings.microphone.map { "Microphone: \($0.name)" } ?? "Choose the microphone for this meeting")
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
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 14) {
                if !isRecording {
                    Label(durationLabel(meeting.duration), systemImage: "clock").monospacedDigit()
                }
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
            .font(.callout)
            .foregroundStyle(.secondary)
            if showsSearch {
                TextField("Find in transcript", text: $transcriptQuery)
                    .textFieldStyle(.roundedBorder)
            }
        }

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

    @ViewBuilder private func listening(_ meeting: Meeting) -> some View {
        let indicator = Image(systemName: "waveform")
            .symbolEffect(.variableColor.iterative, options: .repeating, isActive: !reduceMotion)
            .foregroundStyle(.secondary)
            .accessibilityHidden(true)
        if meeting.segments.isEmpty {
            VStack(spacing: 10) {
                indicator.font(.system(size: 26))
                Text("Listening").font(.system(size: 21, design: .serif))
                Text("Words appear here a few seconds after they’re spoken.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 44)
            .id(Self.listeningAnchor)
        } else {
            HStack(spacing: 8) {
                indicator
                Text(meetings.pendingChunks > 0 ? "Transcribing…" : "Listening…")
                    .foregroundStyle(.secondary)
            }
            .font(.callout)
            .id(Self.listeningAnchor)
        }
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
        HStack(spacing: 6) {
            Text(speaker.label)
                .font(.caption2.weight(.medium))
                .foregroundStyle(.secondary)
                .frame(width: 30, alignment: .leading)
            Waveform(mode: .listening(VoiceLevels(values: [level])), animated: !reduceMotion, color: speaker == .me ? .green : .blue, count: 14)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(speaker.label) level")
        .accessibilityValue("\(Int(level * 100)) percent")
    }
}

/// Reads the running time in its own body so each tick redraws only the clock.
private struct MeetingClock: View {
    let meetings: MeetingModel
    let reduceMotion: Bool

    var body: some View {
        HStack(spacing: 7) {
            Image(systemName: "circle.fill")
                .font(.system(size: 8))
                .foregroundStyle(.red)
                .symbolEffect(.pulse, options: .repeating, isActive: !reduceMotion)
            Text(durationLabel(meetings.elapsed))
                .font(.system(size: 15, weight: .semibold).monospacedDigit())
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Recording")
        .accessibilityValue(durationLabel(meetings.elapsed))
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
