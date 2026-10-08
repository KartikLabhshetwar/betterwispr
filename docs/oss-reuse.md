# Open-source provenance

Reviewed 2026-10-08. BetterWispr's original code remains Apache-2.0. Third-party
components retain their own licenses; model weights have separate terms from
their inference engines.

## Code actually adapted

`Sources/BetterWisprCore/Speech/LocalWhisperTokenizer.swift` adapts the
`WhisperTokenizer` implementation from
[`Sources/WhisperKit/Core/Models.swift`](https://github.com/argmaxinc/argmax-oss-swift/blob/1e2a163736dfa5a198e637ae44c114e1c6d5cc2d/Sources/WhisperKit/Core/Models.swift#L1165),
Argmax OSS v1.1.0, revision `1e2a163736dfa5a198e637ae44c114e1c6d5cc2d`.
The upstream MIT license and copyright 2024 argmax, inc. are retained in the
adapted source. Changes accept a locally loaded `TokenizerWrapper`, validate
required tokens and handle Unicode scalar offsets safely while preserving the
upstream language-aware word grouping. The adaptation is needed because the
upstream initializer is internal and its convenience tokenizer loader may fall
back to a network request. BetterWispr injects a tokenizer constructed from local
files before model loading; it does not use that network fallback during dictation.

`Sources/BetterWisprCore/Speech/ParakeetProvider.swift` uses
[FluidAudio](https://github.com/FluidInference/FluidAudio) 0.17.5 (Apache-2.0)
as a SwiftPM dependency to run NVIDIA Parakeet TDT on the Neural Engine. No
FluidAudio source is copied. Models load with `AsrModels.loadLocal`, which never
fetches missing files; downloads only run from an explicit model installation.

`Sources/BetterWispr/App/AppUpdater.swift` uses
[Sparkle](https://github.com/sparkle-project/Sparkle) 2.10.0 (MIT) as a SwiftPM
dependency for in-app updates. No Sparkle source is copied; its license ships in
the app bundle. `scripts/build-app.sh` removes Sparkle's XPC services because
they exist only for sandboxed apps and BetterWispr is not sandboxed.

`Sources/BetterWispr/App/ToastWindow.swift` adapts `ToastWindow` and its glass
surface from BetterShot (`Sources/Views/ToastWindow.swift` and
`Sources/Views/GlassSurface.swift`), BSD-3-Clause, copyright 2026 Kartik
Labhshetwar, the same author as BetterWispr. Changes take a typed `Toast`, ignore
mouse events, announce the toast to VoiceOver and use an opaque surface before
macOS 26.

`Sources/BetterWisprCore/Audio/SystemAudioTap.swift` adapts the Core Audio
process tap from Muesli's
[`CoreAudioSystemRecorder.swift`](https://github.com/Muesli-HQ/muesli/blob/d9ef2ace6f0eca41dd76302a32ea57d4ca65a4ce/native/MuesliNative/Sources/MuesliNativeApp/CoreAudioSystemRecorder.swift)
(MIT, copyright 2026 Pranav Hari) and AudioCap's
[`AudioCap/ProcessTap/ProcessTap.swift`](https://github.com/insidegui/AudioCap/blob/6f609e8ad1b1e11fa0e8edbe91864cb099f00de3/AudioCap/ProcessTap/ProcessTap.swift)
(BSD-2-Clause, copyright 2024 Guilherme Rambo), revision
`6f609e8ad1b1e11fa0e8edbe91864cb099f00de3`. Both notices are retained in the
adapted source. The adapted parts are the global tap description, the private
aggregate device that carries the tap, reading `kAudioTapPropertyFormat`, the
IOProc block and the teardown order. The tap excludes BetterWispr's own process
and leaves other apps audible. The tap and the aggregate device are private, and
the device gets a fresh UID for each meeting. Reading the tap format retries
briefly, the IOProc hands each buffer to the meeting chunk writer without
copying, and a tap failure leaves the meeting recording the microphone only.

`betterwispr-frontend/apps/web/src/components/apple-logo.tsx` copies the Apple
logo path from [Simple Icons](https://github.com/simple-icons/simple-icons)
16.34.0 (CC0-1.0). The logo is a trademark of Apple Inc. and only labels the
Download for macOS buttons.

`betterwispr-frontend/apps/web/src/components/github-stars.tsx` adapts
[Chánh Đại's GitHub Stars](https://chanhdai.com/components/github-stars),
installed with `npx shadcn@latest add @ncdai/github-stars`. The upstream MIT
license and copyright 2026 Chánh Đại are retained in the source and deployed
with the site at `/licenses/github-stars.txt`. Changes use
the existing shared UI imports, supply the tooltip provider and add an
accessible link label and singular-star wording. The existing GitHub action
supplies BetterWispr's live count to the new compact header variant and retains
a link when that count is unavailable. The hero keeps its original appearance.

`betterwispr-frontend/apps/web/src/components/ui/cards.tsx` and `demo.tsx`
adapt the card and two-row marquee snippets supplied in the integration request.
The request did not include an upstream source page or license notice. Changes
use the existing site typography, Lucide icons, typed X post data, source links,
empty-list hiding, pause controls and reduced-motion support. Sample quotes and
Unsplash portraits appear only in the explicitly labeled demo, not as endorsements.

## Runtime engines and alternatives reviewed

| Project | Upstream terms | Use in this project / useful pattern |
| --- | --- | --- |
| [WhisperKit / Argmax OSS](https://github.com/argmaxinc/argmax-oss-swift) | [MIT](https://github.com/argmaxinc/argmax-oss-swift/blob/main/LICENSE); bundled third-party notices also apply | Native Swift on-device inference; use the OSS library rather than copying an entire app. The old WhisperKit repository URL redirects here. Argmax Pro is a separate product and is not included. |
| [FluidAudio](https://github.com/FluidInference/FluidAudio) | [Apache-2.0](https://github.com/FluidInference/FluidAudio/blob/main/LICENSE) | Core ML Parakeet TDT inference, used for the Parakeet models. |
| [whisper.cpp](https://github.com/ggml-org/whisper.cpp) | [MIT](https://github.com/ggml-org/whisper.cpp/blob/master/LICENSE) | Local C/C++ inference and CLI integration; useful for a separately installed local engine and GGML models. |
| [Handy](https://github.com/cjpais/Handy) | [MIT](https://github.com/cjpais/Handy/blob/afe5a6310534ffb178794365f31abb8b9fd435a7/LICENSE) | Reviewed its separation of recording, model management and transcription. Its [VAD smoother](https://github.com/cjpais/Handy/blob/afe5a6310534ffb178794365f31abb8b9fd435a7/src-tauri/src/audio_toolkit/vad/smoothed.rs) buffers speech onset and trailing frames. No Handy source is vendored by this research task. |
| [VoiceInk](https://github.com/Beingpax/VoiceInk) | [GPL-3.0](https://github.com/Beingpax/VoiceInk/blob/main/LICENSE) | Product/reference research only. No source copied into this Apache-2.0 application. |
| [Muesli](https://github.com/Muesli-HQ/muesli) | MIT | Native meeting recorder. Its Core Audio system recorder is adapted for meeting notes, as described above. |
| [AudioCap](https://github.com/insidegui/AudioCap) | BSD-2-Clause | Minimal process tap sample. Its tap and aggregate device setup is adapted for meeting notes, as described above. |
| [OpenOats](https://github.com/yazinsai/OpenOats) | MIT | Reviewed for labelling the microphone as Me and system audio as Them. No source copied. |
| [Recap](https://github.com/RecapAI/Recap) | MIT | Native meeting summaries reviewed for product shape. No source copied. |
| [anarlog (formerly Hyprnote)](https://github.com/fastrepl/anarlog) | MIT | Rust meeting notes app, reference only. No source copied. |
| [Meetily](https://github.com/Zackriya-Solutions/meetily) | MIT | Rust meeting minutes app, reference only. No source copied. |

The research table is not the dependency lock file: the actual compiled versions
are recorded in `Package.swift` and `Package.resolved`, and a separately installed
CLI has its own version. Keep upstream license files and notices in packaged
releases when distributing those dependencies. A model installation needs its
own model ID, version/hash and license record.

Whisper's released code and weights use [MIT](https://github.com/openai/whisper/blob/main/LICENSE).
[NVIDIA Parakeet TDT 0.6B v3](https://huggingface.co/nvidia/parakeet-tdt-0.6b-v3)
and [v2](https://huggingface.co/nvidia/parakeet-tdt-0.6b-v2) weights use CC-BY-4.0
according to the publisher's model cards. BetterWispr downloads the
[FluidInference Core ML conversions](https://huggingface.co/FluidInference/parakeet-tdt-0.6b-v3-coreml),
which keep that attribution obligation. The optional Parakeet phrase booster
downloads [FluidInference/parakeet-ctc-110m-coreml](https://huggingface.co/FluidInference/parakeet-ctc-110m-coreml),
a conversion of [nvidia/parakeet-tdt_ctc-110m](https://huggingface.co/nvidia/parakeet-tdt_ctc-110m)
that its model card lists as CC-BY-4.0. Do not infer weight terms
from an ONNX/Core ML/MLX conversion library's license.

The copied BetterShot development skills have separate provenance documented in
[`skills.md`](skills.md).
