import AppKit
import BetterWisprCore
import Observation

enum MeetingActivity: Equatable {
    case idle, starting(UUID), recording(UUID), finishing(UUID), generating(UUID)

    var meetingID: UUID? {
        switch self {
        case .idle: nil
        case .starting(let id), .recording(let id), .finishing(let id), .generating(let id): id
        }
    }

    var capturingID: UUID? {
        switch self {
        case .starting(let id), .recording(let id): id
        default: nil
        }
    }
}

@MainActor @Observable
final class MeetingModel {
    var meetings: [Meeting] = []
    var selectedID: UUID?
    var activity: MeetingActivity = .idle
    var levels: (me: Float, them: Float) = (0, 0)
    var elapsed: TimeInterval = 0
    var pendingChunks = 0
    var generationStep: (Int, Int)?
    var message: String?
    var systemAudioIssue: String?
    var showsCallAudioHint = false
    var notesAvailability = MeetingNotesGenerator.availability

    @ObservationIgnored private let store = MeetingStore()
    @ObservationIgnored private let recorder = MeetingRecorder()
    @ObservationIgnored private var provider: (any SpeechProvider)?
    @ObservationIgnored private var session = UUID()
    @ObservationIgnored private var language: String?
    @ObservationIgnored private var vocabulary: [VocabularyEntry] = []
    @ObservationIgnored private var startedAt = Date()
    @ObservationIgnored private var queue: [MeetingAudioChunk] = []
    @ObservationIgnored private var drain: Task<Void, Never>?
    @ObservationIgnored private var work: Task<Void, Never>?
    @ObservationIgnored private var ticker: Task<Void, Never>?
    @ObservationIgnored private var saves: [UUID: Task<Void, Never>] = [:]
    @ObservationIgnored private var heard: (me: Bool, them: Bool) = (false, false)

    init() {
        Self.removeLeftoverAudio()
        let loaded = store.load()
        meetings = loaded.meetings
        selectedID = meetings.first?.id
        if !loaded.unreadable.isEmpty {
            let count = loaded.unreadable.count
            message = "\(count) meeting \(count == 1 ? "file" : "files") in \(store.directory.path) couldn’t be read and \(count == 1 ? "was" : "were") left untouched."
        }
        recorder.onChunk = { [weak self] in self?.enqueue($0) }
        recorder.onLevels = { [weak self] in self?.receive($0) }
        recorder.onError = { [weak self] in self?.message = "Part of the recording couldn’t be saved: \($0.localizedDescription)" }
    }

    var selected: Meeting? { selectedID.flatMap(meeting) }

    func meeting(_ id: UUID) -> Meeting? { meetings.first { $0.id == id } }

    func isActive(_ id: UUID) -> Bool { activity.meetingID == id }

    func start(model: SpeechModel, language: String?, vocabulary: [VocabularyEntry], silenceThreshold: Float) {
        guard activity == .idle else { return }
        let token = UUID()
        let meeting = Meeting(modelName: model.name, language: language ?? "auto")
        session = token
        self.language = language
        self.vocabulary = vocabulary
        meetings.insert(meeting, at: 0)
        selectedID = meeting.id
        saveNow(meeting.id)
        activity = .starting(meeting.id)
        message = nil
        systemAudioIssue = nil
        showsCallAudioHint = false
        heard = (false, false)
        elapsed = 0
        pendingChunks = 0
        work = Task { [weak self] in
            do {
                if model.engine == .apple { try AppleSpeechProvider.checkAvailability(language: language) }
                let provider = Self.makeProvider(for: model)
                try await provider.prepare(model: model, download: false)
                try Task.checkCancellation()
                guard let self, self.session == token else { return }
                self.provider = provider
                try await self.recorder.start(silenceThreshold: silenceThreshold)
                guard self.session == token else { return }
                self.systemAudioIssue = self.recorder.systemAudioIssue
                self.startedAt = Date()
                self.activity = .recording(meeting.id)
                self.startTicker(token)
            } catch {
                guard let self, self.session == token else { return }
                self.provider = nil
                self.activity = .idle
                if !(error is CancellationError) { self.message = "Couldn’t start the meeting. \(error.localizedDescription)" }
                self.discardIfEmpty(meeting.id)
            }
        }
    }

    func stop() {
        if case .starting(let id) = activity {
            session = UUID()
            work?.cancel()
            recorder.cancel()
            provider = nil
            activity = .idle
            discardIfEmpty(id)
            return
        }
        guard case .recording(let id) = activity else { return }
        let token = session
        recorder.stop()
        ticker?.cancel()
        let duration = Date().timeIntervalSince(startedAt)
        elapsed = duration
        activity = .finishing(id)
        work = Task { [weak self] in
            await self?.drain?.value
            guard let self, self.session == token else { return }
            self.edit(id, save: false) { $0.duration = duration }
            self.saveNow(id)
            self.provider = nil
            self.notesAvailability = MeetingNotesGenerator.availability
            if self.notesAvailability == .available, self.meeting(id)?.hasContent == true {
                await self.writeNotes(for: id, token: token)
            } else {
                self.activity = .idle
            }
        }
    }

    func generateNotes(_ id: UUID) {
        guard activity == .idle else { return }
        let token = UUID()
        session = token
        work = Task { [weak self] in await self?.writeNotes(for: id, token: token) }
    }

    func edit(_ id: UUID, save: Bool = true, _ change: (inout Meeting) -> Void) {
        guard let index = meetings.firstIndex(where: { $0.id == id }) else { return }
        change(&meetings[index])
        if save { scheduleSave(id) }
    }

    func toggleActionItem(_ itemID: UUID, in id: UUID) {
        edit(id) { meeting in
            guard let index = meeting.summary?.actionItems.firstIndex(where: { $0.id == itemID }) else { return }
            meeting.summary?.actionItems[index].isDone.toggle()
        }
    }

    func delete(_ id: UUID) {
        guard !isActive(id) else {
            message = "Stop this meeting before deleting it."
            return
        }
        saves.removeValue(forKey: id)?.cancel()
        do {
            try store.delete(id: id)
        } catch {
            message = "Couldn’t delete the meeting. \(error.localizedDescription)"
            return
        }
        meetings.removeAll { $0.id == id }
        if selectedID == id { selectedID = meetings.first?.id }
    }

    func copy(_ id: UUID) {
        guard let markdown = meeting(id)?.markdown else { return }
        Task {
            do { ToastWindow.shared.show(Toast(try await ClipboardIntegration().deliver(markdown, to: nil))) }
            catch { ToastWindow.shared.show(Toast(failure: "Couldn’t copy", error)) }
        }
    }

    func endForQuit() {
        let id = activity.meetingID
        if case .recording = activity { elapsed = Date().timeIntervalSince(startedAt) }
        session = UUID()
        recorder.cancel()
        ticker?.cancel()
        work?.cancel()
        drain?.cancel()
        drain = nil
        provider?.cancel()
        provider = nil
        queue = []
        Self.removeLeftoverAudio()
        pendingChunks = 0
        if let id, meeting(id)?.duration == 0 { edit(id, save: false) { $0.duration = elapsed } }
        for pending in Array(saves.keys) { saveNow(pending) }
        if let id { saveNow(id) }
        activity = .idle
    }

    private func writeNotes(for id: UUID, token: UUID) async {
        notesAvailability = MeetingNotesGenerator.availability
        guard let meeting = meeting(id) else {
            activity = .idle
            return
        }
        activity = .generating(id)
        generationStep = nil
        do {
            let notes = try await MeetingNotesGenerator.generate(segments: meeting.segments, userNotes: meeting.notes) { [weak self] step, total in
                guard let self, self.session == token else { return }
                self.generationStep = (step, total)
            }
            guard session == token else { return }
            edit(id, save: false) { meeting in
                meeting.summary = notes.summary
                if meeting.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { meeting.title = notes.title }
            }
            saveNow(id)
        } catch {
            guard session == token else { return }
            if !(error is CancellationError) { message = "Couldn’t write notes. \(error.localizedDescription)" }
        }
        generationStep = nil
        activity = .idle
    }

    private func enqueue(_ chunk: MeetingAudioChunk) {
        guard chunk.hasSpeech, let id = activity.meetingID, provider != nil else {
            try? FileManager.default.removeItem(at: chunk.url)
            return
        }
        queue.append(chunk)
        pendingChunks += 1
        guard drain == nil else { return }
        let token = session
        drain = Task { [weak self] in await self?.transcribeQueue(into: id, token: token) }
    }

    private func transcribeQueue(into id: UUID, token: UUID) async {
        while session == token, let provider, !queue.isEmpty {
            let chunk = queue.removeFirst()
            defer {
                try? FileManager.default.removeItem(at: chunk.url)
                if session == token { pendingChunks = max(0, pendingChunks - 1) }
            }
            do {
                let hints = vocabulary.map { $0.replacement.isEmpty ? $0.phrase : $0.replacement }
                let raw = try await provider.transcribe(audioURL: chunk.url, language: language, vocabulary: hints)
                guard session == token else { return }
                let text = VocabularyProcessor.apply(vocabulary, to: TranscriptCleaner.clean(raw, language: language))
                guard !text.isEmpty else { continue }
                edit(id, save: false) {
                    $0.insert(MeetingSegment(speaker: chunk.speaker, start: chunk.start, duration: chunk.duration, text: text, rawText: raw))
                }
                saveNow(id)
            } catch {
                guard session == token else { return }
                if !(error is CancellationError) {
                    message = "A few seconds from \(chunk.speaker.label) couldn’t be transcribed. \(error.localizedDescription)"
                }
            }
        }
        if session == token { drain = nil }
    }

    private func receive(_ levels: (me: Float, them: Float)) {
        self.levels = levels
        if levels.me > 0.05 { heard.me = true }
        if levels.them > 0.01 {
            heard.them = true
            showsCallAudioHint = false
        }
    }

    private func startTicker(_ token: UUID) {
        ticker = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(500))
                guard let self, self.session == token, case .recording = self.activity else { return }
                self.elapsed = Date().timeIntervalSince(self.startedAt)
                self.showsCallAudioHint = self.elapsed >= 20 && self.heard.me && !self.heard.them && self.systemAudioIssue == nil
            }
        }
    }

    private func scheduleSave(_ id: UUID) {
        saves[id]?.cancel()
        saves[id] = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(600))
            guard !Task.isCancelled else { return }
            self?.saveNow(id)
        }
    }

    private func saveNow(_ id: UUID) {
        saves.removeValue(forKey: id)?.cancel()
        guard let meeting = meeting(id) else { return }
        do { try store.save(meeting) } catch { message = "This meeting couldn’t be saved. \(error.localizedDescription)" }
    }

    private func discardIfEmpty(_ id: UUID) {
        guard let meeting = meeting(id), !meeting.hasContent, meeting.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        delete(id)
    }

    /// Deletes meeting chunk files a crash or a quit mid-transcription left in the temporary folder.
    private static func removeLeftoverAudio() {
        let folder = FileManager.default.temporaryDirectory
        let files = (try? FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil)) ?? []
        for file in files where file.lastPathComponent.hasPrefix("betterwispr-meeting-") && file.pathExtension == "caf" {
            try? FileManager.default.removeItem(at: file)
        }
    }

    private static func makeProvider(for model: SpeechModel) -> any SpeechProvider {
        switch model.engine {
        case .apple: AppleSpeechProvider()
        case .whisperKit: WhisperKitProvider()
        case .parakeet: ParakeetProvider()
        }
    }
}
