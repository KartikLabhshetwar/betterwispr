#!/usr/bin/env python3
"""Run with python3 Tests/evaluate_check.py; no external dependencies."""

import json
import subprocess
import sys
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "scripts"))
from evaluate_transcripts import edit_distance, evaluate, normalize


assert edit_distance("kitten", "sitting") == 3
assert edit_distance([], ["hello", "world"]) == 2
assert edit_distance(["one", "two"], []) == 2
assert normalize("  Hello, WORLD! ") == "hello world"
assert normalize("Cafe\u0301") == normalize("Café")
assert normalize("हिंदी भाषा") == "हिंदी भाषा"
assert evaluate([{"reference": "你好", "hypothesis": "您好"}])["cer"] == 0.5

pairs = [
    {"reference": "Hello world", "hypothesis": "hello WORLD!"},
    {"reference": "one two three", "hypothesis": "one four"},
    {"reference": "", "hypothesis": "invented"},
    {"reference": "", "hypothesis": ""},
]
result = evaluate(pairs)
assert result["reference_words"] == 5
assert result["word_errors"] == 3
assert result["wer"] == 0.6  # Corpus weighted, including insertions on silence.
assert result["silence_output_rate"] == 0.5
assert evaluate(pairs, raw=True)["wer"] == 1.0
assert evaluate([{"reference": "", "hypothesis": "noise"}])["wer"] is None
assert evaluate([{"reference": "", "hypothesis": "..."}])["silence_output_rate"] == 1

for invalid in ([], [{}], [{"reference": "a", "hypothesis": None}], ["not an object"]):
    try:
        evaluate(invalid)
    except ValueError:
        pass
    else:
        raise AssertionError("invalid input accepted")

with tempfile.TemporaryDirectory() as folder:
    data = Path(folder) / "pairs.jsonl"
    data.write_text("\n".join(json.dumps(pair) for pair in pairs), encoding="utf-8")
    command = [sys.executable, str(ROOT / "scripts/evaluate_transcripts.py"), str(data)]
    output = subprocess.run(command, capture_output=True, text=True, check=True)
    assert json.loads(output.stdout)["wer"] == 0.6
    data.write_text("\n".join(json.dumps({**pair, "language": "de" if index else "en"}) for index, pair in enumerate(pairs)), encoding="utf-8")
    grouped = json.loads(subprocess.run(command + ["--group", "language"], capture_output=True, text=True, check=True).stdout)
    assert grouped["wer"] == 0.6 and set(grouped["groups"]) == {"en", "de"}
    assert grouped["groups"]["en"]["utterances"] == 1 and grouped["groups"]["de"]["utterances"] == len(pairs) - 1
    data.write_text('{"reference": broken}', encoding="utf-8")
    output = subprocess.run(command, capture_output=True, text=True)
    assert output.returncode == 1 and "line 1: invalid JSON" in output.stderr

print("Evaluation checks passed (WER, CER, Unicode, silence, validation, CLI, groups).")
