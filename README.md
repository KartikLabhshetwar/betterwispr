# BetterWispr

Local-first dictation for macOS. Hold **⌥ Space**, speak, release, and the text
lands in whatever app you were typing in. Speech is transcribed on your Mac by
default; nothing is sent anywhere unless you add an API connection yourself.

[Download the latest release](https://github.com/KartikLabhshetwar/betterwispr/releases/latest) ·
[Website](https://betterwispr.com) · [Changelog](CHANGELOG.md)

## Features

- **Dictate anywhere**: hold-to-talk or press-to-toggle, with a shortcut you choose.
- **On-device models**: Apple speech, Parakeet v3 (25 European languages), Parakeet v2 (English) and Whisper large-v3 turbo.
- **Vocabulary**: spelling hints and phrase replacements for names and jargon.
- **Meetings**: live transcript of you and the other side, plus on-device summaries and action items with Apple Intelligence.
- **History**: raw and corrected transcripts, stored locally (can be turned off).
- **Bring your own model**: optional Sarvam AI, Smallest AI or any OpenAI-compatible endpoint.

## Requirements

- macOS 14 or later
- Apple Silicon recommended

## Getting started

1. Download the DMG from [Releases](https://github.com/KartikLabhshetwar/betterwispr/releases/latest) and drag BetterWispr to Applications.
2. Open it and follow the welcome guide.
3. Pick a model in **Models**. Apple on-device needs no download; Parakeet and Whisper download once, then work offline.
4. Grant **Microphone** access, and **Accessibility** access so BetterWispr can paste for you.
5. Click into a text field in any app, hold **⌥ Space**, speak, and release.

If paste can't safely reach the previous app, the text is copied to your
clipboard instead, so you never lose a dictation. Recordings stop automatically
after two minutes.

## Bring your own model

**Models → Bring your own model → Add connection.** Choose a provider, enter the
model ID and API key, save, then click **Use**.

| Provider | Default model | Notes |
| --- | --- | --- |
| Sarvam AI | `saaras:v4` | Long recordings are sent in 25-second chunks |
| Smallest AI | `pulse` | Set an explicit spoken language in Settings |
| OpenAI-compatible | any | Full URL, e.g. `http://localhost:8000/v1/audio/transcriptions`. HTTPS required except on localhost |

When a connection is in use, your audio goes to that endpoint and its pricing
and retention policies apply. Keys are stored in the macOS Keychain. Switch back
to a built-in model to return to fully local transcription. BetterWispr never
falls back to a cloud provider on its own.

## Privacy

- Settings, vocabulary and history live in `~/Library/Application Support/BetterWispr/workspace.json` (not encrypted).
- Models live in the `Models` folder next to it.
- Audio is written to temporary files and deleted after each recording.
- Built-in models only touch the network when you explicitly download one.

## Troubleshooting

- **Paste stopped working after an update or rebuild**: remove and re-add BetterWispr in System Settings → Privacy & Security → Accessibility.
- **Apple on-device model unavailable**: your language or OS speech assets may not support it. Install Parakeet or Whisper instead.
- **First transcription is slow**: large models take time to load the first time.

## Contributing

Build instructions, project layout and guidelines are in [CONTRIBUTING.md](CONTRIBUTING.md).

## License

[Apache-2.0](LICENSE). Third-party code and model weights keep their own terms;
see [docs/oss-reuse.md](docs/oss-reuse.md).
