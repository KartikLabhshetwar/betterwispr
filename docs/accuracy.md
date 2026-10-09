# Local transcription accuracy

Research reviewed 2026-10-08. The only measured accuracy numbers are the
read-speech Parakeet TDT v3 baseline and the cleanup experiment below. There is
still no benchmark of natural dictation.
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
   clip, and keeps the punctuation the decoder put around a replaced word. It
   also raises the spelling similarity a replacement needs to 0.65, and keeps
   the decoded words when they already contain the term, because the lower
   floor swapped everyday words for listed terms in conversation (see
   [Phrase booster floor](#phrase-booster-floor-2026-10-10)). Boosting runs
   when the language is English, or automatic and the decoded text reads as English,
   since the booster is English-only. Before that check, automatic mode with a
   vocabulary rewrote a German clip, turning "meine" into "Mike" and "Zauber" into
   "Zowber".
   On two `say`-synthesized clips it corrected the eight listed terms Parakeet v3
   had misspelled and changed nothing when no vocabulary was given. That is a
   smoke test, not an accuracy measurement. WhisperKit 1.1.0 transcribes with
   its greedy sampler only, so biasing methods that need beam search do not
   apply to it without upstream work.
   Spoken commands are not boosted. On 16 `say` clips in two Indian English
   voices, boosting "comma", "at the rate", "question mark", "exclamation mark"
   and "hyphen" with Parakeet v2 fixed 2 clips and broke 11. "In a coma" became
   "in a comma", "the red light" became "the rate light", and the word before a
   command was dropped ("Is this right question mark" became "Is this question
   mark?"). Instead, a vocabulary entry whose replacement is wholly a voice
   command, such as "Kocia Mark" written as "question mark", is applied before
   voice commands, so a user's own mishearing still becomes "?". Those entries
   are not sent as hints. Mishearings such as "coma" and "at the red" are not
   built in, because "in a coma" and "at the red light" are real phrases.
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
   trimmed. It also resolves one narrow self-repair shape: after a comma, a cue
   containing "no" or "I mean" ("sorry, no", "no wait", ", no,", ", I mean,"),
   followed by a word that also appears in the last four words of the same
   sentence and is not a subject pronoun. The cleaner deletes from that earlier
   word through the cue, so "go to Pune, sorry, no, to Delhi" becomes "go to
   Delhi". A lone "sorry", with or without commas, counts only when the repair
   restarts on in, at, on, from, near, into, by or with, so "I live in Ahmedabad
   sorry in Delhi" becomes "I live in Delhi" and "meet at 5 sorry at 6" becomes
   "meet at 6". Otherwise a lone "sorry" is an apology ("sorry for the wait",
   "sorry, the train was late"), and "so sorry in" or "sorry in advance" stays.
   "Yes to X, no to Y" has no set-off cue, and a repair that shares no word
   ("Pune, sorry, no, Delhi") or restarts on a pronoun ("we go, no, we stay") is
   left alone. "Like", "basically", "sort of" and other repairs and restarts are
   left alone too. A closed list covers fillers, but general repairs need a
   trained model and deleting hedges changes meaning ("it basically works").
   History keeps the raw output. On the 38 saved Parakeet transcripts available
   on 2026-10-08, the cleaner removed all 47 uh/um and 4 mm tokens and otherwise
   only collapsed four one-word stutters; no set-off "you know" occurred. Adding
   the repair rule changed one of those 38 outputs, the "Mdabad, sorry, no to
   Dilli" dictation it was written for. Adding the lone "sorry" rule changed none
   of the 190 saved transcripts available on 2026-10-09; three contain "sorry"
   and none restarts on a preposition it shares with the words before it.

   `VoiceCommands` then writes spoken numbers as digits and spoken symbols as
   @, # and %. "two hundred and fifty thousand" becomes "250,000", "ten
   percent" becomes "10%" and "two point five million" becomes "2.5 million".
   Indian English scales follow the models' own style: "one lakh" becomes "1
   lakh", "two lakh fifty thousand" becomes "2,50,000" with Indian grouping and
   "two point five crore" becomes "2.5 crore". "Twelve hundred" becomes "1200".
   When a larger scale or "hundred" cannot join the number before it, the
   readable part is written as digits and the rest stays as spoken, so "ten
   thousand hundred" becomes "10,000 hundred" and "ten thousand one lakh"
   becomes "10,000 1 lakh".
   "at the rate KV" becomes "@KV", "hashtag launch" becomes "#launch", "issue
   hash forty two" becomes "issue #42" and "kartik at the rate gmail dot com"
   becomes "kartik@gmail.com". Formatting changes how a number is written, not
   its value. A lone digit word ("give me five minutes"), "a hundred times",
   ordinals, spoken digit strings ("5 5 5") and neighbouring number words that
   do not form one number ("nineteen ninety nine", "fifty fifty") stay as
   spoken. These rules run only when the language is English or automatic. The
   raw transcript keeps the model's words, and only the final text changes.

   `EmailDictation` then lays out an explicit spoken request such as "write an
   email to Sarah saying …, best regards, Kartik" as a greeting, a body and a
   sign-off on their own lines. It needs "write", "draft" or "compose" at the
   start and "saying", "that", "telling her" or a similar word after the name,
   so "I will write an email to Sarah" stays as spoken. A sign-off after
   "thanks" or "cheers" needs a capitalized name, because "thanks, see you
   soon" is part of the body. A composed email skips the tone and the Medium
   edit. `TranscriptPolisher` will not follow instructions in the dictation and
   rejects output much longer than the input, so it cannot write the email
   itself.
6. **Measure streaming separately.** Partial text is provisional. Finalize with
   sufficient context, and measure final WER, first-text latency, stop-to-final
   latency and dropped/repeated boundary words. Re-transcribing the full growing
   recording has rising cost; use bounded overlapping chunks only after measuring
   the resulting boundary errors.

These are engineering recommendations inferred from the sources and failure
modes above. They do not imply that VAD, model adaptation, streaming decoding or
an LLM rewrite pipeline are already implemented in BetterWispr.

## Parakeet TDT v3 baseline, 2026-10-09

Measured on an Apple M5 with macOS 26.6.2, a release build of `BetterWisprCLI`
from commit 33f726a plus the uncommitted 0.1.4 changes, FluidAudio 0.17.5 and a
warm model cache. The corpus is 355 read-speech clips fetched by
`scripts/fetch_bench_corpus.py`: 40 evenly spaced clips from each test split of
LibriSpeech (clean and other) and Multilingual LibriSpeech (German, French,
Spanish, Italian, Portuguese, Dutch and Polish), with 35 for German after one
fetch batch failed. This is audiobook speech, not dictation. It measures
recognition and language handling, not the app's cleanup.

| Language | Clips | WER, language chosen | WER, automatic | CER, language chosen | Recognition p50 / p95 |
| --- | ---: | ---: | ---: | ---: | ---: |
| English | 80 | 2.46% | 2.46% | 0.79% | 0.046 s / 0.117 s |
| German | 35 | 9.76% | 9.76% | 3.61% | 0.079 s / 0.129 s |
| French | 40 | 5.21% | 4.86% | 2.02% | 0.116 s / 0.133 s |
| Spanish | 40 | 7.50% | 7.50% | 3.21% | 0.105 s / 0.134 s |
| Italian | 40 | 16.49% | 16.49% | 3.27% | 0.102 s / 0.121 s |
| Portuguese | 40 | 5.38% | 5.38% | 2.03% | 0.106 s / 0.129 s |
| Dutch | 40 | 12.85% | 12.85% | 3.82% | 0.080 s / 0.124 s |
| Polish | 40 | 5.35% | 5.35% | 1.16% | 0.108 s / 0.134 s |
| All | 355 | 7.98% | 7.93% | 2.44% | 0.078 s / 0.129 s |

- English splits into 2.30% WER on test-clean and 2.62% on test-other.
- Choosing the language matched automatic detection on every set except French,
  where automatic was better. Parakeet uses the choice only to filter tokens by
  script, so on this corpus it changed nothing that matters.
- Italian and Dutch WER is high while CER stays under 4%. Their most frequent
  differences are archaic spellings in the audiobook references ("esser" for
  "essere", "pria" for "prima", "z n" for "zijn") that the model writes in
  modern form. Read those two rows as an upper bound.
- Recognition took at most 0.28 s on clips of 5 to 17 seconds, 132 to 182 times
  faster than real time, and preparing the cached model took 0.25 to 0.38 s.
  Recognition is not where dictation latency comes from on this Mac.
- Light cleanup changed 2 of the 80 English clips, both by collapsing a doubled
  word the reader said ("And and", "Truly truly"). WER against the verbatim
  reference rose to 2.57%, which is the intended dictation behavior.

### Small language model cleanup experiment

The question was whether a small local model that rewrites the transcript after
recognition helps. The candidate was Superwhisper's
[S1-mini](https://huggingface.co/superwhisper/s1-mini-GGUF), a Qwen3 0.6B
fine-tune, run as GGUF Q4_K_M through Ollama with its published prompt,
temperature 0 and semi-formal styling. It ran after Light cleanup, and its
output had to pass `TranscriptPolisher`'s acceptance check.

- On 20 `say`-synthesized clips in three voices with fillers, repeats,
  self-repairs and fluent controls, scored against the intended clean text,
  WER was 20.3% raw, 16.9% after Light and 2.8% after Light then S1-mini, which
  fixed every repair and repeat clip. The current Medium path with llama3.1:8b
  through Ollama scored 12.4% and raised fluent-control WER to 15.3%. Apple's
  on-device model could not be tested because Apple Intelligence was off.
- On the 80 fluent English clips above, S1-mini changed 7 and raised WER from
  2.57% to 2.98%. In one it deleted a real clause, so "as I could not let you, I
  did not wish to let you go away" became "as I could not let you go away". The
  acceptance check passed all 80 rewrites because it checks length and new
  words, not deletions.
- S1-mini took 0.12 to 0.16 s per call at the median and 0.50 s at most.

S1-mini fixes self-repairs that rules cannot and is fast enough, but it deletes
fluent speech that looks like a restart. It is not part of the app. Shipping it
would need a deletion check measured on both sets, an explicit model download
and a native runtime.

## Accented conversational English, 2026-10-10

Measured on the same Mac with a release build of `BetterWisprCLI` from commit
cd8e2ca and Light cleanup. The corpus is 300 segments of
[EdAcc](https://huggingface.co/datasets/edinburghcstr/edacc) fetched by
`scripts/fetch_bench_corpus.py --accents`: 100 evenly spaced segments per accent
from the validation and test splits, each with at least four words, skipping
segments marked as overlapping, foreign, DTMF or no speech. Tags and the fillers
um, uh, er, hmm and mm are removed from the reference. Segments run 0.5 to 52 s,
4.6 s at the median. This is unscripted video-call conversation with verbatim
references, not dictation, and each accent has few speakers.

| Accent | Speakers | Reference words | v3 | v3, Light | v2 | v2, Light | 110M | 110M, Light |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| Indian English | 5 | 1751 | 14.51% | 13.65% | 14.45% | 14.85% | 15.71% | 17.13% |
| Nigerian English | 3 | 2186 | 16.42% | 17.98% | 16.70% | 18.98% | 22.00% | 24.34% |
| Mainstream US English | 16 | 1895 | 16.78% | 14.83% | 17.68% | 17.52% | 16.89% | 18.36% |
| All | 24 | 5832 | 15.96% | 15.66% | 16.34% | 17.27% | 18.45% | 20.23% |

- Bootstrap 95% intervals over clips put v2 minus v3 between -0.7 and +1.4
  points overall and across zero for every accent, so this corpus does not
  separate the two. 110M minus v3 is +1.2 to +3.8 points overall and +3.8 to +7.5
  points on Nigerian English.
- Speakers vary more than accents. Among speakers with more than one segment,
  v3 WER runs from 12.7% to 19.8% for Indian English, 8.0% to 18.0% for Nigerian
  English and 10.0% to 32.5% for US English.
- WER is six to seven times the LibriSpeech figure above for every accent, including
  US English, so conversational speech rather than accent drives most of it.
- With v3, Light cleanup lowered errors on 74 segments by 135 and raised them on
  51 by 117. Most rises are removals of "you know", stutters and repeated words
  that the verbatim reference keeps, which is the intended dictation behavior.
  One is not: "drinking more and more and more" became "drinking more and more".
- Real misrecognitions are mostly similar-sounding words, such as pick for speak,
  pocket for bucket, frames for flames and globe for club, and are most frequent
  in Nigerian English.
- Recognition p50 / p95 was 0.042 s / 0.118 s for v3, 0.041 s / 0.074 s for v2
  and 0.016 s / 0.040 s for 110M. Preparing each model took 4 to 22 s on the
  first load after the rebuild and 0.20 to 0.26 s when run again.

## Phrase booster floor, 2026-10-10

Measured on the same Mac with release builds of `BetterWisprCLI`, Parakeet v3,
English and Light cleanup, using `--bench MANIFEST --model parakeet-v3
--vocabulary "A,B,…"`. Three runs per setting:

- **Absent.** The 300 EdAcc segments above with 20 product and name terms that
  none of them say (Granola, Vercel, Supabase, Kubernetes, Postgres, Figma,
  Notion, Linear, Slack, Mem0, BetterWispr, Parakeet, Claude, Anthropic,
  Tailwind, Ollama, Sparkle, Labhshetwar, Kartik, MDX). Any change is a false
  replacement.
- **Present.** The same segments with 14 names they do say (Eragon, Paolini,
  Cinna, Dubai, Thai, Arabian, Harry Potter, Edinburgh, Instagram, Wikipedia,
  Manchester, Glasgow, London, Lisbon). A replacement is counted true when the
  new words appear in the reference.
- **Synthetic.** 84 clips from macOS `say`: 12 sentences using the absent
  terms, read by Rishi and Aman (Indian English), Daniel, Karen, Moira, Tessa
  and Samantha. The clips are not committed.

| Setting | Absent WER | Absent clips changed | Present WER | Present true / false | Synthetic WER | Synthetic true / false |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| No vocabulary | 16.22% | 0 | 16.22% | 0 / 0 | 14.29% | 0 / 0 |
| `itnDefaultConfig` (0.1.4 before this fix) | 17.42% | 44 | 16.90% | 4 / 47 | 7.14% | 41 / 7 |
| Floor 0.60 | 16.74% | 23 | 16.54% | 4 / 27 | 7.14% | 41 / 7 |
| Floor 0.65 | 16.31% | 5 | 16.29% | 4 / 7 | 6.44% | 40 / 0 |
| Floor 0.70 | 16.22% | 0 | 16.27% | 3 / 5 | 8.82% | 25 / 0 |
| Floor 0.75 | 16.22% | 0 | 16.22% | 3 / 3 | 9.10% | 25 / 0 |
| Floor 0.65, decoded words kept when they contain the term | 16.31% | 5 | 16.23% | 4 / 4 | 6.44% | 40 / 0 |

- FluidAudio picks a similarity floor of 0.50 for up to 10 terms and 0.55 for
  11 to 100, and the stricter config does not raise it. At that floor the
  booster turned "not like" and "not seen" into "Notion" and "Thank" into
  "Thai" in conversation that never said them.
- 0.65 is the lowest floor tried that kept all but one synthetic fix and
  removed most false replacements. 0.70 lost 16 of the 41 synthetic fixes.
  The floor was chosen on these same three sets, so it may be tuned to them.
- The rescorer sometimes widened a replacement to a neighbouring word, writing
  "Harry Potter" over "seven Harry Potter", "to Harry Potter" and "with Harry
  Potter". When the decoded words already contain the term, BetterWispr now
  keeps them and does not count a vocabulary fix.
- Remaining false replacements include "list one" to "Lisbon", "cinema" to
  "Cinna" and "Dragon" to "Eragon" in the present set, and "option" to
  "Notion", "cause" to "Claude" and "lines" to "Linear" in the absent set.
- With a non-empty vocabulary, recognition took 0.105 s longer per clip at the
  median than without one (0.153 s against 0.045 s), measured on the absent
  set after the first clip. The first clip also builds the boosting session.
- Turning off FluidAudio's spotter rescue (`FLUID_SPOTTER_RESCUE=0`), tapering
  the weight for short terms, or both, left absent WER at 17.33% to 17.42% and
  present WER at 16.90%, so neither is used.

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

`BetterWisprCLI --bench` writes these lines for a manifest of clips, and
`scripts/fetch_bench_corpus.py` builds the read-speech manifest used above, or
with `--accents` the EdAcc manifest.

```sh
python3 -I scripts/fetch_bench_corpus.py /tmp/bench 40
python3 -I scripts/fetch_bench_corpus.py /tmp/accents 100 --accents
swift build -c release --product BetterWisprCLI
.build/release/BetterWisprCLI --bench /tmp/bench/manifest.jsonl --model parakeet-v3 > results.jsonl
python3 scripts/evaluate_transcripts.py results.jsonl --group language
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
