import BetterWisprCore
import SwiftUI

struct NotesModelPicker: View {
    @Bindable var model: AppModel

    var body: some View {
        Picker("Notes provider", selection: Binding(get: { model.settings.notesSelection }, set: { model.selectNotesModel($0) })) {
            Text("Apple Intelligence · On this Mac").tag(NotesModelSelection.apple)
            ForEach(NotesCLI.allCases, id: \.self) { cli in
                Text("\(cli.name) · Subscription").tag(NotesModelSelection.cli(cli))
            }
            ForEach(ollamaModels, id: \.self) { name in
                Text("Ollama · \(name)").tag(NotesModelSelection.ollama(name))
            }
            ForEach(model.settings.notesConnections) { connection in
                Text("\(connection.name) · \(connection.modelID)").tag(NotesModelSelection.connection(connection.id))
            }
            if let id = model.settings.notesConnectionID, !model.settings.notesConnections.contains(where: { $0.id == id }) {
                Text("Missing notes connection").tag(NotesModelSelection.connection(id))
            }
        }
        if case .cli(let cli) = model.settings.notesSelection {
            let models = model.notesCLICatalogs[cli]?.models ?? []
            Picker("\(cli.name) model", selection: Binding(
                get: { model.settings.cliModel(cli) },
                set: { model.settings.setCLIModel($0, for: cli); model.saveNotesSettings() }
            )) {
                Text("Choose a model").tag("").disabled(true)
                ForEach(models) { item in
                    Text("\(item.name) · \(item.id)").tag(item.id)
                }
                let selected = model.settings.cliModel(cli)
                if !selected.isEmpty, !models.contains(where: { $0.id == selected }) {
                    Text(selected).tag(selected)
                }
            }
            .pickerStyle(.menu)
        }
    }

    private var ollamaModels: [String] {
        let installed = model.meetings.ollamaModels
        guard let saved = model.settings.notesModel, !installed.contains(saved) else { return installed }
        return installed + [saved]
    }
}

struct NotesModelSettings: View {
    @Bindable var model: AppModel
    @State private var testing = false
    @State private var result: String?

    var body: some View {
        NotesModelPicker(model: model)
            .disabled(!model.canEditConnections || testing)
        if case .cli(let cli) = model.settings.notesSelection {
            TextField("Model ID", text: Binding(
                get: { model.settings.cliModel(cli) },
                set: {
                    model.settings.setCLIModel($0, for: cli)
                    model.saveNotesSettings()
                }
            ))
            .disabled(!model.canEditConnections || testing)
            HStack {
                Button("Refresh \(cli.name) models") { Task { await model.refreshNotesCLIModels(cli) } }
                    .disabled(model.loadingNotesCatalogs.contains(cli) || testing)
                if model.loadingNotesCatalogs.contains(cli) { ProgressView().controlSize(.small) }
            }
            if let error = model.notesCatalogErrors[cli] {
                Text(error).font(.caption).foregroundStyle(.secondary)
            } else if let item = model.notesCLICatalogs[cli]?.models.first(where: { $0.id == model.settings.cliModel(cli) }) {
                Text(item.detail).font(.caption).foregroundStyle(.secondary)
            }
            Text("Install the latest \(cli.name) CLI and run \(cli.loginCommand) in Terminal. BetterWispr uses that sign-in; subscription limits apply.")
                .font(.caption).foregroundStyle(.secondary)
        }
        HStack {
            Button(testing ? "Testing…" : "Test notes model") { result = nil; testing = true }
                .disabled(testing || !model.canEditConnections || model.meetings.notesAvailability != .available)
            if testing {
                ProgressView().controlSize(.small)
                Button("Cancel") { testing = false }
            }
            Button("Refresh local models") { Task { await model.meetings.refreshOllamaModels() } }
        }
        Text("Test sends only a short built-in sample to the selected notes model.")
            .font(.caption).foregroundStyle(.secondary)
        if let result { Text(result).font(.callout).textSelection(.enabled) }
        if case .unavailable(let reason) = model.meetings.notesAvailability {
            Text(reason).font(.callout).foregroundStyle(.secondary)
        }
        // A view task cancels the request or CLI when this page is closed or Cancel is clicked.
        Color.clear.frame(height: 0)
            .task { await model.meetings.refreshOllamaModels() }
            .task(id: testing) {
                guard testing else { return }
                let settings = model.settings
                do {
                    let notes = try await MeetingNotesGenerator.generate(segments: [],
                        userNotes: "Synthetic test meeting: We agreed to launch on Friday. Alex will send the checklist tomorrow.",
                        settings: settings) { _, _ in }
                    try Task.checkCancellation()
                    result = "\(notes.summary.modelName ?? settings.notesModelName) is working. Sample summary: \(notes.summary.overview)"
                } catch {
                    guard !Task.isCancelled else { return }
                    result = error.localizedDescription
                }
                testing = false
            }
            .onChange(of: model.settings) { _, _ in result = nil }
    }
}
