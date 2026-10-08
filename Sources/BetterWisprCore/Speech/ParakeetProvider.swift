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
    private var phraseBooster: CtcModels?
    private var boostingSession: (terms: [String], session: VocabularyBoostingSession)?

    nonisolated static let maximumBoostingTerms = ContextBiasingConstants.extraLargeVocabThreshold

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

    /// FluidAudio's vocabulary session reads the CTC tokenizer from this fixed cache folder.
    public nonisolated static var phraseBoosterDirectory: URL { CtcModels.defaultCacheDirectory(for: .ctc110m) }

    public nonisolated static func isPhraseBoosterInstalled(at directory: URL = phraseBoosterDirectory) -> Bool {
        FileManager.default.fileExists(atPath: directory.appending(path: ".betterwispr-installed").path)
            && CtcModels.modelsExist(at: directory)
    }

    nonisolated static func boostingTerms(_ vocabulary: [String]) -> [String] {
        let minimumLength = CustomVocabularyContext(terms: []).minTermLength
        var seen = Set<String>()
        var terms: [String] = []
        for entry in vocabulary {
            let term = entry.trimmingCharacters(in: .whitespacesAndNewlines)
            guard term.count >= minimumLength, seen.insert(term.lowercased()).inserted else { continue }
            terms.append(term)
            if terms.count == maximumBoostingTerms { break }
        }
        return terms
    }

    nonisolated static func restoringPunctuation(original: String, rescored: String, replacements: [(original: String, replacement: String)]) -> String {
        let originalWords = original.split(separator: " ")
        let rescoredWords = rescored.split(separator: " ")
        let spans = replacements
            .map { (original: $0.original.split(separator: " "), replacement: $0.replacement.split(separator: " ")) }
            .filter { !$0.original.isEmpty && !$0.replacement.isEmpty }
        var words: [String] = []
        var originalIndex = 0
        var rescoredIndex = 0
        while originalIndex < originalWords.count, rescoredIndex < rescoredWords.count {
            if let span = spans.first(where: {
                originalWords[originalIndex...].starts(with: $0.original) && rescoredWords[rescoredIndex...].starts(with: $0.replacement)
            }) {
                let first = originalWords[originalIndex]
                let last = originalWords[originalIndex + span.original.count - 1]
                let leading = first.firstIndex { $0.isLetter || $0.isNumber }.map { String(first[..<$0]) } ?? ""
                let trailing = last.lastIndex { $0.isLetter || $0.isNumber }.map { String(last[last.index(after: $0)...]) } ?? ""
                var replaced = span.replacement.map(String.init)
                if !replaced[0].hasPrefix(leading) { replaced[0] = leading + replaced[0] }
                if !replaced[replaced.count - 1].hasSuffix(trailing) { replaced[replaced.count - 1] += trailing }
                words += replaced
                originalIndex += span.original.count
                rescoredIndex += span.replacement.count
            } else if originalWords[originalIndex] == rescoredWords[rescoredIndex] {
                words.append(String(originalWords[originalIndex]))
                originalIndex += 1
                rescoredIndex += 1
            } else {
                return rescored
            }
        }
        guard originalIndex == originalWords.count, rescoredIndex == rescoredWords.count else { return rescored }
        return words.joined(separator: " ")
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
        if phraseBooster == nil, Self.isPhraseBoosterInstalled() {
            phraseBooster = try? await CtcModels.loadDirect(from: Self.phraseBoosterDirectory)
        }
        manager = asr
        loadedModelID = model.id
        onProgress?(1)
    }

    /// Downloads the CTC phrase booster on an explicit user request and keeps it loaded for transcription.
    public func installPhraseBooster() async throws {
        guard !preparing, transcriptionTask == nil else { throw SpeechError.busy }
        preparing = true
        defer { preparing = false }
        try Task.checkCancellation()
        let directory = Self.phraseBoosterDirectory
        onProgress?(0)
        try await CtcModels.download(to: directory)
        try Task.checkCancellation()
        let booster = try await CtcModels.loadDirect(from: directory)
        _ = try await CtcTokenizer.load(from: directory)
        try Task.checkCancellation()
        try Data(directory.lastPathComponent.utf8).write(to: directory.appending(path: ".betterwispr-installed"), options: .atomic)
        phraseBooster = booster
        boostingSession = nil
        onProgress?(1)
    }

    public func transcribe(audioURL: URL, language: String?, vocabulary: [String]) async throws -> String {
        guard let manager, !preparing else { throw SpeechError.notPrepared }
        guard transcriptionTask == nil else { throw SpeechError.busy }
        guard audioURL.isFileURL, FileManager.default.fileExists(atPath: audioURL.path) else { throw SpeechError.audioUnavailable }
        try Task.checkCancellation()
        let hint = language.flatMap { Locale(identifier: $0).language.languageCode?.identifier }.flatMap(Language.init(rawValue:))
        let terms = hint == nil || hint == .english ? Self.boostingTerms(vocabulary) : []
        let task = Task {
            let text: String
            if let session = await self.boostingSession(for: terms) {
                text = try await Self.boostedTranscript(of: audioURL, language: hint, manager: manager, session: session)
            } else {
                var state = TdtDecoderState.make(decoderLayers: await manager.decoderLayerCount)
                text = try await manager.transcribe(audioURL, decoderState: &state, language: hint).text
            }
            try Task.checkCancellation()
            return text.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        transcriptionTask = task
        defer { transcriptionTask = nil }
        return try await withTaskCancellationHandler { try await task.value } onCancel: { task.cancel() }
    }

    public func cancel() {
        transcriptionTask?.cancel()
    }

    private func boostingSession(for terms: [String]) async -> VocabularyBoostingSession? {
        guard !terms.isEmpty, let phraseBooster else { return nil }
        if let boostingSession, boostingSession.terms == terms { return boostingSession.session }
        let vocabulary = CustomVocabularyContext(terms: terms.map { CustomVocabularyTerm(text: $0) })
        guard let session = try? await VocabularyBoostingSession(vocabulary: vocabulary, ctcModels: phraseBooster, config: VocabularyBoostingSession.itnDefaultConfig) else { return nil }
        boostingSession = (terms, session)
        return session
    }

    @concurrent
    private nonisolated static func boostedTranscript(
        of audioURL: URL, language: Language?, manager: AsrManager, session: VocabularyBoostingSession
    ) async throws -> String {
        let samples = try AudioConverter().resampleAudioFile(audioURL)
        try Task.checkCancellation()
        var state = TdtDecoderState.make(decoderLayers: await manager.decoderLayerCount)
        let result = try await manager.transcribe(samples, decoderState: &state, language: language)
        try Task.checkCancellation()
        guard let rescored = await session.rescore(text: result.text, tokenTimings: result.tokenTimings ?? [], audioSamples: samples),
              rescored.wasModified else { return result.text }
        let replacements = rescored.replacements.compactMap { item in
            item.shouldReplace ? item.replacementWord.map { (original: item.originalWord, replacement: $0) } : nil
        }
        return restoringPunctuation(original: result.text, rescored: rescored.text, replacements: replacements)
    }
}
