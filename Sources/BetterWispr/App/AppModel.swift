import AppKit
import AVFoundation
@preconcurrency import ApplicationServices
import BetterWisprCore
import Observation
import ServiceManagement
import UniformTypeIdentifiers

enum RecordingPhase: Equatable {
    case idle, preparing, recording, transcribing
    case failed(DictationFailure)
}

struct DictationFailure: Equatable {
    var title: String
    var message: String
    var needsAccessibility = false

    static func tapped(_ shortcut: DictationShortcut) -> DictationFailure {
        DictationFailure(title: "Don’t tap. Hold \(shortcut.displayName).", message: "Hold \(shortcut.displayName) while speaking, release to see text.")
    }
    static func releasedEarly(_ shortcut: DictationShortcut) -> DictationFailure {
        DictationFailure(title: "Keep holding \(shortcut.displayName).", message: "Wait for the bars to move, then speak and release.")
    }
    static let noSpeech = DictationFailure(title: "No speech heard.", message: "Move closer to your microphone and try again.")
    static let pasteBlocked = DictationFailure(title: "Copied, not pasted.", message: "Allow Accessibility so text lands at your cursor. Press ⌘V for now.", needsAccessibility: true)
}

@MainActor @Observable
final class AppModel {
    var selectedPage: AppPage = .overview
    var phase: RecordingPhase = .idle { didSet { onPresentationChange?() } }
    var statusMessage = ""
    var partialTranscript = ""
    var voiceLevels = VoiceLevels()
    var isHeldSession = false
    var recordingDuration: TimeInterval = 0
    var history: [Transcript] = []
    var vocabulary: [VocabularyEntry] = []
    var settings = AppSettings()
    let models = SpeechModel.catalog
    let updater = AppUpdater()
    let meetings = MeetingModel()
    var preparingModelID: String?
    var downloadProgress: Double = 0
    var isInstallingPhraseBooster = false
    var phraseBoosterInstalled = false
    var microphoneGranted = AVCaptureDevice.authorizationStatus(for: .audio) == .authorized
    var accessibilityGranted = AXIsProcessTrusted()
    var onPresentationChange: (() -> Void)?
    var onShowCapsule: (() -> Void)?

    @ObservationIgnored private let store = LocalStore()
    @ObservationIgnored private let recorder = AudioRecorder()
    @ObservationIgnored private let globalShortcut = GlobalShortcut()
    @ObservationIgnored private var shortcutWarning: String?
    @ObservationIgnored private var provider: (any SpeechProvider)?
    @ObservationIgnored private var preparedModelID: String?
    @ObservationIgnored private var loading: (id: String, task: Task<Void, any Error>)?
    @ObservationIgnored private var operation: Task<Void, Never>?
    @ObservationIgnored private var ticker: Task<Void, Never>?
    @ObservationIgnored private var failureDismissal: Task<Void, Never>?
    @ObservationIgnored private var shortcutPressedAt: Date?
    @ObservationIgnored private var generation = UUID()
    @ObservationIgnored private var targetApplication: NSRunningApplication?
    @ObservationIgnored private var activeAudioURL: URL?
    @ObservationIgnored private var storageIsReadable = true
    @ObservationIgnored private var installedModelIDs: Set<String> = []
    var modelRevision = 0

    var selectedModel: SpeechModel { models.first { $0.id == settings.selectedModelID } ?? models[0] }
    var isBusy: Bool { phase == .preparing || phase == .recording || phase == .transcribing }
    var failure: DictationFailure? { if case .failed(let failure) = phase { failure } else { nil } }
    var totalWords: Int { history.reduce(0) { $0 + $1.wordCount } }
    var totalDuration: TimeInterval { history.reduce(0) { $0 + $1.duration } }

    init() {
        do {
            let state = try store.load()
            settings = state.settings
            history = state.history
            vocabulary = state.vocabulary
        } catch {
            storageIsReadable = false
            statusMessage = "Could not read your saved workspace. It has been left untouched: \(error.localizedDescription)"
        }
        if !models.contains(where: { $0.id == settings.selectedModelID }) { settings.selectedModelID = "apple" }
        settings.launchAtLogin = SMAppService.mainApp.status == .enabled
        refreshModels()
        recorder.onLevel = { [weak self] levels in self?.voiceLevels = levels }
        globalShortcut.onPress = { [weak self] in self?.shortcutPressed() }
        globalShortcut.onRelease = { [weak self] in self?.shortcutReleased() }
        warmUpSelectedModel()
    }

    func shortcutPressed() {
        guard shortcutPressedAt == nil || !isBusy else { return }
        guard settings.dictationMode == .hold, !isBusy else { toggleRecording(); return }
        shortcutPressedAt = Date()
        startRecording(held: true)
    }

    func shortcutReleased() {
        guard let pressedAt = shortcutPressedAt else { return }
        shortcutPressedAt = nil
        guard phase == .preparing || phase == .recording else { return }
        if Date().timeIntervalSince(pressedAt) < 0.3 { abandon(.tapped(settings.shortcut)) }
        else if phase == .preparing { abandon(.releasedEarly(settings.shortcut)) }
        else { finishRecording() }
    }

    func registerShortcut() {
        do {
            try globalShortcut.register(settings.shortcut)
            if statusMessage == shortcutWarning { statusMessage = "" }
        } catch {
            statusMessage = "\(error.localizedDescription) Use the menu bar or Record button to dictate, or choose another shortcut in Settings."
            shortcutWarning = statusMessage
        }
    }

    func suspendShortcut() { globalShortcut.unregister() }

    func changeShortcut(_ shortcut: DictationShortcut) {
        guard !isBusy else { return }
        do {
            try globalShortcut.register(shortcut)
        } catch {
            registerShortcut()
            ToastWindow.shared.show(Toast(failure: "Couldn’t use \(shortcut.displayName)", error))
            return
        }
        if statusMessage == shortcutWarning { statusMessage = "" }
        settings.shortcut = shortcut
        saveSettings()
    }

    func toggleRecording() {
        if phase == .recording { finishRecording(); return }
        startRecording(held: false)
    }

    private func startRecording(held: Bool) {
        guard !isBusy else { return }
        guard isModelInstalled(selectedModel) else {
            selectedPage = .models
            fail(DictationFailure(title: "Download a model first.", message: "Download \(selectedModel.name) in Models before recording."))
            return
        }
        targetApplication = NSWorkspace.shared.frontmostApplication
        isHeldSession = held
        let token = UUID()
        generation = token
        phase = .preparing
        statusMessage = "Preparing \(selectedModel.name)…"
        partialTranscript = ""
        recordingDuration = 0
        let model = selectedModel
        operation = Task { [weak self] in
            guard let self else { return }
            do {
                try await self.prepare(model, download: false)
                try Task.checkCancellation()
                guard self.generation == token else { return }
                self.recorder.silenceThreshold = self.settings.silenceThreshold
                try await self.recorder.start()
                try Task.checkCancellation()
                guard self.generation == token else { return }
                self.microphoneGranted = true
                self.phase = .recording
                let shortcut = self.settings.shortcut.displayName
                self.statusMessage = held ? "Listening. Release \(shortcut) to finish." : "Listening. Press \(shortcut) or click the capsule to finish."
                let started = Date()
                self.ticker = Task { [weak self] in
                    while !Task.isCancelled {
                        try? await Task.sleep(for: .milliseconds(100))
                        guard !Task.isCancelled, let self, self.generation == token else { return }
                        self.recordingDuration = Date().timeIntervalSince(started)
                        // Keep dictation bounded; a new recording can start immediately afterwards.
                        if self.recordingDuration >= 120 { self.finishRecording(); return }
                    }
                }
            } catch {
                guard self.generation == token else { return }
                self.recorder.cancel()
                self.fail(DictationFailure(title: "Couldn’t start dictation.", message: error.localizedDescription))
            }
        }
    }

    private func finishRecording() {
        guard phase == .recording else { return }
        ticker?.cancel()
        ticker = nil
        voiceLevels = VoiceLevels()
        let audio: RecordedAudio
        do { audio = try recorder.stop() }
        catch { recorder.cancel(); fail(DictationFailure(title: "Couldn’t finish recording.", message: error.localizedDescription)); return }
        recordingDuration = audio.duration
        guard audio.hasSpeech else {
            try? FileManager.default.removeItem(at: audio.url)
            fail(.noSpeech)
            return
        }
        let token = generation
        activeAudioURL = audio.url
        let model = selectedModel
        let language = settings.language == "auto" ? nil : settings.language
        let entries = vocabulary
        phase = .transcribing
        statusMessage = "Transcribing on your Mac…"
        operation = Task { [weak self] in
            defer {
                try? FileManager.default.removeItem(at: audio.url)
                if self?.activeAudioURL == audio.url { self?.activeAudioURL = nil }
            }
            guard let self, let provider = self.provider else { return }
            do {
                let hints = entries.map { $0.replacement.isEmpty ? $0.phrase : $0.replacement }
                let raw = try await provider.transcribe(audioURL: audio.url, language: language, vocabulary: hints)
                try Task.checkCancellation()
                guard self.generation == token else { return }
                let text = VocabularyProcessor.apply(entries, to: TranscriptCleaner.clean(raw, language: language))
                guard !text.isEmpty else { self.fail(.noSpeech); return }
                self.partialTranscript = text
                let transcript = Transcript(text: text, rawText: raw, duration: audio.duration,
                                            modelName: model.name, language: language ?? "auto")
                var persistenceWarning: String?
                if self.settings.saveHistory {
                    self.history.insert(transcript, at: 0)
                    do { try self.persist() } catch { persistenceWarning = error.localizedDescription }
                }
                let integration: (any TextOutputIntegration)? = self.settings.autoPaste
                    ? FocusedAppIntegration(keepsCopy: self.settings.copyToClipboard)
                    : self.settings.copyToClipboard ? ClipboardIntegration() : nil
                let result = try await integration?.deliver(text, to: self.targetApplication)
                guard self.generation == token else { return }
                if result == .copiedForManualPaste && !AXIsProcessTrusted() { self.fail(.pasteBlocked) }
                else {
                    self.phase = .idle
                    self.statusMessage = ""
                    switch result {
                    case .pasted, nil: break
                    case let result?: ToastWindow.shared.show(Toast(result))
                    }
                }
                if let persistenceWarning { self.statusMessage = "History could not be saved: \(persistenceWarning)" }
            } catch {
                guard self.generation == token else { return }
                self.fail(DictationFailure(title: "Couldn’t transcribe.", message: error.localizedDescription))
            }
        }
    }

    func cancelRecording() {
        generation = UUID()
        operation?.cancel()
        operation = nil
        ticker?.cancel()
        ticker = nil
        provider?.cancel()
        recorder.cancel()
        if let activeAudioURL { try? FileManager.default.removeItem(at: activeAudioURL) }
        activeAudioURL = nil
        // A cancelled preparation may leave a partially loaded provider; load cleanly next time.
        if phase == .transcribing || isInstallingPhraseBooster || (preparedModelID == nil && loading == nil) {
            provider = nil
            preparedModelID = nil
        }
        preparingModelID = nil
        isInstallingPhraseBooster = false
        voiceLevels = VoiceLevels()
        partialTranscript = ""
        phase = .idle
        statusMessage = "Cancelled."
        refreshModels()
    }

    private func prepare(_ model: SpeechModel, download: Bool) async throws {
        if model.engine == .apple {
            try AppleSpeechProvider.checkAvailability(language: settings.language == "auto" ? nil : settings.language)
        }
        let token = generation
        guard download else {
            if preparedModelID != model.id || provider == nil { try await load(model).value }
            try Task.checkCancellation()
            guard generation == token, let provider else { throw CancellationError() }
            observe(provider, token: token)
            return
        }
        let next = Self.makeProvider(for: model)
        observe(next, token: token)
        loading = nil
        preparedModelID = nil
        provider = next
        try await next.prepare(model: model, download: true)
        try Task.checkCancellation()
        guard generation == token else { throw CancellationError() }
        preparedModelID = model.id
    }

    /// Loads an installed model once, sharing the in-flight load so a cancelled dictation never discards it.
    @discardableResult
    private func load(_ model: SpeechModel) -> Task<Void, any Error> {
        if let loading, loading.id == model.id { return loading.task }
        let next = Self.makeProvider(for: model)
        preparedModelID = nil
        provider = next
        let task = Task { [weak self] in
            defer { if self?.provider === next { self?.loading = nil } }
            try await next.prepare(model: model, download: false)
            guard let self, self.provider === next else { throw CancellationError() }
            self.preparedModelID = model.id
        }
        loading = (model.id, task)
        return task
    }

    private func warmUpSelectedModel() {
        let model = selectedModel
        guard model.engine != .apple, isModelInstalled(model), preparedModelID != model.id else { return }
        load(model)
    }

    private func observe(_ provider: any SpeechProvider, token: UUID) {
        provider.onProgress = { [weak self] progress in
            guard let self, self.generation == token else { return }
            self.downloadProgress = progress
        }
        provider.onPartialTranscript = { [weak self] text in
            guard let self, self.generation == token, self.phase == .transcribing else { return }
            self.partialTranscript = text
        }
    }

    private static func makeProvider(for model: SpeechModel) -> any SpeechProvider {
        switch model.engine {
        case .apple: AppleSpeechProvider()
        case .whisperKit: WhisperKitProvider()
        case .parakeet: ParakeetProvider()
        }
    }

    func installModel(_ model: SpeechModel) {
        guard !isBusy else { return }
        let token = UUID()
        generation = token
        preparingModelID = model.id
        downloadProgress = 0
        phase = .preparing
        statusMessage = "Downloading \(model.name)…"
        operation = Task { [weak self] in
            guard let self else { return }
            do {
                try await self.prepare(model, download: true)
                guard self.generation == token else { return }
                self.refreshModels()
                self.settings.selectedModelID = model.id
                self.preparingModelID = nil
                self.phase = .idle
                self.statusMessage = "\(model.name) is ready for offline dictation."
                self.saveSettings()
            } catch {
                guard self.generation == token else { return }
                self.preparingModelID = nil
                self.fail(DictationFailure(title: "Couldn’t prepare \(model.name).", message: error.localizedDescription))
            }
        }
    }

    func installPhraseBooster() {
        guard !isBusy, selectedModel.engine == .parakeet else { return }
        let token = UUID()
        generation = token
        isInstallingPhraseBooster = true
        downloadProgress = 0
        phase = .preparing
        statusMessage = "Downloading the phrase booster…"
        operation = Task { [weak self] in
            guard let self else { return }
            do {
                try? await self.loading?.task.value
                let booster = self.provider as? ParakeetProvider ?? ParakeetProvider()
                self.observe(booster, token: token)
                try await booster.installPhraseBooster()
                guard self.generation == token else { return }
                self.isInstallingPhraseBooster = false
                self.refreshModels()
                self.phase = .idle
                self.statusMessage = "Parakeet now uses your vocabulary to spell names and terms."
            } catch {
                guard self.generation == token else { return }
                self.isInstallingPhraseBooster = false
                self.fail(DictationFailure(title: "Couldn’t download the phrase booster.", message: error.localizedDescription))
            }
        }
    }

    func selectModel(_ model: SpeechModel) {
        guard !isBusy else { return }
        settings.selectedModelID = model.id
        provider = nil
        preparedModelID = nil
        loading = nil
        saveSettings()
        warmUpSelectedModel()
    }

    func isModelInstalled(_ model: SpeechModel) -> Bool {
        _ = modelRevision
        return model.engine == .apple || installedModelIDs.contains(model.id)
    }

    private func refreshModels() {
        installedModelIDs = Set(models.filter { WhisperKitProvider.isInstalled($0) || ParakeetProvider.isInstalled($0) }.map(\.id))
        phraseBoosterInstalled = ParakeetProvider.isPhraseBoosterInstalled()
        modelRevision += 1
    }

    func copyTranscript(_ transcript: Transcript) {
        copyText(transcript.text)
    }

    func copyLatestTranscript() { copyText(partialTranscript) }

    private func copyText(_ text: String) {
        Task {
            do { ToastWindow.shared.show(Toast(try await ClipboardIntegration().deliver(text, to: nil))) }
            catch { ToastWindow.shared.show(Toast(failure: "Couldn’t copy", error)) }
        }
    }

    func deleteTranscript(_ transcript: Transcript) {
        let previous = history
        history.removeAll { $0.id == transcript.id }
        do {
            try persist()
            ToastWindow.shared.show(Toast(title: "Deleted", message: "The dictation was removed from history.", systemImage: "trash"))
        } catch {
            history = previous
            ToastWindow.shared.show(Toast(failure: "Couldn’t delete dictation", error))
        }
    }

    func addVocabulary(phrase: String, replacement: String) {
        let phrase = phrase.trimmingCharacters(in: .whitespacesAndNewlines)
        let replacement = replacement.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !phrase.isEmpty, phrase.count <= 100, replacement.count <= 100 else {
            statusMessage = "Use a phrase and spelling of at most 100 characters."; return
        }
        guard vocabulary.count < 200 else { statusMessage = "Keep your vocabulary to 200 entries for focused hints."; return }
        guard !vocabulary.contains(where: { $0.phrase.caseInsensitiveCompare(phrase) == .orderedSame }) else {
            statusMessage = "That phrase is already in your vocabulary."; return
        }
        vocabulary.append(VocabularyEntry(phrase: phrase, replacement: replacement))
        saveSettings()
    }

    func deleteVocabulary(_ entry: VocabularyEntry) {
        let previous = vocabulary
        vocabulary.removeAll { $0.id == entry.id }
        do {
            try persist()
            ToastWindow.shared.show(Toast(title: "Deleted", message: "“\(entry.phrase)” was removed from your vocabulary.", systemImage: "trash"))
        } catch {
            vocabulary = previous
            ToastWindow.shared.show(Toast(failure: "Couldn’t delete word", error))
        }
    }

    func saveSettings() {
        do {
            let registered = SMAppService.mainApp.status == .enabled
            if settings.launchAtLogin != registered {
                if settings.launchAtLogin { try SMAppService.mainApp.register() }
                else { try SMAppService.mainApp.unregister() }
            }
            try persist()
        } catch {
            settings.launchAtLogin = SMAppService.mainApp.status == .enabled
            statusMessage = "Could not save settings: \(error.localizedDescription)"
        }
        onPresentationChange?()
    }

    private func persist() throws {
        guard storageIsReadable else {
            throw NSError(domain: "BetterWispr", code: 1, userInfo: [NSLocalizedDescriptionKey:
                "The existing workspace could not be read, so it will not be overwritten. Back it up in \(store.directory.path) and restart."])
        }
        var state = SavedState()
        state.settings = settings
        state.history = history
        state.vocabulary = vocabulary
        try store.save(state)
    }

    func exportHistory() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.json]
        panel.nameFieldStringValue = "BetterWispr-history.json"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            encoder.dateEncodingStrategy = .iso8601
            try encoder.encode(history).write(to: url, options: .atomic)
            statusMessage = "History exported."
        } catch { statusMessage = "Export failed: \(error.localizedDescription)" }
    }

    func requestMicrophone() {
        Task {
            microphoneGranted = await AVCaptureDevice.requestAccess(for: .audio)
            if !microphoneGranted {
                NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone")!)
            }
        }
    }

    func requestAccessibility() {
        let key = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
        accessibilityGranted = AXIsProcessTrustedWithOptions([key: true] as CFDictionary)
    }

    func refreshPermissions() {
        microphoneGranted = AVCaptureDevice.authorizationStatus(for: .audio) == .authorized
        accessibilityGranted = AXIsProcessTrusted()
    }

    func showCapsule() { onShowCapsule?() }

    func dismissFailure() {
        if failure != nil { phase = .idle }
    }

    private func abandon(_ failure: DictationFailure) {
        cancelRecording()
        fail(failure)
    }

    private func fail(_ failure: DictationFailure) {
        phase = .failed(failure)
        statusMessage = failure.message
        failureDismissal?.cancel()
        failureDismissal = Task { [weak self] in
            try? await Task.sleep(for: .seconds(6))
            guard !Task.isCancelled, let self, self.phase == .failed(failure) else { return }
            self.phase = .idle
        }
    }
}
