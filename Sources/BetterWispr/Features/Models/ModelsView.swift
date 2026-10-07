import BetterWisprCore
import SwiftUI

struct ModelsView: View {
    @Bindable var model: AppModel

    var body: some View {
        Form {
            Section {
                ForEach(model.models) { speechModel in
                    modelRow(speechModel)
                }
            } header: {
                Text("Speech Models")
            } footer: {
                Label("Parakeet and Whisper models need an internet connection for their first download. Your recordings and transcriptions are processed locally.", systemImage: "internaldrive")
                    .foregroundStyle(.secondary)
            }

            Section {
                LabeledContent {
                    Button("Open Vocabulary") { model.selectedPage = .vocabulary }
                } label: {
                    Text("Improve accuracy")
                    Text("Larger models handle accents and challenging audio better, but use more memory and take longer. A quiet microphone, the correct language and your personal vocabulary also make a difference.")
                }
            }
        }
        .formStyle(.grouped)
    }

    private func modelRow(_ speechModel: SpeechModel) -> some View {
        let selected = speechModel.id == model.selectedModel.id
        let preparing = model.preparingModelID == speechModel.id
        let installed = model.isModelInstalled(speechModel)

        return HStack(alignment: .top, spacing: 12) {
            SymbolTile(
                symbol: speechModel.engine == .apple ? "apple.logo" : "waveform",
                color: speechModel.engine == .apple ? .gray : .purple,
                size: 32
            )
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(speechModel.name).fontWeight(.medium)
                    if selected {
                        Text("Active")
                            .font(.caption.weight(.medium))
                            .foregroundStyle(.green)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 1)
                            .background(.green.opacity(0.15), in: Capsule())
                    }
                }
                Text(speechModel.detail)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                Text("\(speechModel.sizeLabel) · \(engineLabel(speechModel.engine))")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                if preparing {
                    Group {
                        if model.downloadProgress > 0 {
                            ProgressView(value: min(1, max(0, model.downloadProgress)))
                        } else {
                            ProgressView().progressViewStyle(.linear)
                        }
                    }
                    .padding(.top, 4)
                    Text("Preparing \(speechModel.name)… This can take a few minutes on first use.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer(minLength: 8)
            if selected && installed && !preparing {
                Image(systemName: "checkmark.circle.fill")
                    .font(.title3)
                    .foregroundStyle(.green)
                    .accessibilityLabel("Active model")
            } else if !preparing {
                Button(installed ? "Use" : "Download") {
                    if installed { model.selectModel(speechModel) }
                    else { model.installModel(speechModel) }
                }
                .disabled(model.isBusy)
            }
        }
        .padding(.vertical, 4)
    }

    private func engineLabel(_ engine: SpeechEngine) -> String {
        switch engine {
        case .apple: "System speech"
        case .whisperKit: "WhisperKit · Apple Silicon"
        case .parakeet: "Parakeet · Neural Engine"
        }
    }
}
