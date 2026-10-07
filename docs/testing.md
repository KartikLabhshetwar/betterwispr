# Verification checklist

The validation record below lists checks actually performed. The remaining
unchecked items are procedures, not passed tests. Record the commit, macOS
version, Mac model, input device, engine/model and date for future runs. A
successful build does not verify microphone capture, clipboard behavior or
general recognition accuracy.

## Validation record — 2026-10-08

Environment: Apple M5, macOS 26.6.2 (25G83), development working tree.

- Native Swift build succeeded; all three Swift tests and the Python evaluator
  checks passed. The app bundle was packaged, its ad-hoc code signature verified,
  and the native app launched and visually inspected in a screenshot.
- Downloaded Whisper Tiny and its tokenizer explicitly, then ran file recognition
  in a **fresh process with networking denied** by `sandbox-exec`. The public
  [whisper.cpp JFK sample](https://github.com/ggml-org/whisper.cpp/blob/master/samples/jfk.wav)
  (11 seconds, 16 kHz mono Int16) produced:

  > And so my fellow Americans ask not what your country can do for you ask what you can do for your country.

  One run took approximately **1.17 seconds including model loading**. This is
  a single functional smoke test, not a general accuracy or latency benchmark.
- A two-second digital-silence WAV produced an empty transcript with exit code 0
  under the same network restriction after the shared silence guard was added.
- **Not exercised:** live microphone dictation, interactive permission prompts,
  automatic paste/clipboard restoration, and a representative accuracy corpus.
  The manual checks below remain pending even where a related file test passed.

Reproduce the local file checks after building the CLI:

```sh
swift build --product BetterWisprCLI
.build/debug/BetterWisprCLI --download-model parakeet-v3
curl -fL https://raw.githubusercontent.com/ggml-org/whisper.cpp/master/samples/jfk.wav -o /tmp/betterwispr-jfk.wav
sandbox-exec -p '(version 1) (allow default) (deny network*)' .build/debug/BetterWisprCLI --transcribe-file /tmp/betterwispr-jfk.wav --model parakeet-v3 --language en
python3 -c 'import wave; w=wave.open("/tmp/betterwispr-silence.wav","wb"); w.setnchannels(1); w.setsampwidth(2); w.setframerate(16000); w.writeframes(bytes(64000)); w.close()'
sandbox-exec -p '(version 1) (allow default) (deny network*)' .build/debug/BetterWisprCLI --transcribe-file /tmp/betterwispr-silence.wav --model parakeet-v3 --language en
```

Downloads happen before the restricted process. Test audio is not committed to
the repository. `sandbox-exec` is a macOS development verification tool, not the
app's runtime sandbox or a cross-platform test dependency.

## Automated checks

```sh
swift build
swift test
python3 Tests/evaluate_check.py
./scripts/build-app.sh
```

Inspect failures and preserve exact commands/results. Swift tests cover only the
behaviors asserted in `Tests/BetterWisprCoreTests/`; the Python check covers
scoring, Unicode normalization, empty references, invalid input and the evaluator
CLI. Neither recognizes microphone audio.

## First launch and permissions

- [ ] Launch the packaged app with `./scripts/run.sh`; the dashboard and menu-bar
  entry appear without requiring an account.
- [ ] Start with microphone permission denied. No recording proceeds; the app
  gives a useful recovery path. Grant permission in System Settings and retry.
- [ ] Deny Speech Recognition permission for the Apple provider. It reports the
  denial; Whisper remains usable after its model is installed.
- [ ] Choose a locale without available Apple on-device support. The app reports
  unavailability and does not send audio to a server.
- [ ] Deny Accessibility. Dictation and manual copy remain usable; automatic
  insertion explains its permission requirement rather than pretending it worked.

## Recording, capsule and cancellation

- [ ] Focus a TextEdit document, press **Option–Space**, speak a distinctive sentence,
  and press it again. The capsule appears at bottom center without stealing focus;
  level animation responds to actual microphone input. Final text is recoverable.
- [ ] Check the built-in mic and one external input. Verify audio rate/channel
  conversion by comparing a short recording with the recognized text.
- [ ] Try 1-second, 10-second and longer dictation. Say a word immediately at start
  and another immediately before stop; neither boundary should disappear.
- [ ] Record silence, fan noise and keyboard clicks. Log any inserted text; do not
  assume an energy threshold is a reliable speech detector.
- [ ] Repeat rapid start/stop, stop while preparation is pending, and cancel during
  recording/recognition. Only one session is active; no later transcript is pasted
  after cancellation and the microphone indicator turns off.
- [ ] Hold mode: hold ⌥ Space, speak, release. The capsule shows only the waveform,
  with no cancel or finish buttons. Text is inserted once. Tap ⌥ Space
  briefly; the capsule shakes, shows "Don’t tap. Hold ⌥ Space." and pastes nothing.
  Release before the bars move; it shows "Keep holding ⌥ Space." and pastes nothing.
- [ ] Toggle mode: press ⌥ Space once and speak. The capsule shows cancel, the
  waveform and a red stop mark. Clicking anywhere on the capsule finishes, as does
  pressing ⌥ Space again. The cancel button discards the session and pastes nothing.
- [ ] Disconnect the input device during capture; retry after reconnecting.
- [ ] Move between Spaces, fullscreen windows and monitors. Confirm capsule
  positioning, keyboard controls, VoiceOver labels and reduced-motion behavior.

## Clipboard and insertion

- [ ] Start with a known clipboard string, dictate into TextEdit and verify final
  insertion. Paste manually afterward: with "Copy to clipboard" on the transcript
  pastes again, with it off the prior clipboard was restored.
- [ ] Turn off both "Paste into the active app" and "Copy to clipboard". Dictation
  must leave the clipboard untouched and show no toast.
- [ ] While dictating or transcribing, the capsule must show only the waveform,
  never the recognized text.
- [ ] After a successful paste no toast appears. Copy-only results still show
  a "Copied" toast.
- [ ] Repeat with a clipboard image or rich text; the app must preserve supported
  pasteboard representations, not just plain text.
- [ ] Change clipboard contents while recognition/paste is pending. New user
  clipboard contents must not be replaced by an old snapshot.
- [ ] Switch to another app while recognition is pending. It must not paste into
  the newly focused app. Retrieve the transcript by manual copy. The current
  guard checks the app process, not changes between fields inside the same app;
  record this limitation when testing.
- [ ] Quit the original destination app before recognition finishes. Verify a
  recoverable failure and no paste into a replacement app.
- [ ] Disable automatic paste. Dictation/history still work and no keystroke is
  sent to the frontmost app.
- [ ] Revoke Accessibility and dictate. The capsule shows "Copied, not pasted."
  with an Allow button. Grant it, rebuild with `scripts/build-app.sh`, and check
  that paste still works without granting again.

## Offline models and failure recovery

- [ ] Install a Whisper model/tokenizer explicitly. Verify progress, local storage
  and that cancellation leaves no model falsely marked ready.
- [ ] Quit BetterWispr, disconnect networking, relaunch, select the installed
  model and dictate. A warm already-loaded model alone is not an offline-load test.
- [ ] Monitor outbound connections in an appropriate local network tool while
  preparing with downloads disabled and transcribing. No speech/model request
  should occur; account for unrelated OS traffic separately.
- [ ] With networking disabled, choose an uninstalled model. Get a clear setup
  error instead of a stalled download or silent engine switch.
- [ ] Using a disposable model copy, test a missing tokenizer file, truncated
  weights and failed/incomplete installation. Keep the working model untouched.
- [ ] Compare Small, Turbo and Large v3 on the same clips; record peak memory,
  first load, warm inference and stop-to-final time. Test cancellation under load.

## Local history and privacy

- [ ] Enable history, dictate, relaunch and confirm raw/final text and settings
  persist. Dashboard totals derive from actual saved sessions.
- [ ] Disable history, dictate again and relaunch. That new transcript must not
  have been persisted. Delete existing history entries explicitly and verify
  they stay deleted after relaunch.
- [ ] Verify temporary audio removal after success, error and cancellation. Force
  termination is a separate check: record whether recovery removes orphaned files.
- [ ] In a temporary profile, supply malformed JSON or an unsupported schema
  version. The app reports the problem and preserves the original file.
- [ ] Add vocabulary with punctuation, accented letters, Hindi combining marks,
  overlapping phrases and literal `$`/backslash text. Confirm whole-word matching,
  no cascading replacements and access to the original transcription.

## Updates

- [ ] Settings shows the installed version under About. "Check for Updates…" in
  About and in the app menu opens Sparkle's update window and is disabled while
  a check is already running.
- [ ] Change both update toggles, quit and relaunch. Both keep their values, and
  "Download and install automatically" is disabled while automatic checks are off.
- [ ] Install an older signed release, publish a newer GitHub release with its
  `appcast.xml`, then check for updates. The older build downloads, verifies and
  installs the newer one and relaunches at the new version.
- [ ] Turn off automatic checks and relaunch. A network monitor shows no request
  for the appcast until you choose "Check for Updates…".

## Accuracy

- [ ] Follow [the corpus and scoring protocol](accuracy.md). Use consented natural
  speech and human references; do not use synthetic demo text as an app benchmark.
- [ ] Compare raw/normalized WER and CER, entity/number correctness, silence
  hallucinations, rejected speech and correction time on the same held-out clips.
- [ ] Separate language/accent/device groups and latency measurements. Record
  settings and model hashes; do not report another project's paper numbers as
  BetterWispr results.
