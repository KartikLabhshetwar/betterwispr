import SwiftUI

struct CapsuleView: View {
    @Bindable var model: AppModel
    let hover: CapsuleHover
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var shakes = 0

    private var isRecording: Bool { model.phase == .recording }
    private var isFailed: Bool { model.failure != nil }
    private var isActive: Bool { model.isBusy || isFailed }
    private var hovering: Bool { hover.isHovering }
    private var isOpen: Bool { model.isBusy || hovering }
    private var showsControls: Bool { model.isBusy && !model.isHeldSession }
    private var finishesOnClick: Bool { showsControls && isRecording }
    private var spring: Animation? { reduceMotion ? nil : .spring(duration: 0.38, bounce: 0.28) }

    var body: some View {
        VStack(spacing: 5) {
            Spacer(minLength: 0)
            message
            pill
        }
        .padding(.bottom, 6)
        .frame(width: 440, height: 160)
        .animation(spring, value: model.phase)
        .animation(spring, value: hovering)
        .onChange(of: model.phase) {
            guard let failure = model.failure else { return }
            AccessibilityNotification.Announcement("\(failure.title) \(failure.message)").post()
            if !reduceMotion { withAnimation(.linear(duration: 0.5)) { shakes += 1 } }
        }
    }

    @ViewBuilder private var message: some View {
        if let failure = model.failure {
            failureCard(failure)
        } else if hovering && !isActive {
            tooltip
        }
    }

    private var tooltip: some View {
        HStack(spacing: 4) {
            Text("Dictate")
            Text("⌥ Space").fontWeight(.bold)
        }
        .font(.system(size: 13))
        .foregroundStyle(.white)
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(.black, in: Capsule())
        .overlay { Capsule().strokeBorder(.white.opacity(0.2), lineWidth: 1) }
        .transition(.offset(y: 4).combined(with: .opacity))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Dictate with Option Space")
    }

    private func failureCard(_ failure: DictationFailure) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 18))
                .foregroundStyle(.yellow)
                .symbolEffect(.bounce, value: shakes)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(failure.title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white)
                Text(failure.message)
                    .font(.system(size: 12))
                    .foregroundStyle(.white.opacity(0.65))
                    .lineLimit(2)
            }
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
            if failure.needsAccessibility {
                Button {
                    model.requestAccessibility()
                    model.dismissFailure()
                } label: {
                    Text("Allow")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.black)
                        .padding(.horizontal, 11)
                        .padding(.vertical, 5)
                        .background(.white, in: Capsule())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Allow Accessibility")
            }
            Button(action: model.dismissFailure) {
                Image(systemName: "xmark")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(.white.opacity(0.7))
                    .frame(width: 20, height: 20)
                    .background(.white.opacity(0.12), in: Circle())
            }
            .buttonStyle(.plain)
            .help("Dismiss")
            .accessibilityLabel("Dismiss")
        }
        .padding(.leading, 14)
        .padding(.trailing, 10)
        .padding(.vertical, 11)
        .frame(width: 380)
        .background(Color(white: 0.11), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay { RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(.white.opacity(0.14), lineWidth: 1) }
        .shadow(color: .black.opacity(0.35), radius: 10, y: 3)
        .transition(.asymmetric(
            insertion: .offset(y: 14).combined(with: .scale(scale: 0.85, anchor: .bottom)).combined(with: .opacity),
            removal: .scale(scale: 0.95, anchor: .bottom).combined(with: .opacity)))
        .accessibilityElement(children: .contain)
    }

    private var pill: some View {
        HStack(spacing: 8) {
            if model.isBusy {
                if showsControls {
                    roundButton("xmark", label: "Cancel dictation", action: model.cancelRecording)
                }
                Waveform(mode: waveformMode, animated: !reduceMotion)
                    .transition(.scale(scale: 0.4).combined(with: .opacity))
                    .accessibilityLabel(waveformLabel)
                    .accessibilityValue(isRecording ? "\(Int(model.audioLevel * 100)) percent" : "")
                if finishesOnClick {
                    stopMark
                }
            } else if hovering {
                Button(action: model.toggleRecording) {
                    Image(systemName: "mic.fill")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.white)
                        .frame(width: 42, height: 24)
                        .contentShape(Capsule())
                }
                .buttonStyle(.plain)
                .help("Start dictation")
                .accessibilityLabel("Start dictation")
                .transition(.scale(scale: 0.3).combined(with: .opacity))
            }
        }
        .padding(.horizontal, showsControls ? 5 : model.isBusy ? 14 : 4)
        .frame(minWidth: isOpen ? nil : 40, minHeight: isOpen ? 32 : 9)
        .background(isOpen ? Color(white: 0.07) : .black.opacity(0.6), in: Capsule())
        .overlay { Capsule().strokeBorder(isFailed ? Color.red.opacity(0.85) : .white.opacity(isOpen ? 0.16 : 0.5), lineWidth: 1) }
        .shadow(color: .black.opacity(isOpen ? 0.3 : 0), radius: 8, y: 2)
        .contentShape(Capsule())
        .onTapGesture { if finishesOnClick { model.toggleRecording() } }
        .help(finishesOnClick ? "Click to finish dictation" : "")
        .accessibilityElement(children: .contain)
        .modifier(Shake(animatableData: CGFloat(shakes)))
        .padding(.bottom, 10)
    }

    private var waveformMode: Waveform.Mode {
        switch model.phase {
        case .recording: .listening(CGFloat(model.audioLevel))
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

    private var stopMark: some View {
        Image(systemName: "stop.fill")
            .font(.system(size: 8, weight: .bold))
            .foregroundStyle(.white)
            .frame(width: 22, height: 22)
            .background(Color.red, in: Circle())
            .transition(.scale(scale: 0.3).combined(with: .opacity))
            .accessibilityLabel("Finish dictation")
            .accessibilityAddTraits(.isButton)
            .accessibilityAction { model.toggleRecording() }
    }

    private func roundButton(_ symbol: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(.white.opacity(0.85))
                .frame(width: 22, height: 22)
                .background(.white.opacity(0.16), in: Circle())
                .contentTransition(.symbolEffect(.replace))
        }
        .buttonStyle(.plain)
        .help(label)
        .accessibilityLabel(label)
        .transition(.scale(scale: 0.3).combined(with: .opacity))
    }
}

private struct Waveform: View {
    enum Mode: Equatable {
        case waiting, processing
        case listening(CGFloat)
    }

    let mode: Mode
    let animated: Bool
    private static let count = 11

    var body: some View {
        if animated && mode != .waiting {
            TimelineView(.animation) { context in
                bars(at: context.date.timeIntervalSinceReferenceDate)
            }
        } else {
            bars(at: 0)
        }
    }

    private func bars(at time: Double) -> some View {
        HStack(spacing: 2.5) {
            ForEach(0..<Self.count, id: \.self) { index in
                Capsule()
                    .fill(.white.opacity(mode == .waiting ? 0.4 : 0.95))
                    .frame(width: 3, height: 3 + 15 * height(of: index, at: time))
            }
        }
        .frame(height: 18)
    }

    private func height(of index: Int, at time: Double) -> CGFloat {
        let position = Double(index)
        let middle = Double(Self.count - 1) / 2
        let distance = abs(position - middle) / middle
        switch mode {
        case .waiting:
            return 0
        case .listening(let level):
            let envelope = 1 - 0.5 * distance * distance
            let motion = animated ? 0.75 + 0.125 * (sin(time * 9.1 + position * 1.7) + sin(time * 5.3 + position * 0.8) + 2) / 2 : 1
            return level * envelope * motion
        case .processing:
            return 0.12 + 0.3 * (1 + sin(time * 6 - position * 0.75)) / 2
        }
    }
}

private struct Shake: GeometryEffect {
    var animatableData: CGFloat

    func effectValue(size: CGSize) -> ProjectionTransform {
        let decay = 1 - (animatableData - animatableData.rounded(.down))
        return ProjectionTransform(CGAffineTransform(translationX: 7 * decay * sin(animatableData * .pi * 6), y: 0))
    }
}
