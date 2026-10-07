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
    let silence = (0..<40).map { _ in quietRoom.update(rms: amplitude(-60)) }
    let quietVoice = (0..<40).map { quietRoom.update(rms: amplitude($0 % 4 == 0 ? -56 : -45)) }
    let pause = (0..<20).map { _ in quietRoom.update(rms: amplitude(-60)) }
    #expect(silence.allSatisfy { $0 < 0.05 })
    #expect(quietVoice.max()! > 0.9)
    #expect(quietVoice.suffix(20).reduce(0, +) / 20 > 0.6)
    #expect(pause.last! < 0.05)

    var noisyRoom = VoiceLevelMeter()
    #expect((0..<200).map { _ in noisyRoom.update(rms: amplitude(-42)) }.allSatisfy { $0 < 0.05 })
    #expect(noisyRoom.update(rms: amplitude(-25)) > 0.5)

    var muted = VoiceLevelMeter()
    #expect([0, .nan, .infinity].map { muted.update(rms: $0) } == [0, 0, 0])
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
