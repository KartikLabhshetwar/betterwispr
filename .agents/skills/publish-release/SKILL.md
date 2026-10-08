---
name: publish-release
description: Publish a BetterWispr GitHub release after `make ship` finishes. Switches gh to the personal KartikLabhshetwar account, tags vX.Y.Z, and creates the release with notes taken from CHANGELOG.md in the BetterShot release format. Use when asked to tag, release, publish or ship a version.
---

# Release BetterWispr

Format reference: https://github.com/KartikLabhshetwar/better-shot/releases/tag/v0.5.8

## Preconditions

- `VERSION` holds the new version and `CHANGELOG.md` has a `## [X.Y.Z] - date` section for it.
- `make ship` has finished and printed `=== Release Complete ===`. It leaves
  `release/BetterWispr-arm64.dmg`, `release/BetterWispr-x86_64.dmg` and `release/appcast.xml`,
  all notarized and stapled. If it has not run, ask the user to run it (it needs their
  signing keychain and notary profile); never fake or skip notarization.
- The release commit is on `origin/main` (`git status -sb` shows no ahead/behind). Commit and push
  only if the user asked for it.

## Steps

1. Use the personal account. The repo lives at `opennookorg/betterwispr`:
   ```sh
   gh auth switch -u KartikLabhshetwar
   gh auth status | grep -A1 KartikLabhshetwar
   ```
2. Preview the notes and show them to the user:
   ```sh
   V=$(cat VERSION)
   python3 scripts/release-notes.py "$V" > "$TMPDIR/notes-$V.md"
   ```
   The script copies the version's changelog section, keeps `### Added` / `### Changed` /
   `### Fixed` headings, and bolds the lead sentence of the first item as the headline.
   Edit the changelog, not the notes, if wording needs to change.
3. Tag the pushed commit and push the tag:
   ```sh
   git tag -a "v$V" -m "BetterWispr $V"
   git push origin "v$V"
   ```
4. Create the release. Keep the asset names unchanged: `appcast.xml` enclosure URLs and the
   Sparkle feed (`releases/latest/download/appcast.xml`) depend on them.
   ```sh
   gh release create "v$V" release/BetterWispr-arm64.dmg release/BetterWispr-x86_64.dmg release/appcast.xml \
     --title "BetterWispr $V" --notes-file "$TMPDIR/notes-$V.md" --verify-tag
   ```
5. Verify, then report the release URL:
   ```sh
   gh release view "v$V" --json name,tagName,author,assets -q '.name, .tagName, .author.login, [.assets[].name]'
   curl -sL https://github.com/opennookorg/betterwispr/releases/latest/download/appcast.xml | grep shortVersionString
   ```

## Format

- Title: `BetterWispr X.Y.Z`. No "Full Changelog" footer, no generated notes.
- Body: changelog sections in order, a blank line after each heading, one bullet per change,
  user-facing wording from the changelog.
