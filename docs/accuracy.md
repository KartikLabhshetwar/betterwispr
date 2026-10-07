# Local transcription accuracy

Research reviewed 2026-10-08. BetterWispr has no measured accuracy benchmark yet.
The goal is to reduce real dictation errors on the user's hardware and languages;
neither a model leaderboard nor a paper justifies claiming "best accuracy" for
this application. A network-denied Tiny-model file smoke test and digital-silence
check passed; [the validation record](testing.md) documents their narrow scope.
The corpus work below remains a measurement plan, not benchmark results.

## What the evidence supports

| Primary source | Finding and practical implication |
| --- | --- |
| [Radford et al., Whisper, arXiv:2212.04356](https://arxiv.org/abs/2212.04356) | Large multilingual weak supervision produced strong zero-shot generalization. Use Whisper as a credible baseline, then measure accent, language, microphone and domain errors rather than assuming every subgroup performs equally. |
| [Gandhi et al., Distil-Whisper, arXiv:2311.00430](https://arxiv.org/abs/2311.00430) | Distillation reduces inference cost while retaining much of the teacher's performance on the evaluated English tasks. This makes distilled models useful latency candidates; the reported numbers are not a guarantee for multilingual dictation or this Mac. |
| [Bain et al., WhisperX, arXiv:2303.00747](https://arxiv.org/abs/2303.00747) | VAD-based segmentation improves long-form transcription and enables batching. Preserve speech boundaries and context when segmenting; forced alignment helps timestamps but does not independently repair wrong words. |
| [Barański et al., arXiv:2501.11378](https://arxiv.org/abs/2501.11378) | Non-speech audio can produce recurring hallucinations. Include silent/noisy negative examples in the benchmark. The paper's phrase filtering motivates evaluation, not unconditional deletion of phrases a user may actually say. |
| [Orhon et al., WhisperKit, arXiv:2507.10860](https://arxiv.org/abs/2507.10860) | On-device inference optimization can combine useful latency with low WER in the authors' benchmark. Treat it as evidence that local execution is viable, not a measurement of BetterWispr or proof that every feature is in the public OSS SDK. |

## Models to compare

Start with the same recordings and identical scoring for Whisper small, large-v3
turbo, and large-v3. Small is a practical low-resource starting point; turbo is
the latency candidate; large-v3 is the quality candidate. These roles are
hypotheses to test on target Macs. The publisher describes turbo as a pruned
large-v3 with four decoder layers instead of 32 and a speed/quality tradeoff.
[Whisper large-v3-turbo model card](https://huggingface.co/openai/whisper-large-v3-turbo).

WhisperKit provides a native Swift/Core ML route on Apple Silicon, while
whisper.cpp provides a separate local inference route. Quantized and unquantized
weights should have separate benchmark rows. A model file cached locally is
required for offline use; downloading an engine/model is an explicit setup step.
[Argmax OSS](https://github.com/argmaxinc/argmax-oss-swift),
[whisper.cpp](https://github.com/ggml-org/whisper.cpp).

For a later provider, compare Parakeet TDT 0.6B v3 on its supported languages. Its
publisher lists 25 European languages; it is not a universal replacement for
Whisper and does not list Hindi. A published server benchmark does not establish
latency on a Mac or preserve accuracy after conversion/quantization.
[NVIDIA model card](https://huggingface.co/nvidia/parakeet-tdt-0.6b-v3).

## Accuracy work, in order

1. **Preserve the audio.** Resample once to the engine's required rate; avoid
   clipping, incorrect channel mixing and sample loss during start/stop. Include
   very short utterances and speech at both recording boundaries. Keep a visible
   microphone level and actionable permission/device errors.
2. **Reject empty input carefully.** A signal-energy gate catches silence, not
   speech reliably: keyboard noise can pass and quiet speech can fail. Measure a
   trained VAD with onset padding and trailing hangover before relying on it to
   remove audio. Tune false rejection and hallucination rates together. The
   current shared Whisper provider rejects digital silence before decoding;
   this fixed an observed Tiny-model insertion on an all-zero WAV. That guard
   and the recorder's adjustable RMS gate are not learned noise classifiers.
3. **Control decoding.** Offer the spoken language when known, retain an automatic
   option for mixed use, and transcribe rather than translate. Start deterministic
   decoding; evaluate fallback, no-speech/log-probability thresholds and context
   independently. Whisper's reference implementation exposes these controls and
   notes that previous-text conditioning can cause repetition/failure loops.
   [Reference implementation](https://github.com/openai/whisper/blob/main/whisper/transcribe.py).
4. **Use vocabulary conservatively.** Small user-supplied name/product lists can
   seed supported decoders; a prompt is a hint, not guaranteed recognition. Measure
   exact entity recall and false insertions both with and without hints. Explicit
   user dictionary replacements should respect word boundaries and retain the
   original transcript for correction. Do not rewrite arbitrary near-matches.
5. **Separate recognition from rewriting.** First measure verbatim output. Local
   formatting or an optional local LLM must be scored separately and must not
   silently change negation, numbers, names or intent. Preserve raw and edited
   text. Automatic filler removal and broad hallucination blocklists can delete
   intended speech.
6. **Measure streaming separately.** Partial text is provisional. Finalize with
   sufficient context, and measure final WER, first-text latency, stop-to-final
   latency and dropped/repeated boundary words. Re-transcribing the full growing
   recording has rising cost; use bounded overlapping chunks only after measuring
   the resulting boundary errors.

These are engineering recommendations inferred from the sources and failure
modes above. They do not imply that VAD, model adaptation, streaming decoding or
an LLM rewrite pipeline are already implemented in BetterWispr.

## Reproducible evaluation

Create a consented local corpus of natural 3–30 second dictation clips, with a
smaller set of longer clips, spanning built-in/USB/Bluetooth microphones, quiet
and noisy rooms, accents, English/Hindi and code-switching where relevant, names,
technical vocabulary, numbers, negation, soft speech, restarts, repeated words
and silence. Keep validation and test speakers separate. Write transcripts by
listening to the audio, not by editing one model's output. Keep audio and private
transcripts outside Git; publish only recordings you have permission to share.

Record the app commit, engine/version, model ID and checksum, precision, language,
vocabulary, decoding/VAD settings, hardware, OS, audio checksum, sample rate and
whether the model was warm. Run the same clips through each candidate. Save one
UTF-8 JSON object per line:

```json
{"id":"001","reference":"Send the draft tomorrow","hypothesis":"Send a draft tomorrow"}
{"id":"silence-001","reference":"","hypothesis":""}
```

```sh
python3 scripts/evaluate_transcripts.py /path/to/pairs.jsonl
python3 scripts/evaluate_transcripts.py /path/to/pairs.jsonl --raw
python3 Tests/evaluate_check.py
```

The dependency-free evaluator reports corpus-weighted WER (total word edit
distance / total reference words), CER (Unicode code-point edit distance /
reference code points, excluding whitespace), and the fraction of annotated
silent clips with any non-whitespace output. WER can exceed 1. Insertions on
silent clips count in corpus errors; all-silence input reports `null` WER/CER
because their denominators are zero. An empty file or invalid text fields fail.

Default scoring lowercases, normalizes to NFC, preserves letters/marks/numbers
and replaces punctuation/symbols with spaces. `--raw` preserves case,
punctuation and symbols, while word splitting and CER still ignore whitespace.
Neither mode normalizes spoken numbers or abbreviations. This is not Whisper's
official English normalizer, so scores are not directly comparable to published
leaderboards. Whitespace WER is unsuitable for unsegmented languages; use the
documented CER, and introduce a fixed language-specific tokenizer before making
word-based comparisons. CER here counts code points, not grapheme clusters.

Run per-language/accent/device subsets separately; do not let an easy majority
hide regressions. Add exact-match rates for names and numbers, human correction
time, false speech rejection, hallucinated words per silent minute, p50/p95
latency, real-time factor and peak memory. The script measures text errors only;
timing, memory, entity analysis and bootstrap confidence intervals require a
separate experiment log. Retain individual clip pairs to support paired
resampling. Do not accept a default-model change until accuracy and usability
improve on the held-out corpus and silence/boundary tests still pass.
