import Foundation
#if canImport(FoundationModels)
import FoundationModels
#endif

public enum NotesAvailability: Equatable, Sendable {
    case available
    case unavailable(String)
}

public struct GeneratedMeetingNotes: Sendable {
    public var title: String
    public var summary: MeetingSummary
}

public enum MeetingNotesError: LocalizedError {
    case nothingToSummarize
    case unavailable(String)

    public var errorDescription: String? {
        switch self {
        case .nothingToSummarize: "There’s nothing to summarize yet. Speak or type a few notes first."
        case .unavailable(let message): message
        }
    }
}

public enum MeetingNotesGenerator {
    // ponytail: characters at ~4 per token; switch to SystemLanguageModel.tokenCount(for:) once the minimum OS reaches 26.4.
    static let budget = 6000

    public static var availability: NotesAvailability {
        #if canImport(FoundationModels)
        if #available(macOS 26.0, *) {
            switch SystemLanguageModel.default.availability {
            case .available: return .available
            case .unavailable(.deviceNotEligible): return .unavailable("This Mac doesn’t support Apple Intelligence, so notes can’t be written here. Your transcript and notes are still saved.")
            case .unavailable(.appleIntelligenceNotEnabled): return .unavailable("Turn on Apple Intelligence in System Settings to write notes on this Mac.")
            case .unavailable(.modelNotReady): return .unavailable("Apple Intelligence is still downloading its model. Try again soon.")
            case .unavailable: return .unavailable("Apple Intelligence isn’t available right now. Your transcript and notes are still saved.")
            }
        }
        #endif
        return .unavailable("Notes need macOS 26 with Apple Intelligence. Your transcript and notes are still saved.")
    }

    /// Writes a title and summary on device, condensing long transcripts part by part first.
    public static func generate(segments: [MeetingSegment], userNotes: String,
                                onStep: @escaping @MainActor @Sendable (Int, Int) -> Void) async throws -> GeneratedMeetingNotes {
        let notes = userNotes.trimmingCharacters(in: .whitespacesAndNewlines)
        let spoken = segments.filter { !$0.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        guard !spoken.isEmpty || !notes.isEmpty else { throw MeetingNotesError.nothingToSummarize }
        if case .unavailable(let message) = availability { throw MeetingNotesError.unavailable(message) }
        #if canImport(FoundationModels)
        if #available(macOS 26.0, *) {
            return try await NotesWriter.write(parts: TranscriptChunker.chunks(spoken, budget: budget), notes: notes, onStep: onStep)
        }
        #endif
        throw MeetingNotesError.unavailable(availability.message)
    }
}

extension NotesAvailability {
    var message: String {
        if case .unavailable(let message) = self { message } else { "" }
    }
}

public enum TranscriptChunker {
    /// Renders `Me: text` lines in order and packs them into chunks of at most `budget` characters.
    public static func chunks(_ segments: [MeetingSegment], budget: Int) -> [String] {
        pack(segments.flatMap { lines(of: $0.text, prefix: "\($0.speaker.label): ", budget: budget) }, budget: budget)
    }

    static func chunks(of text: String, budget: Int) -> [String] {
        pack(text.split(whereSeparator: \.isNewline).flatMap { lines(of: String($0), prefix: "", budget: budget) }, budget: budget)
    }

    private static func pack(_ lines: [String], budget: Int) -> [String] {
        var chunks: [String] = []
        var current: [String] = []
        var length = 0
        for line in lines {
            if !current.isEmpty, length + 1 + line.count > budget {
                chunks.append(current.joined(separator: "\n"))
                current = []
                length = 0
            }
            length += (current.isEmpty ? 0 : 1) + line.count
            current.append(line)
        }
        if !current.isEmpty { chunks.append(current.joined(separator: "\n")) }
        return chunks
    }

    private static func lines(of text: String, prefix: String, budget: Int) -> [String] {
        let room = max(1, budget - prefix.count)
        var lines: [String] = []
        var line = ""
        var length = 0
        for word in text.split(whereSeparator: \.isWhitespace) {
            for start in stride(from: 0, to: word.count, by: room) {
                let piece = word.dropFirst(start).prefix(room)
                if length > 0, length + 1 + piece.count > room {
                    lines.append(prefix + line)
                    line = ""
                    length = 0
                }
                let separator = length == 0 ? "" : " "
                line += separator + piece
                length += separator.count + piece.count
            }
        }
        if length > 0 { lines.append(prefix + line) }
        return lines
    }
}

#if canImport(FoundationModels)
@available(macOS 26.0, *)
@Generable
struct GeneratedNotes {
    @Guide(description: "A short, specific title for the meeting, at most eight words")
    var title: String
    @Guide(description: "Two or three sentences on what the meeting covered")
    var overview: String
    @Guide(description: "The most important points discussed", .maximumCount(8))
    var keyPoints: [String]
    @Guide(description: "Decisions that were explicitly made", .maximumCount(6))
    var decisions: [String]
    @Guide(description: "Concrete follow-up tasks, naming the owner only when the transcript does", .maximumCount(8))
    var actionItems: [String]
}

@available(macOS 26.0, *)
private enum NotesWriter {
    static let instructions = """
        You write notes for a meeting between "Me", the person taking notes, and "Them", everyone else on the call. \
        Be factual. Use only the transcript and Me's own notes. Never invent names, numbers, dates or decisions. \
        Return an empty list when nothing applies.
        """
    static let options = GenerationOptions(temperature: 0.3)
    static let condensePrompt = """
        Write short plain bullet notes for this part of a meeting. Keep who said what (Me or Them), \
        and keep names, numbers, dates, decisions and follow-up tasks exactly as stated. Add nothing else.
        """
    static let maximumRounds = 3

    static func write(parts: [String], notes: String, onStep: @escaping @MainActor @Sendable (Int, Int) -> Void) async throws -> GeneratedMeetingNotes {
        let budget = MeetingNotesGenerator.budget
        var material = parts.joined(separator: "\n")
        var step = 0
        var total = parts.count > 1 ? parts.count + 1 : 1
        if parts.count > 1 {
            var pending = parts
            for round in 0..<maximumRounds {
                var condensed: [String] = []
                for part in pending {
                    step += 1
                    await onStep(step, total)
                    try Task.checkCancellation()
                    condensed.append(try await condense(part))
                }
                material = condensed.joined(separator: "\n")
                guard material.count > budget, round + 1 < maximumRounds else { break }
                pending = TranscriptChunker.chunks(of: material, budget: budget)
                total += pending.count
            }
        }
        await onStep(total, total)
        try Task.checkCancellation()
        let source = parts.count > 1 ? "Notes from each part of the meeting, in order:" : "Transcript:"
        let transcript = material.isEmpty ? "No speech was transcribed." : String(material.prefix(budget))
        let userNotes = notes.isEmpty ? "" : "Me's own notes, which the summary should follow:\n\(notes.prefix(budget / 3))\n\n"
        let session = LanguageModelSession(instructions: instructions)
        let response = try await session.respond(to: "Write the meeting notes.\n\n\(userNotes)\(source)\n\(transcript)",
                                                 generating: GeneratedNotes.self, options: options)
        let generated = response.content
        return GeneratedMeetingNotes(
            title: clean(generated.title),
            summary: MeetingSummary(overview: clean(generated.overview), keyPoints: generated.keyPoints.compactMap(nonEmpty),
                                    decisions: generated.decisions.compactMap(nonEmpty),
                                    actionItems: generated.actionItems.compactMap(nonEmpty).map { ActionItem(text: $0) }))
    }

    private static func condense(_ part: String) async throws -> String {
        let session = LanguageModelSession(instructions: instructions)
        return try await session.respond(to: "\(condensePrompt)\n\n\(part)", options: options).content
    }

    private static func clean(_ text: String) -> String {
        text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func nonEmpty(_ text: String) -> String? {
        let text = clean(text)
        return text.isEmpty ? nil : text
    }
}
#endif
