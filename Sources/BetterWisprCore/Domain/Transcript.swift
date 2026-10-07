import Foundation

public struct Transcript: Codable, Identifiable, Equatable, Sendable {
    public var id: UUID
    public var createdAt: Date
    public var text: String
    public var rawText: String
    public var duration: TimeInterval
    public var modelName: String
    public var language: String

    public init(id: UUID = UUID(), createdAt: Date = .now, text: String, rawText: String,
                duration: TimeInterval, modelName: String, language: String) {
        self.id = id
        self.createdAt = createdAt
        self.text = text
        self.rawText = rawText
        self.duration = duration
        self.modelName = modelName
        self.language = language
    }

    public var wordCount: Int { text.split(whereSeparator: \.isWhitespace).count }
}

public struct VocabularyEntry: Codable, Identifiable, Equatable, Sendable {
    public var id: UUID
    public var phrase: String
    public var replacement: String

    public init(id: UUID = UUID(), phrase: String, replacement: String) {
        self.id = id
        self.phrase = phrase
        self.replacement = replacement
    }
}
