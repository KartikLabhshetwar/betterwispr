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
    App/              Lifecycle, session coordination, global shortcut, capsule and toast panels, updater
    Features/         Dashboard, meetings, history, models, vocabulary, settings and capsule UI
    Design/           Small shared view components and the brand mark, which also renders the app icon
  BetterWisprCore/
    Domain/           AppSettings, DictationShortcut, Transcript, VocabularyEntry and Meeting value types
    Persistence/      SavedState, per-meeting files and atomic local JSON storage
    Audio/            Microphone and system audio capture, temporary recordings and level metering
    Speech/           SpeechProvider contract, model catalog, Apple and WhisperKit
    Transcription/    Deterministic English filler/stutter cleanup and explicit vocabulary replacements
    Notes/            Meeting notes with Apple Intelligence, Ollama, signed-in CLIs and explicit API connections
    Integrations/     Clipboard and guarded paste delivery
  BetterWisprCLI/      Developer entry point for model and file smoke tests
```

## Dictation flow

1. A dashboard action or the global shortcut (**Option–Space** unless changed in
   Settings) starts a session. Capture the previously focused external app before
   showing the nonactivating capsule.
2. Check microphone permission and prepare the selected provider. Model downloads
   are separate user actions, never a side effect of transcription.
3. Record microphone audio locally and publish levels to the capsule. Stopping
   closes the recording before recognition reads it.
4. Pass the recording URL, selected language and vocabulary hints to the provider.
   Provider partial callbacks are provisional text during recognition, not audio
   streaming while capture is still running.
5. Remove English filled pauses and unpunctuated stutters, then apply
   user-defined vocabulary substitutions once. Keep both raw and final text;
   save a transcript only when history is enabled.
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

## Meeting notes flow

`MeetingModel` owns meetings and is separate from dictation. It loads its own
speech provider with `download: false` and releases it when the meeting ends.
The Notetaker page's settings menu exposes the same model and microphone
selection as dictation, plus the notes model; both use `SpeechModel.makeProvider()` with independent
provider instances. The model name is captured when recording starts. The page
lists notes by day beside the current note (the one recording, otherwise the
latest); `MeetingModel.selectedID` opens one full page, and nil returns to the
list. Starting a meeting docks its card beside the call and leaves the dashboard
on the list; the finished note opens there once notes are written. Personal thoughts, the transcript, and the generated summary have separate
tabs backed by the existing meeting fields.

1. Starting a meeting saves an empty `Meeting`, checks microphone permission and
   starts `MeetingRecorder`. The microphone becomes "Me". On macOS 14.2 and later
   a private Core Audio process tap on a private aggregate device records every
   other app as "Them". If the tap fails, the meeting records the microphone only
   and says so.
2. Each source writes 10 to 30 second chunk files to the temporary folder and
   rotates on a pause. Chunks without speech are deleted unread.
3. One serial queue transcribes chunks in order, applies the same cleanup and
   vocabulary as dictation, keeps raw and final text, inserts the segment by start
   time and saves. A failed chunk shows a message and the meeting continues.
4. Stopping closes both sources, transcribes the remaining chunks, then writes
   notes with the explicitly chosen notes model: Apple Intelligence by default,
   local Ollama, Claude Code, Codex, or an OpenAI-compatible chat API. Transcription
   selection remains independent. `NotesWriter` combines the transcript and all
   personal thoughts, condensing long inputs before the final structured summary.
   If condensation still exceeds the budget it reports an error instead of
   truncating the source. Provider failure never selects another engine; the
   transcript, thoughts and previous summary remain saved.
5. Each meeting is one JSON file in `Application Support/BetterWispr/Meetings`.
   Unreadable files are reported and left untouched. Chunk files are deleted after
   transcription, on cancel and at quit, and leftovers are removed at launch.

A session token guards every continuation, so a stopped or quit meeting never
receives a late segment or summary.

`AppSettings.notesSelection` resolves the legacy Ollama choice plus the new optional
CLI or notes-connection selection. Old workspaces decode without changing providers.
`notesConnections` reuses `SpeechConnection` metadata and URL/key validation, with
keys stored under a separate notes Keychain service. API generation uses ephemeral
sessions, rejects redirects and checks both HTTP status and completion status.
Any model ID is accepted if the selected server supports OpenAI-compatible chat
completions and JSON-object output. Saving a connection makes no request; selecting
it explicitly enables sending transcript and thoughts. Keys are never inferred
from a speech connection or moved to an edited destination.

Claude Code uses `claude --print` and its existing Claude subscription sign-in;
Codex uses `codex exec` with ChatGPT authentication required. BetterWispr does not
extract OAuth tokens. These CLI routes strip inherited provider/key environment
variables, run in a private temporary directory, disable tools/customizations as
supported by each CLI, and disable session persistence. Codex also uses read-only
sandboxing. A timeout or cancellation terminates the child and removes temporary
input/output files. Install/update and sign in to the CLIs separately. Subscription
limits and model access remain the provider's responsibility. Models discovers
Claude's model catalog through its stream-JSON initialize response and Codex's
through app-server `model/list`, including pagination. Claude aliases resolve to
exact IDs; an empty legacy choice is pinned to the reported account default.
Refresh never replaces an explicit model choice. Users can also enter an exact ID
when discovery fails or a new model is available. Generation passes that ID with
`--model`, and Claude's reported model usage is recorded in the saved summary.
Models also exposes notes API endpoints and a cancellable synthetic sample test.
CLI flags were verified against the locally installed help and
[Claude's CLI reference](https://code.claude.com/docs/en/cli-reference),
[Codex non-interactive mode](https://learn.chatgpt.com/docs/non-interactive-mode)
and [Codex configuration](https://learn.chatgpt.com/docs/config-file/config-reference).
Model discovery follows [Claude's model configuration](https://code.claude.com/docs/en/model-config)
and [Codex's app-server protocol](https://learn.chatgpt.com/docs/app-server).
The API format follows [Chat Completions](https://developers.openai.com/api/reference/resources/chat/subresources/completions/methods/create).

Summaries record their provider label and a digest of the transcript plus thoughts
used to generate them. Editing thoughts marks an existing summary as needing an
update, including edits made while generation is running. “Update summary” on both
My thoughts and Summary regenerates from both sources using the selected model.
Older summaries without these optional fields remain readable and can be updated.

`MeetingTranscript.removingEchoes` hides matching microphone/system-audio phrases
of at least eight words within a 30-second capture window. It runs for transcript
display, copying/export and summary input, while original segments and raw text stay
on disk. “Show repeated microphone audio” reveals those segments. This is conservative
text matching, not acoustic echo cancellation: different recognition, mixed speech
or different chunk boundaries can still produce echoes, and an intentional long
verbatim repetition inside that window can be hidden. Short replies and later
repetitions are retained. Speaker playback can also affect system-tap timestamps;
those timestamps are capture-chunk offsets, not word-level alignment.


Starting a meeting from the capsule or the menu bar docks a floating card
(`NotetakerController`) to the right edge of the screen under the pointer. It
hosts the same `MeetingDetailView` as the dashboard, closes when its meeting is
deleted, and its expand button opens the meeting in the dashboard instead.

## Microphone selection

`AudioInputs` lists Core Audio devices with an input stream, keyed by UID, and
skips private aggregate devices (Core Audio's per-process default aggregate and
BetterWispr's system audio tap). `AppSettings.microphone` is the saved choice;
nil means Automatic and follows the macOS default input. A chosen microphone is
used only while it is connected, otherwise the macOS default is used; there is
no other fallback. Dictation and meetings both route a fresh `AVAudioEngine`
input to the resolved device before reading its format.

`AudioInputObserver` reports connects, disconnects and default-input changes,
debounced on the main actor. The settings picker and the meeting card's
microphone menu refresh from it. During a meeting, `MeetingRecorder` rebuilds
its microphone engine when the resolved device changes or the engine has
stopped, closing the current "Me" chunk first so offsets stay continuous. A
configuration change on a running engine bound to the same device is ignored,
because every fresh engine posts one as it binds its input; rebuilding on it
loops and leaves only sub-second chunks that are dropped as silence. A dictation already in progress keeps its device until it ends.

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

For built-in engines, `download: false` must load local resources only. `download: true` authorizes an
explicit model setup operation, not future background network use. Validate
files and required tokenizer tokens before marking a model installed. Report
unsupported languages/assets clearly, prevent simultaneous operations, honor
task cancellation and clear callbacks/resources when a session ends. Do not
silently route failures to a cloud service.

### User-configured API connections

`SpeechConnection` metadata lives in `AppSettings.speechConnections`; old saved
settings decode with an empty list. The built-in catalog stays static and local.
`AppModel.models` adds each saved connection as a selectable `.api` speech model.
`SpeechModel.makeProvider()` is shared by dictation and meetings.

`APISpeechProvider.prepare` validates configuration and Keychain access without
network requests. Only transcription through a selected connection uploads audio.
It reuses WhisperKit's audio conversion to produce 16 kHz mono PCM WAV in memory,
off the main actor. Sarvam receives sequential 25-second clips; other APIs receive
the bounded dictation/meeting clip. Fixed cuts can affect words at boundaries.
No partial transcript is delivered on failure. Cancellation stops URLSession
requests; callers retain their generation checks before history and paste.

Sarvam uses multipart uploads and `api-subscription-key`; Smallest uses binary WAV
with Bearer authentication; custom endpoints use OpenAI-compatible multipart and
JSON `text` responses. Smallest requires an explicit spoken language. New model
IDs are editable without a catalog update if they retain the provider's wire
format. Other formats need a concrete adapter, not a generic plugin system.

Keys are stored as nonsynchronizing, device-only Keychain items bound to connection
ID, API format and full endpoint. Connection edits cannot reuse a key at a different
URL. Requests use ephemeral sessions without cookies, cached credentials or disk
cache. HTTPS is required except for literal loopback destinations; every redirect
is rejected. Provider response bodies are not included in errors. Vocabulary
substitution remains local and hints are not uploaded. External providers control
their own audio retention; local history settings do not control that retention.

Wire formats checked against [Sarvam REST](https://docs.sarvam.ai/api-reference/speech-to-text/transcribe),
[Smallest pre-recorded STT](https://docs.smallest.ai/models/speech-to-text/pre-recorded/quickstart),
and [OpenAI transcription](https://developers.openai.com/api/reference/resources/audio/subresources/transcriptions/methods/create).
Automated tests use synthetic audio and stub responses; live provider acceptance
requires the user's own account and credentials.

The Apple provider requires on-device recognition and uses the current locale
when no language is supplied. WhisperKit uses locally loaded Core ML weights and
tokenizers. Its tokenizer adapter exists because the upstream public loader can
fall back to the network; see [source attribution](oss-reuse.md).

Parakeet's optional phrase booster is FluidAudio's CTC word-spotting model. It
downloads only from the Vocabulary page or `--download-phrase-booster`, into
FluidAudio's shared cache (`CtcModels.defaultCacheDirectory(for: .ctc110m)`),
because FluidAudio reads the booster's tokenizer from that fixed folder. A
`.betterwispr-installed` marker is written after the files load. `prepare`
loads an installed booster with `CtcModels.loadDirect` and never downloads it;
a missing or broken booster leaves plain Parakeet transcription unchanged.
`transcribe` boosts only English or automatic-language dictation with a
non-empty vocabulary and keeps the decoder's text when rescoring changes nothing.

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

## Updates

`AppUpdater` wraps Sparkle's standard updater and is owned by `AppModel`. Sparkle
reads `appcast.xml` from the latest GitHub release (`SUFeedURL`) and installs an
update only when its EdDSA signature matches `SUPublicEDKey`. Its network use is
limited to update checks and downloads. Automatic checks are opt-in: Sparkle
asks on the second launch, and Settings can change automatic checks and
automatic installs at any time. Update requests carry no audio, transcripts or
vocabulary, and system profiling stays off. Sparkle keeps these preferences in
its own user defaults, not in `SavedState`. `scripts/release.sh` signs the DMG
with the private key in the login keychain and writes the appcast.

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
