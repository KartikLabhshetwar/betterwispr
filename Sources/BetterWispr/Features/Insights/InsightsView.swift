import BetterWisprCore
import SwiftUI

private extension AppCategory {
    var label: String {
        switch self {
        case .aiPrompts: "AI prompts"
        case .work: "work messages"
        case .personal: "personal messages"
        case .documents: "documents"
        case .email: "emails"
        case .other: "other tasks"
        }
    }

    var symbol: String {
        switch self {
        case .aiPrompts: "sparkles"
        case .work: "text.bubble"
        case .personal: "bubble.left.and.bubble.right"
        case .documents: "doc.text"
        case .email: "envelope"
        case .other: "infinity"
        }
    }
}

struct InsightsView: View {
    let history: [Transcript]
    let savesHistory: Bool
    @State private var isWide = true

    var body: some View {
        if history.isEmpty {
            ContentUnavailableView(
                "No Insights Yet",
                systemImage: "chart.bar",
                description: Text(savesHistory
                    ? "Dictate a few times and your pace, streak and favorite apps appear here."
                    : "Insights are built from saved dictations. Turn on Save history in Settings to see them.")
            )
        } else {
            content(UsageInsights(history))
        }
    }

    private func content(_ insights: UsageInsights) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if !savesHistory {
                    Label("History is off, so new dictations are not counted.", systemImage: "info.circle")
                        .foregroundStyle(.secondary)
                }
                row {
                    InsightCard { PaceComparison(wordsPerMinute: insights.wordsPerMinute) }
                    InsightCard { fixes(insights) }
                    InsightCard { totalWords(insights) }
                }
                row {
                    InsightCard { usage(insights) }
                    InsightCard { StreakCalendar(insights: insights) }
                }
            }
            .onGeometryChange(for: Bool.self) { $0.size.width >= 780 } action: { isWide = $0 }
            .padding(24)
            .frame(maxWidth: 1000, alignment: .leading)
            .frame(maxWidth: .infinity)
        }
        .toolbar {
            ToolbarItem {
                ShareLink(item: "I’ve dictated \(insights.totalWords.formatted()) words with BetterWispr at \(insights.wordsPerMinute) words per minute, on a \(insights.currentStreak) day streak.") {
                    Label("Share Insights", systemImage: "square.and.arrow.up")
                }
            }
        }
    }

    private func row(@ViewBuilder _ cards: () -> some View) -> some View {
        let layout = isWide ? AnyLayout(HStackLayout(alignment: .top, spacing: 16)) : AnyLayout(VStackLayout(spacing: 16))
        return layout(cards).fixedSize(horizontal: false, vertical: isWide)
    }

    private func fixes(_ insights: UsageInsights) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            StatHeader(value: insights.wordsCleaned + insights.dictionaryFixes, title: "Fixes made by BetterWispr")
            Divider()
            Label("\(insights.wordsCleaned.formatted()) words cleaned up", systemImage: "wand.and.stars")
                .help("Filler words, repeats and edits, counted against each original transcription.")
            Label("\(insights.dictionaryFixes.formatted()) vocabulary fixes", systemImage: "character.book.closed")
                .help("Words respelled from your Vocabulary, counted from version 0.1.1.")
        }
    }

    private func totalWords(_ insights: UsageInsights) -> some View {
        let novels = insights.totalWords / 50_000
        let pages = max(1, insights.totalWords / 250)
        return VStack(alignment: .leading, spacing: 10) {
            StatHeader(value: insights.totalWords, title: "Total words dictated")
            Divider()
            if novels > 0 {
                Text("That’s ^[\(novels) novel](inflect: true), at 50,000 words each.")
            } else {
                Text("That’s about ^[\(pages) page](inflect: true), at 250 words a page.")
            }
            Text("^[\(history.count) dictation](inflect: true) saved")
                .foregroundStyle(.secondary)
        }
    }

    private func usage(_ insights: UsageInsights) -> some View {
        let tracked = insights.dictationsByCategory.values.reduce(0, +)
        let rows = insights.dictationsByCategory.sorted { $0.value == $1.value ? $0.key.label < $1.key.label : $0.value > $1.value }
        return VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text("App usage").font(.title2.weight(.semibold))
                Spacer()
                Text("APPS USED | \(insights.appsUsed)")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            if rows.isEmpty {
                Text("New dictations record the app they were sent to, so this fills in as you dictate.")
                    .foregroundStyle(.secondary)
            }
            ForEach(rows, id: \.key) { category, count in
                UsageBar(category: category, count: count, fraction: Double(count) / Double(max(tracked, 1)))
            }
            if tracked < history.count, !rows.isEmpty {
                Text("Dictations saved before 0.1.1 have no app recorded and are not counted.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

private struct InsightCard<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        content
            .padding(18)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(.quaternary))
    }
}

private struct StatHeader: View {
    let value: Int
    let title: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(value.formatted()).font(.system(size: 32, weight: .semibold)).monospacedDigit()
            Text(title.uppercased()).font(.caption.weight(.semibold)).foregroundStyle(.secondary)
        }
    }
}

private struct PaceComparison: View {
    /// Mean of 168,000 typists in Dhakal et al., "Observations on Typing from 136 Million Keystrokes", CHI 2018.
    static let typingWordsPerMinute = 52
    let wordsPerMinute: Int

    var body: some View {
        let typing = Self.typingWordsPerMinute
        let ratio = Double(wordsPerMinute) / Double(typing)
        let scale = Double(max(wordsPerMinute, typing))
        VStack(alignment: .leading, spacing: 10) {
            StatHeader(value: wordsPerMinute, title: "Words per minute")
                .help("Words divided by recording time, pauses included.")
            Divider()
            Text(ratio >= 1.1
                ? "\(ratio.formatted(.number.precision(.fractionLength(1))))× faster than typing"
                : "Pauses count toward your pace, so long silences slow it down.")
            PaceBar(label: "You, speaking", wordsPerMinute: wordsPerMinute, fraction: Double(wordsPerMinute) / scale, color: .teal)
            PaceBar(label: "Average typist", wordsPerMinute: typing, fraction: Double(typing) / scale, color: .secondary.opacity(0.5))
                .help("Mean typing speed of 168,000 people measured by Dhakal et al., CHI 2018.")
        }
    }
}

private struct PaceBar: View {
    let label: String
    let wordsPerMinute: Int
    let fraction: Double
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(label)
                Spacer()
                Text("\(wordsPerMinute) wpm").monospacedDigit()
            }
            .font(.caption.weight(.semibold))
            .foregroundStyle(.secondary)
            GeometryReader { proxy in
                Capsule().fill(color).frame(width: max(10, proxy.size.width * fraction))
            }
            .frame(height: 10)
        }
        .accessibilityElement(children: .combine)
    }
}

private struct UsageBar: View {
    let category: AppCategory
    let count: Int
    let fraction: Double

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: category.symbol)
                .frame(width: 22)
                .foregroundStyle(.secondary)
            GeometryReader { proxy in
                HStack(spacing: 10) {
                    Text(fraction.formatted(.percent.precision(.fractionLength(0))))
                        .font(.caption.weight(.semibold))
                        .frame(width: max(44, proxy.size.width * 0.6 * fraction), height: 24)
                        .background(Color.teal.opacity(0.25 + 0.35 * fraction), in: RoundedRectangle(cornerRadius: 6, style: .continuous))
                    Text("\(count.formatted()) \(category.label)".uppercased())
                        .font(.caption.weight(.semibold))
                        .lineLimit(1)
                }
            }
            .frame(height: 24)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(count) \(category.label), \(fraction.formatted(.percent.precision(.fractionLength(0))))")
    }
}

private struct StreakCalendar: View {
    let insights: UsageInsights
    @State private var page = 0
    private let weeks = 18
    private let calendar = Calendar.current

    var body: some View {
        let today = calendar.startOfDay(for: .now)
        let columns = weekStarts(today: today)
        let busiest = max(insights.wordsByDay.values.max() ?? 1, 1)
        let streak = streakDays(today: today)
        let oldest = insights.wordsByDay.keys.min() ?? today
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text("\(insights.currentStreak)-day streak").font(.title2.weight(.semibold))
                Spacer()
                Text("Longest streak | ^[\(insights.longestStreak) day](inflect: true)")
                    .textCase(.uppercase)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            HStack(alignment: .bottom, spacing: 6) {
                VStack(alignment: .trailing, spacing: 3) {
                    ForEach(Array(weekdaySymbols.enumerated()), id: \.offset) { Text($0.element).frame(height: 12) }
                }
                .font(.caption2)
                .foregroundStyle(.secondary)
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 8) {
                        monthLabels(columns)
                        Spacer(minLength: 0)
                        Button { page += 1 } label: { Image(systemName: "chevron.left") }
                            .disabled((columns.first ?? today) <= oldest)
                            .accessibilityLabel("Earlier weeks")
                        Button { page -= 1 } label: { Image(systemName: "chevron.right") }
                            .disabled(page == 0)
                            .accessibilityLabel("Later weeks")
                    }
                    .buttonStyle(.borderless)
                    HStack(spacing: 3) {
                        ForEach(columns, id: \.self) { weekStart in
                            VStack(spacing: 3) {
                                ForEach(0..<7, id: \.self) { offset in
                                    cell(day(weekStart, offset), today: today, busiest: busiest, streak: streak)
                                }
                            }
                        }
                    }
                }
            }
            HStack(spacing: 4) {
                Text("Less")
                ForEach(0..<5, id: \.self) { level in
                    RoundedRectangle(cornerRadius: 2).fill(color(level: level)).frame(width: 12, height: 12)
                }
                Text("More")
                Spacer()
                RoundedRectangle(cornerRadius: 2).strokeBorder(Color.primary.opacity(0.7), lineWidth: 1.5).frame(width: 12, height: 12)
                Text("Current streak")
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
    }

    private var weekdaySymbols: [String] {
        let symbols = calendar.shortWeekdaySymbols
        let first = calendar.firstWeekday - 1
        return Array(symbols[first...] + symbols[..<first])
    }

    private func weekStarts(today: Date) -> [Date] {
        let thisWeek = calendar.dateInterval(of: .weekOfYear, for: today)?.start ?? today
        return (0..<weeks).compactMap {
            calendar.date(byAdding: .weekOfYear, value: $0 - (weeks - 1) - page * weeks, to: thisWeek)
        }
    }

    private func day(_ weekStart: Date, _ offset: Int) -> Date {
        calendar.date(byAdding: .day, value: offset, to: weekStart) ?? weekStart
    }

    private func streakDays(today: Date) -> Set<Date> {
        let end = insights.wordsByDay[today] == nil ? calendar.date(byAdding: .day, value: -1, to: today) ?? today : today
        return Set((0..<insights.currentStreak).compactMap { calendar.date(byAdding: .day, value: -$0, to: end) })
    }

    private func monthLabels(_ columns: [Date]) -> some View {
        HStack(spacing: 3) {
            ForEach(Array(columns.enumerated()), id: \.element) { index, weekStart in
                let month = calendar.component(.month, from: weekStart)
                let startsMonth = index == 0 || month != calendar.component(.month, from: columns[index - 1])
                Color.clear
                    .frame(width: 12, height: 14)
                    .overlay(alignment: .leading) {
                        if startsMonth {
                            Text(weekStart, format: .dateTime.month(.abbreviated)).font(.caption2).foregroundStyle(.secondary).fixedSize()
                        }
                    }
            }
        }
    }

    private func cell(_ date: Date, today: Date, busiest: Int, streak: Set<Date>) -> some View {
        let words = insights.wordsByDay[date] ?? 0
        let level = words == 0 ? 0 : max(1, Int((4 * Double(words) / Double(busiest)).rounded(.up)))
        return RoundedRectangle(cornerRadius: 2)
            .fill(date > today ? Color.clear : color(level: level))
            .overlay {
                if streak.contains(date) {
                    RoundedRectangle(cornerRadius: 2).strokeBorder(Color.primary.opacity(0.7), lineWidth: 1.5)
                }
            }
            .frame(width: 12, height: 12)
            .help("\(date.formatted(date: .abbreviated, time: .omitted)): \(words.formatted()) words")
            .accessibilityLabel("\(date.formatted(date: .abbreviated, time: .omitted)), \(words) words")
    }

    private func color(level: Int) -> Color {
        level == 0 ? Color.secondary.opacity(0.15) : Color.teal.opacity(0.25 + 0.75 * Double(level) / 4)
    }
}
