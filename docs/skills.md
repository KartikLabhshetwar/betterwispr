# Imported BetterShot skills

Copied on 2026-10-08 from the local `../better-shot` checkout, whose HEAD was
`102b3648eff0cd254b26f3e15d60d6ca102a85ff`. This is a snapshot of the working
tree, including any local skill changes, not a claim that every file matches HEAD.

Both `.agents/skills/` and `.claude/skills/` were copied independently, preserving
their contents and directory layout. Each contains 55 files, including 14
`SKILL.md` files. All copied file bytes were checked against their corresponding
source files. No symlinks were present. Existing files were checked for conflicts
before copying; none were overwritten with different content.

| Skill family | Recorded upstream |
| --- | --- |
| `apple-design` | `emilkowalski/skills` |
| `write-swift` | `emilkowalski/skills` |
| `macos-development` | `rshankras/claude-code-apple-skills` |
| `landing-page-design` | `elayadesign/ai-design-skills` |
| `ip-as-logo` | `s1dashu/ip-as-logo-skill` |
| `design-anti-slop` | Local BetterShot skill; absent from its lock file |

`skills-lock.json` is an unchanged copy of BetterShot's lock file. It records the
first five families and their original computed hashes. Those hashes were not
regenerated and should not be interpreted as verification of later local edits.
The copied `ip-as-logo/LICENSE` and all other existing notices remain in place.
These are development resources, not app runtime dependencies; their original
terms and attribution continue to apply.

For native app work, start with `macos-development/SKILL.md`, `write-swift/SKILL.md`,
and `apple-design/SKILL.md`. Open only the relevant macOS submodules. Advice that
refers to newer Swift or macOS APIs must be checked against the actual deployment
target and compiler.

BetterShot's screenshot-specific `AGENTS.md`, `.claude/settings.local.json`,
worktrees, credentials and app source were not part of this skills import.

`publish-release` is a local BetterWispr skill, not imported. It publishes a GitHub release after
`make ship`, using `scripts/release-notes.py` to turn the `CHANGELOG.md` section into notes.
