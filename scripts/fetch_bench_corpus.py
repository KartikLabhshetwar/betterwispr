"""Fetch a small multilingual read-speech test corpus from the HF datasets-server rows API."""
import json, subprocess, time, urllib.error, sys, urllib.request, urllib.parse
from pathlib import Path

OUT = Path(sys.argv[1])
PER_LANG = int(sys.argv[2]) if len(sys.argv) > 2 else 40
SOURCES = [
    ("en", "openslr/librispeech_asr", "clean", "test", 2620, "text"),
    ("en-other", "openslr/librispeech_asr", "other", "test", 2939, "text"),
    ("de", "facebook/multilingual_librispeech", "german", "test", 3394, "transcript"),
    ("fr", "facebook/multilingual_librispeech", "french", "test", 2426, "transcript"),
    ("es", "facebook/multilingual_librispeech", "spanish", "test", 2385, "transcript"),
    ("it", "facebook/multilingual_librispeech", "italian", "test", 1262, "transcript"),
    ("pt", "facebook/multilingual_librispeech", "portuguese", "test", 871, "transcript"),
    ("nl", "facebook/multilingual_librispeech", "dutch", "test", 3075, "transcript"),
    ("pl", "facebook/multilingual_librispeech", "polish", "test", 520, "transcript"),
]

def rows(dataset, config, split, offset, length):
    query = urllib.parse.urlencode({"dataset": dataset, "config": config, "split": split, "offset": offset, "length": length})
    for attempt in range(6):
        try:
            with urllib.request.urlopen(f"https://datasets-server.huggingface.co/rows?{query}", timeout=120) as r:
                return json.load(r)["rows"]
        except urllib.error.HTTPError as error:
            if error.code != 429 or attempt == 5:
                raise
            time.sleep(15 * (attempt + 1))

manifest = []
for lang, dataset, config, split, total, field in SOURCES:
    batches = 8
    step = max(1, total // batches)
    picked = []
    for b in range(batches):
        try:
            picked += [(b * step + i, item["row"]) for i, item in enumerate(rows(dataset, config, split, b * step, PER_LANG // batches))]
        except Exception as error:
            print(f"skip {lang} batch {b}: {error}", file=sys.stderr)
        time.sleep(2)
    for offset, row in picked:
        clip_id = f"{lang}-{offset:05d}"
        src = OUT / f"{clip_id}.src"
        wav = OUT / f"{clip_id}.wav"
        if not wav.exists():
            urllib.request.urlretrieve(row["audio"][0]["src"], src)
            subprocess.run(["afconvert", "-f", "WAVE", "-d", "LEI16@16000", "-c", "1", str(src), str(wav)], check=True)
            src.unlink()
        manifest.append({"id": clip_id, "language": lang.split("-")[0], "audio": str(wav), "reference": row[field]})
        print(clip_id, file=sys.stderr)

(OUT / "manifest.jsonl").write_text("".join(json.dumps(m, ensure_ascii=False) + "\n" for m in manifest))
print(f"{len(manifest)} clips", file=sys.stderr)
