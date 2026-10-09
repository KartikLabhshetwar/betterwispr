import Foundation

public enum DictationMode: String, Codable, CaseIterable, Sendable {
    case hold, toggle
}

public enum AppTheme: String, Codable, CaseIterable, Sendable {
    case system, light, dark
}

public struct AppSettings: Codable, Equatable, Sendable {
    public var selectedModelID: String = "apple"
    public var speechConnections: [SpeechConnection] = []
    public var notesConnections: [SpeechConnection] = []
    public var notesConnectionID: UUID?
    public var notesCLI: NotesCLI?
    public var claudeNotesModel: String = ""
    public var codexNotesModel: String = ""
    public var language: String = "auto"
    public var autoPaste: Bool = true
    public var copyToClipboard: Bool = false
    public var saveHistory: Bool = true
    public var showCapsule: Bool = true
    public var soundEffects: Bool = true
    /// Offers the notetaker when a known call app or web meeting starts recording.
    public var detectMeetings: Bool = true
    public var theme: AppTheme = .dark
    public var launchAtLogin: Bool = false
    public var silenceThreshold: Float = 0.002
    public var dictationMode: DictationMode = .hold
    public var shortcut: DictationShortcut = .optionSpace
    public var learnCorrections: Bool = true
    public var cleanup: CleanupLevel = .light
    /// Missing contexts use `.formal`, which leaves the transcript as recognized.
    public var styles: [StyleContext: StyleTone] = [:]
    /// Nil uses Automatic: the macOS default input, or the built-in mic instead of a Bluetooth headset while the lid is open.
    public var microphone: AudioInputDevice?
    /// The Ollama model that writes meeting notes; nil uses Apple Intelligence.
    public var notesModel: String?
    /// The newest onboarding the user finished or skipped; 0 shows it again.
    public var completedOnboardingVersion: Int = 0
    /// The onboarding page to resume after quitting midway.
    public var onboardingStep: Int = 0

    public var notesSelection: NotesModelSelection {
        get {
            if let notesCLI { return .cli(notesCLI) }
            if let notesConnectionID { return .connection(notesConnectionID) }
            return notesModel.map(NotesModelSelection.ollama) ?? .apple
        }
        set {
            notesConnectionID = nil
            notesModel = nil
            notesCLI = nil
            switch newValue {
            case .apple: break
            case .ollama(let name): notesModel = name
            case .connection(let id): notesConnectionID = id
            case .cli(let cli): notesCLI = cli
            }
        }
    }

    public init() {}

    public func tone(for context: StyleContext) -> StyleTone { styles[context] ?? .formal }

    public func cliModel(_ cli: NotesCLI) -> String { cli == .claudeCode ? claudeNotesModel : codexNotesModel }

    public mutating func setCLIModel(_ model: String, for cli: NotesCLI) {
        if cli == .claudeCode { claudeNotesModel = model } else { codexNotesModel = model }
    }

    public var notesModelName: String {
        switch notesSelection {
        case .apple: "Apple Intelligence"
        case .ollama(let name): "Ollama · \(name)"
        case .connection(let id): notesConnections.first { $0.id == id }.map { "\($0.name) · \($0.modelID)" } ?? "Missing notes connection"
        case .cli(let cli): "\(cli.name) · \(cliModel(cli).isEmpty ? "Choose a model" : cliModel(cli))"
        }
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        selectedModelID = try container.decode(String.self, forKey: .selectedModelID)
        speechConnections = try container.decodeIfPresent([SpeechConnection].self, forKey: .speechConnections) ?? []
        notesConnections = try container.decodeIfPresent([SpeechConnection].self, forKey: .notesConnections) ?? []
        notesConnectionID = try container.decodeIfPresent(UUID.self, forKey: .notesConnectionID)
        notesCLI = try container.decodeIfPresent(NotesCLI.self, forKey: .notesCLI)
        claudeNotesModel = try container.decodeIfPresent(String.self, forKey: .claudeNotesModel) ?? ""
        codexNotesModel = try container.decodeIfPresent(String.self, forKey: .codexNotesModel) ?? ""
        language = try container.decode(String.self, forKey: .language)
        autoPaste = try container.decode(Bool.self, forKey: .autoPaste)
        copyToClipboard = try container.decodeIfPresent(Bool.self, forKey: .copyToClipboard) ?? false
        saveHistory = try container.decode(Bool.self, forKey: .saveHistory)
        showCapsule = try container.decode(Bool.self, forKey: .showCapsule)
        soundEffects = try container.decodeIfPresent(Bool.self, forKey: .soundEffects) ?? true
        detectMeetings = try container.decodeIfPresent(Bool.self, forKey: .detectMeetings) ?? true
        theme = try container.decodeIfPresent(AppTheme.self, forKey: .theme) ?? .dark
        launchAtLogin = try container.decode(Bool.self, forKey: .launchAtLogin)
        silenceThreshold = try container.decode(Float.self, forKey: .silenceThreshold)
        dictationMode = try container.decodeIfPresent(DictationMode.self, forKey: .dictationMode) ?? .hold
        shortcut = try container.decodeIfPresent(DictationShortcut.self, forKey: .shortcut) ?? .optionSpace
        microphone = try container.decodeIfPresent(AudioInputDevice.self, forKey: .microphone)
        learnCorrections = try container.decodeIfPresent(Bool.self, forKey: .learnCorrections) ?? true
        cleanup = try container.decodeIfPresent(CleanupLevel.self, forKey: .cleanup) ?? .light
        styles = try container.decodeIfPresent([StyleContext: StyleTone].self, forKey: .styles) ?? [:]
        notesModel = try container.decodeIfPresent(String.self, forKey: .notesModel)
        completedOnboardingVersion = try container.decodeIfPresent(Int.self, forKey: .completedOnboardingVersion) ?? 0
        onboardingStep = try container.decodeIfPresent(Int.self, forKey: .onboardingStep) ?? 0
    }
}
