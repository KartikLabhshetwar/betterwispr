import BetterWisprCore
import Foundation

enum CLIError: LocalizedError {
    case usage(String)
    var errorDescription: String? {
        switch self { case .usage(let message): message }
    }
}

@MainActor
func run() async throws {
    let arguments = Array(CommandLine.arguments.dropFirst())
    if arguments.isEmpty || arguments == ["--help"] {
        print("""
        BetterWisprCLI: local speech recognition

          --list-models
          --download-model MODEL_ID
          --download-phrase-booster
          --transcribe-file PATH [--model MODEL_ID] [--language en] [--vocabulary "Term,Other term"]
          --bench MANIFEST.jsonl [--model MODEL_ID] [--language auto|en] [--vocabulary "Term,Other term"] [--cleanup light|medium] [--notes-model OLLAMA_MODEL]
            Each manifest line is {"id", "language", "audio", "reference"}. Prints one JSON line per clip
            with the hypothesis and recognition seconds. Without --language, each clip uses its own language.
            --cleanup adds the app's cleanup of English text; medium edits with Apple's on-device model
            or the named Ollama model.

        Default model: parakeet-v3. Downloads only run with --download-model or --download-phrase-booster.
        Audio transcription loads existing local assets and never downloads them.
        """)
        return
    }
    if arguments == ["--list-models"] {
        for model in SpeechModel.catalog {
            print("\(model.id)\t\(model.name)\t\(model.sizeLabel)")
        }
        return
    }
    if arguments == ["--download-phrase-booster"] {
        try await ParakeetProvider.installPhraseBooster()
        print("Installed the Parakeet phrase booster at \(ParakeetProvider.phraseBoosterDirectory.path).")
        return
    }
    var options: [String: String] = [:]
    var index = 0
    while index < arguments.count {
        let option = arguments[index]
        guard ["--download-model", "--transcribe-file", "--bench", "--model", "--language", "--vocabulary", "--cleanup", "--notes-model"].contains(option),
              index + 1 < arguments.count, !arguments[index + 1].hasPrefix("--"), options[option] == nil else {
            throw CLIError.usage("Invalid or repeated argument: \(option). Run --help for usage.")
        }
        options[option] = arguments[index + 1]
        index += 2
    }
    guard options["--download-model"] != nil || options["--transcribe-file"] != nil || options["--bench"] != nil else {
        throw CLIError.usage("Choose --download-model, --transcribe-file or --bench.")
    }
    if let downloadID = options["--download-model"], let modelID = options["--model"], downloadID != modelID {
        throw CLIError.usage("Download and transcription must select the same model.")
    }
    let modelID = options["--model"] ?? options["--download-model"] ?? "parakeet-v3"
    guard let model = SpeechModel.catalog.first(where: { $0.id == modelID }) else {
        throw CLIError.usage("Unknown model: \(modelID). Run --list-models.")
    }
    let provider: any SpeechProvider
    switch model.engine {
    case .apple: throw CLIError.usage("Apple speech requires permissions granted through the macOS app. Select a Parakeet or Whisper model in the CLI.")
    case .whisperKit: provider = WhisperKitProvider()
    case .parakeet: provider = ParakeetProvider()
    case .api: throw CLIError.usage("Configure API connections in the macOS app. The CLI uses local models only.")
    }
    let clock = ContinuousClock()
    let started = clock.now
    if options["--download-model"] != nil {
        provider.onProgress = { FileHandle.standardError.write(Data("\rInstalling \(model.name): \(Int($0 * 100))%".utf8)) }
    }
    try await provider.prepare(model: model, download: options["--download-model"] != nil)
    FileHandle.standardError.write(Data("Prepared \(model.name) in \(started.duration(to: clock.now)).\n".utf8))
    let vocabulary = options["--vocabulary"].map { $0.split(separator: ",").map(String.init) } ?? []
    if let path = options["--bench"] {
        guard let cleanup = CleanupLevel(rawValue: options["--cleanup"] ?? "none") else {
            throw CLIError.usage("--cleanup must be light or medium.")
        }
        var settings = AppSettings()
        settings.cleanup = cleanup
        settings.notesModel = options["--notes-model"]
        try await bench(manifest: URL(fileURLWithPath: (path as NSString).expandingTildeInPath), provider: provider,
                        language: options["--language"], vocabulary: vocabulary, settings: settings)
    } else if let path = options["--transcribe-file"] {
        let url = URL(fileURLWithPath: (path as NSString).expandingTildeInPath)
        let language = options["--language"].flatMap { $0 == "auto" ? nil : $0 }
        let transcript = try await provider.transcribe(audioURL: url, language: language, vocabulary: vocabulary)
        print(transcript)
        FileHandle.standardError.write(Data("Completed in \(started.duration(to: clock.now)).\n".utf8))
    } else {
        print("\nInstalled \(model.name). Future transcription runs locally.")
    }
}

struct BenchClip: Codable {
    let id: String
    let language: String
    let audio: String
    let reference: String
}

struct BenchResult: Codable {
    let id: String
    let language: String
    let reference: String
    let hypothesis: String
    let seconds: Double
    var cleaned: String?
    var cleanupSeconds: Double?
}

/// Transcribes every manifest clip with the prepared provider, one JSON line per clip on stdout.
@MainActor
func bench(manifest: URL, provider: any SpeechProvider, language: String?, vocabulary: [String], settings: AppSettings) async throws {
    let decoder = JSONDecoder()
    let encoder = JSONEncoder()
    encoder.outputFormatting = .withoutEscapingSlashes
    let clock = ContinuousClock()
    for line in try String(contentsOf: manifest, encoding: .utf8).split(whereSeparator: \.isNewline) {
        let clip = try decoder.decode(BenchClip.self, from: Data(line.utf8))
        let spoken = (language ?? clip.language) == "auto" ? nil : language ?? clip.language
        let started = clock.now
        let hypothesis = try await provider.transcribe(audioURL: URL(fileURLWithPath: clip.audio), language: spoken, vocabulary: vocabulary)
        var result = BenchResult(id: clip.id, language: clip.language, reference: clip.reference, hypothesis: hypothesis,
                                 seconds: seconds(started.duration(to: clock.now)))
        if settings.cleanup != .none {
            let cleaning = clock.now
            var cleaned = TranscriptCleaner.clean(hypothesis, language: spoken)
            if settings.cleanup == .medium, TranscriptCleaner.isEnglish(cleaned, language: spoken) {
                cleaned = await TranscriptPolisher.polish(cleaned, settings: settings) ?? cleaned
            }
            result.cleaned = cleaned
            result.cleanupSeconds = seconds(cleaning.duration(to: clock.now))
        }
        print(String(decoding: try encoder.encode(result), as: UTF8.self))
    }
}

func seconds(_ duration: Duration) -> Double {
    Double(duration.components.seconds) + Double(duration.components.attoseconds) / 1e18
}

do {
    try await run()
} catch {
    FileHandle.standardError.write(Data("BetterWispr: \(error.localizedDescription)\n".utf8))
    exit(1)
}
