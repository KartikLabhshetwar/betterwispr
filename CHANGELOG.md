# Changelog

All notable changes to BetterWispr are listed here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and the project uses
[Semantic Versioning](https://semver.org/). The current version lives in `VERSION`.

## [Unreleased]

### Added
- Hold-to-talk dictation, now the default: hold ⌥ Space while speaking and release to finish. "Press to toggle" keeps the previous behavior and is set in Settings.
- "Copy to clipboard" setting, on by default. When on, each dictation stays on the clipboard after it is pasted. When off, BetterWispr restores the previous clipboard, and with paste also off it leaves the clipboard alone. A blocked paste still copies so the text is never lost.
- Error card above the capsule with a shake and red outline for taps, early releases, missing speech, blocked paste and other failures. It dismisses itself after six seconds and respects Reduce Motion.
- About section at the bottom of Settings with the app logo, version, a link to the source code and the author's X profile.
- In-app updates from GitHub Releases through Sparkle 2. Check from Settings or the app menu, and choose whether BetterWispr checks daily and installs new versions on its own. Updates install only when their EdDSA signature matches the app's public key.
- Meeting notes. Start a meeting from the Meetings page or the menu bar to record your microphone as "Me" and other apps' audio as "Them" (macOS 14.2 or later), follow a live transcript, and write your own notes. When it ends, Apple Intelligence writes a summary, key points, decisions and action items on this Mac. Without Apple Intelligence the transcript and your notes are still saved. Audio never leaves the Mac.

### Changed
- The app bundle's `CFBundleVersion` now follows `VERSION` instead of a fixed `1`, so Sparkle can tell releases apart.
- The capsule no longer shows the recognized text above the waveform while you dictate or while it transcribes.
- A successful paste no longer shows a "Pasted" toast. Copy-only results still confirm with a toast.
- Recording capsule redesign. Holding ⌥ Space shows only a waveform. In toggle mode the capsule shows cancel, the waveform and a stop mark, and a click anywhere on it finishes dictation. A failed session collapses back to the idle pill with a red outline under the error card.
- Waveform that fits your voice. It learns the room's noise floor and your recent loudness, so quiet voices fill the bars and steady background noise stays flat. Bars rise fast and fall slowly, follow the voice in steps of about 20 ms instead of jumping with each 100 ms audio buffer, and a travelling wave shows while transcribing. Reduce Motion keeps the bars still.

### Fixed
- Paste into other apps stopped after every rebuild because ad-hoc signing changed the app's code requirement and macOS revoked Accessibility. `scripts/build-app.sh` now signs with a stable identity, and a blocked paste shows an Allow button instead of silently copying.
- Dictation no longer pastes filler words or stutters. English "uh", "um", "er" and "hmm" and back-to-back repeats such as "which you which you" are removed before vocabulary replacements. Comma-separated repeats, numbers and common doubles such as "that that" and "long long" are kept, other languages are left as spoken, and history keeps the raw recognizer output.

## [0.1.0] - 2026-10-08

### Added
- Native macOS dictation app with a global ⌥ Space shortcut, paste into the focused app and transcript history.
- Local speech models: Apple speech, Parakeet TDT v3 (25 European languages) and v2 (English) through FluidAudio, and Whisper large-v3 turbo through WhisperKit.
- Compact recording overlay: idle pill, "Dictate ⌥ Space" hover tooltip with a dictate button, live waveform with cancel and finish buttons.
- Three-step welcome guide on first launch: intro, permissions, model and first dictation. Replay it from the menu bar.
- Personal vocabulary and local model management.
- Toast confirmations for copy, paste and delete, adapted from BetterShot's toast panel.
- Menu bar icon switches to a microphone while recording.
- App icon and in-app logo: a hand-drawn "w" on a light tile, shown on a dark tile in Dark Mode. `scripts/build-app.sh` renders the icon from the same SwiftUI view.
- `BetterWisprCLI` for local model downloads and file transcription, defaulting to `parakeet-v3`.
- `make dev` for local testing and `make ship` for a signed, notarized DMG.
- `VERSION` file and this changelog. The app bundle version is stamped from `VERSION` at build time.
