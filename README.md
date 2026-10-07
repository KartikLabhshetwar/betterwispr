# BetterWispr

A local-first, open-source macOS dictation app. Press **Option–Space**, speak,
then press it again to transcribe and insert text into your previous app. A small
capsule sits at the bottom center of the screen while recording; the dashboard
holds transcripts, model selection, vocabulary and preferences.

BetterWispr uses Apple on-device speech recognition or Whisper through
WhisperKit. Audio is processed on your Mac. There is no account, API key or cloud
transcription fallback. Whisper models and tokenizers require an explicit first
download; installed models can then be loaded offline.

## Build and run

Requirements: macOS 14 or later, a Swift 6.2+ toolchain, and Xcode/Command Line
Tools with the macOS SDK. Apple Silicon is recommended for Whisper inference.
The Swift package pins Argmax OSS / WhisperKit to **1.1.0**. Building dependencies
for the first time requires an internet connection.

```sh
swift build
swift test
./scripts/build-app.sh
./scripts/run.sh
```

Or use `make`: `make dev` builds, runs every check and launches the debug app.
`make ship` builds, signs with Developer ID, notarizes and staples
`release/BetterWispr-<version>_arm64.dmg`. `make help` lists every target.

The development app bundle is `.build/debug/BetterWispr.app`. Launch the bundle
using the run script so macOS can associate its microphone/speech usage
descriptions and permissions with the app. A Swift package build alone is not a
signed/notarized distribution release.

## First run

1. Open the dashboard and select a speech model. **Apple on-device** needs Speech
   Recognition permission and a supported on-device language/OS asset. Its
   automatic language option uses your system locale. If unavailable, install a
   Whisper model instead; BetterWispr does not fall back to Apple's servers.
2. For Whisper, explicitly download a model in **Models** and wait for preparation
   to complete. Tiny is a lightweight smoke-test option with lower accuracy;
   Small uses fewer resources than Large v3 Turbo and Large v3. The best choice
   depends on your Mac, language and speech.
3. Allow **Microphone** access when starting a recording. Allow **Accessibility**
   access if you want automatic insertion into other apps. Permissions can be
   changed in System Settings → Privacy & Security.
4. Focus a text field in another app. Hold **Option–Space** while you speak and
   release it to finish. Choose **Press to toggle** in Settings to press once to
   start and again to finish instead. The capsule shows microphone activity while capturing and processing
   state while transcribing. Recognition starts after recording stops; this
   version does not display continuously decoded words during capture.
5. If automatic paste cannot safely target the previous app, copy the result
   from the dashboard. Vocabulary entries can supply decoder hints and explicit
   phrase replacements; the original transcript remains available in history.

A recording finishes automatically after two minutes; start another session to
continue. In hold mode, a quick tap or a release before the microphone is ready
discards the session and shows a hint instead of pasting.

`scripts/build-app.sh` signs with the first code-signing identity in your
keychain, or `CODESIGN_IDENTITY` when set. Ad-hoc signing is the fallback, and
macOS then revokes Accessibility after every rebuild, so paste falls back to copy.

Apple speech support varies by locale and installed OS assets. Whisper loading
and first inference may take time, especially with large models. A missing model
or unavailable local speech engine produces an error rather than a network
fallback. Recognition quality has not yet been benchmarked for BetterWispr;
[the accuracy plan](docs/accuracy.md) explains how to measure it.

## Local data

Settings, vocabulary and optional transcript history are stored in
`~/Library/Application Support/BetterWispr/workspace.json`. History includes raw
and corrected text and is enabled by default; turn it off in preferences if you
do not want subsequent transcripts saved. This JSON is not encrypted by the app.
Downloaded models/tokenizers live in the `Models` folder under the same directory.

Recording files are temporary and removed after normal completion or cancellation.
The app does not intentionally retain an audio archive. Force termination and
system crashes should be included in privacy verification. See
[the manual checklist](docs/testing.md) for offline, clipboard and permission tests.

## Development

```text
Sources/BetterWispr/       App composition, SwiftUI features and design components
Sources/BetterWisprCore/   Audio, speech providers, integrations, persistence and domain
Sources/BetterWisprCLI/    Local model installation and audio-file smoke tests
Tests/                    Swift checks and Python evaluation checks
scripts/                  App packaging, launch and transcript evaluation
docs/                     Architecture, accuracy, testing and source provenance
.agents/skills/           Imported macOS/Swift/design development skills
.claude/skills/           Matching BetterShot skill snapshot for Claude tooling
```

See [architecture and extension points](docs/architecture.md) for adding a model
or integration, and [AGENTS.md](AGENTS.md) for repository working rules. All six
BetterShot skill families were copied with their existing references and assets;
[the import record](docs/skills.md) identifies their source and scope.

Score your own reference/hypothesis JSONL pairs without extra Python dependencies:

```sh
python3 scripts/evaluate_transcripts.py /path/to/pairs.jsonl
python3 Tests/evaluate_check.py
```

The development CLI exercises local models without opening the dashboard:

```sh
swift run BetterWisprCLI --list-models
swift run BetterWisprCLI --download-model parakeet-v3
swift run BetterWisprCLI --transcribe-file /path/to/audio.wav --model parakeet-v3 --language en
```

Only the explicit download command installs assets. File transcription requires
the chosen model to be installed already. Apple speech remains an app workflow
because it depends on macOS permission handling.

## License

Original BetterWispr code is [Apache-2.0](LICENSE). Third-party code and model
weights retain their respective terms. [OSS reuse and attribution](docs/oss-reuse.md)
records the WhisperKit tokenizer adaptation, FluidAudio and Parakeet terms,
reviewed alternatives and retained licenses.
