import Foundation

/// Rewrites spoken English numbers as digits for the final dictation text.
enum SpokenNumbers {
    private enum Kind { case unit, teen, tens, hundred, scale, and }
    private typealias Word = (value: Int, kind: Kind)

    private static let lexicon: [String: Word] = [
        "zero": (0, .unit), "one": (1, .unit), "two": (2, .unit), "three": (3, .unit), "four": (4, .unit),
        "five": (5, .unit), "six": (6, .unit), "seven": (7, .unit), "eight": (8, .unit), "nine": (9, .unit),
        "ten": (10, .teen), "eleven": (11, .teen), "twelve": (12, .teen), "thirteen": (13, .teen), "fourteen": (14, .teen),
        "fifteen": (15, .teen), "sixteen": (16, .teen), "seventeen": (17, .teen), "eighteen": (18, .teen), "nineteen": (19, .teen),
        "twenty": (20, .tens), "thirty": (30, .tens), "forty": (40, .tens), "fifty": (50, .tens),
        "sixty": (60, .tens), "seventy": (70, .tens), "eighty": (80, .tens), "ninety": (90, .tens),
        "hundred": (100, .hundred), "thousand": (1_000, .scale), "million": (1_000_000, .scale),
        "billion": (1_000_000_000, .scale), "trillion": (1_000_000_000_000, .scale),
        "lakh": (100_000, .scale), "lakhs": (100_000, .scale), "crore": (10_000_000, .scale), "crores": (10_000_000, .scale),
    ]
    private static let indianScales: Set<String> = ["lakh", "lakhs", "crore", "crores"]
    private static let follows: [Kind?: Set<Kind>] = [
        nil: [.unit, .teen, .tens], .unit: [.hundred, .scale], .teen: [.hundred, .scale], .tens: [.unit, .hundred, .scale],
        .hundred: [.unit, .teen, .tens, .scale, .and], .scale: [.unit, .teen, .tens, .and], .and: [.unit, .teen, .tens],
    ]
    private static let ordinals: Set<String> = [
        "first", "second", "third", "fourth", "fifth", "sixth", "seventh", "eighth", "ninth", "tenth",
        "eleventh", "twelfth", "thirteenth", "fourteenth", "fifteenth", "sixteenth", "seventeenth", "eighteenth", "nineteenth",
        "twentieth", "thirtieth", "fortieth", "fiftieth", "sixtieth", "seventieth", "eightieth", "ninetieth",
        "hundredth", "thousandth", "millionth", "billionth", "trillionth",
    ]
    private static let suffixes: [([String], String)] = [
        (["percent"], "%"), (["percentage"], "%"), (["per", "cent"], "%"), (["k"], "K"),
    ]

    /// A space-separated word split into edge punctuation and the number words its hyphenated core spells, if any.
    private struct Token {
        let text: String
        let leading: String
        let core: String
        let trailing: String
        let key: String
        let words: [Word]?

        init(_ text: Substring) {
            let isWordCharacter = { (character: Character) in character.isLetter || character.isNumber }
            let end = text.lastIndex(where: isWordCharacter).map(text.index(after:)) ?? text.startIndex
            let start = text[..<end].firstIndex(where: isWordCharacter) ?? end
            self.text = String(text)
            leading = String(text[..<start])
            core = String(text[start..<end])
            trailing = String(text[end...])
            key = core.lowercased()
            let pieces = key.split(separator: "-", omittingEmptySubsequences: false)
            let found = pieces.compactMap { SpokenNumbers.lexicon[String($0)] }
            words = found.count == pieces.count ? found : nil
        }
    }

    /// The finished scale groups, the group below the last scale, how many scale words were read and the kind of the last word.
    private struct Reading {
        var total = 0
        var group = 0
        var scale = Int.max
        var scales = 0
        var last: Kind?

        var value: Int { total + group }

        mutating func read(_ word: Word) -> Bool {
            guard SpokenNumbers.follows[last, default: []].contains(word.kind) else { return false }
            switch word.kind {
            case .unit, .teen, .tens:
                guard word.value > 0 || last == nil else { return false }
                group += word.value
            case .hundred:
                guard (1...99).contains(group) else { return false }
                group *= 100
            case .scale:
                guard group > 0, word.value < scale else { return false }
                total += group * word.value
                group = 0
                scale = word.value
                scales += 1
            case .and:
                break
            }
            last = word.kind
            return true
        }
    }

    /// Writes English number words as digits, so "two hundred and fifty thousand" becomes "250,000", "two lakh fifty thousand" "2,50,000" and "ten percent" "10%".
    static func apply(_ text: String) -> String {
        let tokens = text.split(separator: " ").map(Token.init)
        var out: [String] = []
        var i = 0
        while i < tokens.count {
            let (digits, end) = number(at: i, in: tokens)
            out += digits.map { [$0] } ?? tokens[i..<end].map(\.text)
            i = end
        }
        return out.joined(separator: " ")
    }

    /// The digits for the number spoken at `start`, or nil to keep the words, and the index after them.
    private static func number(at start: Int, in tokens: [Token]) -> (digits: String?, end: Int) {
        func open(_ j: Int) -> Bool {
            j < tokens.count && (j == start || (tokens[j - 1].trailing.isEmpty && tokens[j].leading.isEmpty))
        }
        func isNumberWord(_ j: Int) -> Bool { open(j) && tokens[j].words != nil }
        func single(_ j: Int, _ kind: Kind) -> Word? {
            guard open(j), let words = tokens[j].words, words.count == 1, words[0].kind == kind else { return nil }
            return words[0]
        }
        func words(_ j: Int) -> [Word]? {
            if tokens[j].key == "and" { return [(0, .and)] }
            if j == start, tokens[j].key == "a", (single(j + 1, .hundred) ?? single(j + 1, .scale)) != nil { return [(1, .unit)] }
            return tokens[j].words
        }
        func suffix(at j: Int) -> (symbol: String, end: Int)? {
            suffixes.first { words, _ in words.indices.allSatisfy { open(j + $0) && tokens[j + $0].key == words[$0] } }
                .map { ($0.1, j + $0.0.count) }
        }

        let first = tokens[start]
        if first.core.wholeMatch(of: /\d+(?:[.,]\d+)*/) != nil, let (symbol, end) = suffix(at: start + 1) {
            return (first.leading + first.core + symbol + tokens[end - 1].trailing, end)
        }

        var reading = Reading()
        var end = start
        var beforeAnd: (Reading, Int)?
        var afterScale: (Reading, Int)?
        while open(end), let spoken = words(end) {
            var next = reading
            guard spoken.allSatisfy({ next.read($0) }) else { break }
            if next.last == .and { beforeAnd = (reading, end) }
            if next.last == .scale { afterScale = (next, end + 1) }
            reading = next
            end += 1
        }
        guard end > start else { return (nil, start + 1) }
        let scaleFollows = single(end, .scale) != nil
        let multiplierFollows = scaleFollows || single(end, .hundred) != nil
        if let beforeAnd, reading.last == .and || isNumberWord(end) {
            (reading, end) = beforeAnd
        } else if scaleFollows, reading.group > 0, let afterScale {
            (reading, end) = afterScale
        }

        var fraction = ""
        var named: String?
        while open(end), tokens[end].key == "point" {
            var digits = ""
            var j = end + 1
            while let digit = single(j, .unit) {
                digits += String(digit.value)
                j += 1
            }
            guard !digits.isEmpty else { break }
            fraction += "." + digits
            end = j
        }
        if !fraction.isEmpty, single(end, .scale) != nil {
            named = tokens[end].core
            end += 1
        }

        if isNumberWord(end), !multiplierFollows {
            var runEnd = end
            while isNumberWord(runEnd) { runEnd += 1 }
            return (nil, runEnd)
        }
        if open(end), ordinals.contains(tokens[end].key) { return (nil, end) }
        let unit = suffix(at: end)
        let lone = end - start == 1 && reading.value < 10
        let bareA = first.key == "a" && end - start <= 2
        if unit == nil, lone || bareA { return (nil, end) }

        var value = reading.value
        if fraction.isEmpty, reading.last == .scale, reading.scales == 1, reading.scale >= 100_000, value / reading.scale < 1_000 {
            value /= reading.scale
            named = tokens[end - 1].core
        }
        let last = unit?.end ?? end
        let indian = tokens[start..<end].contains { indianScales.contains($0.key) }
        let digits = format(value, indian: indian) + fraction + (named.map { " " + $0 } ?? "") + (unit?.symbol ?? "")
        return (first.leading + digits + tokens[last - 1].trailing, last)
    }

    private static func format(_ value: Int, indian: Bool) -> String {
        value < 10_000 ? String(value) : value.formatted(.number.locale(Locale(identifier: indian ? "en_IN" : "en_US")))
    }
}
