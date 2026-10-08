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
| [Romana et al., arXiv:2311.00867](https://arxiv.org/abs/2311.00867) | Filled pauses were the easiest disfluency to detect (recall 1.00 in the authors' setup), repetitions came next and restarts were the hardest. A fixed English filler list is a sound first step. Repairs and restarts need a trained model, not rules. |
| [Zayats et al., arXiv:1904.04388](https://arxiv.org/abs/1904.04388) | Repetitions were 46% of disfluent words in their data, and intended repetitions were only 4% of all repetitions, usually emphasis such as "a long long time ago". Collapsing adjacent repeats is usually right when emphatic and grammatical doubles are protected. |
| [Andrusenko et al., arXiv:2406.07096](https://arxiv.org/abs/2406.07096) | A CTC word spotter that rescores a transducer's output raised recall of listed terms at a small precision cost. This is the route for names and jargon with Parakeet. FluidAudio implements it with a separate CTC model that must be installed explicitly. |
| [Jogi et al., arXiv:2502.11572](https://arxiv.org/abs/2502.11572); [Peng et al., arXiv:2305.11095](https://arxiv.org/abs/2305.11095) | A Whisper keyword-list prompt helped rare words but raised average WER, and word-list prompts hurt multilingual models. The comma-joined Whisper vocabulary prompt should be measured with and without hints before it stays on by default. |
| [Andrusenko et al., TurboBias, arXiv:2508.07014](https://arxiv.org/abs/2508.07014) | A phrase-boosting tree applied during greedy decoding of an attention encoder-decoder (Canary) raised listed-phrase F-score from 52.6 to 75.6 with precision falling from 97 to 93. Whisper is the same model family, so a WhisperKit logits filter is the candidate replacement for the keyword prompt. The transfer to Whisper is unmeasured. |
| [Jamshid Lou and Johnson, arXiv:2004.05323](https://arxiv.org/abs/2004.05323) | Filled pauses and discourse markers "belong to a finite set of words and phrases" and are trivial to detect in parsed transcripts, while self-repairs need a trained model. This supports a closed filler list and no rule-based repair guessing. |
| [arXiv:2509.20321](https://arxiv.org/abs/2509.20321) | On a deletion-only disfluency benchmark, LLM cleaners were weakest on fillers and discourse markers, and reasoning models over-deleted fluent words. Over-deletion is the main failure to guard against. |
| [arXiv:2307.04008](https://arxiv.org/abs/2307.04008) | Shipping dictation products edit with flat templates invoked by trigger words, and open-ended spoken editing reached 30% to 55% end-state accuracy. Spoken edit commands should be a closed trigger set. |
| [arXiv:2503.06924](https://arxiv.org/abs/2503.06924) | Prompting Whisper large-v3 with filler words ("um, uh") caused inserted sentences, loops and invented text. Never put fillers in a Whisper prompt. |
| [arXiv:2402.08021](https://arxiv.org/abs/2402.08021) | About 1% of Whisper transcripts contained hallucinated phrases, and longer non-vocal duration predicted them. Trimming long pauses before decoding is the evidenced mitigation. |
| [Gu et al., arXiv:2405.15216](https://arxiv.org/abs/2405.15216); [Pu et al., arXiv:2310.11532](https://arxiv.org/abs/2310.11532) | Zero-shot LLM correction degraded strong recognizer output, and correcting every utterance raised WER. A general LLM rewrite is not an accuracy fix. |
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
   WhisperKit's built-in VAD chunking is also energy-based (`EnergyVAD`).
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
   Parakeet uses vocabulary only when the optional phrase booster is installed.
   The booster is FluidAudio's CTC word spotter (arXiv:2406.07096): a separate
   110M CTC model (about 99 MB) scores each listed term against the audio, and a
   decoded word is replaced only when a term fits the audio better. BetterWispr
   uses FluidAudio's stricter `itnDefaultConfig` similarity floors, because the
   default config replaced "We should render" with "Supabase" on a synthetic
   clip, and keeps the punctuation the decoder put around a replaced word. Boosting runs
   when the language is English or automatic, since the booster is English-only.
   On two `say`-synthesized clips it corrected the eight listed terms Parakeet v3
   had misspelled and changed nothing when no vocabulary was given. That is a
   smoke test, not an accuracy measurement. WhisperKit 1.1.0 transcribes with
   its greedy sampler only, so biasing methods that need beam search do not
   apply to it without upstream work.
5. **Separate recognition from rewriting.** First measure verbatim output. Local
   formatting or an optional local LLM must be scored separately and must not
   silently change negation, numbers, names or intent. Preserve raw and edited
   text. Broad hallucination blocklists can delete intended speech.
   `TranscriptCleaner` removes only a fixed list of English filled pauses (uh,
   um, er, hmm, mm and their spellings), the discourse marker "you know" when
   commas or a sentence boundary set it off on both sides, and back-to-back
   repeats of one to three words that no punctuation separates. "mm" after a
   number stays as a unit, and "you know?" stays because removing it would turn
   a statement into a question. Digits, number words and a short list of
   grammatical or emphatic doubles ("that that", "had had", "long long") are
   kept. Language detection ignores the fillers, and non-English text is only
   trimmed. "I mean", "like", "basically", "sort of", repairs and restarts are
   left alone. A closed list covers fillers, but repairs need a trained model
   and deleting hedges changes meaning ("it basically works"). History keeps
   the raw output. On the 38 saved Parakeet transcripts available on 2026-10-08,
   the cleaner removed all 47 uh/um and 4 mm tokens and otherwise only collapsed
   four one-word stutters; no set-off "you know" occurred.
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
