import Foundation
import Testing
@testable import BetterWisprCore

@MainActor
@Test func offlineSpeechRejectsMissingAssets() async throws {
    let directory = FileManager.default.temporaryDirectory.appending(path: "betterwispr-offline-test-\(UUID().uuidString)")
    let model = try #require(SpeechModel.catalog.first { $0.id == "whisper-turbo" })
    let provider = WhisperKitProvider(modelsDirectory: directory)
    #expect(!WhisperKitProvider.isInstalled(model, modelsDirectory: directory))
    do {
        try await provider.prepare(model: model, download: false)
        Issue.record("An absent local model must not be prepared or downloaded")
    } catch SpeechError.modelNotInstalled {
        #expect(!FileManager.default.fileExists(atPath: directory.path))
    }
    #expect(!WhisperKitProvider.containsSignal(in: Array(repeating: 0, count: 32_000)))
    #expect(!WhisperKitProvider.containsSignal(in: [.nan, .infinity]))
    #expect(WhisperKitProvider.containsSignal(in: [0, -0.0001, 0]))
}

@Test func waveformFillsForQuietVoicesAndStaysFlatInSteadyNoise() {
    func amplitude(_ decibels: Float) -> Float { pow(10, decibels / 20) }
    var quietRoom = VoiceLevelMeter()
    let silence = (0..<40).map { _ in quietRoom.update(rms: amplitude(-60), over: 0.1) }
    let quietVoice = (0..<40).map { quietRoom.update(rms: amplitude($0 % 4 == 0 ? -56 : -45), over: 0.1) }
    let pause = (0..<20).map { _ in quietRoom.update(rms: amplitude(-60), over: 0.1) }
    #expect(silence.allSatisfy { $0 < 0.05 })
    #expect(quietVoice.max()! > 0.9)
    #expect(quietVoice.suffix(20).reduce(0, +) / 20 > 0.6)
    #expect(pause.last! < 0.05)

    var noisyRoom = VoiceLevelMeter()
    #expect((0..<200).map { _ in noisyRoom.update(rms: amplitude(-42), over: 0.1) }.allSatisfy { $0 < 0.05 })
    #expect(noisyRoom.update(rms: amplitude(-25), over: 0.1) > 0.5)

    var muted = VoiceLevelMeter()
    #expect([0, .nan, .infinity].map { muted.update(rms: $0, over: 0.1) } == [0, 0, 0])
}

@Test func waveformMovesAtTheSameSpeedForAnySliceLength() {
    func amplitude(_ decibels: Float) -> Float { pow(10, decibels / 20) }
    let speech: [Float] = Array(repeating: -60, count: 10) + Array(repeating: -35, count: 3) + Array(repeating: -60, count: 4)
    var buffers = VoiceLevelMeter()
    var slices = VoiceLevelMeter()
    let buffered = speech.map { buffers.update(rms: amplitude($0), over: 0.1) }
    let sliced = speech.map { decibels in (0..<5).map { _ in slices.update(rms: amplitude(decibels), over: 0.02) }.last! }
    #expect(buffered.max()! > 0.9)
    #expect(buffered.last! < 0.05)
    #expect(zip(buffered, sliced).allSatisfy { abs($0 - $1) < 0.03 })
}

@Test func waveformPlaysBufferSlicesAcrossTheirDuration() {
    let start = Date(timeIntervalSinceReferenceDate: 100)
    let levels = VoiceLevels(values: [0.2, 0.9, 0.5], start: start, step: 0.02)
    #expect(levels.value(at: start.addingTimeInterval(-1)) == 0.2)
    #expect(levels.value(at: start.addingTimeInterval(0.025)) == 0.9)
    #expect(levels.value(at: start.addingTimeInterval(0.045)) == 0.5)
    #expect(levels.value(at: start.addingTimeInterval(5)) == 0.5)
    #expect(VoiceLevels().value(at: start) == 0)
}

@MainActor
@Test func parakeetRejectsMissingAssetsWithoutDownloading() async throws {
    let directory = FileManager.default.temporaryDirectory.appending(path: "betterwispr-parakeet-test-\(UUID().uuidString)")
    for model in SpeechModel.catalog where model.engine == .parakeet {
        #expect(ParakeetProvider.version(for: model) != nil)
        #expect(!ParakeetProvider.isInstalled(model, modelsDirectory: directory))
        do {
            try await ParakeetProvider(modelsDirectory: directory).prepare(model: model, download: false)
            Issue.record("An absent local model must not be prepared or downloaded")
        } catch SpeechError.modelNotInstalled {
            #expect(!FileManager.default.fileExists(atPath: directory.path))
        }
    }
}
