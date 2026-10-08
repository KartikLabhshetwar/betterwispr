import Foundation

public enum VoiceCommands {
    private static let edgePunctuation = CharacterSet(charactersIn: ".,!?;:…\"“”")
    private static let sentenceEnds: Set<Character> = [".", "!", "?", "\n"]
    private static let nounMarkers: Set<String> = ["a", "an", "the", "this", "that", "oxford", "serial"]
    private static let requests: Set<String> = ["add", "insert", "put"]
    private static let apologies: Set<String> = ["sorry", "oops", "wait"]

    private static let alwaysPunctuation: [([String], String)] = [
        (["exclamation", "mark"], "!"), (["exclamation", "point"], "!"), (["question", "mark"], "?"),
        (["full", "stop"], "."), (["semicolon"], ";"), (["comma"], ","),
    ]
    private static let requestedPunctuation: [([String], String)] = [
        (["period"], "."), (["colon"], ":"), (["dash"], " –"), (["hyphen"], "-"),
    ]

    /// Applies English spoken punctuation, line breaks, "scratch that" and "at the rate" mentions.
    public static func apply(_ text: String) -> String {
        let tokens = text.split(whereSeparator: { $0 == " " || $0 == "\t" }).map(String.init)
        var out = ""
        var capitalizeNext = false
        var i = 0

        func key(_ j: Int) -> String {
            j >= 0 && j < tokens.count ? tokens[j].lowercased().trimmingCharacters(in: edgePunctuation) : ""
        }
        func endsSetOff(_ j: Int) -> Bool {
            j < 0 || tokens[j].last.map { ",.!?;:…".contains($0) } == true || apologies.contains(key(j))
        }
        func matches(_ words: [String], at j: Int) -> Bool {
            words.indices.allSatisfy { key(j + $0) == words[$0] }
        }
        func trimTrailing(_ characters: String) {
            while let last = out.last, last == " " || characters.contains(last) { out.removeLast() }
        }
        func dropApology() {
            trimTrailing(",;:")
            let words = out.split(separator: " ", omittingEmptySubsequences: false)
            guard let last = words.last, apologies.contains(last.lowercased().trimmingCharacters(in: edgePunctuation)) else { return }
            out.removeLast(last.count)
        }
        func append(_ word: String) {
            var word = word
            if capitalizeNext, let first = word.first, first.isLowercase { word = first.uppercased() + word.dropFirst() }
            capitalizeNext = false
            if !out.isEmpty, !out.hasSuffix("\n") { out += " " }
            out += word
        }
        func punctuation(at j: Int) -> (symbol: String, length: Int)? {
            let requested = requests.contains(key(j - 1)) || (nounMarkers.contains(key(j - 1)) && requests.contains(key(j - 2)))
            if !requested, nounMarkers.contains(key(j - 1)) { return nil }
            if let (words, symbol) = alwaysPunctuation.first(where: { matches($0.0, at: j) }) { return (symbol, words.count) }
            let isLast = tokens[(j + 1)...].allSatisfy { $0.trimmingCharacters(in: edgePunctuation).isEmpty }
            if let (words, symbol) = requestedPunctuation.first(where: { matches($0.0, at: j) }), requested || (isLast && words == ["period"]) {
                return (symbol, words.count)
            }
            return nil
        }

        while i < tokens.count {
            let k = key(i)

            if requests.contains(k) {
                let target = nounMarkers.contains(key(i + 1)) ? i + 2 : i + 1
                if target < tokens.count, punctuation(at: target) != nil { i = target; continue }
            }

            if let (symbol, length) = punctuation(at: i) {
                trimTrailing(",;:" + (symbol == "," ? "" : ".!?"))
                out += symbol
                capitalizeNext = ".!?".contains(symbol)
                i += length
                continue
            }

            if ["new", "next"].contains(k), ["line", "paragraph"].contains(key(i + 1)), !nounMarkers.contains(key(i - 1)) {
                trimTrailing("")
                out += key(i + 1) == "line" ? "\n" : "\n\n"
                capitalizeNext = true
                i += 2
                continue
            }

            let forced = ["scratch", "strike"].contains(k) && key(i + 1) == "that"
            let setOff = ["remove", "delete", "undo", "cancel"].contains(k) && key(i + 1) == "that"
                && endsSetOff(i - 1) && (i + 2 == tokens.count || endsSetOff(i + 1))
            if forced || setOff {
                dropApology()
                trimTrailing(",;:.!?…")
                if let end = out.lastIndex(where: sentenceEnds.contains) { out = String(out[...end]) } else { out = "" }
                capitalizeNext = true
                i += 2
                continue
            }

            if (k == "at" && key(i + 1) == "the" && key(i + 2) == "rate") || (k == "at" && key(i + 1) == "sign") || tokens[i] == "@" {
                let name = i + (tokens[i] == "@" ? 1 : k == "at" && key(i + 1) == "sign" ? 2 : 3)
                if name < tokens.count, key(name) != "of", !key(name).isEmpty {
                    capitalizeNext = false
                    append("@" + tokens[name])
                    i = name + 1
                    continue
                }
            }

            append(tokens[i])
            i += 1
        }

        return out.replacing(#/[ \t]+([,.!?;:])/#, with: { $0.output.1 })
            .replacing(#/([,;:])[,;:]+/#, with: { $0.output.1 })
            .replacing(#/[ \t]*\n[ \t]*/#, with: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
