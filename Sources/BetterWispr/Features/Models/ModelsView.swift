import BetterWisprCore
import SwiftUI

struct ModelsView: View {
    @Bindable var model: AppModel
    @State private var editing: SpeechConnection?
    @State private var error: String?
    @State private var editingNotes = false

    var body: some View {
        Form {
            Section {
                ForEach(SpeechModel.catalog) { speechModel in
                    modelRow(speechModel)
                }
            } header: {
                Text("On this Mac")
            } footer: {
                Label("These models process audio on your Mac. Parakeet and Whisper need an internet connection only for installation.", systemImage: "internaldrive")
                    .foregroundStyle(.secondary)
            }

            Section {
                ForEach(model.settings.speechConnections) { connection in
                    VStack(alignment: .leading, spacing: 8) {
                        modelRow(connection.speechModel)
                        HStack {
                            Button("Edit…") { editingNotes = false; editing = connection }
                            Button("Remove", role: .destructive) {
                                do { try model.deleteConnection(connection) }
                                catch { self.error = error.localizedDescription }
                            }
                        }
                        .disabled(!model.canEditConnections)
                    }
                }
                Button("Add connection…", systemImage: "plus") { editingNotes = false; editing = SpeechConnection() }
                    .disabled(!model.canEditConnections)
            } header: {
                Text("Bring your own model")
            } footer: {
                Text("Choosing Use sends dictation and meeting audio to that endpoint. Provider charges and retention policies apply. API keys are kept in macOS Keychain; vocabulary replacements stay on your Mac. Open-source models need a server with a compatible transcription API.")
            }

            Section {
                NotesModelSettings(model: model)
                ForEach(model.settings.notesConnections) { connection in
                    HStack {
                        VStack(alignment: .leading) {
                            Text(connection.name).fontWeight(.medium)
                            Text(connection.modelID).font(.caption).foregroundStyle(.secondary)
                            Text(connection.endpoint).font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Button("Edit…") { editingNotes = true; editing = connection }
                        Button("Remove", role: .destructive) {
                            do { try model.deleteConnection(connection, forNotes: true) }
                            catch { self.error = error.localizedDescription }
                        }
                    }
                    .disabled(!model.canEditConnections)
                }
                Button("Add notes API connection…", systemImage: "plus") {
                    var connection = SpeechConnection(api: .openAICompatible)
                    connection.name = "My notes model"
                    connection.endpoint = "https://api.openai.com/v1/chat/completions"
                    connection.modelID = ""
                    editingNotes = true
                    editing = connection
                }
                .disabled(!model.canEditConnections)
            } header: {
                Text("Meeting notes · Bring your own LLM")
            } footer: {
                Text("The selected notes model processes the transcript and your thoughts after recording, and whenever you generate a summary. Claude Code and Codex use their signed-in subscriptions. API connections use your key and provider billing. Cloud choices send meeting text to that provider; speech recognition is selected separately.")
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
        .sheet(item: $editing) { connection in
            SpeechConnectionEditor(model: model, connection: connection, forNotes: editingNotes)
        }
        .alert("Couldn’t remove connection", isPresented: Binding(get: { error != nil }, set: { if !$0 { error = nil } })) {
            Button("OK") { error = nil }
        } message: { Text(error ?? "") }
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
        case .api: "API connection"
        }
    }
}

private struct SpeechConnectionEditor: View {
    let model: AppModel
    @State var connection: SpeechConnection
    var forNotes = false
    @State private var key = ""
    @State private var removeKey = false
    @State private var error: String?
    @Environment(\.dismiss) private var dismiss

    private var original: SpeechConnection? { (forNotes ? model.settings.notesConnections : model.settings.speechConnections).first { $0.id == connection.id } }
    private var canKeepKey: Bool { original?.keychainAccount == connection.keychainAccount }

    var body: some View {
        VStack(spacing: 0) {
            Form {
                Section {
                    if forNotes {
                        LabeledContent("API format", value: "OpenAI-compatible chat completions")
                    } else {
                        Picker("Provider", selection: $connection.api) {
                            ForEach(SpeechAPI.allCases, id: \.self) { Text($0.name).tag($0) }
                        }
                    }
                    TextField("Name", text: $connection.name)
                    TextField("Model ID", text: $connection.modelID)
                    if connection.api == .openAICompatible {
                        TextField(forNotes ? "Chat completions URL" : "Transcription URL", text: $connection.endpoint)
                        Text(forNotes ? "Enter a full /chat/completions endpoint and any model ID your provider supports. Works with OpenAI-compatible services and local servers. API keys use Bearer authentication." : "Enter the full endpoint, for example http://localhost:8000/v1/audio/transcriptions. It must accept a WAV file and return JSON with a text field. API keys use Bearer authentication.")
                            .font(.caption).foregroundStyle(.secondary)
                    } else {
                        LabeledContent("Endpoint") { Text(connection.endpoint).textSelection(.enabled) }
                    }
                    SecureField(canKeepKey ? "New API key (blank keeps saved key)" : "API key", text: $key)
                        .disabled(removeKey)
                    if connection.api == .openAICompatible {
                        Toggle("Use without an API key", isOn: $removeKey)
                    }
                    if connection.api == .smallest {
                        Text("Use pulse for multilingual speech or pulse-pro for English. Choose a spoken language in Settings; automatic detection is not configured for this connection.")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                } header: {
                    Text(forNotes ? "Notes API connection" : original == nil ? "Add speech connection" : "Edit speech connection")
                } footer: {
                    Text(forNotes ? "Saving makes no network request. Select this connection under Notes model to send meeting text to it. Keys stay in macOS Keychain. Changing an active endpoint resets the notes choice to Apple Intelligence; select the connection again to use the new URL." : "Saving makes no network request. Choose Use in Models to send future dictation and meeting audio to this endpoint. Keys are stored only in macOS Keychain.")
                }
                if let error { Text(error).foregroundStyle(.red).textSelection(.enabled) }
            }
            .formStyle(.grouped)
            Divider()
            HStack {
                Button("Cancel") { dismiss() }.keyboardShortcut(.cancelAction)
                Spacer()
                Button("Save connection") { save() }
                    .keyboardShortcut(.defaultAction)
                    .disabled(!model.canEditConnections)
            }
            .padding()
        }
        .frame(width: 600, height: 540)
        .onChange(of: connection.api) { _, api in
            connection.name = api.name
            connection.endpoint = api.endpoint
            connection.modelID = api.defaultModel
            key = ""
            removeKey = false
            error = nil
        }
    }

    private func save() {
        connection.name = connection.name.trimmingCharacters(in: .whitespacesAndNewlines)
        connection.endpoint = connection.endpoint.trimmingCharacters(in: .whitespacesAndNewlines)
        connection.modelID = connection.modelID.trimmingCharacters(in: .whitespacesAndNewlines)
        let key = key.trimmingCharacters(in: .whitespacesAndNewlines)
        do {
            try model.saveConnection(connection, key: removeKey ? "" : key.isEmpty && canKeepKey ? nil : key, forNotes: forNotes)
            dismiss()
        } catch { self.error = error.localizedDescription }
    }
}
