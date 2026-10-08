import BetterWisprCore
import SwiftUI

struct CapsuleView: View {
    @Bindable var model: AppModel
    let hover: CapsuleHover
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var isRecording: Bool { model.phase == .recording }
    private var isMeetingCapturing: Bool { model.meetings.activity.capturingID != nil }
    private var isMeetingRecording: Bool {
        if case .recording = model.meetings.activity { true } else { false }
    }
    private var failure: DictationFailure? {
        model.failure ?? (model.isBusy ? nil : model.meetings.message.map {
            DictationFailure(title: "Notetaker needs attention", message: $0)
        })
    }
    private var showsToolbar: Bool { failure == nil && !model.isBusy && (hover.isHovering || isMeetingCapturing) }
    private var showsControls: Bool { model.isBusy && !model.isHeldSession }
    private var finishesOnClick: Bool { showsControls && isRecording }
    private var spring: Animation? { reduceMotion ? nil : .spring(duration: 0.26, bounce: 0) }

    var body: some View {
        VStack(spacing: 6) {
            Spacer(minLength: 0)
            if failure == nil, let target = hover.target {
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
        .animation(spring, value: model.meetings.activity)
        .animation(spring, value: failure)
        .animation(spring, value: hover.isHovering)
        .animation(reduceMotion ? nil : .easeOut(duration: 0.12), value: hover.target)
        .onChange(of: failure) {
            guard let failure else { return }
            AccessibilityNotification.Announcement("\(failure.title) \(failure.message)").post()
        }
    }

    private var surface: some View {
        VStack(spacing: 0) {
            if let failure {
                failureCard(failure)
                    .transition(.opacity)
            } else if model.isBusy {
                recordingPill
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
                CapsuleGlass(cornerRadius: failure == nil ? 18 : 22)
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
                Image(systemName: "exclamationmark.triangle")
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
            if failure.needsAccessibility {
                Button("Allow Accessibility") {
                    model.requestAccessibility()
                    model.dismissFailure()
                }
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

    private func dismissFailure() {
        if model.failure != nil { model.dismissFailure() }
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

    private var recordingPill: some View {
        HStack(spacing: 8) {
            Waveform(mode: waveformMode, animated: !reduceMotion)
                .frame(width: 24)
                .accessibilityLabel(waveformLabel)
                .accessibilityValue(isRecording ? "\(Int((model.voiceLevels.values.last ?? 0) * 100)) percent" : "")
            if finishesOnClick {
                RoundedRectangle(cornerRadius: 2)
                    .fill(.white)
                    .frame(width: 8, height: 8)
                    .frame(width: 24, height: 24)
                    .background(.white.opacity(0.16), in: Circle())
                    .accessibilityLabel("Finish dictation")
                    .accessibilityAddTraits(.isButton)
                    .accessibilityAction { model.toggleRecording() }
            } else if showsControls {
                Button(action: model.cancelRecording) {
                    Image(systemName: "xmark")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 24, height: 24)
                        .background(.white.opacity(0.12), in: Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Cancel dictation")
            }
        }
        .padding(.leading, 12)
        .padding(.trailing, showsControls ? 6 : 12)
        .frame(height: showsControls ? 32 : 28)
        .contentShape(Capsule())
        .onTapGesture { if finishesOnClick { model.toggleRecording() } }
        .contextMenu { Button("Cancel dictation", action: model.cancelRecording) }
        .accessibilityAction(named: Text("Cancel dictation"), model.cancelRecording)
        .capsuleRegion(.dictation)
    }

    private var meetingButton: some View {
        HStack(spacing: 0) {
            Button {
                if isMeetingCapturing { model.meetings.stop() }
                else {
                    model.startMeeting()
                    model.onShowDashboard?()
                }
            } label: {
                Image(systemName: isMeetingCapturing ? "stop.fill" : "record.circle")
                    .font(.system(size: isMeetingCapturing ? 10 : 15, weight: .medium))
                    .foregroundStyle(.white)
                    .frame(width: 28, height: 28)
                    .background(.white.opacity(hover.target == .notetaker ? 0.12 : 0), in: Circle())
                    .contentShape(Circle())
            }
            .accessibilityLabel(isMeetingCapturing ? "Stop notetaker" : "Start notetaker")
            .disabled(model.meetings.activity != .idle && !isMeetingCapturing)
            .capsuleRegion(.notetaker)
            Button {
                model.selectedPage = .meetings
                model.onShowDashboard?()
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
        .overlay {
            if isMeetingRecording {
                Capsule().strokeBorder(Color(red: 0, green: 0.73, blue: 0.51), lineWidth: 2)
                    .allowsHitTesting(false)
            }
        }
    }

    private var waveformMode: Waveform.Mode {
        switch model.phase {
        case .recording: .listening(model.voiceLevels)
        case .transcribing: .processing
        default: .waiting
        }
    }

    private var waveformLabel: String {
        switch model.phase {
        case .recording: "Microphone input level"
        case .transcribing: "Transcribing"
        default: "Starting microphone"
        }
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

private struct Waveform: View {
    enum Mode: Equatable {
        case waiting, processing
        case listening(VoiceLevels)
    }

    let mode: Mode
    let animated: Bool
    private static let count = 5

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
            ForEach(0..<Self.count, id: \.self) { index in
                Capsule()
                    .fill(.white.opacity(mode == .waiting ? 0.4 : 0.95))
                    .frame(width: 2.5, height: 3 + 11 * height(of: index, at: date))
            }
        }
        .frame(height: 14)
    }

    private func height(of index: Int, at date: Date) -> CGFloat {
        let time = date.timeIntervalSinceReferenceDate
        let position = Double(index)
        let middle = Double(Self.count - 1) / 2
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
