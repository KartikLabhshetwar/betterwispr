"""Fetch a small multilingual read-speech, or with --accents accented conversational English, test corpus from HF datasets-server."""
import json, re, subprocess, time, urllib.error, sys, urllib.request, urllib.parse
from pathlib import Path

OUT = Path(sys.argv[1])
PER_LANG = int(sys.argv[2]) if len(sys.argv) > 2 else 40
ACCENTS = [("en-IN", "Indian English"), ("en-NG", "Nigerian English"), ("en-US", "Mainstream US English")]
UNSCORABLE = re.compile(r"<(?:OVERLAP|FOREIGN|DTMF|NO-SPEECH)>|IGNORE_TIME_SEGMENT")
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

def rows(dataset, config, split, offset, length, where=None):
    params = {"dataset": dataset, "config": config, "split": split, "offset": offset, "length": length}
    query = urllib.parse.urlencode(params | ({"where": where} if where else {}))
    for attempt in range(6):
        try:
            with urllib.request.urlopen(f"https://datasets-server.huggingface.co/{'filter' if where else 'rows'}?{query}", timeout=120) as r:
                return json.load(r)["rows"]
        except urllib.error.HTTPError as error:
            if error.code != 429 or attempt == 5:
                raise
            time.sleep(15 * (attempt + 1))

def edacc(accent):
    """Evenly spaced EdAcc segments of one accent with at least four scorable words, fillers and noise tags removed."""
    usable = []
    for split in ("validation", "test"):
        offset = 0
        while batch := rows("edinburghcstr/edacc", "default", split, offset, 100, f"\"accent\"='{accent}'"):
            for i, item in enumerate(batch):
                words = re.sub(r"<[^>]+>|\b(?:UM|UH|ER|HMM|MM)\b", " ", item["row"]["text"]).split()
                if not UNSCORABLE.search(item["row"]["text"]) and len(words) >= 4:
                    usable.append((f"{split[0]}{offset + i:05d}", item["row"], " ".join(words)))
            offset += 100
            time.sleep(2)
    return usable[::max(1, len(usable) // PER_LANG)][:PER_LANG]

def save(clip_id, language, audio, reference):
    src = OUT / f"{clip_id}.src"
    wav = OUT / f"{clip_id}.wav"
    if not wav.exists():
        urllib.request.urlretrieve(audio, src)
        subprocess.run(["afconvert", "-f", "WAVE", "-d", "LEI16@16000", "-c", "1", str(src), str(wav)], check=True)
        src.unlink()
    manifest.append({"id": clip_id, "language": language, "audio": str(wav), "reference": reference})
    print(clip_id, file=sys.stderr)

manifest = []
if "--accents" in sys.argv:
    for language, accent in ACCENTS:
        for key, row, reference in edacc(accent):
            save(f"{language}-{key}", language, row["audio"][0]["src"], reference)
else:
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
            save(f"{lang}-{offset:05d}", lang.split("-")[0], row["audio"][0]["src"], row[field])

(OUT / "manifest.jsonl").write_text("".join(json.dumps(m, ensure_ascii=False) + "\n" for m in manifest))
print(f"{len(manifest)} clips", file=sys.stderr)
