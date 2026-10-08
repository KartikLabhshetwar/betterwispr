import Foundation

public enum SpeechAPI: String, Codable, CaseIterable, Hashable, Sendable {
    case sarvam, smallest, openAICompatible

    public var name: String {
        switch self {
        case .sarvam: "Sarvam AI"
        case .smallest: "Smallest AI"
        case .openAICompatible: "OpenAI-compatible"
        }
    }

    public var endpoint: String {
        switch self {
        case .sarvam: "https://api.sarvam.ai/speech-to-text"
        case .smallest: "https://api.smallest.ai/waves/v1/stt/"
        case .openAICompatible: "http://localhost:8000/v1/audio/transcriptions"
        }
    }

    public var defaultModel: String {
        switch self {
        case .sarvam: "saaras:v4"
        case .smallest: "pulse"
        case .openAICompatible: "whisper-1"
        }
    }
}

/// Only connection metadata is persisted. Secrets live in the login Keychain.
public struct SpeechConnection: Identifiable, Codable, Equatable, Hashable, Sendable {
    public var id: UUID
    public var name: String
    public var api: SpeechAPI
    public var endpoint: String
    public var modelID: String

    public init(id: UUID = UUID(), api: SpeechAPI = .sarvam) {
        self.id = id
        self.api = api
        name = api.name
        endpoint = api.endpoint
        modelID = api.defaultModel
    }

    public var speechModel: SpeechModel {
        SpeechModel(id: "connection-\(id.uuidString)", name: name,
                    detail: "\(api.name) · \(endpoint)", sizeLabel: "Uses your endpoint",
                    engine: .api, modelName: modelID, connection: self)
    }

    // Bind credentials to the exact destination and API. Editing a URL cannot forward an old key.
    public var keychainAccount: String { "\(id.uuidString)|\(api.rawValue)|\(endpoint)" }

    public func validatedURL() throws -> URL {
        guard !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, name.count <= 100,
              !modelID.isEmpty, modelID.count <= 200,
              !modelID.unicodeScalars.contains(where: { CharacterSet.controlCharacters.contains($0) }) else {
            throw SpeechAPIError.configuration("Enter a name and a model ID (up to 100 and 200 characters).")
        }
        guard endpoint.count <= 2048,
              let parts = URLComponents(string: endpoint), let url = parts.url,
              let host = parts.host, !host.isEmpty,
              parts.user == nil, parts.password == nil, parts.query == nil, parts.fragment == nil,
              parts.port.map({ (1...65535).contains($0) }) ?? true,
              parts.scheme == "https" || (parts.scheme == "http" && Self.isLoopback(host)),
              api == .openAICompatible || endpoint == api.endpoint else {
            throw SpeechAPIError.configuration("Use a full HTTPS endpoint URL without credentials, query parameters or fragments. HTTP is allowed only for localhost, 127.0.0.1 or [::1].")
        }
        return url
    }

    private static func isLoopback(_ host: String) -> Bool {
        ["localhost", "127.0.0.1", "[::1]", "::1"].contains(host.lowercased())
    }

    public func validateAPIKey(_ key: String) throws {
        guard api == .openAICompatible || !key.isEmpty else { throw SpeechAPIError.missingKey }
        guard key.utf8.count <= 8192, key.utf8.allSatisfy({ (33...126).contains($0) }) else {
            throw SpeechAPIError.configuration("The API key contains spaces or unsupported characters. Paste only the key.")
        }
    }

    /// Checked before recording in both session coordinators, and again at the request boundary.
    public func validateLanguage(_ language: String?) throws {
        let code = language.flatMap { $0 == "auto" ? nil : Locale(identifier: $0).language.languageCode?.identifier }
        if api == .smallest {
            guard let code else {
                throw SpeechAPIError.configuration("Choose a spoken language in Settings for Smallest AI. This connection requires an explicit language.")
            }
            if modelID == "pulse-pro", code != "en" {
                throw SpeechAPIError.configuration("Pulse Pro requires English. Choose English in Settings or use the pulse model.")
            }
        }
        if api == .sarvam, let code {
            let supported = ["en", "hi", "bn", "kn", "ml", "mr", "od", "pa", "ta", "te", "gu", "as", "ur", "ne", "kok", "ks", "sd", "sa", "sat", "mni", "brx", "mai", "doi"]
            guard supported.contains(code) else {
                throw SpeechAPIError.configuration("Sarvam does not support the selected language. Choose a supported language or Detect automatically in Settings.")
            }
        }
    }
}

public enum SpeechAPIError: LocalizedError, Sendable {
    case configuration(String), missingKey, keychain(Int32), http(Int), invalidResponse, audioTooLong

    public var errorDescription: String? {
        switch self {
        case .configuration(let message): message
        case .missingKey: "Add your API key in Models → Bring your own model."
        case .keychain(let status): "Couldn’t access the API key in macOS Keychain (\(status)). Unlock your login keychain and try again."
        case .http(401), .http(403): "The provider rejected your API key. Check the key and its permissions in Models."
        case .http(429): "The provider’s rate limit or account quota was reached. Check your account and try again later."
        case .http(300..<400): "The endpoint redirected the request. Enter its final URL in Models; audio and keys are never forwarded to redirects."
        case .http(let code): "The speech endpoint returned HTTP \(code). Check the endpoint, model and selected language."
        case .invalidResponse: "The endpoint did not return a supported transcription response. Check its API format and model."
        case .audioTooLong: "Use an audio clip of at most two minutes for this connection."
        }
    }
}
