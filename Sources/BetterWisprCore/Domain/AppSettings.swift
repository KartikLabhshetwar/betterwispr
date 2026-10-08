import Foundation

public enum DictationMode: String, Codable, CaseIterable, Sendable {
    case hold, toggle
}

public struct AppSettings: Codable, Equatable, Sendable {
    public var selectedModelID: String = "apple"
    public var speechConnections: [SpeechConnection] = []
    public var language: String = "auto"
    public var autoPaste: Bool = true
    public var copyToClipboard: Bool = true
    public var saveHistory: Bool = true
    public var showCapsule: Bool = true
    public var launchAtLogin: Bool = false
    public var silenceThreshold: Float = 0.002
    public var dictationMode: DictationMode = .hold
    public var shortcut: DictationShortcut = .optionSpace

    public init() {}

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        selectedModelID = try container.decode(String.self, forKey: .selectedModelID)
        speechConnections = try container.decodeIfPresent([SpeechConnection].self, forKey: .speechConnections) ?? []
        language = try container.decode(String.self, forKey: .language)
        autoPaste = try container.decode(Bool.self, forKey: .autoPaste)
        copyToClipboard = try container.decodeIfPresent(Bool.self, forKey: .copyToClipboard) ?? true
        saveHistory = try container.decode(Bool.self, forKey: .saveHistory)
        showCapsule = try container.decode(Bool.self, forKey: .showCapsule)
        launchAtLogin = try container.decode(Bool.self, forKey: .launchAtLogin)
        silenceThreshold = try container.decode(Float.self, forKey: .silenceThreshold)
        dictationMode = try container.decodeIfPresent(DictationMode.self, forKey: .dictationMode) ?? .hold
        shortcut = try container.decodeIfPresent(DictationShortcut.self, forKey: .shortcut) ?? .optionSpace
    }
}
