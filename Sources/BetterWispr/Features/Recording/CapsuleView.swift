import BetterWisprCore
import SwiftUI

struct CapsuleView: View {
    @Bindable var model: AppModel
    let hover: CapsuleHover
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var isRecording: Bool { model.phase == .recording }
    private var isMeetingCapturing: Bool { model.meetings.activity.capturingID != nil }
    private var isNotetaking: Bool { !model.isBusy && isMeetingCapturing }
    private var isMeetingRecording: Bool {
        if case .recording = model.meetings.activity { true } else { false }
    }
    private var failure: DictationFailure? {
        model.failure ?? (model.phase != .idle ? nil : model.meetings.message.map {
            DictationFailure(title: "Notetaker needs attention", message: $0)
        })
    }
    private var showsCard: Bool {
        switch model.phase {
        case .cancelled, .completed, .unpasted, .failed: true
        default: failure != nil
        }
    }
    private var showsToolbar: Bool { !showsCard && !model.isBusy && !isMeetingCapturing && hover.isHovering }
    private var spring: Animation? { reduceMotion ? nil : .spring(duration: 0.26, bounce: 0) }

    var body: some View {
        VStack(spacing: 6) {
            Spacer(minLength: 0)
            if !showsCard, let target = hover.target {
                tooltip(for: target)
            }
            surface
        }
        .padding(.bottom, 16)
        .frame(width: 440, height: 240)
        .coordinateSpace(name: "capsule")
        .onPreferenceChange(CapsuleRegions.self) { hover.update(regions: $0) }
        .environment(\.colorScheme, .dark)
        .animation(spring, value: model.phase)
        .animation(spring, value: model.isHeldSession)
        .animation(spring, value: model.meetings.activity)
        .animation(spring, value: failure)
        .animation(spring, value: hover.isHovering)
        .animation(reduceMotion ? nil : .easeOut(duration: 0.12), value: hover.target)
        .onChange(of: failure) {
            guard let failure else { return }
            AccessibilityNotification.Announcement("\(failure.title) \(failure.message)").post()
        }
        .onChange(of: model.unpasted) {
            guard model.unpasted != nil else { return }
            AccessibilityNotification.Announcement("Copied, not pasted. Press Command V to paste it.").post()
        }
        .onChange(of: model.phase) {
            switch model.phase {
            case .cancelled:
                AccessibilityNotification.Announcement(model.canUndoCancellation ? "Transcript cancelled. Undo is available for five seconds." : "Transcript cancelled.").post()
            case .completed(let message): AccessibilityNotification.Announcement(message).post()
            default: break
            }
        }
    }

    private var surface: some View {
        VStack(spacing: 0) {
            if let failure {
                failureCard(failure)
                    .transition(.opacity)
            } else if let text = model.unpasted {
                unpastedCard(text)
                    .transition(.opacity)
            } else if model.phase == .cancelled {
                cancellationCard
                    .transition(.opacity)
            } else if case .completed(let message) = model.phase {
                completionCard(message)
                    .transition(.opacity)
            } else if isNotetaking {
                notetakingPill
                    .transition(.opacity)
            } else if model.isBusy {
                dictationPill
                    .transition(.opacity)
            } else if showsToolbar {
                controls
                    .transition(.opacity)
            } else {
                Color.clear.frame(width: 36, height: 6)
            }
        }
        .background {
            if !showsToolbar {
                CapsuleGlass(cornerRadius: model.phase != .idle ? 24 : showsCard ? 22 : 18)
            }
        }
        .overlay(alignment: .bottom) {
            if showsCard, let deadline = model.cardDeadline {
                CapsuleCountdown(deadline: deadline, duration: model.cardDuration)
                    .padding(.horizontal, 22)
                    .allowsHitTesting(false)
            }
        }
        .overlay {
            if isNotetaking && isMeetingRecording && !showsCard {
                Capsule().strokeBorder(Color(red: 0, green: 0.73, blue: 0.51), lineWidth: 1.5)
                    .allowsHitTesting(false)
            }
        }
        .capsuleRegion(.surface)
        .accessibilityElement(children: .contain)
    }

    private func tooltip(for target: CapsuleHover.Target) -> some View {
        HStack(spacing: 4) {
            Text(tooltipTitle(for: target))
            if target == .microphone {
                Text(model.settings.shortcut.displayName).fontWeight(.semibold)
            }
        }
        .font(.system(size: 11, weight: .medium))
        .foregroundStyle(.white)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background { CapsuleGlass(cornerRadius: 14) }
        .allowsHitTesting(false)
        .transition(.opacity)
        .accessibilityElement(children: .combine)
    }

    private func tooltipTitle(for target: CapsuleHover.Target) -> String {
        switch target {
        case .microphone: "Dictate"
        case .notetaker:
            isMeetingCapturing ? "Stop notetaker" : model.meetings.activity == .idle ? "Start notetaker" : "Finishing notes…"
        case .meetingNotes: "Open meeting notes"
        case .dictation:
            switch model.phase {
            case .recording: model.isHeldSession ? "Release \(model.settings.shortcut.displayName) to finish" : "Finish dictation"
            case .transcribing: "Transcribing…"
            default: "Starting microphone…"
            }
        case .surface: ""
        }
    }

    private func failureCard(_ failure: DictationFailure) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 9) {
                Image(systemName: model.failure == nil ? "exclamationmark.triangle" : failure.symbol)
                    .font(.system(size: 17, weight: .medium))
                    .foregroundStyle(.yellow)
                    .accessibilityHidden(true)
                Text(failure.title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 4)
                Button(action: dismissFailure) {
                    Image(systemName: "xmark")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.white.opacity(0.85))
                        .frame(width: 26, height: 26)
                        .background(.white.opacity(0.06), in: Circle())
                        .overlay { Circle().strokeBorder(.white.opacity(0.18), lineWidth: 1) }
                        .contentShape(Circle())
                }
                .buttonStyle(.plain)
                .help("Dismiss error")
                .accessibilityLabel("Dismiss error")
            }
            Text(failure.message)
                .font(.system(size: 13))
                .foregroundStyle(.white.opacity(0.7))
                .fixedSize(horizontal: false, vertical: true)
                .lineLimit(model.failure == nil ? nil : 4)
            if failure.needsAccessibility {
                Button("Allow Accessibility") {
                    model.requestAccessibility()
                    model.dismissCard()
                }
                .buttonStyle(.bordered)
            } else if model.failure != nil {
                Button("Try again", action: model.toggleRecording)
                    .buttonStyle(.bordered)
            }
            if isMeetingCapturing {
                Button("Stop notetaker", action: model.meetings.stop)
                    .buttonStyle(.bordered)
            }
        }
        .padding(18)
        .frame(width: 360, alignment: .leading)
    }

    private func unpastedCard(_ text: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 9) {
                Image(systemName: "doc.on.clipboard")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(.white.opacity(0.7))
                    .accessibilityHidden(true)
                Text("Copied, not pasted.")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white)
                Spacer(minLength: 4)
                Button {
                    model.copyText(text)
                    model.dismissCard()
                } label: {
                    Image(systemName: "doc.on.doc")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.white.opacity(0.85))
                        .frame(width: 26, height: 26)
                        .background(.white.opacity(0.06), in: Circle())
                        .overlay { Circle().strokeBorder(.white.opacity(0.18), lineWidth: 1) }
                        .contentShape(Circle())
                }
                .buttonStyle(.plain)
                .help("Copy text")
                .accessibilityLabel("Copy text")
            }
            Text(text)
                .font(.system(size: 13))
                .foregroundStyle(.white.opacity(0.85))
                .lineLimit(4)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(18)
        .frame(width: 360, alignment: .leading)
    }

    private var cancellationCard: some View {
        HStack(spacing: 16) {
            Text("Transcript cancelled")
                .font(.system(size: 14, weight: .medium))
            Spacer(minLength: 0)
            if model.canUndoCancellation {
                Button("Undo", action: model.undoCancellation)
                    .help("Transcribe the audio you just cancelled")
            } else {
                Button("Dismiss", action: model.dismissCard)
            }
        }
        .foregroundStyle(.white)
        .buttonStyle(CapsuleCardButtonStyle())
        .padding(.horizontal, 18)
        .frame(width: 320, height: 56)
    }

    private func completionCard(_ message: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(Color(red: 0.55, green: 0.9, blue: 0.7))
                .accessibilityHidden(true)
            Text(message)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.white)
        }
        .padding(.horizontal, 22)
        .frame(height: 48)
    }

    private func dismissFailure() {
        if model.failure != nil { model.dismissCard() }
        else { model.meetings.message = nil }
    }

    private var controls: some View {
        HStack(spacing: 4) {
            Button(action: model.toggleRecording) {
                Image(systemName: "mic.fill")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.white)
                    .frame(width: 42, height: 28)
                    .background(.white.opacity(hover.target == .microphone ? 0.1 : 0), in: Capsule())
                    .contentShape(Capsule())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Start dictation")
            .background { CapsuleGlass(cornerRadius: 14) }
            .capsuleRegion(.microphone)
            meetingButton
        }
    }

    private var dictationPill: some View {
        HStack(spacing: 4) {
            if !model.isHeldSession {
                Button(action: model.cancelRecording) {
                    Image(systemName: "xmark")
                        .frame(width: 18, height: 18)
                        .background(.white.opacity(0.2), in: Circle())
                        .frame(width: 24, height: 24)
                        .contentShape(Circle())
                }
                .help("Cancel dictation")
                .accessibilityLabel("Cancel dictation")
            }
            if model.phase == .transcribing {
                ProgressView()
                    .controlSize(.small)
                    .frame(maxWidth: .infinity)
                    .accessibilityLabel("Transcribing")
            } else {
                CapsuleWaveform(model: model, isNotetaking: isNotetaking, animated: !reduceMotion, count: model.isHeldSession ? 13 : 9)
                    .frame(maxWidth: .infinity)
                    .accessibilityLabel(waveformLabel)
            }
            if !model.isHeldSession {
                Button(action: model.toggleRecording) {
                    Image(systemName: "checkmark")
                        .foregroundStyle(.black.opacity(isRecording ? 1 : 0.45))
                        .frame(width: 18, height: 18)
                        .background(.white.opacity(isRecording ? 1 : 0.25), in: Circle())
                        .frame(width: 24, height: 24)
                        .contentShape(Circle())
                }
                .disabled(!isRecording)
                .help("Finish dictation")
                .accessibilityLabel("Finish dictation")
            }
        }
        .font(.system(size: 10, weight: .semibold))
        .foregroundStyle(.white)
        .buttonStyle(.plain)
        .padding(.horizontal, 4)
        .frame(width: model.isHeldSession ? 96 : 108, height: 28)
        .contentShape(Capsule())
        .contextMenu { Button("Cancel dictation", action: model.cancelRecording) }
        .accessibilityActions { Button("Cancel dictation", action: model.cancelRecording) }
        .capsuleRegion(.dictation)
    }

    private var notetakingPill: some View {
        HStack(spacing: 4) {
            CapsuleWaveform(model: model, isNotetaking: isNotetaking, animated: !reduceMotion, count: 13)
                .frame(maxWidth: .infinity)
                .accessibilityLabel(waveformLabel)
            RoundedRectangle(cornerRadius: 2)
                .fill(.white)
                .frame(width: 7, height: 7)
                .frame(width: 18, height: 18)
                .background(.white.opacity(0.16), in: Circle())
                .frame(width: 24, height: 24)
                .accessibilityLabel("Stop notetaker")
                .accessibilityAddTraits(.isButton)
                .accessibilityAction { model.meetings.stop() }
        }
        .padding(.leading, 8)
        .padding(.trailing, 4)
        .frame(width: 100, height: 26)
        .contentShape(Capsule())
        .onTapGesture { if isMeetingRecording { model.meetings.stop() } }
        .contextMenu {
            Button("Stop notetaker", action: model.meetings.stop)
        }
        .accessibilityActions {
            Button("Stop notetaker", action: model.meetings.stop)
        }
        .capsuleRegion(.notetaker)
    }

    private var meetingButton: some View {
        HStack(spacing: 0) {
            Button(action: model.startNotetaker) {
                Image(systemName: "record.circle")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(.white)
                    .frame(width: 28, height: 28)
                    .background(.white.opacity(hover.target == .notetaker ? 0.12 : 0), in: Circle())
                    .contentShape(Circle())
            }
            .accessibilityLabel("Start notetaker")
            .disabled(model.meetings.activity != .idle)
            .capsuleRegion(.notetaker)
            Button {
                if let id = model.meetings.activity.meetingID {
                    model.onShowNotetaker?(id)
                } else {
                    model.selectedPage = .meetings
                    model.onShowDashboard?()
                }
            } label: {
                Image(systemName: "chevron.up")
                    .font(.system(size: 8, weight: .semibold))
                    .foregroundStyle(.white.opacity(hover.target == .meetingNotes ? 1 : 0.6))
                    .frame(width: 22, height: 28)
                    .contentShape(Rectangle())
            }
            .accessibilityLabel("Open meeting notes")
            .capsuleRegion(.meetingNotes)
        }
        .buttonStyle(.plain)
        .background { CapsuleGlass(cornerRadius: 14) }
    }

    private var waveformLabel: String {
        if isNotetaking { return isMeetingRecording ? "Meeting audio level" : "Starting notetaker" }
        switch model.phase {
        case .recording: return "Microphone input level"
        default: return "Starting microphone"
        }
    }
}

private struct CapsuleCardButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 14, weight: .medium))
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(.white.opacity(configuration.isPressed ? 0.2 : 0.08), in: RoundedRectangle(cornerRadius: 12))
    }
}

/// Reads the live audio level in its own body so each level update redraws only the bars, not the whole capsule.
private struct CapsuleWaveform: View {
    let model: AppModel
    let isNotetaking: Bool
    let animated: Bool
    let count: Int

    var body: some View {
        Waveform(mode: mode, animated: animated, count: count)
    }

    private var mode: Waveform.Mode {
        if isNotetaking {
            guard case .recording = model.meetings.activity else { return .waiting }
            return .listening(VoiceLevels(values: [max(model.meetings.levels.me, model.meetings.levels.them)]))
        }
        return model.phase == .recording ? .listening(model.voiceLevels) : .waiting
    }
}

private struct CapsuleCountdown: View {
    let deadline: Date
    let duration: Double
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30, paused: reduceMotion)) { context in
            GeometryReader { geometry in
                Rectangle().fill(.white.opacity(0.18))
                Rectangle().fill(.white.opacity(0.9))
                    .frame(width: geometry.size.width * (reduceMotion ? 1 : max(0, min(1, deadline.timeIntervalSince(context.date) / max(duration, 0.01)))))
            }
        }
            .frame(height: 3)
            .accessibilityHidden(true)
    }
}

private struct CapsuleGlass: View {
    var cornerRadius: CGFloat
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorSchemeContrast) private var contrast

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        Group {
            if reduceTransparency {
                shape.fill(Color(white: 0.09))
            } else if #available(macOS 26.0, *) {
                Color.clear.glassEffect(.regular.tint(.black.opacity(0.45)), in: shape)
            } else {
                shape.fill(.ultraThinMaterial)
                    .overlay { shape.fill(.black.opacity(0.45)) }
            }
        }
        .overlay { shape.strokeBorder(.white.opacity(contrast == .increased ? 0.6 : 0.16), lineWidth: 1) }
        .shadow(color: .black.opacity(0.2), radius: 8, y: 3)
        .allowsHitTesting(false)
    }
}

struct Waveform: View {
    enum Mode: Equatable {
        case waiting, processing
        case listening(VoiceLevels)
    }

    let mode: Mode
    let animated: Bool
    var color: Color = .white
    var count = 5

    var body: some View {
        if animated && mode != .waiting {
            TimelineView(.animation) { context in
                bars(at: context.date)
            }
        } else {
            bars(at: .now)
        }
    }

    private func bars(at date: Date) -> some View {
        HStack(spacing: 2.5) {
            ForEach(0..<count, id: \.self) { index in
                Capsule()
                    .fill(color.opacity(mode == .waiting ? 0.4 : 0.95))
                    .frame(width: 2, height: 3 + 11 * height(of: index, at: date))
            }
        }
        .frame(height: 14)
    }

    private func height(of index: Int, at date: Date) -> CGFloat {
        let time = date.timeIntervalSinceReferenceDate
        let position = Double(index)
        let middle = Double(max(2, count) - 1) / 2
        let distance = abs(position - middle) / middle
        switch mode {
        case .waiting:
            return 0
        case .listening(let levels):
            let level = CGFloat(levels.value(at: date))
            let envelope = 1 - 0.85 * distance * distance
            let motion = animated ? 0.75 + 0.125 * (sin(time * 9.1 + position * 1.7) + sin(time * 5.3 + position * 0.8) + 2) / 2 : 1
            return level * envelope * motion
        case .processing:
            return 0.12 + 0.3 * (1 + sin(time * 6 - position * 0.75)) / 2
        }
    }
}
