import FluidAudio
import Foundation

@MainActor
public final class ParakeetProvider: SpeechProvider {
    public var onProgress: (@MainActor @Sendable (Double) -> Void)?
    public var onPartialTranscript: (@MainActor @Sendable (String) -> Void)?
    private let modelsDirectory: URL
    private var manager: AsrManager?
    private var loadedModelID: String?
    private var preparing = false
    private var transcriptionTask: Task<String, any Error>?

    public init(modelsDirectory: URL = WhisperKitProvider.defaultModelsDirectory) {
        self.modelsDirectory = modelsDirectory
    }

    nonisolated static func version(for model: SpeechModel) -> AsrModelVersion? {
        switch model.modelName {
        case "parakeet-tdt-0.6b-v3": .v3
        case "parakeet-tdt-0.6b-v2": .v2
        default: nil
        }
    }

    /// FluidAudio resolves a model's files from the sibling folder named after its repository.
    nonisolated static func folder(for model: SpeechModel, modelsDirectory: URL) -> URL {
        modelsDirectory.appending(path: "Parakeet/\(model.modelName)", directoryHint: .isDirectory)
    }

    public static func isInstalled(_ model: SpeechModel, modelsDirectory: URL = WhisperKitProvider.defaultModelsDirectory) -> Bool {
        guard model.engine == .parakeet, let version = version(for: model) else { return false }
        let folder = folder(for: model, modelsDirectory: modelsDirectory)
        return FileManager.default.fileExists(atPath: folder.appending(path: ".betterwispr-installed").path)
            && AsrModels.modelsExist(at: folder, version: version)
    }

    public func prepare(model: SpeechModel, download: Bool) async throws {
        guard model.engine == .parakeet, let version = Self.version(for: model) else { throw SpeechError.invalidModel }
        guard !preparing, transcriptionTask == nil else { throw SpeechError.busy }
        if loadedModelID == model.id, manager != nil { onProgress?(1); return }
        preparing = true
        defer { preparing = false }
        try Task.checkCancellation()
        let folder = Self.folder(for: model, modelsDirectory: modelsDirectory)
        if download && !Self.isInstalled(model, modelsDirectory: modelsDirectory) {
            try FileManager.default.createDirectory(at: folder.deletingLastPathComponent(), withIntermediateDirectories: true)
            onProgress?(0)
            let progress = onProgress
            try await AsrModels.download(to: folder, version: version) { value in
                let fraction = value.fractionCompleted * 0.9
                Task { @MainActor in progress?(fraction) }
            }
            try Task.checkCancellation()
        }
        guard download || Self.isInstalled(model, modelsDirectory: modelsDirectory) else { throw SpeechError.modelNotInstalled(model.name) }
        onProgress?(0.95)
        manager = nil
        loadedModelID = nil
        let models = try await Task.detached { try AsrModels.loadLocal(from: folder, version: version) }.value
        let asr = AsrManager()
        try await asr.loadModels(models)
        try Task.checkCancellation()
        if download {
            try Data(model.modelName.utf8).write(to: folder.appending(path: ".betterwispr-installed"), options: .atomic)
        }
        manager = asr
        loadedModelID = model.id
        onProgress?(1)
    }

    public func transcribe(audioURL: URL, language: String?, vocabulary: [String]) async throws -> String {
        guard let manager, !preparing else { throw SpeechError.notPrepared }
        guard transcriptionTask == nil else { throw SpeechError.busy }
        guard audioURL.isFileURL, FileManager.default.fileExists(atPath: audioURL.path) else { throw SpeechError.audioUnavailable }
        try Task.checkCancellation()
        let hint = language.flatMap { Locale(identifier: $0).language.languageCode?.identifier }.flatMap(Language.init(rawValue:))
        let task = Task {
            var state = TdtDecoderState.make(decoderLayers: await manager.decoderLayerCount)
            let result = try await manager.transcribe(audioURL, decoderState: &state, language: hint)
            try Task.checkCancellation()
            return result.text.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        transcriptionTask = task
        defer { transcriptionTask = nil }
        return try await withTaskCancellationHandler { try await task.value } onCancel: { task.cancel() }
    }

    public func cancel() {
        transcriptionTask?.cancel()
    }
}
