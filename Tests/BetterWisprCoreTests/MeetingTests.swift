import Foundation
import Testing
@testable import BetterWisprCore

@Test func chunkPolicyWaitsForMinimumThenRotatesOnPauseOrMaximum() {
    let policy = ChunkPolicy()
    #expect(!policy.shouldRotate(duration: 9.9, trailingSilence: 5))
    #expect(!policy.shouldRotate(duration: 12, trailingSilence: 0.5))
    #expect(policy.shouldRotate(duration: 10, trailingSilence: 0.6))
    #expect(policy.shouldRotate(duration: 30, trailingSilence: 0))
    #expect(!policy.shouldRotate(duration: 29.9, trailingSilence: 0))
}

@Test func meetingStoreRoundTripsNewestFirstAndDeletes() throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    let store = MeetingStore(directory: directory)
    var older = Meeting(title: "Planning", createdAt: Date(timeIntervalSince1970: 1_000), modelName: "Whisper", language: "en")
    older.insert(MeetingSegment(speaker: .them, start: 4, duration: 2, text: "Ship Friday", rawText: "ship friday"))
    older.summary = MeetingSummary(overview: "Release plan", actionItems: [ActionItem(text: "Tag build", isDone: true)])
    let newer = Meeting(createdAt: Date(timeIntervalSince1970: 2_000), notes: "Ask about budget", modelName: "Whisper", language: "en")
    try store.save(older)
    try store.save(newer)

    let loaded = store.load()
    #expect(loaded.meetings == [newer, older])
    #expect(loaded.unreadable.isEmpty)
    let attributes = try FileManager.default.attributesOfItem(atPath: directory.appendingPathComponent("\(older.id.uuidString).json").path)
    #expect(attributes[.posixPermissions] as? Int == 0o600)

    try store.delete(id: newer.id)
    #expect(store.load().meetings == [older])
}

@Test func meetingStoreReportsUnreadableFilesWithoutTouchingThem() throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    let store = MeetingStore(directory: directory)
    let kept = Meeting(title: "Kept", modelName: "Whisper", language: "en")
    try store.save(kept)
    let malformed = directory.appendingPathComponent("\(UUID().uuidString).json")
    let future = directory.appendingPathComponent("\(UUID().uuidString).json")
    let malformedBytes = Data("{\"version\": 1, \"meeting\": {\"title\": ".utf8)
    let futureBytes = try JSONEncoder().encode(["version": 2])
    try malformedBytes.write(to: malformed)
    try futureBytes.write(to: future)

    let loaded = store.load()
    #expect(loaded.meetings == [kept])
    #expect(Set(loaded.unreadable.map(\.lastPathComponent)) == [malformed.lastPathComponent, future.lastPathComponent])
    #expect(try Data(contentsOf: malformed) == malformedBytes)
    #expect(try Data(contentsOf: future) == futureBytes)
}

@Test func meetingKeepsSegmentsSortedByStart() {
    var meeting = Meeting(modelName: "Whisper", language: "en")
    for (speaker, start) in [(Speaker.me, 20.0), (.them, 5), (.me, 12)] {
        meeting.insert(MeetingSegment(speaker: speaker, start: start, duration: 1, text: "\(start)", rawText: "\(start)"))
    }
    #expect(meeting.segments.map(\.start) == [5, 12, 20])
}

@Test func transcriptChunkerKeepsOrderSpeakersAndBudget() throws {
    let segments = [
        MeetingSegment(speaker: .me, start: 0, duration: 2, text: "Can we ship on Friday?", rawText: ""),
        MeetingSegment(speaker: .them, start: 2, duration: 2, text: "Only if QA signs off.", rawText: ""),
        MeetingSegment(speaker: .me, start: 4, duration: 30, text: (1...60).map { "word\($0)" }.joined(separator: " "), rawText: ""),
        MeetingSegment(speaker: .them, start: 40, duration: 1, text: "Agreed.", rawText: ""),
    ]
    let budget = 80
    let chunks = TranscriptChunker.chunks(segments, budget: budget)
    let lines = chunks.flatMap { $0.split(separator: "\n").map(String.init) }

    #expect(chunks.count > 1)
    #expect(chunks.allSatisfy { $0.count <= budget })
    #expect(lines.allSatisfy { $0.hasPrefix("Me: ") || $0.hasPrefix("Them: ") })
    #expect(lines.first == "Me: Can we ship on Friday?")
    #expect(lines.last == "Them: Agreed.")
    let longLines = lines.filter { $0.contains("word") }
    #expect(longLines.count > 1)
    #expect(longLines.allSatisfy { $0.hasPrefix("Me: ") })
    #expect(longLines.joined(separator: " ").replacingOccurrences(of: "Me: ", with: "") == segments[2].text)
    #expect(lines.firstIndex(of: "Them: Only if QA signs off.") == 1)
}

@Test func meetingMarkdownIncludesChecklistAndTimestamps() {
    var meeting = Meeting(title: "Launch sync", createdAt: Date(timeIntervalSince1970: 0), notes: "Budget is fixed.", modelName: "Whisper", language: "en")
    meeting.summary = MeetingSummary(overview: "We agreed on the launch.", keyPoints: ["QA owns sign-off"], decisions: [],
                                     actionItems: [ActionItem(text: "Send notes", isDone: true), ActionItem(text: "Book room")])
    meeting.insert(MeetingSegment(speaker: .me, start: 192, duration: 3, text: "Let's launch.", rawText: "lets launch"))
    meeting.insert(MeetingSegment(speaker: .them, start: 5, duration: 2, text: "Sounds good.", rawText: "sounds good"))
    let markdown = meeting.markdown

    #expect(markdown.hasPrefix("# Launch sync\n"))
    #expect(markdown.contains("## Summary\n\nWe agreed on the launch."))
    #expect(markdown.contains("- QA owns sign-off"))
    #expect(!markdown.contains("## Decisions"))
    #expect(markdown.contains("- [x] Send notes\n- [ ] Book room"))
    #expect(markdown.contains("## My notes\n\nBudget is fixed."))
    #expect(markdown.contains("[00:05] Them: Sounds good.\n[03:12] Me: Let's launch."))
    #expect(meeting.transcript == "[00:05] Them: Sounds good.\n[03:12] Me: Let's launch.")
}

@Test func meetingFallsBackToNewMeetingTitleAndFirstSnippet() {
    var meeting = Meeting(title: "  ", modelName: "Whisper", language: "en")
    #expect(meeting.displayTitle == "New Meeting")
    #expect(meeting.snippet.isEmpty)
    meeting.insert(MeetingSegment(speaker: .them, start: 0, duration: 1, text: "Hello there", rawText: ""))
    #expect(meeting.snippet == "Hello there")
    meeting.notes = "My own line"
    #expect(meeting.snippet == "My own line")
}

@Test func meetingSectionsGroupByDay() throws {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = try #require(TimeZone(identifier: "UTC"))
    let now = try #require(calendar.date(from: DateComponents(year: 2026, month: 10, day: 8, hour: 12)))
    let ages: [Double] = [0, 0.1, 1, 2, 2.2, 400]
    let meetings = ages.map { Meeting(createdAt: now.addingTimeInterval(-$0 * 86_400), modelName: "Whisper", language: "en") }
    let sections = MeetingSection.group(meetings, now: now, calendar: calendar)

    #expect(sections.map(\.meetings.count) == [2, 1, 2, 1])
    #expect(sections[0].title.hasPrefix("Today, "))
    #expect(sections[1].title.hasPrefix("Yesterday, "))
    #expect(!sections[2].title.contains("2026"))
    #expect(sections[3].title.contains("2025"))
}
