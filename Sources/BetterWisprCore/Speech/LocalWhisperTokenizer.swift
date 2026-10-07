// Adapted from WhisperKit v1.1.0, Sources/WhisperKit/Core/Models.swift.
// https://github.com/argmaxinc/argmax-oss-swift/blob/v1.1.0/Sources/WhisperKit/Core/Models.swift
// Changes: local-only construction, required-token validation, safe Unicode grouping.
//
// MIT License
// Copyright (c) 2024 argmax, inc.
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in all
// copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
// SOFTWARE.

import Foundation
import NaturalLanguage
@preconcurrency import WhisperKit

/// WhisperKit's built-in loader falls back to the network even with download:false.
/// This adapter accepts only a tokenizer already loaded from a local folder.
final class LocalWhisperTokenizer: WhisperTokenizer {
    private let tokenizer: TokenizerWrapper
    let specialTokens: SpecialTokens
    let allLanguageTokens: Set<Int>

    init(tokenizer: TokenizerWrapper) throws {
        func token(_ value: String) throws -> Int {
            guard let id = tokenizer.convertTokenToId(value) else { throw SpeechError.invalidModel }
            return id
        }
        specialTokens = try SpecialTokens(
            endToken: token("<|endoftext|>"), englishToken: token("<|en|>"),
            noSpeechToken: token("<|nospeech|>"), noTimestampsToken: token("<|notimestamps|>"),
            specialTokenBegin: token("<|endoftext|>"), startOfPreviousToken: token("<|startofprev|>"),
            startOfTranscriptToken: token("<|startoftranscript|>"), timeTokenBegin: token("<|0.00|>"),
            transcribeToken: token("<|transcribe|>"), translateToken: token("<|translate|>"),
            whitespaceToken: tokenizer.encode(text: " ", addSpecialTokens: false).first ?? 220
        )
        self.tokenizer = tokenizer
        allLanguageTokens = Set(Constants.languages.values.compactMap { tokenizer.convertTokenToId("<|\($0)|>") })
    }

    func encode(text: String) -> [Int] { tokenizer.encode(text: text) }
    func decode(tokens: [Int]) -> String { tokenizer.decode(tokens: tokens) }
    func convertTokenToId(_ token: String) -> Int? { tokenizer.convertTokenToId(token) }
    func convertIdToToken(_ id: Int) -> String? { tokenizer.convertIdToToken(id) }

    func splitToWordTokens(tokenIds: [Int]) -> (words: [String], wordTokens: [[Int]]) {
        let fullText = tokenizer.decode(tokens: tokenIds)
        var pieces: [String] = []
        var pieceTokens: [[Int]] = []
        var pending: [Int] = []
        var scalarOffset = 0
        let fullScalars = Array(fullText.unicodeScalars)
        for token in tokenIds {
            pending.append(token)
            let decoded = tokenizer.decode(tokens: pending)
            let scalars = Array(decoded.unicodeScalars)
            let hasIncompleteUnicode = scalars.enumerated().contains { offset, scalar in
                scalar == "\u{fffd}" && (scalarOffset + offset >= fullScalars.count || fullScalars[scalarOffset + offset] != scalar)
            }
            guard !hasIncompleteUnicode else { continue }
            pieces.append(decoded)
            pieceTokens.append(pending)
            pending.removeAll(keepingCapacity: true)
            scalarOffset += scalars.count
        }
        if !pending.isEmpty {
            pieces.append(tokenizer.decode(tokens: pending))
            pieceTokens.append(pending)
        }

        let recognizer = NLLanguageRecognizer()
        recognizer.processString(tokenizer.decode(tokens: tokenIds.filter { $0 < specialTokens.specialTokenBegin }))
        let language = recognizer.dominantLanguage.flatMap { Locale(identifier: $0.rawValue).language.languageCode?.identifier }
        if ["zh", "ja", "th", "lo", "my", "yue"].contains(language) { return (pieces, pieceTokens) }

        var words: [String] = []
        var wordTokens: [[Int]] = []
        for (piece, tokens) in zip(pieces, pieceTokens) {
            let special = (tokens.first ?? 0) >= specialTokens.specialTokenBegin
            let punctuation = UnicodeScalar(piece.trimmingCharacters(in: .whitespaces)).map { CharacterSet.punctuationCharacters.contains($0) } ?? false
            if special || piece.hasPrefix(" ") || punctuation || words.isEmpty {
                words.append(piece)
                wordTokens.append(tokens)
            } else {
                words[words.count - 1] += piece
                wordTokens[wordTokens.count - 1].append(contentsOf: tokens)
            }
        }
        return (words, wordTokens)
    }
}
