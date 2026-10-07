import Foundation
import Testing
@testable import BetterWisprCore

@Test func vocabularyUsesWholeWordsAndNeverCascades() {
    let entries = [VocabularyEntry(phrase: "better whisper", replacement: "BetterWispr"),
                   VocabularyEntry(phrase: "BetterWispr", replacement: "wrong"),
                   VocabularyEntry(phrase: "café", replacement: "Café"),
                   VocabularyEntry(phrase: "cat", replacement: "$1\\dog")]
    #expect(VocabularyProcessor.apply(entries, to: "better whisper at café, not cafés. cat scatter")
            == "BetterWispr at Café, not cafés. $1\\dog scatter")
    #expect(VocabularyProcessor.apply([.init(phrase: "ह", replacement: "wrong")], to: "हिंदी") == "हिंदी")
}

@Test func workspaceRoundTripsAndRefusesCorruptData() throws {
    let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: folder) }
    let store = LocalStore(directory: folder)
    #expect(try store.load() == SavedState())
    var state = SavedState()
    state.history = [Transcript(text: "Hello", rawText: "hello", duration: 2, modelName: "Test", language: "en")]
    try store.save(state)
    #expect(try store.load() == state)
    try Data("broken".utf8).write(to: store.stateURL)
    #expect(throws: (any Error).self) { try store.load() }
    #expect(try String(contentsOf: store.stateURL, encoding: .utf8) == "broken")
}

@Test func settingsSavedBeforeDictationModesStillLoad() throws {
    let saved = #"{"autoPaste":true,"language":"auto","launchAtLogin":false,"saveHistory":true,"selectedModelID":"parakeet-v3","showCapsule":true,"silenceThreshold":0.002}"#
    let settings = try JSONDecoder().decode(AppSettings.self, from: Data(saved.utf8))
    #expect(settings.selectedModelID == "parakeet-v3")
    #expect(settings.dictationMode == .hold)
    #expect(settings.copyToClipboard)
    var toggled = settings
    toggled.dictationMode = .toggle
    toggled.copyToClipboard = false
    #expect(try JSONDecoder().decode(AppSettings.self, from: JSONEncoder().encode(toggled)) == toggled)
}
