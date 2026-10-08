import Foundation

public enum VocabularyProcessor {
    /// One pass avoids cascading replacements; Unicode boundaries preserve words like café.
    public static func apply(_ entries: [VocabularyEntry], to text: String) -> String {
        corrected(entries, in: text).text
    }

    /// Applies vocabulary and counts the matches whose spelling actually changed.
    public static func corrected(_ entries: [VocabularyEntry], in text: String) -> (text: String, fixes: Int) {
        let entries = entries.filter { !$0.phrase.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            .sorted { $0.phrase.count > $1.phrase.count }
        guard !entries.isEmpty else { return (text.trimmingCharacters(in: .whitespacesAndNewlines), 0) }
        let alternatives = entries.map { NSRegularExpression.escapedPattern(for: $0.phrase) }.joined(separator: "|")
        guard let regex = try? NSRegularExpression(pattern: "(?<![\\p{L}\\p{M}\\p{N}_])(?:\(alternatives))(?![\\p{L}\\p{M}\\p{N}_])", options: .caseInsensitive) else { return (text, 0) }
        let source = text as NSString
        let output = NSMutableString(string: text)
        var fixes = 0
        for match in regex.matches(in: text, range: NSRange(location: 0, length: source.length)).reversed() {
            let phrase = source.substring(with: match.range)
            if let entry = entries.first(where: { $0.phrase.caseInsensitiveCompare(phrase) == .orderedSame }) {
                let replacement = entry.replacement.isEmpty ? entry.phrase : entry.replacement
                if replacement != phrase { fixes += 1 }
                output.replaceCharacters(in: match.range, with: replacement)
            }
        }
        return ((output as String).trimmingCharacters(in: .whitespacesAndNewlines), fixes)
    }
}
