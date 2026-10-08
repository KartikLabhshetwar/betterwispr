import Foundation

public struct UsageInsights: Equatable, Sendable {
    public var totalWords = 0
    public var wordsPerMinute = 0
    public var wordsCleaned = 0
    public var dictionaryFixes = 0
    public var dictationsByCategory: [AppCategory: Int] = [:]
    public var appsUsed = 0
    public var wordsByDay: [Date: Int] = [:]
    public var currentStreak = 0
    public var longestStreak = 0

    /// Derives usage from saved history; dictations saved before 0.1.1 have no app and are left out of categories.
    public init(_ history: [Transcript], calendar: Calendar = .current, now: Date = .now) {
        var seconds: TimeInterval = 0
        var apps = Set<String>()
        for transcript in history {
            let words = transcript.wordCount
            totalWords += words
            seconds += transcript.duration
            wordsCleaned += Self.removedWords(from: transcript.rawText, to: transcript.text)
            dictionaryFixes += transcript.vocabularyFixes ?? 0
            wordsByDay[calendar.startOfDay(for: transcript.createdAt), default: 0] += words
            guard let app = transcript.appBundleID else { continue }
            apps.insert(app)
            dictationsByCategory[AppCategory(bundleID: app), default: 0] += 1
        }
        appsUsed = apps.count
        wordsPerMinute = seconds > 0 ? Int((Double(totalWords) / (seconds / 60)).rounded()) : 0
        (currentStreak, longestStreak) = Self.streaks(Set(wordsByDay.keys), calendar: calendar, today: calendar.startOfDay(for: now))
    }

    /// Counts recognized words that cleanup, rewriting or vocabulary removed or replaced, ignoring case and punctuation.
    static func removedWords(from raw: String, to text: String) -> Int {
        var kept = [String: Int]()
        for word in CorrectionLearner.tokenize(text) { kept[word.lowercased(), default: 0] += 1 }
        var removed = 0
        for word in CorrectionLearner.tokenize(raw) {
            let key = word.lowercased()
            if let count = kept[key], count > 0 { kept[key] = count - 1 } else { removed += 1 }
        }
        return removed
    }

    /// A streak still counts today until the day ends without a dictation.
    static func streaks(_ days: Set<Date>, calendar: Calendar, today: Date) -> (current: Int, longest: Int) {
        func previous(_ day: Date) -> Date { calendar.date(byAdding: .day, value: -1, to: day) ?? day }
        func run(endingAt day: Date) -> Int {
            var length = 0, day = day
            while days.contains(day) { length += 1; day = previous(day) }
            return length
        }
        let longest = days.filter { !days.contains(calendar.date(byAdding: .day, value: 1, to: $0) ?? $0) }
            .map(run(endingAt:)).max() ?? 0
        return (max(run(endingAt: today), run(endingAt: previous(today))), longest)
    }
}
