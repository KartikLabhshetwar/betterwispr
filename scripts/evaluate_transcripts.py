#!/usr/bin/env python3
"""Score local JSONL reference/hypothesis pairs; see docs/accuracy.md."""

import argparse
import json
import sys
import unicodedata
from pathlib import Path


def normalize(text):
    text = unicodedata.normalize("NFC", text).lower()
    text = "".join(c if unicodedata.category(c)[0] in "LMN" else " " for c in text)
    return " ".join(text.split())


def edit_distance(reference, hypothesis):
    """Levenshtein distance; a substitution, deletion or insertion costs one."""
    if reference == hypothesis:
        return 0
    if len(reference) < len(hypothesis):
        reference, hypothesis = hypothesis, reference
    # ponytail: O(n*m) time, O(min(n,m)) space; use RapidFuzz for long recordings.
    if len(reference) * len(hypothesis) > 25_000_000:
        raise ValueError("utterance too long: split at matching audio boundaries before scoring")
    previous = list(range(len(hypothesis) + 1))
    for i, left in enumerate(reference, 1):
        current = [i]
        for j, right in enumerate(hypothesis, 1):
            current.append(min(current[-1] + 1, previous[j] + 1,
                               previous[j - 1] + (left != right)))
        previous = current
    return previous[-1]


def evaluate(rows, raw=False):
    counts = dict(utterances=0, reference_words=0, word_errors=0,
                  reference_characters=0, character_errors=0,
                  silent_clips=0, silent_clips_with_output=0)
    for number, row in enumerate(rows, 1):
        if not isinstance(row, dict) or not all(
            isinstance(row.get(field), str) for field in ("reference", "hypothesis")
        ):
            raise ValueError(f"row {number}: reference and hypothesis must be strings")
        reference, hypothesis = row["reference"], row["hypothesis"]
        # Silence is annotated with an empty reference, never inferred from punctuation.
        if not reference.strip():
            counts["silent_clips"] += 1
            counts["silent_clips_with_output"] += bool(hypothesis.strip())
        if not raw:
            reference, hypothesis = normalize(reference), normalize(hypothesis)
        words_ref, words_hyp = reference.split(), hypothesis.split()
        chars_ref = "".join(reference.split())
        chars_hyp = "".join(hypothesis.split())
        counts["utterances"] += 1
        counts["reference_words"] += len(words_ref)
        counts["word_errors"] += edit_distance(words_ref, words_hyp)
        counts["reference_characters"] += len(chars_ref)
        counts["character_errors"] += edit_distance(chars_ref, chars_hyp)
    if not counts["utterances"]:
        raise ValueError("input contains no transcript pairs")
    return {
        "normalization": "raw" if raw else "unicode-lower-letters-marks-numbers-v1",
        **counts,
        "wer": counts["word_errors"] / counts["reference_words"] if counts["reference_words"] else None,
        "cer": counts["character_errors"] / counts["reference_characters"] if counts["reference_characters"] else None,
        "silence_output_rate": counts["silent_clips_with_output"] / counts["silent_clips"] if counts["silent_clips"] else None,
    }


def read_rows(path):
    with path.open(encoding="utf-8") as source:
        for number, line in enumerate(source, 1):
            if line.strip():
                try:
                    yield json.loads(line)
                except json.JSONDecodeError as error:
                    raise ValueError(f"line {number}: invalid JSON: {error.msg}") from error


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("pairs", type=Path, help="UTF-8 JSONL with reference/hypothesis strings")
    parser.add_argument("--raw", action="store_true", help="keep case, punctuation and symbols")
    args = parser.parse_args()
    try:
        print(json.dumps(evaluate(read_rows(args.pairs), args.raw), ensure_ascii=False, indent=2))
    except (OSError, ValueError) as error:
        print(f"error: {error}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
