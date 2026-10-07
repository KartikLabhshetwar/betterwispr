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
          --transcribe-file PATH [--model MODEL_ID] [--language en]

        Default model: parakeet-v3. Downloads only run with --download-model.
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
    var options: [String: String] = [:]
    var index = 0
    while index < arguments.count {
        let option = arguments[index]
        guard ["--download-model", "--transcribe-file", "--model", "--language"].contains(option),
              index + 1 < arguments.count, !arguments[index + 1].hasPrefix("--"), options[option] == nil else {
            throw CLIError.usage("Invalid or repeated argument: \(option). Run --help for usage.")
        }
        options[option] = arguments[index + 1]
        index += 2
    }
    guard options["--download-model"] != nil || options["--transcribe-file"] != nil else {
        throw CLIError.usage("Choose --download-model or --transcribe-file.")
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
    }
    let clock = ContinuousClock()
    let started = clock.now
    try await provider.prepare(model: model, download: options["--download-model"] != nil)
    if let path = options["--transcribe-file"] {
        let url = URL(fileURLWithPath: (path as NSString).expandingTildeInPath)
        let language = options["--language"].flatMap { $0 == "auto" ? nil : $0 }
        let transcript = try await provider.transcribe(audioURL: url, language: language, vocabulary: [])
        print(transcript)
        FileHandle.standardError.write(Data("Completed in \(started.duration(to: clock.now)).\n".utf8))
    } else {
        print("Installed \(model.name). Future transcription runs locally.")
    }
}

do {
    try await run()
} catch {
    FileHandle.standardError.write(Data("BetterWispr: \(error.localizedDescription)\n".utf8))
    exit(1)
}
