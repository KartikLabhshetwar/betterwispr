# Changelog

All notable changes to BetterWispr are listed here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and the project uses
[Semantic Versioning](https://semver.org/). The current version lives in `VERSION`.

## [0.1.0] - 2026-10-08

### Added
- Meeting notes and titles with Ollama. Choose an installed Ollama model under Notes model in the Notetaker settings menu, and BetterWispr writes the title, summary, key points, decisions and action items with it on this Mac. Apple Intelligence stays the default, BetterWispr never switches models on its own, and cloud and embedding models are not offered.
- Voice commands for English and Auto language: "comma", "question mark", "full stop", "add a period", "new line", "new paragraph", "scratch that" and "sorry, remove that" delete the last sentence, and "at the rate KV" or "at sign KV" types "@KV". Commands are rule-based and run on your Mac.
- Learn from corrections: fix a misheard word in History with the pencil, or in the text field within 30 seconds of a paste, and BetterWispr adds it to Vocabulary with a Learned badge and a toast. Turn it off in Settings.
- Native macOS dictation app with a global ⌥ Space shortcut, paste into the focused app and transcript history.
- Local speech models: Apple speech, Parakeet TDT v3 (25 European languages) and v2 (English) through FluidAudio, and Whisper large-v3 turbo through WhisperKit.
- Compact recording overlay with an idle pill, a hover tooltip showing the chosen shortcut and a dictate button.
- Three-step welcome guide on first launch: intro, permissions, model and first dictation. Replay it from the menu bar.
- Personal vocabulary with spelling hints and whole-phrase replacements, plus local model management.
- Optional local phrase booster for Parakeet vocabulary. Download it explicitly from the Vocabulary page to help recognize names and technical terms. The English-only booster runs with English or automatic language selection, preserves punctuation around replaced words, and loads installed assets offline.
- Hold-to-talk dictation, now the default: hold ⌥ Space while speaking and release to finish. "Press to toggle" keeps the previous behavior and is set in Settings.
- Change the dictation shortcut in Settings. Click the shortcut, press a new combination that includes ⌘, ⌥ or ⌃ or an F-key such as F5, or reset it to ⌥ Space. The recorder shows the keys you hold and says why a key it refuses can’t be used. Hints, menus and error cards show the shortcut you chose.
- "Copy to clipboard" setting, off by default. When on, each dictation stays on the clipboard after it is pasted. When off, BetterWispr restores the previous clipboard, and with paste also off it leaves the clipboard alone. A blocked paste still copies so the text is never lost.
- Settings for spoken language, input sensitivity, automatic paste, local transcript history, the floating capsule and opening at login.
- Error card above the capsule with a shake and red outline for taps, early releases, missing speech, blocked paste and other failures. It dismisses itself after six seconds and respects Reduce Motion.
- Toast confirmations for copy and delete, adapted from BetterShot's toast panel.
- Menu bar icon switches to a microphone while recording.
- App icon and in-app logo: a hand-drawn "w" on a light tile, shown on a dark tile in Dark Mode. `scripts/build-app.sh` renders the icon from the same SwiftUI view.
- Dedicated About page with the app logo, version, source code and issue links, and the author's X profile.
- In-app updates from GitHub Releases through Sparkle 2. Check from About or the app menu, and choose whether BetterWispr checks daily and installs new versions on its own. Updates install only when their EdDSA signature matches the app's public key.
- Meeting notes. Start a meeting from the Meetings page or the menu bar to record your microphone as "Me" and other apps' audio as "Them" (macOS 14.2 or later), follow a live transcript, and write your own notes. When it ends, Apple Intelligence on a supported Mac running macOS 26 or later writes a summary, key points, decisions and action items locally. Without Apple Intelligence the transcript and your notes are still saved. Search saved meetings, mark action items complete and copy meeting notes and transcripts as Markdown. Audio never leaves the Mac.
- Website with a typing and dictation demo, feature overview, comparison pages, download links, privacy and terms pages, and a dedicated changelog rendered from this file. Pages include static content and social previews.
- `BetterWisprCLI` for local model downloads and file transcription, defaulting to `parakeet-v3`. Pass comma-separated spelling hints with `--vocabulary` or explicitly install the Parakeet booster with `--download-phrase-booster`.
- Local transcript evaluation script reporting word error rate, character error rate and false speech on silent clips, with an accuracy evaluation plan.
- `make dev` for local testing and `make ship` for a signed, notarized DMG and Sparkle update feed.
- `VERSION` file and this changelog. The app bundle version is stamped from `VERSION` at build time.

### Changed
- Start Notetaker on the dashboard now docks the meeting card beside your call, the same as starting from the capsule or the menu bar.
- The dashboard no longer opens the live transcript while you record. It keeps the list of notes and opens the finished note once recording and notes are done.
- The app bundle's `CFBundleVersion` now follows `VERSION` instead of a fixed `1`, so Sparkle can tell releases apart.
- The capsule no longer shows the recognized text above the waveform while you dictate or while it transcribes.
- A successful paste no longer shows a "Pasted" toast. Copy-only results still confirm with a toast.
- Recording capsule redesign. Holding ⌥ Space shows only a waveform. In toggle mode the capsule shows cancel, the waveform and a stop mark, and a click anywhere on it finishes dictation. A failed session collapses back to the idle pill with a red outline under the error card.
- Waveform that fits your voice. It learns the room's noise floor and your recent loudness, so quiet voices fill the bars and steady background noise stays flat. Bars rise fast and fall slowly, follow the voice in steps of about 20 ms instead of jumping with each 100 ms audio buffer, and a travelling wave shows while transcribing. Reduce Motion keeps the bars still.

### Fixed
- An open note now switches to its Summary tab as soon as the notes are written, instead of staying on the transcript.
- Paste into other apps stopped after every rebuild because ad-hoc signing changed the app's code requirement and macOS revoked Accessibility. `scripts/build-app.sh` now signs with a stable identity, and a blocked paste shows an Allow button instead of silently copying.
- English transcript cleanup removes "uh", "um", "er", "hmm", "mm" and their supported spellings, set-off "you know", and unpunctuated back-to-back repeats such as "which you which you" before vocabulary replacements. It preserves "mm" after a numeric value, "you know?", punctuated repeats, numbers and common doubles such as "that that" and "long long". Language detection ignores fillers; other languages are left as spoken, and history keeps the raw recognizer output.
