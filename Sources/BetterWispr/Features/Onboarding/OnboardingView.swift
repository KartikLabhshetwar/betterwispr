import BetterWisprCore
import SwiftUI

struct OnboardingView: View {
    @Bindable var model: AppModel
    let finish: () -> Void
    @State private var step = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let stepCount = 3
    private var recommended: SpeechModel? { model.models.first { $0.id == "parakeet-v3" } }

    var body: some View {
        VStack(spacing: 0) {
            Group {
                switch step {
                case 0: welcome
                case 1: permissions
                default: tryIt
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(.horizontal, 36)
            .padding(.top, 32)
            .id(step)
            .transition(reduceMotion ? .opacity : .asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity),
                                                               removal: .move(edge: .leading).combined(with: .opacity)))
            Divider()
            footer
        }
        .frame(width: 520, height: 440)
        .task {
            while !Task.isCancelled {
                model.refreshPermissions()
                try? await Task.sleep(for: .seconds(1))
            }
        }
    }

    private var welcome: some View {
        VStack(spacing: 14) {
            BrandMark(size: 64)
            Text("Talk instead of type")
                .font(.title.weight(.semibold))
            Text("Hold ⌥ Space anywhere and speak. Release it, and your words appear where your cursor is.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
            Label("Everything runs on your Mac. No audio leaves it.", systemImage: "lock.fill")
                .font(.callout)
                .foregroundStyle(.secondary)
                .padding(.top, 8)
        }
    }

    private var permissions: some View {
        VStack(alignment: .leading, spacing: 16) {
            header("Two quick permissions", "BetterWispr needs your microphone to hear you. Accessibility lets it paste text for you.")
            Form {
                PermissionRow(title: "Microphone", detail: "Required to dictate.", granted: model.microphoneGranted, action: model.requestMicrophone)
                PermissionRow(title: "Paste into apps", detail: "Optional. Without it, text is copied to your clipboard.", granted: model.accessibilityGranted, action: model.requestAccessibility)
            }
            .formStyle(.grouped)
            .scrollDisabled(true)
            .padding(.horizontal, -20)
        }
    }

    private var tryIt: some View {
        VStack(alignment: .leading, spacing: 16) {
            header("Try it now", "Pick a speech model, then hold ⌥ Space and say something.")
            Form {
                modelRow
                LabeledContent("Shortcut") { KeyboardHint().font(.body.weight(.semibold)) }
            }
            .formStyle(.grouped)
            .scrollDisabled(true)
            .padding(.horizontal, -20)
            if model.isBusy || !model.partialTranscript.isEmpty {
                Text(model.partialTranscript.isEmpty ? model.statusMessage : model.partialTranscript)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
        }
    }

    @ViewBuilder private var modelRow: some View {
        let selected = model.selectedModel
        LabeledContent {
            if model.preparingModelID != nil {
                ProgressView(value: min(1, max(0, model.downloadProgress))).frame(width: 120)
            } else if let recommended, selected.id != recommended.id || !model.isModelInstalled(recommended) {
                Button(model.isModelInstalled(recommended) ? "Use \(recommended.name)" : "Download \(recommended.name)") {
                    if model.isModelInstalled(recommended) { model.selectModel(recommended) }
                    else { model.installModel(recommended) }
                }
                .disabled(model.isBusy)
            } else {
                Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
            }
        } label: {
            Text(selected.name)
            Text(model.isModelInstalled(selected) ? "Ready to use offline." : "Not downloaded yet.")
        }
    }

    private func header(_ title: String, _ detail: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.title2.weight(.semibold))
            Text(detail).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
        }
    }

    private var footer: some View {
        HStack {
            if step > 0 {
                Button("Back") { go(step - 1) }
            } else {
                Button("Skip", action: finish)
            }
            Spacer()
            HStack(spacing: 6) {
                ForEach(0..<stepCount, id: \.self) { index in
                    Circle()
                        .fill(index == step ? Color.accentColor : Color.secondary.opacity(0.3))
                        .frame(width: 6, height: 6)
                }
            }
            .accessibilityElement()
            .accessibilityLabel("Step \(step + 1) of \(stepCount)")
            Spacer()
            if step < stepCount - 1 {
                Button("Continue") { go(step + 1) }
                    .keyboardShortcut(.defaultAction)
            } else {
                Button("Done", action: finish)
                    .keyboardShortcut(.defaultAction)
            }
        }
        .controlSize(.large)
        .padding(16)
    }

    private func go(_ target: Int) {
        withAnimation(reduceMotion ? nil : .spring(duration: 0.35)) { step = target }
    }
}
