import Foundation

public enum InsightsPeriod: String, CaseIterable, Identifiable, Sendable {
    case week, month, allTime

    public var id: String { rawValue }
    public var days: Int? {
        switch self {
        case .week: 7
        case .month: 30
        case .allTime: nil
        }
    }
}

public struct UsageTotals: Equatable, Sendable {
    public var words = 0
    public var dictations = 0
    public var speakingTime: TimeInterval = 0

    public init(words: Int = 0, dictations: Int = 0, speakingTime: TimeInterval = 0) {
        self.words = words
        self.dictations = dictations
        self.speakingTime = speakingTime
    }

    public var wordsPerMinute: Int {
        speakingTime > 0 ? Int((Double(words) / (speakingTime / 60)).rounded()) : 0
    }

    /// Time the same words would take to type at the average typist's pace, minus the time spent speaking.
    public var timeSaved: TimeInterval {
        max(0, Double(words) / Double(UsageInsights.typingWordsPerMinute) * 60 - speakingTime)
    }

    mutating func add(_ transcript: Transcript) {
        words += transcript.wordCount
        dictations += 1
        speakingTime += transcript.duration
    }
}

public struct UsageInsights: Equatable, Sendable {
    public struct Bucket: Equatable, Sendable {
        public var start: Date
        public var words: Int
    }

    public struct AppUsage: Equatable, Sendable {
        public var bundleID: String
        public var words: Int
        public var dictations: Int
    }

    public struct WordCount: Equatable, Sendable {
        public var word: String
        public var count: Int
    }

    /// Mean of 168,000 typists in Dhakal et al., "Observations on Typing from 136 Million Keystrokes", CHI 2018.
    public static let typingWordsPerMinute = 52

    public var period: InsightsPeriod
    public var start: Date
    public var current = UsageTotals()
    public var previous: UsageTotals?
    public var granularity: Calendar.Component = .day
    public var activity: [Bucket] = []
    public var wordsByHour = [Int](repeating: 0, count: 24)
    public var apps: [AppUsage] = []
    public var dictationsWithoutApp = 0
    public var spokenWords = 0
    public var wordsCleaned = 0
    public var mostRemoved: [WordCount] = []
    public var vocabularyFixes = 0
    public var activeDays = 0
    public var activeDates: Set<Date>
    public var currentStreak = 0
    public var longestStreak = 0

    /// Summarizes the saved dictations inside `period`; dictations saved before 0.1.1 have no app and are left out of `apps`.
    public init(_ history: [Transcript], period: InsightsPeriod = .allTime, calendar: Calendar = .current, now: Date = .now) {
        let today = calendar.startOfDay(for: now)
        let end = calendar.date(byAdding: .day, value: 1, to: today) ?? now
        self.period = period
        activeDates = Set(history.map { calendar.startOfDay(for: $0.createdAt) })
        if let days = period.days {
            start = calendar.date(byAdding: .day, value: 1 - days, to: today) ?? today
            previous = UsageTotals()
        } else {
            start = min(activeDates.min() ?? today, today)
        }
        let previousStart = period.days.flatMap { calendar.date(byAdding: .day, value: -$0, to: start) } ?? start
        let span = calendar.dateComponents([.day], from: start, to: today).day ?? 0
        granularity = span <= 31 ? .day : span <= 182 ? .weekOfYear : .month

        var wordsByBucket = [Date: Int]()
        var apps = [String: AppUsage]()
        var removed = [String: Int]()
        var days = Set<Date>()
        for transcript in history where transcript.createdAt < end {
            guard transcript.createdAt >= start else {
                if transcript.createdAt >= previousStart { previous?.add(transcript) }
                continue
            }
            let words = transcript.wordCount
            current.add(transcript)
            days.insert(calendar.startOfDay(for: transcript.createdAt))
            wordsByBucket[bucketStart(transcript.createdAt, calendar), default: 0] += words
            wordsByHour[calendar.component(.hour, from: transcript.createdAt)] += words
            spokenWords += CorrectionLearner.tokenize(transcript.rawText).count
            for word in Self.removedWords(from: transcript.rawText, to: transcript.text) {
                wordsCleaned += 1
                removed[word, default: 0] += 1
            }
            vocabularyFixes += transcript.vocabularyFixes ?? 0
            guard let app = transcript.appBundleID else {
                dictationsWithoutApp += 1
                continue
            }
            apps[app, default: AppUsage(bundleID: app, words: 0, dictations: 0)].words += words
            apps[app]?.dictations += 1
        }

        activeDays = days.count
        self.apps = apps.values.sorted { ($0.words, $0.dictations, $1.bundleID) > ($1.words, $1.dictations, $0.bundleID) }
        mostRemoved = Array(removed.map { WordCount(word: $0.key, count: $0.value) }
            .sorted { ($0.count, $1.word) > ($1.count, $0.word) }
            .prefix(5))
        var bucket = bucketStart(start, calendar)
        while bucket <= today {
            activity.append(Bucket(start: bucket, words: wordsByBucket[bucket] ?? 0))
            guard let next = calendar.date(byAdding: granularity, value: 1, to: bucket) else { break }
            bucket = next
        }
        (currentStreak, longestStreak) = Self.streaks(activeDates, calendar: calendar, today: today)
    }

    private func bucketStart(_ date: Date, _ calendar: Calendar) -> Date {
        calendar.dateInterval(of: granularity, for: date)?.start ?? calendar.startOfDay(for: date)
    }

    /// Lists recognized words that cleanup, rewriting or vocabulary removed or replaced, lowercased and without punctuation.
    static func removedWords(from raw: String, to text: String) -> [String] {
        var kept = [String: Int]()
        for word in CorrectionLearner.tokenize(text) { kept[word.lowercased(), default: 0] += 1 }
        var removed = [String]()
        for word in CorrectionLearner.tokenize(raw) {
            let key = word.lowercased()
            if let count = kept[key], count > 0 { kept[key] = count - 1 } else { removed.append(key) }
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
