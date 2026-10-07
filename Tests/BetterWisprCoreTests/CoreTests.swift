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

@Test func cleanerDropsMidSentenceFillersAndKeepsPrecedingPunctuation() {
    #expect(TranscriptCleaner.clean("The tests passed, uh, so merge it um now", language: "en")
            == "The tests passed, so merge it now")
    #expect(TranscriptCleaner.clean("Rename the file uh, then reload the hmm window", language: "en")
            == "Rename the file then reload the window")
    #expect(TranscriptCleaner.clean("and uh uh we can build um the export", language: "en") == "and we can build the export")
}

@Test func cleanerCapitalizesAfterSentenceInitialFiller() {
    #expect(TranscriptCleaner.clean("Can you check the logs? um yes, and the tests too.", language: "en")
            == "Can you check the logs? Yes, and the tests too.")
    #expect(TranscriptCleaner.clean("uh iPhone builds are slow", language: "en") == "iPhone builds are slow")
}

@Test func cleanerMovesTerminalPunctuationFromFiller() {
    #expect(TranscriptCleaner.clean("We are done for today uh.", language: "en") == "We are done for today.")
    #expect(TranscriptCleaner.clean("Is the build ready um?", language: "en") == "Is the build ready?")
}

@Test func cleanerRemovesRepeatedPhrases() {
    #expect(TranscriptCleaner.clean("Then we can we can deploy the app", language: "en") == "Then we can deploy the app")
    #expect(TranscriptCleaner.clean("I want to I want to fix the login bug", language: nil) == "I want to fix the login bug")
}

@Test func cleanerKeepsFirstCopyOfStutteredWord() {
    #expect(TranscriptCleaner.clean("We we should test it", language: "en") == "We should test it")
    #expect(TranscriptCleaner.clean("I I I think so", language: "en") == "I think so")
}

@Test func cleanerKeepsDeliberateRepeats() {
    #expect(TranscriptCleaner.clean("Hello, hello, hello, is this on?", language: "en") == "Hello, hello, hello, is this on?")
    #expect(TranscriptCleaner.clean("I know that that works", language: "en") == "I know that that works")
    #expect(TranscriptCleaner.clean("call 5 5 5 now", language: "en") == "call 5 5 5 now")
    #expect(TranscriptCleaner.clean("dial one one two", language: "en") == "dial one one two")
    #expect(TranscriptCleaner.clean("uh-huh, that sounds right", language: "en") == "uh-huh, that sounds right")
}

@Test func cleanerLeavesOtherLanguagesAndEmptiesFillerOnlyText() {
    #expect(TranscriptCleaner.clean(" Wir treffen uns um acht Uhr ", language: "de") == "Wir treffen uns um acht Uhr")
    #expect(TranscriptCleaner.clean("uh, um... hmm", language: "en") == "")
    #expect(TranscriptCleaner.clean("", language: "en") == "")
}
