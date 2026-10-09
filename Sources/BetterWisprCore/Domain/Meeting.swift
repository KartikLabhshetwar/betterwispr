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

    /// Keep the original segments on disk; hide remote speech picked up again by the microphone.
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
    private static let echoRun = 3
    private static let echoGap = 2
    private static let fragmentWords = 3
    private static let overlapSlack: TimeInterval = 3

    /// Cuts runs of remote words the microphone picked up while they played; drops Me segments left as fragments.
    public static func removingEchoes(from segments: [MeetingSegment]) -> [MeetingSegment] {
        segments.compactMap { segment in
            guard segment.speaker == .me else { return segment }
            let tokens = words(in: segment.text)
            let heard = segments.filter {
                $0.speaker == .them && $0.start < segment.start + segment.duration + overlapSlack
                    && $0.start + $0.duration > segment.start - overlapSlack
            }.flatMap { words(in: $0.text).map { $0.lowercased() } }
            let echo = echoMask(tokens.map { $0.lowercased() }, heard: heard)
            guard echo.contains(true) else { return segment }
            guard echo.filter({ !$0 }).count >= fragmentWords else { return nil }
            var text = ""
            var position = segment.text.startIndex
            for index in tokens.indices where echo[index] {
                text += segment.text[position..<tokens[index].startIndex]
                position = index + 1 < tokens.count ? tokens[index + 1].startIndex : segment.text.endIndex
            }
            text += segment.text[position...]
            var trimmed = segment
            trimmed.text = text.split(whereSeparator: \.isWhitespace).joined(separator: " ")
            return trimmed
        }
    }

    private static func words(in text: String) -> [Substring] {
        text.split { !$0.isLetter && !$0.isNumber }
    }

    /// Marks words in long common runs with `heard`, tolerating misheard, extra or missing words inside a run and short gaps between runs.
    private static func echoMask(_ mine: [String], heard: [String]) -> [Bool] {
        var echo = Array(repeating: false, count: mine.count)
        guard !heard.isEmpty else { return echo }
        let matches = mine.map { word in heard.map { sounds(word, like: $0) } }
        var common = Array(repeating: Array(repeating: 0, count: heard.count + 1), count: mine.count + 1)
        for i in mine.indices.reversed() {
            for j in heard.indices.reversed() {
                common[i][j] = matches[i][j] ? common[i + 1][j + 1] + 1 : max(common[i + 1][j], common[i][j + 1])
            }
        }
        var runs: [[(mine: Int, heard: Int)]] = []
        var i = 0, j = 0
        while i < mine.count, j < heard.count {
            if matches[i][j] {
                if let last = runs.last?.last, [1, 2].contains(i - last.mine), [1, 2].contains(j - last.heard) {
                    runs[runs.count - 1].append((i, j))
                } else {
                    runs.append([(i, j)])
                }
                i += 1
                j += 1
            } else if common[i + 1][j] >= common[i][j + 1] {
                i += 1
            } else {
                j += 1
            }
        }
        for run in runs where run.count >= echoRun {
            var first = run[0]
            while first.mine > 0, first.heard > 0, matches[first.mine - 1][first.heard - 1] {
                first = (first.mine - 1, first.heard - 1)
            }
            for index in first.mine...run[run.count - 1].mine { echo[index] = true }
        }
        var start = 0
        while start < echo.count {
            guard !echo[start] else { start += 1; continue }
            let end = echo[start...].firstIndex(of: true) ?? echo.count
            if start > 0, end < echo.count, end - start <= echoGap {
                for index in start..<end { echo[index] = true }
            }
            start = end
        }
        return echo
    }

    /// Equal words, or words of four or more letters that differ in at most a quarter of their letters, like "campaign" heard as "campage".
    private static func sounds(_ word: String, like other: String) -> Bool {
        if word == other { return true }
        let a = Array(word), b = Array(other)
        let allowed = max(a.count, b.count) / 4
        guard min(a.count, b.count) >= 4, abs(a.count - b.count) <= allowed else { return false }
        var previous = Array(0...b.count)
        for i in 1...a.count {
            var current = [i] + Array(repeating: 0, count: b.count)
            for j in 1...b.count {
                current[j] = min(previous[j] + 1, current[j - 1] + 1, previous[j - 1] + (a[i - 1] == b[j - 1] ? 0 : 1))
            }
            previous = current
        }
        return previous[b.count] <= allowed
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
