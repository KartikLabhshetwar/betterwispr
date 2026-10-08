# Changelog

All notable changes to BetterWispr are listed here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and the project uses
[Semantic Versioning](https://semver.org/). The current version lives in `VERSION`.

## [0.1.1] - 2026-10-08

### Added
- More local models in Models: Parakeet Ultra (a further-trained TDT v3 with punctuation), Parakeet TDT-CTC 110M (a small English model), Parakeet Japanese, Whisper Large v3 Turbo (compressed) and Whisper Small. Each downloads only when you choose Download.
- Help > Show Welcome Guide replays the welcome guide.
- `BetterWisprCLI --download-model` shows install progress.
- Style page with a writing tone for each kind of app. Personal messages offer Formal, Casual and Very casual. Work messages, Email and Other offer Formal, Casual and Excited. Casual drops most commas and the final period, Very casual also lowercases sentence starts, and Excited ends the last sentence with an exclamation mark. BetterWispr picks the tone from the app you dictate into, so Slack gets your work style and Mail your email style, while browsers and AI apps use Other. Styles change English dictation only, run on your Mac, and default to Formal, which leaves your text as it was.
- Auto cleanup on the Style page. None keeps your words as recognized, still applying voice commands and Vocabulary. Light, the default and the previous behavior, removes filler words like "um" and "you know" and stutters. Medium also edits English dictation for clarity and conciseness with the notes model chosen in Models (Apple Intelligence, Ollama, Claude Code, Codex or an API connection), so it works with whichever one you already use for meeting notes. Apple Intelligence and Ollama run on your Mac. Claude Code, Codex and API connections send the dictation to that provider and add a few seconds. Other languages, very short dictations and edits that fail, take too long, answer the dictation or add new content keep the Light result. The Style page uses standard macOS grouped settings, and choosing Medium shows the notes model it will use.
- Insights page with your words per minute compared with average typing speed, words cleaned up, vocabulary fixes, total words dictated, the kinds of apps you dictate into, and a streak calendar with your current and longest streak. Insights are computed on your Mac from saved history, and the Share button offers a one-line summary through the macOS share menu.
- Use Original in History, under Original transcription, puts back what you said when cleanup or a style changed it.

### Changed
- Parakeet installs fetch the model in one pass instead of one pass per file, and the phrase booster downloads alongside it by default. Model sizes in Models include the booster, which downloads once and is shared by every Parakeet model. If the booster download fails, the model still installs and Vocabulary offers it again.
- Model downloads run separately from dictation. You can dictate with the current model while another downloads, and When it finishes, BetterWispr switches to the new model, unless you picked a different one meanwhile or are mid-dictation.
- Download progress only moves forward and covers the whole install, from the download to setup on this Mac. Models, the welcome guide and Vocabulary offer Cancel during a download and Retry after a failure.
- The welcome guide's completion is saved with your workspace and versioned, so a reset workspace shows the guide again. Quitting midway reopens the guide on the same step. The 0.1.0 preference flag is migrated once and then removed.
- New dictations save the app they were sent to and how many words Vocabulary respelled, for Insights. Dictations saved by 0.1.0 load unchanged and count toward every total except app usage.

### Fixed
- The welcome guide's speech model download no longer stops when Escape, the capsule, the menu or a shortcut release cancels dictation, and a failed download now shows its error in the guide.
- Parakeet Japanese never applies the English phrase booster.
- Insights counts the words the Parakeet phrase booster spells from your Vocabulary while it recognizes speech. Before, those dictations came out right but counted no vocabulary fixes.
- Learn from corrections catches a fix you send right away, as in chat apps that clear the field on send. BetterWispr now checks the field every half second and learns from text that stayed unchanged for half a second before the field emptied. A fix you leave in place is still learned after two seconds without changes.

## [0.1.0] - 2026-10-08

### Added
- Meeting summaries with signed-in Claude Code and Codex subscriptions, or a custom OpenAI-compatible chat-completions endpoint and API key stored in macOS Keychain. Choose the notes provider independently of speech recognition; Apple Intelligence remains the default, with no automatic cloud fallback.
- Claude Code and Codex model pickers populated by the installed CLIs, including exact model IDs, refresh and custom model entry. The chosen model is saved and identified on generated summaries.
- A notes-model test in Models that uses a short synthetic sample, with cancellation and actionable connection errors.
- Meeting notes and titles with Ollama. Choose an installed Ollama model under Notes model in the Notetaker settings menu, and BetterWispr writes the title, summary, key points, decisions and action items with it on this Mac. Apple Intelligence stays the default, BetterWispr never switches models on its own, and cloud and embedding models are not offered.
- Voice commands for English and Auto language: "comma", "question mark", "full stop", "add a period", "new line", "new paragraph", "scratch that" and "sorry, remove that" delete the last sentence, and "at the rate KV" or "at sign KV" types "@KV". Commands are rule-based and run on your Mac.
- Learn from corrections: fix a misheard word in History with the pencil, or in the text field within 30 seconds of a paste, and BetterWispr adds it to Vocabulary with a Learned badge and a toast. Turn it off in Settings.
- Native macOS dictation app with a global ⌥ Space shortcut, paste into the focused app and transcript history.
- Local speech models: Apple speech, Parakeet TDT v3 (25 European languages) and v2 (English) through FluidAudio, and Whisper large-v3 turbo through WhisperKit.
- Compact recording overlay with an idle pill, a hover tooltip showing the chosen shortcut and a dictate button.
- Welcome guide on first launch. It fills the main window, walks through permissions, the recommended speech model and a first dictation, and runs only once.
- Disk image window with BetterWispr and Applications side by side on a warm paper background, a hand-drawn arrow between them and the hint "Drag to Applications". `scripts/dmg-background.swift` renders it at 1x and 2x so it stays sharp on Retina displays, and Finder's labels read in Light and Dark Mode.
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
- Meeting notes. Start a meeting from the Meetings page or the menu bar to record your microphone as "Me" and other apps' audio as "Them" (macOS 14.2 or later), follow a live transcript, and write your own notes. When it ends, Apple Intelligence on a supported Mac running macOS 26 or later writes a summary, key points, decisions and action items locally. Without Apple Intelligence the transcript and your notes are still saved. Search saved meetings, mark action items complete and copy meeting notes and transcripts as Markdown. With a built-in speech provider, audio stays on the Mac; API providers require explicit selection.
- Website with a typing and dictation demo, feature overview, comparison pages, download links, privacy and terms pages, and a dedicated changelog rendered from this file. Pages include static content and social previews.
- `BetterWisprCLI` for local model downloads and file transcription, defaulting to `parakeet-v3`. Pass comma-separated spelling hints with `--vocabulary` or explicitly install the Parakeet booster with `--download-phrase-booster`.
- Local transcript evaluation script reporting word error rate, character error rate and false speech on silent clips, with an accuracy evaluation plan.
- `make dev` for local testing and `make ship` for separate Developer ID-signed, notarized and stapled Apple Silicon and Intel DMGs, with a Sparkle update feed that selects the matching architecture. Notarization credentials are stored once in Keychain with `make setup-notary`.
- `VERSION` file and this changelog. The app bundle version is stamped from `VERSION` at build time.

### Changed
- Meeting summaries combine the transcript and all of My thoughts, including longer notes. Edited thoughts show when the summary needs updating, with an Update summary button.
- The menu bar menu shows whether BetterWispr is ready, listening or transcribing, switches the speech model and microphone, and opens Settings and update checks. Show capsule and Show welcome guide are gone.
- Start Notetaker on the dashboard now docks the meeting card beside your call, the same as starting from the capsule or the menu bar.
- The dashboard no longer opens the live transcript while you record. It keeps the list of notes and opens the finished note once recording and notes are done.
- The app bundle's `CFBundleVersion` now follows `VERSION` instead of a fixed `1`, so Sparkle can tell releases apart.
- The capsule no longer shows the recognized text above the waveform while you dictate or while it transcribes.
- A successful paste no longer shows a "Pasted" toast. Copy-only results still confirm with a toast.
- Recording capsule redesign. Holding ⌥ Space shows only a waveform. In toggle mode the capsule shows cancel, the waveform and a stop mark, and a click anywhere on it finishes dictation. A failed session collapses back to the idle pill with a red outline under the error card.
- Waveform that fits your voice. It learns the room's noise floor and your recent loudness, so quiet voices fill the bars and steady background noise stays flat. Bars rise fast and fall slowly, follow the voice in steps of about 20 ms instead of jumping with each 100 ms audio buffer, and a travelling wave shows while transcribing. Reduce Motion keeps the bars still.

### Fixed
- Escape now cancels an active dictation from the dashboard without adding a history entry. DMG packaging retries Finder's temporary busy error, and release preflight distinguishes Apple agreement errors from invalid credentials.
- Hide matching long microphone echoes of nearby system-audio transcript entries in the transcript, export and summarization input. Original entries remain saved and can be revealed with Show repeated microphone audio.
- Cancelled or failed summary generation preserves the saved meeting and previous summary. Oversized notes fail explicitly if they cannot be condensed, instead of silently losing the end of the source.
- An open note now switches to its Summary tab as soon as the notes are written, instead of staying on the transcript.
- Paste into other apps stopped after every rebuild because ad-hoc signing changed the app's code requirement and macOS revoked Accessibility. `scripts/build-app.sh` now signs with a stable identity, and a blocked paste shows an Allow button instead of silently copying.
- English transcript cleanup removes "uh", "um", "er", "hmm", "mm" and their supported spellings, set-off "you know", and unpunctuated back-to-back repeats such as "which you which you" before vocabulary replacements. It preserves "mm" after a numeric value, "you know?", punctuated repeats, numbers and common doubles such as "that that" and "long long". Language detection ignores fillers; other languages are left as spoken, and history keeps the raw recognizer output.
