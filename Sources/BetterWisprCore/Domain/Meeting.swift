import Foundation
import CryptoKit

public enum Speaker: String, Codable, Sendable {
    case me, them

    public var label: String { self == .me ? "Me" : "Them" }
}

public struct MeetingSegment: Codable, Identifiable, Equatable, Sendable {
    public var id: UUID
    public var speaker: Speaker
    public var start: TimeInterval
    public var duration: TimeInterval
    public var text: String
    public var rawText: String

    public init(id: UUID = UUID(), speaker: Speaker, start: TimeInterval, duration: TimeInterval, text: String, rawText: String) {
        self.id = id
        self.speaker = speaker
        self.start = start
        self.duration = duration
        self.text = text
        self.rawText = rawText
    }

    public var timestamp: String {
        let seconds = max(0, Int(start))
        return String(format: "%02d:%02d", seconds / 60, seconds % 60)
    }
}

public struct ActionItem: Codable, Identifiable, Equatable, Sendable {
    public var id: UUID
    public var text: String
    public var isDone: Bool

    public init(id: UUID = UUID(), text: String, isDone: Bool = false) {
        self.id = id
        self.text = text
        self.isDone = isDone
    }
}

public struct MeetingSummary: Codable, Equatable, Sendable {
    public var overview: String
    public var keyPoints: [String]
    public var decisions: [String]
    public var actionItems: [ActionItem]
    public var modelName: String?
    public var sourceFingerprint: String?
    public var generatedAt: Date

    public init(overview: String, keyPoints: [String] = [], decisions: [String] = [], actionItems: [ActionItem] = [], generatedAt: Date = .now) {
        self.overview = overview
        self.keyPoints = keyPoints
        self.decisions = decisions
        self.actionItems = actionItems
        self.generatedAt = generatedAt
    }
}

public struct Meeting: Codable, Identifiable, Equatable, Sendable {
    public var id: UUID
    public var title: String
    public var createdAt: Date
    public var duration: TimeInterval
    public var notes: String
    public var summary: MeetingSummary?
    public var segments: [MeetingSegment]
    public var modelName: String
    public var language: String

    public init(id: UUID = UUID(), title: String = "", createdAt: Date = .now, duration: TimeInterval = 0, notes: String = "",
                summary: MeetingSummary? = nil, segments: [MeetingSegment] = [], modelName: String, language: String) {
        self.id = id
        self.title = title
        self.createdAt = createdAt
        self.duration = duration
        self.notes = notes
        self.summary = summary
        self.segments = segments
        self.modelName = modelName
        self.language = language
    }

    public var displayTitle: String {
        let title = title.trimmingCharacters(in: .whitespacesAndNewlines)
        return title.isEmpty ? "New Meeting" : title
    }

    public var snippet: String {
        [summary?.overview, notes, segments.first?.text]
            .compactMap { $0?.split(whereSeparator: \.isNewline).joined(separator: " ").trimmingCharacters(in: .whitespaces) }
            .first { !$0.isEmpty } ?? ""
    }

    public var hasContent: Bool {
        segments.contains { !$0.text.isEmpty } || !notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    public mutating func insert(_ segment: MeetingSegment) {
        segments.insert(segment, at: segments.firstIndex { $0.start > segment.start } ?? segments.endIndex)
    }

    public var transcript: String {
        transcriptSegments.map { "[\($0.timestamp)] \($0.speaker.label): \($0.text)" }.joined(separator: "\n")
    }

    /// Keep the original segments on disk; hide speaker playback picked up again by the microphone.
    public var transcriptSegments: [MeetingSegment] { MeetingTranscript.removingEchoes(from: segments) }

    public var summarySourceFingerprint: String {
        // Length-prefix each input so different transcript/thought pairs cannot share a boundary.
        let transcript = transcript
        let source = "\(transcript.utf8.count):\(transcript)\(notes.utf8.count):\(notes)"
        return SHA256.hash(data: Data(source.utf8)).map { String(format: "%02x", $0) }.joined()
    }

    public var summaryNeedsUpdate: Bool {
        summary != nil && summary?.sourceFingerprint != summarySourceFingerprint
    }

    public var markdown: String {
        var blocks = ["# \(displayTitle)", createdAt.formatted(date: .long, time: .shortened)]
        if let summary {
            if !summary.overview.isEmpty { blocks.append("## Summary\n\n\(summary.overview)") }
            if !summary.keyPoints.isEmpty { blocks.append("## Key points\n\n" + summary.keyPoints.map { "- \($0)" }.joined(separator: "\n")) }
            if !summary.decisions.isEmpty { blocks.append("## Decisions\n\n" + summary.decisions.map { "- \($0)" }.joined(separator: "\n")) }
            if !summary.actionItems.isEmpty {
                blocks.append("## Action items\n\n" + summary.actionItems.map { "- [\($0.isDone ? "x" : " ")] \($0.text)" }.joined(separator: "\n"))
            }
        }
        let notes = notes.trimmingCharacters(in: .whitespacesAndNewlines)
        if !notes.isEmpty { blocks.append("## My notes\n\n\(notes)") }
        if !segments.isEmpty {
            blocks.append("## Transcript\n\n" + transcript)
        }
        return blocks.joined(separator: "\n\n") + "\n"
    }
}

public enum MeetingTranscript {
    public static func removingEchoes(from segments: [MeetingSegment]) -> [MeetingSegment] {
        func words(_ text: String) -> [String] {
            text.lowercased().split { !$0.isLetter && !$0.isNumber }.map(String.init)
        }
        var systemSpeech: [String: [TimeInterval]] = [:]
        for segment in segments where segment.speaker == .them {
            let words = words(segment.text)
            if words.count >= 8 { systemSpeech[words.joined(separator: " "), default: []].append(segment.start) }
        }
        return segments.filter { segment in
            guard segment.speaker == .me else { return true }
            let normalized = words(segment.text).joined(separator: " ")
            // ponytail: exact cross-channel matches within one 30 s capture chunk only;
            // audio echo cancellation is needed for mixed speech or differently recognized echoes.
            return !(systemSpeech[normalized]?.contains { abs($0 - segment.start) <= 30 } ?? false)
        }
    }
}

public struct MeetingSection: Equatable, Sendable {
    public var title: String
    public var meetings: [Meeting]

    /// Groups newest-first meetings by day, titled like "Today, Oct 8" or "Tue, Oct 6".
    public static func group(_ meetings: [Meeting], now: Date = .now, calendar: Calendar = .current) -> [MeetingSection] {
        let today = calendar.startOfDay(for: now)
        var style = Date.FormatStyle.dateTime.month(.abbreviated).day()
        style.calendar = calendar
        style.timeZone = calendar.timeZone
        var sections: [MeetingSection] = []
        for meeting in meetings {
            let days = calendar.dateComponents([.day], from: calendar.startOfDay(for: meeting.createdAt), to: today).day ?? 0
            let day = calendar.isDate(meeting.createdAt, equalTo: now, toGranularity: .year) ? style : style.year()
            let title = switch days {
            case ...0: "Today, \(meeting.createdAt.formatted(day))"
            case 1: "Yesterday, \(meeting.createdAt.formatted(day))"
            default: meeting.createdAt.formatted(day.weekday(.abbreviated))
            }
            if sections.last?.title == title { sections[sections.count - 1].meetings.append(meeting) }
            else { sections.append(MeetingSection(title: title, meetings: [meeting])) }
        }
        return sections
    }
}
