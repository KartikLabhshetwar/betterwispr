# Changelog

All notable changes to BetterWispr are listed here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and the project uses
[Semantic Versioning](https://semver.org/). The current version lives in `VERSION`.

## [Unreleased]

### Added
- Hold-to-talk dictation, now the default: hold ⌥ Space while speaking and release to finish. "Press to toggle" keeps the previous behavior and is set in Settings.
- "Copy to clipboard" setting, on by default. When on, each dictation stays on the clipboard after it is pasted. When off, BetterWispr restores the previous clipboard, and with paste also off it leaves the clipboard alone. A blocked paste still copies so the text is never lost.
- Error card above the capsule with a shake and red outline for taps, early releases, missing speech, blocked paste and other failures. It dismisses itself after six seconds and respects Reduce Motion.

### Changed
- The capsule no longer shows the recognized text above the waveform while you dictate or while it transcribes.
- Recording capsule redesign. Holding ⌥ Space shows only a waveform. In toggle mode the capsule shows cancel, the waveform and a stop mark, and a click anywhere on it finishes dictation. A failed session collapses back to the idle pill with a red outline under the error card.
- Waveform that fits your voice. It learns the room's noise floor and your recent loudness, so quiet voices fill the bars and steady background noise stays flat. Bars rise fast and fall slowly, and a travelling wave shows while transcribing. Reduce Motion keeps the bars still.

### Fixed
- Paste into other apps stopped after every rebuild because ad-hoc signing changed the app's code requirement and macOS revoked Accessibility. `scripts/build-app.sh` now signs with a stable identity, and a blocked paste shows an Allow button instead of silently copying.

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
