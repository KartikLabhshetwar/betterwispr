import Foundation
import NaturalLanguage

public enum TranscriptCleaner {
    private struct Token {
        var word: String
        var trailing: String
    }

    private static let fillers: Set<String> = ["uh", "uhh", "uhm", "um", "umm", "er", "erm", "hm", "hmm", "mm", "mmm"]
    private static let keptDoubles: Set<String> = ["that", "had", "is", "very", "really", "long", "bye", "no", "ha"]
    private static let numberWords: Set<String> = ["zero", "oh", "one", "two", "three", "four", "five", "six", "seven", "eight", "nine", "ten"]
    private static let repairCues: [[String]] = [["sorry"], ["no"], ["wait"], ["oops"], ["actually"], ["i", "mean"]]
    private static let correctingCues: Set<[String]> = [["no"], ["i", "mean"]]
    private static let subjectPronouns: Set<String> = ["i", "we", "you", "he", "she", "it", "they"]
    private static let repairReach = 4
    private static let sentenceEnders: Set<Character> = [".", "?", "!"]
    private static let terminators = sentenceEnders.union(["…"])
    private static let clauseBreaks = terminators.union([","])

    /// Removes English filled pauses, set-off "you know" and unpunctuated stutters; other languages are only trimmed.
    public static func clean(_ text: String, language: String?) -> String {
        let ranges = text.ranges(of: /[\p{L}\p{M}\p{N}_'’-]+/)
        let ends = ranges.dropFirst().map(\.lowerBound) + [text.endIndex]
        let tokens = zip(ranges, ends).map { Token(word: String(text[$0]), trailing: String(text[$0.upperBound..<$1])) }
        let spoken = tokens.map(\.word).filter { !fillers.contains($0.lowercased()) }.joined(separator: " ")
        guard isEnglish(spoken, language: language) else { return text.trimmingCharacters(in: .whitespacesAndNewlines) }
        let leading = text[..<(ranges.first?.lowerBound ?? text.endIndex)]
        let rebuilt = String(leading) + destutter(dropRepairs(dropFillers(tokens))).map { $0.word + $0.trailing }.joined()
        var result = rebuilt.replacing(/\ {2,}/, with: " ").trimmingCharacters(in: .whitespacesAndNewlines)
        if result.hasSuffix(",") { result.removeLast() }
        return result.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Uses the chosen language, or detects it when the language is automatic; undetectable text counts as English.
    public static func isEnglish(_ text: String, language: String?) -> Bool {
        let code = language.map { Locale(identifier: $0).language.languageCode?.identifier }
            ?? NLLanguageRecognizer.dominantLanguage(for: text)?.rawValue
        return code == nil || code == "en"
    }

    private static func dropFillers(_ tokens: [Token]) -> [Token] {
        var kept: [Token] = []
        var capitalizeNext = false
        var tokensToSkip = 0
        for (index, var token) in tokens.enumerated() {
            if tokensToSkip > 0 { tokensToSkip -= 1; continue }
            let removedCount = fillerLength(tokens, at: index, after: kept.last?.trailing)
            if removedCount > 0 {
                tokensToSkip = removedCount - 1
                let removedTrailing = tokens[index + tokensToSkip].trailing
                guard let previous = kept.last?.trailing else { capitalizeNext = true; continue }
                capitalizeNext = previous.contains(where: sentenceEnders.contains)
                if removedTrailing.contains(where: terminators.contains), !previous.contains(where: terminators.contains) {
                    kept[kept.count - 1].trailing = removedTrailing
                } else if removedCount > 1, previous.contains(","), removedTrailing.contains(",") {
                    kept[kept.count - 1].trailing = previous.replacing(",", with: "")
                }
                continue
            }
            if capitalizeNext, token.word == token.word.lowercased() {
                token.word = token.word.prefix(1).uppercased() + token.word.dropFirst()
            }
            capitalizeNext = false
            kept.append(token)
        }
        return kept
    }

    private static func fillerLength(_ tokens: [Token], at index: Int, after previous: String?) -> Int {
        let word = tokens[index].word.lowercased()
        let followsNumber = index > 0 && tokens[index - 1].word.allSatisfy(\.isNumber)
        if fillers.contains(word), !(word == "mm" && followsNumber) { return 1 }
        return isSetOffYouKnow(tokens, at: index, after: previous) ? 2 : 0
    }

    private static func isSetOffYouKnow(_ tokens: [Token], at index: Int, after previous: String?) -> Bool {
        guard index + 1 < tokens.count,
              tokens[index].word.lowercased() == "you", tokens[index + 1].word.lowercased() == "know",
              tokens[index].trailing.allSatisfy(\.isWhitespace) else { return false }
        let following = tokens[index + 1].trailing
        let setOffBefore = previous.map { $0.contains(where: clauseBreaks.contains) } ?? true
        let setOffAfter = !following.contains("?") && (index + 2 == tokens.count || following.contains(where: clauseBreaks.contains))
        return setOffBefore && setOffAfter
    }

    /// Turns "to Pune, sorry, no, to Delhi" into "to Delhi" when the repair restarts on a recent non-pronoun word.
    private static func dropRepairs(_ tokens: [Token]) -> [Token] {
        var tokens = tokens
        var i = 1
        while i < tokens.count {
            let window = max(0, i - repairReach)..<i
            let sentenceStart = window.last { tokens[$0].trailing.contains(where: terminators.contains) }.map { $0 + 1 } ?? window.lowerBound
            guard tokens[i - 1].trailing.contains(","), let onset = repairOnset(tokens, at: i),
                  let anchor = (sentenceStart..<i).last(where: { tokens[$0].word.lowercased() == tokens[onset].word.lowercased() }),
                  !subjectPronouns.contains(String(tokens[anchor].word.lowercased().prefix { $0 != "'" && $0 != "’" }))
            else { i += 1; continue }
            tokens[anchor].trailing = tokens[onset].trailing
            tokens.removeSubrange(anchor + 1...onset)
            i = anchor + 1
        }
        return tokens
    }

    /// The first repair word after a cue that says "no" or "I mean", set off by a comma unless the cue is compound.
    private static func repairOnset(_ tokens: [Token], at start: Int) -> Int? {
        var end = start
        var cues: [[String]] = []
        while let cue = repairCues.first(where: { cue in
            end + cue.count <= tokens.count && cue.indices.allSatisfy { tokens[end + $0].word.lowercased() == cue[$0] }
        }) {
            cues.append(cue)
            end += cue.count
        }
        guard end > start, end < tokens.count, cues.contains(where: correctingCues.contains),
              cues.count > 1 || tokens[end - 1].trailing.contains(","),
              !tokens[start..<end].contains(where: { $0.trailing.contains(where: terminators.contains) }) else { return nil }
        return end
    }

    private static func destutter(_ tokens: [Token]) -> [Token] {
        var tokens = tokens
        var i = 0
        while i < tokens.count {
            guard let n = [3, 2, 1].first(where: { repeats(tokens, at: i, length: $0) }) else { i += 1; continue }
            tokens[i + n - 1].trailing = tokens[i + 2 * n - 1].trailing
            tokens.removeSubrange(i + n..<i + 2 * n)
        }
        return tokens
    }

    private static func repeats(_ tokens: [Token], at i: Int, length n: Int) -> Bool {
        guard i + 2 * n <= tokens.count else { return false }
        let span = tokens[i..<i + 2 * n]
        return (0..<n).allSatisfy { tokens[i + $0].word.lowercased() == tokens[i + n + $0].word.lowercased() }
            && span.dropLast().allSatisfy { $0.trailing.allSatisfy(\.isWhitespace) }
            && !span.contains { isProtected($0.word.lowercased(), single: n == 1) }
    }

    private static func isProtected(_ word: String, single: Bool) -> Bool {
        word.contains(where: \.isNumber) || numberWords.contains(word) || (single && keptDoubles.contains(word))
    }
}
