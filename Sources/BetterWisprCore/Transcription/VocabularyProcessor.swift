import Foundation

public enum VocabularyProcessor {
    /// One pass avoids cascading replacements; Unicode boundaries preserve words like café.
    public static func apply(_ entries: [VocabularyEntry], to text: String) -> String {
        let entries = entries.filter { !$0.phrase.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            .sorted { $0.phrase.count > $1.phrase.count }
        guard !entries.isEmpty else { return text.trimmingCharacters(in: .whitespacesAndNewlines) }
        let alternatives = entries.map { NSRegularExpression.escapedPattern(for: $0.phrase) }.joined(separator: "|")
        guard let regex = try? NSRegularExpression(pattern: "(?<![\\p{L}\\p{M}\\p{N}_])(?:\(alternatives))(?![\\p{L}\\p{M}\\p{N}_])", options: .caseInsensitive) else { return text }
        let source = text as NSString
        let output = NSMutableString(string: text)
        for match in regex.matches(in: text, range: NSRange(location: 0, length: source.length)).reversed() {
            let phrase = source.substring(with: match.range)
            if let entry = entries.first(where: { $0.phrase.caseInsensitiveCompare(phrase) == .orderedSame }) {
                output.replaceCharacters(in: match.range, with: entry.replacement.isEmpty ? entry.phrase : entry.replacement)
            }
        }
        return (output as String).trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
