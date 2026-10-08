import Foundation
import Testing
@testable import BetterWisprCore
@testable import BetterWispr

@Test func localSoundsNeverFallBackToAnotherPack() throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    #expect(DictationSound.finished.url(in: directory) == nil)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    #expect(DictationSound.finished.url(in: directory) == nil)
    let custom = directory.appendingPathComponent("finished.wav")
    try Data().write(to: custom)
    #expect(DictationSound.finished.url(in: directory) == custom)
    #expect(DictationSound.attention.url(in: directory) == nil)
    try FileManager.default.removeItem(at: directory)
    #expect(DictationSound.finished.url(in: directory) == nil)
}

@Test @MainActor func capsuleHoverTracksEachControlAcrossExpansionAndExit() {
    let hover = CapsuleHover()
    hover.update(regions: [.surface: CGRect(x: 202, y: 218, width: 36, height: 6)])
    hover.move(to: CGPoint(x: 190, y: 210))
    #expect(hover.isHovering)

    let controls: [CapsuleHover.Target: CGRect] = [
        .surface: CGRect(x: 172, y: 196, width: 96, height: 28),
        .microphone: CGRect(x: 172, y: 196, width: 42, height: 28),
        .notetaker: CGRect(x: 218, y: 196, width: 28, height: 28),
        .meetingNotes: CGRect(x: 246, y: 196, width: 22, height: 28)
    ]
    hover.update(regions: controls)
    #expect(hover.target == .microphone)
    hover.move(to: CGPoint(x: 216, y: 210))
    #expect(hover.target == .microphone) // The gap should not flicker.
    hover.move(to: CGPoint(x: 230, y: 210))
    #expect(hover.target == .notetaker)
    hover.move(to: CGPoint(x: 257, y: 210))
    #expect(hover.target == .meetingNotes)

    hover.move(to: CGPoint(x: 10, y: 210))
    #expect(!hover.isHovering && hover.target == nil)
    hover.move(to: CGPoint(x: 230, y: 210))
    hover.move(to: nil)
    #expect(!hover.isHovering && hover.target == nil)

    hover.move(to: CGPoint(x: 220, y: 210))
    hover.update(regions: [
        .surface: CGRect(x: 183, y: 192, width: 74, height: 32),
        .dictation: CGRect(x: 183, y: 192, width: 74, height: 32)
    ])
    #expect(hover.target == .dictation)
    hover.update(regions: [
        .surface: CGRect(x: 183, y: 192, width: 74, height: 32),
        .notetaker: CGRect(x: 183, y: 192, width: 74, height: 32)
    ])
    #expect(hover.target == .notetaker) // The recording pill replaces all idle controls.
    hover.update(regions: [.surface: CGRect(x: 40, y: 104, width: 360, height: 120)])
    #expect(hover.isHovering && hover.target == nil) // No stale tooltip over an error.
}

@Test @MainActor func quickTapBecomesHandsFreeAndCancelledReleaseCannotFinishANewSession() {
    let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    let model = AppModel(store: LocalStore(directory: folder), startsServices: false)
    model.settings.soundEffects = false
    defer { model.discardRecording() }

    model.shortcutPressed()
    #expect(model.phase == .preparing && model.isHeldSession)
    model.shortcutReleased()
    #expect(model.phase == .preparing && !model.isHeldSession)
    model.shortcutReleased()
    #expect(model.phase == .preparing)
    model.cancelRecording()
    #expect(model.phase == .cancelled && !model.canUndoCancellation)
    #expect(model.cardDeadline != nil)

    model.shortcutPressed()
    model.cancelRecording()
    model.toggleRecording()
    model.shortcutReleased()
    #expect(model.phase == .preparing && !model.isHeldSession)
    #expect(model.cardDeadline == nil)
}

@Test @MainActor func cancellationUndoOwnsAudioUntilDismissalAndNeverDeliversStaleWork() async throws {
    let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: folder) }
    let model = AppModel(store: LocalStore(directory: folder), startsServices: false)
    model.settings.soundEffects = false
    model.settings.autoPaste = false
    model.settings.copyToClipboard = false
    defer { model.discardRecording() }
    let url = folder.appendingPathComponent("cancelled.caf")
    try Data("synthetic audio ownership check".utf8).write(to: url)
    var recording: DictationRecording? = DictationRecording(
        audio: RecordedAudio(url: url, duration: 1, hasSpeech: true), model: model.selectedModel,
        settings: model.settings, vocabulary: [], target: nil)
    weak let retained = recording
    model.transcribe(try #require(recording))
    recording = nil
    model.cancelRecording()
    #expect(model.canUndoCancellation)
    #expect(FileManager.default.fileExists(atPath: url.path))
    model.settings.language = "hi"
    #expect(retained?.settings.language == "auto")

    model.undoCancellation()
    #expect(model.phase == .transcribing && !model.canUndoCancellation)
    #expect(model.cardDeadline == nil)
    model.undoCancellation()
    model.cancelRecording()
    #expect(model.canUndoCancellation)
    model.dismissCard()
    model.undoCancellation()
    #expect(model.phase == .idle && !model.canUndoCancellation)
    try await Task.sleep(for: .milliseconds(100))
    #expect(retained == nil)
    #expect(!FileManager.default.fileExists(atPath: url.path))
    #expect(model.history.isEmpty && model.partialTranscript.isEmpty)

    model.toggleRecording()
    model.cancelRecording()
    model.phase = .recording
    try await Task.sleep(for: .seconds(AppModel.cancellationSeconds + 0.1))
    #expect(model.phase == .recording)
    model.discardRecording()

    try Data("synthetic expired undo check".utf8).write(to: url)
    model.transcribe(DictationRecording(
        audio: RecordedAudio(url: url, duration: 1, hasSpeech: true), model: model.selectedModel,
        settings: model.settings, vocabulary: [], target: nil))
    model.cancelRecording()
    #expect(model.canUndoCancellation)
    try await Task.sleep(for: .seconds(AppModel.cancellationSeconds + 0.1))
    #expect(model.phase == .idle && !model.canUndoCancellation)
    #expect(!FileManager.default.fileExists(atPath: url.path))
    model.undoCancellation()
    #expect(model.phase == .idle)
}
