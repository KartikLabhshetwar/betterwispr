# Verification checklist

The validation record below lists checks actually performed. The remaining
unchecked items are procedures, not passed tests. Record the commit, macOS
version, Mac model, input device, engine/model and date for future runs. A
successful build does not verify microphone capture, clipboard behavior or
general recognition accuracy.

## Release check — 2026-10-08, version 0.1.0

Base commit: `490ae9787842548c49bd70ad93a200f53062add0`, plus the dashboard
Escape-cancellation fix. Apple M5 MacBook Pro (32 GB), macOS 26.6.2 (25G83),
Swift 6.3.3; built-in MacBook Pro microphone, Parakeet TDT v3, automatic language.

- `swift package clean` removed generated builds, module caches and app bundles.
  Dependency checkouts, installed speech models and saved user data were retained.
- `swift build`, `swift test`, `swift build -c release`, `swift test -c release`
  and both app packaging configurations passed. Each test suite passed 60 test
  functions and skipped the one opt-in live test. Python evaluator checks passed.
- `BETTERWISPR_LIVE_NOTES=1 swift test --skip-build --filter
  liveNotesProvidersGenerateFromSyntheticMeeting` passed all three synthetic
  cases: Claude Code, Codex and the local Ollama-compatible API. The release app's
  own **Test notes model** also succeeded with Claude Code.
- Fresh debug and release CLI processes, with networking denied by
  `sandbox-exec`, transcribed synthetic speech with Parakeet v3 and returned
  empty text for digital silence. Missing audio, unavailable Whisper Turbo,
  unknown models and repeated CLI options failed with the expected errors.
  Whisper Turbo is not installed; its recognition was not exercised.
- The native app opened, restored saved settings/history/meetings and displayed
  Models, Vocabulary, Settings and all three meeting-detail tabs. Microphone
  recording and menu cancellation worked. Escape initially failed to cancel;
  the dashboard now handles the native exit command. Retesting the rebuilt
  release app and a copy extracted from its DMG confirmed Escape returns to
  idle without adding history or leaving new temporary audio files.
- Developer ID signatures, hardened runtime, bundled framework signatures and
  DMG integrity passed. **The initial run was blocked:** `scripts/release.sh` failed
  at notarization with HTTP 403: a required Apple developer agreement is missing
  or expired. That run produced a signed but unnotarized `release/BetterWispr.dmg`;
  no stapling or appcast was produced, and no release was published.

Still pending: real speech through the global hold/toggle shortcut into another
app, paste and clipboard restoration, denied permissions, live system-audio
meetings, microphone hot-plug, long recordings, Apple/Whisper recognition and
minimum-supported-macOS checks. A pre-existing 4 KB dictation CAF from an earlier
run remained in the temporary directory; normal cancellations in this run
cleaned up, but crash/forced-quit cleanup was not exercised.

Local logs are in `.build/release-check/`. The signed, unnotarized DMG SHA-256 is
`b7c46f85a8a17b3cc9dec80eb348cd45bda0d0e7a58d9ddcae75eafe9b7c7a48`.

Shipping workflow follow-up on 2026-10-08:

- `make test` passed, including the new release-script checks. Shell syntax
  checks passed for both release and DMG scripts.
- Real DMG packaging completed and `hdiutil verify` passed for
  `.build/release-check/BetterWispr-packaging-check.dmg`.
- Real `make ship` stopped at preflight because `betterwispr-notary` has not
  been configured in Keychain. Existing artifacts were unchanged. No live
  notarization or stapling was completed in this follow-up.

After credential setup, the script's misleading setup advice for agreement
errors was corrected. Shell syntax and release-script checks passed, including
missing credentials, HTTP 401, agreement-specific HTTP 403, other HTTP 403 and
network failures. A subsequent real `make ship` passed Apple's access check and
completed successfully:

- Apple accepted submission `27bcf9d0-0416-42c9-838f-5cb4c66effaf`.
- Stapling succeeded and Gatekeeper reported `Notarized Developer ID`.
- `release/appcast.xml` was generated; its file length and Sparkle signature
  were verified against the final DMG.
- Final `release/BetterWispr.dmg` SHA-256:
  `a5e6584c55491a04334c6b5bfdf8654fea4cc85fdb5c28d536e0fb56b6abd4f4`.
  These files are ready for publishing; no GitHub release was published.

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
- After `--download-phrase-booster` (99 MB), Parakeet v3 with networking denied
  transcribed a `say`-synthesized clip with `--language en --vocabulary
  "Granola,Vercel,Supabase,MDX"` and spelled all four terms as listed. Without
  the vocabulary it wrote "granula", "Versal" and "Superbase". On a second clip,
  `--language de` left the listed names misspelled, as intended for the
  English-only booster. Single runs on synthetic audio, not an accuracy
  measurement.
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
python3 Tests/release_check.py
./scripts/build-app.sh
```

Inspect failures and preserve exact commands/results. Swift tests cover only the
behaviors asserted in `Tests/BetterWisprCoreTests/`; the Python check covers
scoring, Unicode normalization, empty references, invalid input and the evaluator
CLI. Neither recognizes microphone audio.

Release script checks use stub tools to exercise Keychain setup arguments,
credential preflight, notarization failure handling and bounded Finder-busy
retries. They do not access Keychain, mount disk images or submit to Apple.

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

## Disk image and first launch

- [ ] Run `bash scripts/create-dmg.sh .build/debug/BetterWispr.app /tmp/BetterWispr.dmg`
  and open the DMG in Light and Dark Mode. BetterWispr and Applications sit either
  side of the arrow, their Finder labels are readable, and the install line stays
  visible with Finder's path bar shown.
- [ ] Drag BetterWispr to Applications and open it. The welcome guide appears once.
  Quit and relaunch; the dashboard opens and the menu bar menu offers no way to replay it.

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
- [ ] With the dashboard focused, click Start Dictating, then press Escape.
  It returns to Start Dictating with "Cancelled.", adds no history entry and
  removes the session's temporary audio. Escape still cancels shortcut capture
  in Settings without changing the saved shortcut.
- [ ] Hold mode: hold ⌥ Space, speak, release. The compact glass capsule shows only the waveform,
  with no cancel or finish buttons. Text is inserted once. Tap ⌥ Space
  briefly; the capsule expands into an error card, shows "Don’t tap. Hold ⌥ Space." and pastes nothing.
  Release before the bars move; it shows "Keep holding ⌥ Space." and pastes nothing.
- [ ] Toggle mode: press ⌥ Space once and speak. The glass capsule is 64 × 28 points,
  with a neutral border, five white waveform bars and a white stop square in a gray circle.
  Clicking anywhere on the capsule finishes, as does pressing ⌥ Space again.
  Right-click and choose Cancel dictation; the session is discarded and nothing
  is pasted. During preparation/transcription, the visible cancel button works.
- [ ] Keep another app focused and hover the microphone, notetaker icon and chevron.
  The tooltip changes to "Dictate" with the shortcut, "Start notetaker" and
  "Open meeting notes" respectively. Move between them and then away; tooltips
  update without flickering and the controls collapse without taking focus.
- [ ] Trigger a dictation error and a notetaker error. Each replaces the pill with
  one rounded glass card, with a warning/title row, message below and a dismiss
  button. Accessibility errors keep the Allow action; errors during a meeting
  retain Stop notetaker. Check reduced motion, reduced transparency and increased contrast.
- [ ] In Settings, click the keyboard shortcut and press a new combination such as
  ⌃⌥D. ⌥ Space no longer starts dictation; the new shortcut works in hold and
  toggle mode and is still set after relaunch. While recording a shortcut, Esc
  cancels and keeps the old one. Held modifiers show on the button as you press
  them. A letter alone or with only ⇧, Fn, or multiple modifiers released without
  a key are refused with feedback. An F-key alone such as F5 is accepted.
  A shortcut another app holds shows a toast and the old one keeps
  working. Reset restores ⌥ Space.
- [ ] In Settings, press and release left Option alone. With Accessibility enabled,
  it saves as Left Option, works in hold and toggle mode inside BetterWispr and
  TextEdit, and survives relaunch. Repeat for right Option, Control, Shift and
  Command. The opposite-side key alone must not trigger dictation. Releasing the
  chosen key must finish hold mode even if another modifier is down. Recording
  ⌥ Space must still save the combination, not Option alone. Cancelling capture,
  leaving Settings and resetting must remove the temporary listeners.
- [ ] With Accessibility denied, selecting a modifier-only shortcut explains the
  required permission and keeps the previous shortcut. Revoke permission with a
  saved modifier shortcut, relaunch, then grant it again and return to BetterWispr;
  the saved shortcut resumes working. Ordinary combinations remain available.
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

### Voice commands and learned corrections

- [ ] With English or Auto language, say "hello comma how are you question mark".
  Expect "Hello, how are you?" or the model's casing of it.
- [ ] Say "Send it Monday. Sorry, remove that. Send it Tuesday." Only "Send it
  Tuesday." is pasted. "Please remove that file" stays as spoken.
- [ ] In Slack, say "ping at the rate KV". Expect "ping @KV". Whether Slack then
  opens its mention picker is Slack's behavior; record what happens.
- [ ] Dictate a name into TextEdit, fix the spelling within 30 seconds and wait
  about 4 seconds. Expect a "Learned" toast and a Learned entry in Vocabulary.
  Repeat in Slack and Notes and record whether the app exposes its text field to
  Accessibility (Electron apps may not).
- [ ] Fix a word with the pencil in History. The raw transcription stays
  unchanged and the word appears in Vocabulary as Learned.
- [ ] Turn off "Learn from my corrections" and repeat. Nothing is learned.
- [ ] Type in a password field after dictating. Nothing is read or learned.

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
- [ ] With Parakeet selected, download the phrase booster from Vocabulary. Verify
  the progress state, the installed confirmation, and that a dictation with a
  listed name uses the listed spelling without relaunching. Cancel a booster
  download and confirm it is not reported as installed.
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

## Bring your own model / API connections

Automated coverage uses synthetic audio and stub HTTP responses. It checks old
settings decoding, URL/key validation, the three request/response formats,
48 kHz stereo CAF conversion to 16 kHz mono WAV, Sarvam chunk coverage, real
Keychain insert/read/rotation/deletion using disposable test keys, redirect
refusal, no requests in preparation, and cancellation of an in-flight request.
These checks do not establish live provider acceptance or recognition quality.

- [ ] Add Sarvam and Smallest connections using your own keys. Saving makes no
  request. Select Use and dictate, then start a meeting with each provider.
  For Smallest choose an explicit spoken language; Pulse Pro needs English.
- [ ] Select an unsupported language or Smallest with automatic language. The
  error appears before recording begins, and no audio is uploaded.
- [ ] Dictate longer than 30 seconds with Sarvam. Confirm the full transcript and
  inspect words around each 25-second boundary; fixed cuts may affect recognition.
- [ ] Connect an OpenAI-compatible server over localhost HTTP without a key, then
  an HTTPS endpoint with a Bearer key. Confirm both dictation and meeting chunks.
- [ ] Relaunch with a selected connection. Its selection persists; its key is
  absent from workspace JSON and history exports. Rotating/removing a key takes
  effect on the next recording. Editing the URL requires a new key and selecting
  Use again if the edited connection was active.
- [ ] Try an invalid key, quota error, unsupported model, malformed JSON, stopped
  local server and redirect. Surface a useful error without exposing response
  bodies or credentials. Never switch to another endpoint automatically.
- [ ] Cancel during upload/response and rapidly start another recording. No late
  result enters history or gets pasted; temporary audio is removed. Quit during
  an API meeting and verify the same cleanup.
- [ ] Select a built-in model and disconnect networking. It still runs locally;
  neither saved connections nor Keychain configuration trigger network requests.

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

## Meeting notes

Validation on 2026-10-08 for BYOK/subscription notes:
- `swift build`, `swift test` (61 tests, live-provider test disabled by default),
  and `./scripts/build-app.sh` passed. Added checks cover old settings/summary
  decoding, real CAF chunk writing and conversion through stubbed speech/notes HTTP,
  raw transcript persistence and export, malformed/failed/truncated responses,
  cancellation, CLI process timeout/large output/interactive replies, model catalog
  parsing and explicit selection persistence, long thoughts and echo filtering.
- `BETTERWISPR_LIVE_NOTES=1 swift test --filter liveNotesProvidersGenerateFromSyntheticMeeting`
  passed all three provider cases using synthetic text: signed-in Claude Code,
  signed-in Codex, and Ollama's OpenAI-compatible HTTP endpoint with `llama3.1:8b`.
  Requires both CLIs already signed in and that Ollama model already installed;
  this command never downloads models. A first local-API run exposed an invalid
  structured response; JSON-object output plus explicit string/array types in the
  prompt fixed the observed schema mismatches before the passing run.
- Native capture test: Parakeet v3 recorded microphone (Me) and synthetic playback
  through the system-audio tap (Them), stopped, and automatically generated a saved
  Ollama summary with decisions and an action item. Speaker audio was also picked
  up by the microphone; the new filter hid the matching Me segment after relaunch.
- The Models “Test notes model” button returned a real Claude summary. The saved
  test meeting was then updated with a synthetic QA thought and regenerated with
  Claude Code. This checks combined thoughts/transcript input, not recognition
  accuracy. No live cloud API key endpoint was exercised.
- Native model pickers showed all 12 Claude and 7 Codex models reported by the
  installed CLIs. Choosing Claude Sonnet and testing returned a summary labeled
  `claude-sonnet-5-5`; live tests also checked explicit default-model generation
  and summary provenance for both CLIs. Catalog counts depend on the CLI/account.
- After relaunching the final packaged app, the saved synthetic meeting regenerated
  with `Claude Code · claude-sonnet-5-5`. Its summary combined the spoken Friday
  launch/$500 budget with the personal QA sign-off thought. The selected model
  survived the relaunch and the summary footer showed the exact model ID.

Additional regression checks:
- [ ] Add a notes API connection using a complete chat-completions URL, custom
  model ID and key. Saving sends nothing; select it under Notes model and test.
  Rotate its key, change its URL, remove it and relaunch. Speech selection stays
  unchanged, keys stay in Keychain, and an edited active URL needs selection again.
- [ ] Select Claude Code or Codex, choose a discovered model or enter an exact ID,
  and test. Refresh the catalog and relaunch: the chosen ID should stay selected,
  and generated summaries should name it. Signed-out, missing/outdated CLI and subscription-limit failures should
  be actionable without exposing provider output or starting another provider.
- [ ] Edit thoughts during summary generation. The completed summary should be
  marked for update until regenerated with the new text. Cancel generation and
  verify the previous summary remains intact with no late replacement.
- [ ] Test speaker playback with partial overlap and different recognition results;
  exact text filtering does not replace acoustic echo cancellation. Verify short
  replies and intentional later repetitions stay visible.


UI validation on 2026-10-08: inspected the packaged native app in dark appearance
with a temporary synthetic meeting. Verified the meeting sidebar, separate
My thoughts / Transcript / Summary tabs, transcript search, the Parakeet v3
selection, and persisted thoughts and action-item edits. Removed the synthetic
meeting afterwards. `swift build`, all 40 Swift tests, and app packaging passed.
Live capture, summary generation, compact-window layout, and the OS checks below
were not exercised in this UI pass.

- [ ] Resize to the minimum window size; all three tabs and recording controls
  stay usable, and the current-note column hides instead of squeezing the list.
  Search notes, open a note, step with the arrows, and return with the back button.
- [ ] Select an installed model in the Notetaker settings menu, start a meeting, and
  confirm the header identifies that model. Missing models must require an
  explicit installation in Models; starting a meeting never downloads them.

- [ ] Close the dashboard and hover over the floating capsule. The meeting button
  appears in its own capsule beside the microphone, with "Start notetaker" on hover.
  Its chevron opens Meetings without starting a recording. Click the record icon: the
  meeting card docks on the right and recording starts. Move the pointer away: the
  single waveform/stop capsule stays visible and stops capture when clicked;
  the microphone and chevron are hidden throughout notetaker capture.
  The green outline appears only during notetaker recording, never during dictation
  or while the notetaker is still starting. While
  finishing or writing notes, a second meeting cannot be started. With an
  uninstalled model selected, the button opens Models with the download message.
- [ ] Start the first meeting on macOS 14.2 or later. macOS asks for system audio
  access with the `NSAudioCaptureUsageDescription` text. Allow it, play a video
  call or any audio, and confirm "Them" transcript entries appear and the Them meter moves.
- [ ] Deny system audio access, start a meeting and talk for 20 seconds. The
  banner shows the call audio hint, and Open Settings opens Screen & System
  Audio Recording. Me transcript entries still appear.
- [ ] Hold a call through headphones, then through the built-in speakers. With
  speakers, note how often the other side's words also appear as "Me" through
  the microphone. Record the result; do not assume either way.
- [ ] Start a meeting on the built-in microphone, then connect AirPods or another
  headset mid-meeting. Both meters keep moving and new Me and Them entries keep
  appearing after the switch.
- [ ] With Microphone set to Automatic, connect and disconnect AirPods and a USB
  mic during a meeting. The card's microphone label follows the macOS default
  input each time, and Me entries keep appearing. Pick a specific mic from the
  card menu mid-meeting; capture switches to it without stopping the meeting.
- [ ] Choose a USB mic in Settings, unplug it, and dictate. Dictation uses the
  macOS default; the picker shows the mic as "(not connected)". Plug it back in
  and it is used again without reselecting.
- [ ] The microphone list in Settings and in the card matches System Settings,
  Sound, Input, and never lists "CADefaultDeviceAggregate" or
  "BetterWispr Meeting Audio", including while a meeting is recording.
- [ ] Start notetaker from the capsule and from the menu bar with another app
  focused. A card docks to the right edge of the current screen without stealing
  focus. The expand button opens the meeting in the dashboard and closes the
  card; deleting the meeting closes the card.
- [ ] Record a meeting of 30 minutes or more. The transcript keeps up within a
  few chunks, memory stays bounded, notes are written, and the meeting file
  reopens after relaunch.
- [ ] Quit BetterWispr from the menu bar mid-meeting. The meeting is kept with
  the segments transcribed so far and a duration, and no
  `betterwispr-meeting-*.caf` files remain in the temporary folder.
- [ ] With Apple Intelligence on, stop a meeting and confirm the summary, key
  points, decisions and action items. Ticking an action item survives relaunch.
  A title you typed before the notes were written is kept.
- [ ] With Apple Intelligence off or unsupported, stop a meeting. The transcript
  and notes are saved, and Generate summary is disabled with the reason shown.
- [ ] Start Notetaker from the dashboard. The card docks beside the call, and the
  dashboard stays on the list instead of showing the live transcript. Stop the
  meeting; the dashboard opens the finished note on its Summary tab.
- [ ] With Ollama running and a model pulled, choose it under Notes model in the
  Notetaker settings menu. Stop a meeting; the title and summary are written by
  that model. Embedding and cloud models are not listed. Quit Ollama and Generate
  summary says Ollama isn't running; Apple Intelligence is never used instead.
- [ ] Disconnect networking, then start, record, stop and summarize a meeting with
  an installed model. Everything works and a network monitor shows no requests.

## Accuracy

- [ ] Follow [the corpus and scoring protocol](accuracy.md). Use consented natural
  speech and human references; do not use synthetic demo text as an app benchmark.
- [ ] Compare raw/normalized WER and CER, entity/number correctness, silence
  hallucinations, rejected speech and correction time on the same held-out clips.
- [ ] Separate language/accent/device groups and latency measurements. Record
  settings and model hashes; do not report another project's paper numbers as
  BetterWispr results.
