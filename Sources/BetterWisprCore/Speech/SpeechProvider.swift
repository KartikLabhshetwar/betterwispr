import Foundation

public enum SpeechEngine: String, Codable, Sendable {
    case apple, whisperKit, parakeet, api
}

public struct SpeechModel: Identifiable, Hashable, Sendable {
    public let id: String
    public let name: String
    public let detail: String
    public let sizeLabel: String
    public let engine: SpeechEngine
    public let modelName: String
    public let tokenizerName: String?
    public let connection: SpeechConnection?

    public init(id: String, name: String, detail: String, sizeLabel: String, engine: SpeechEngine,
                modelName: String, tokenizerName: String? = nil, connection: SpeechConnection? = nil) {
        self.id = id
        self.name = name
        self.detail = detail
        self.sizeLabel = sizeLabel
        self.engine = engine
        self.modelName = modelName
        self.tokenizerName = tokenizerName
        self.connection = connection
    }

    public static let catalog: [SpeechModel] = [
        .init(id: "apple", name: "Apple on-device", detail: "Uses an available macOS language pack. No cloud fallback.",
              sizeLabel: "System managed", engine: .apple, modelName: "apple"),
        .init(id: "parakeet-v3", name: "Parakeet TDT v3", detail: "NVIDIA's multilingual model for 25 European languages, with punctuation. Fast on the Neural Engine.",
              sizeLabel: "~480 MB", engine: .parakeet, modelName: "parakeet-tdt-0.6b-v3"),
        .init(id: "parakeet-v2", name: "Parakeet TDT v2", detail: "NVIDIA's English-only model, tuned for English accuracy, with punctuation.",
              sizeLabel: "~460 MB", engine: .parakeet, modelName: "parakeet-tdt-0.6b-v2"),
        .init(id: "whisper-turbo", name: "Whisper Large v3 Turbo", detail: "Broadest language coverage, including languages Parakeet does not support.",
              sizeLabel: "~1.6 GB", engine: .whisperKit, modelName: "openai_whisper-large-v3-v20240930_turbo", tokenizerName: "openai/whisper-large-v3")
    ]
}

@MainActor
public protocol SpeechProvider: AnyObject {
    var onProgress: (@MainActor @Sendable (Double) -> Void)? { get set }
    var onPartialTranscript: (@MainActor @Sendable (String) -> Void)? { get set }
    /// Local providers may download only with `download: true`. API providers only validate here;
    /// their explicitly selected connection authorizes network use during transcription.
    func prepare(model: SpeechModel, download: Bool) async throws
    func transcribe(audioURL: URL, language: String?, vocabulary: [String]) async throws -> String
    func cancel()
}

extension SpeechModel {
    @MainActor public func makeProvider() -> any SpeechProvider {
        switch engine {
        case .apple: AppleSpeechProvider()
        case .whisperKit: WhisperKitProvider()
        case .parakeet: ParakeetProvider()
        case .api: APISpeechProvider()
        }
    }
}

public enum SpeechError: LocalizedError, Sendable {
    case modelNotInstalled(String)
    case invalidModel
    case notPrepared
    case busy
    case permissionDenied
    case onDeviceUnavailable(String)
    case timedOut
    case emptyAudio
    case audioUnavailable

    public var errorDescription: String? {
        switch self {
        case .modelNotInstalled(let name): "Download \(name) in Models first. Transcription never downloads files."
        case .invalidModel: "This speech provider cannot load the selected model."
        case .notPrepared: "Prepare a speech model before starting dictation."
        case .busy: "A speech operation is already running."
        case .permissionDenied: "Allow Speech Recognition for BetterWispr in System Settings → Privacy & Security."
        case .onDeviceUnavailable(let locale): "Apple on-device recognition is unavailable for \(locale). Install a Whisper model for offline dictation."
        case .timedOut: "On-device speech recognition timed out. Try a shorter recording or a Whisper model."
        case .emptyAudio: "The recording contains no audio."
        case .audioUnavailable: "Select an existing local audio file."
        }
    }
}
