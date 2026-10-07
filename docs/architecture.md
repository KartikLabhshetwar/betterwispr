# Architecture and extension points

BetterWispr is one Swift package with a `BetterWispr` macOS executable,
`BetterWisprCore` library and `BetterWisprCLI` developer executable. The app owns
presentation and session coordination. The library owns recording, speech
engines, local storage and delivery to other apps. The CLI reuses the local
Whisper provider for explicit model installation and audio-file transcription.
`BetterWisprCoreTests` checks shared behavior.

This is a native macOS application. Core includes platform frameworks where
needed; it is not a promise of Linux/iOS portability. Feature folders are source
organization, not separate packages or a plugin loader.

```text
Sources/
  BetterWispr/
    App/              Lifecycle, session coordination, global shortcut, capsule and toast panels
    Features/         Dashboard, history, models, vocabulary, settings and capsule UI
    Design/           Small shared view components and the brand mark, which also renders the app icon
  BetterWisprCore/
    Domain/           AppSettings, Transcript and VocabularyEntry value types
    Persistence/      SavedState and atomic local JSON storage
    Audio/            Microphone capture, temporary recordings and level metering
    Speech/           SpeechProvider contract, model catalog, Apple and WhisperKit
    Transcription/    Deterministic, explicit vocabulary replacements
    Integrations/     Clipboard and guarded paste delivery
  BetterWisprCLI/      Developer entry point for model and file smoke tests
```

## Dictation flow

1. A dashboard action or global **Option–Space** starts a session. Capture the
   previously focused external app before showing the nonactivating capsule.
2. Check microphone permission and prepare the selected provider. Model downloads
   are separate user actions, never a side effect of transcription.
3. Record microphone audio locally and publish levels to the capsule. Stopping
   closes the recording before recognition reads it.
4. Pass the recording URL, selected language and vocabulary hints to the provider.
   Provider partial callbacks are provisional text during recognition, not audio
   streaming while capture is still running.
5. Apply user-defined vocabulary substitutions once. Keep both raw and final
   text; save a transcript only when history is enabled.
6. Deliver through clipboard/guarded paste when enabled. Only paste if the
   original destination is still suitable; never treat a changed focus as consent
   to paste elsewhere. With "Copy to clipboard" on, leave the transcript on the
   clipboard. With it off, restore clipboard contents without overwriting newer
   user clipboard changes. Make failed insertion recoverable through copy either way.
7. Remove temporary audio on completion/error/cancellation and return to idle.

Swift UI-facing state and speech-provider methods are isolated to `@MainActor`.
Audio callbacks must not mutate view state unsafely. Cancelled operations must
not publish stale text or paste a result from a prior session. Keep these
invariants when changing the implementation; the manual checklist covers OS
behavior that unit tests cannot establish.

## Add a model

Add an entry to `SpeechModel.catalog` in
[`SpeechProvider.swift`](../Sources/BetterWisprCore/Speech/SpeechProvider.swift).
Use a stable ID, a compatible Core ML model folder name, the correct tokenizer
repository, an honest resource description and `.whisperKit` as its engine. Parakeet
entries use `.parakeet` and a `modelName` that `ParakeetProvider.version(for:)` maps.
Model IDs are persisted, so renaming/removing one requires a fallback or migration.

Verify that the model/tokenizer match before presenting the entry as supported.
Download once, quit the app, disconnect networking, then prepare and transcribe
again. Test cancellation, corrupt/incomplete files and insufficient storage.
Record the model revision/hash, upstream license and evaluation results. A catalog
entry alone is not proof of compatibility or acceptable speed/accuracy.

## Add an STT engine

Implement the existing `@MainActor SpeechProvider` protocol in `Speech/`:

```swift
func prepare(model: SpeechModel, download: Bool) async throws
func transcribe(audioURL: URL, language: String?, vocabulary: [String]) async throws -> String
func cancel()
```

The provider also exposes progress and provisional-text callbacks. Add its
`SpeechEngine` case and instantiate it where the app selects providers. Reuse the
shared recorder, vocabulary processor, history and delivery path. Keep engine
configuration inside its provider rather than branching across SwiftUI views.

`download: false` must load local resources only. `download: true` authorizes an
explicit model setup operation, not future background network use. Validate
files and required tokenizer tokens before marking a model installed. Report
unsupported languages/assets clearly, prevent simultaneous operations, honor
task cancellation and clear callbacks/resources when a session ends. Do not
silently route failures to a cloud service.

The Apple provider requires on-device recognition and uses the current locale
when no language is supplied. WhisperKit uses locally loaded Core ML weights and
tokenizers. Its tokenizer adapter exists because the upstream public loader can
fall back to the network; see [source attribution](oss-reuse.md).

## Add an integration

Put OS/application delivery behavior in `Integrations/` and implement the
existing `TextOutputIntegration.deliver(_:to:)` contract. `ClipboardIntegration`
copies explicitly; `FocusedAppIntegration` checks the captured app's process ID
and sends paste only while it remains frontmost. Otherwise it copies for manual
paste. Its guard tracks the destination app, not the individual text field.
`deliver` returns an `OutputResult` case (`copied`, `copiedForManualPaste` or
`pasted(into:)`); the app maps each case to a toast.

Current destinations share the same final transcript; model inference should not
know which app will receive text. Validate prerequisites and expose errors
through the existing session state. Keep clipboard/focus restoration,
Accessibility checks and cancellation behavior in the shared path. Clipboard
restoration after automated paste uses a bounded delay because arbitrary apps
do not acknowledge receipt; slow recipient apps need explicit manual testing.

Add only the concrete integration and its required settings. Do not introduce
per-app speech providers or duplicate recording code. Any future network
integration must require explicit opt-in and preserve the local default.

## Persistence and boundaries

`SavedState` contains a schema version, settings, vocabulary and transcripts.
`LocalStore` writes atomically to `workspace.json` in the app's Application
Support directory, restricts file permissions and rejects unsupported versions
or malformed JSON. Preserve existing data on decode/migration errors. Schema
changes need a deliberate migration or decoding defaults plus a check using an
older saved file.

Raw audio is temporary; persisted history is text and metadata. History being
disabled does not by itself imply previously saved history was erased. Keep
deletion an explicit action. Model files are managed separately from history.
Do not commit recordings, user transcripts, model binaries, signing material or
local development permission settings.

Keep the core/app boundary until a concrete independent consumer or build-time
problem justifies another library module. Runtime engine implementations and their
configuration are the extension points; a generic plugin system is unnecessary.
