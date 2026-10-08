# Working on BetterWispr

Native macOS 14+ dictation app; Swift 6.2+, SwiftUI/AppKit, Swift Package Manager.
`BetterWispr` owns app composition, feature views and design components.
`BetterWisprCore` owns domain types, persistence, audio, speech providers,
transcription and OS integrations. `BetterWisprCLI` reuses its Whisper provider
for file/model smoke tests. See `docs/architecture.md` before reorganizing.

- Read the affected flow and callers before editing. Reuse the existing recorder,
  `SpeechProvider`, catalog, store and delivery path. Keep changes concrete; add
  modules or abstractions only for demonstrated needs.
- Keep built-in transcription local-only and the default. API connections require
  explicit user selection; never use one as a fallback. Keep API keys in Keychain.
  Download models/tokenizers only after an
  explicit model installation action; cached-model loading must never silently
  access the network or fall back to cloud recognition.
- Preserve microphone/speech/Accessibility checks, app-focus and clipboard
  safeguards, cancellation and audio cleanup. Never paste a stale session result.
- Keep UI state on the main actor. Do not block audio callbacks or bypass Swift
  concurrency diagnostics with unchecked annotations without a documented reason.
- Keep raw and corrected transcripts distinct. Preserve corrupt/unsupported saved
  data, add migrations for persistent schema changes, and do not invent accuracy
  claims, benchmark numbers or successful manual test results.
- Do not commit models, recordings, private transcripts, keys or signing assets.
  Retain upstream licenses and record adapted code in `docs/oss-reuse.md`.

## Skills

Imported skills are in `.agents/skills/` and `.claude/skills/`; their provenance
is in `docs/skills.md`. For relevant native changes, read
`.agents/skills/macos-development/SKILL.md`, then only the needed submodules.
Use `.agents/skills/write-swift/SKILL.md` for Swift work and
`.agents/skills/apple-design/SKILL.md` for native UI. Skills are guidance; check
suggested APIs against the actual deployment target and available compiler.
Keep BetterShot-specific screenshot behavior out of this app.

## Verification

Run `swift build` and `swift test` for Swift changes. Run
`python3 Tests/evaluate_check.py` when changing evaluation/normalization.
`./scripts/build-app.sh` creates `.build/debug/BetterWispr.app`;
`./scripts/run.sh` launches the bundle. Follow `docs/testing.md` for permission,
microphone, global shortcut, paste, cancellation and offline model checks.
Distinguish automated checks from OS behavior that has not been exercised.
