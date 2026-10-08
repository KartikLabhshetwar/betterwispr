#!/usr/bin/env python3
"""Check release control flow with stub tools; no Keychain, network or mounts."""

import os
from pathlib import Path
import plistlib
import shutil
import subprocess
import tempfile


SOURCE = Path(__file__).resolve().parents[1]

with tempfile.TemporaryDirectory(prefix="betterwispr-release-check-") as directory:
    root = Path(directory).resolve()
    (root / "scripts").mkdir()
    (root / "bin").mkdir()
    for name in ("Makefile", "VERSION", "scripts/release.sh"):
        shutil.copy2(SOURCE / name, root / name)
    env = dict(os.environ, PATH=f"{root / 'bin'}:{os.environ['PATH']}",
               CHECK_LOG=str(root / "calls"), CHECK_ATTEMPTS=str(root / "attempts"))
    env.pop("NOTARY_PROFILE", None)

    def stub(name, body):
        path = root / name
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text("#!/bin/bash\nset -eu\n" + body + "\n")
        path.chmod(0o755)

    def run(*args, input="", **overrides):
        (root / "calls").write_text("")
        return subprocess.run(args, cwd=root, env=dict(env, **overrides),
                              input=input, text=True, capture_output=True)

    def calls():
        return (root / "calls").read_text().splitlines()

    stub("bin/xcrun", '''printf '%s\n' "$*" >> "$CHECK_LOG"
case "$1 $2" in
    'notarytool history'|'notarytool store-credentials') exit "${CHECK_AUTH_STATUS:-0}" ;;
    'notarytool submit') exit "${CHECK_SUBMIT_STATUS:-0}" ;;
esac''')
    stub("scripts/build-app.sh", '''echo build >> "$CHECK_LOG"
mkdir -p .build/release/BetterWispr.app/Contents
cp app.plist .build/release/BetterWispr.app/Contents/Info.plist''')
    (root / "app.plist").write_bytes(plistlib.dumps({
        "CFBundleVersion": "0", "CFBundleShortVersionString": "0"}))
    stub("scripts/create-dmg.sh", 'printf new-dmg > "$2"')
    for tool in ("codesign", "spctl"):
        stub(f"bin/{tool}", 'exit 0')
    stub(".build/artifacts/sparkle/Sparkle/bin/sign_update",
         '''echo 'sparkle:edSignature="test-signature" length="7"' ''')

    # Setup delegates the hidden password prompt to notarytool, using the same
    # profile as shipping. Failed validation must propagate to Make.
    for profile in ("betterwispr-notary", "custom profile"):
        override = {} if profile == "betterwispr-notary" else {"NOTARY_PROFILE": profile}
        result = run("make", "-s", "setup-notary", input="release@example.com\n", **override)
        assert result.returncode == 0, result.stderr
        assert calls() == [f"notarytool store-credentials {profile} --apple-id release@example.com --team-id 8JL39GK2DC"], calls()
    result = run("make", "-s", "setup-notary", input="\n")
    assert result.returncode != 0 and not calls()
    result = run("make", "-s", "setup-notary", input="release@example.com\n", CHECK_AUTH_STATUS="1")
    assert result.returncode != 0

    # Missing credentials or an agreement error must preserve old artifacts.
    (root / "release").mkdir()
    dmg = root / "release/BetterWispr.dmg"
    dmg.write_text("previous release")
    result = run("make", "-s", "ship", CHECK_AUTH_STATUS="1")
    assert result.returncode != 0 and "make setup-notary" in result.stderr
    assert calls() == ["notarytool history --keychain-profile betterwispr-notary"]
    assert dmg.read_text() == "previous release"

    for profile in ("betterwispr-notary", "custom profile"):
        result = run("make", "-s", "ship", NOTARY_PROFILE=profile)
        assert result.returncode == 0, result.stderr
        assert calls() == [
            f"notarytool history --keychain-profile {profile}", "build",
            f"notarytool submit {dmg} --keychain-profile {profile} --wait",
            f"stapler staple {dmg}"], calls()
        assert "Release Complete" in result.stdout
        assert "test-signature" in (root / "release/appcast.xml").read_text()
    result = run("make", "-s", "ship", CHECK_SUBMIT_STATUS="1")
    assert result.returncode != 0 and "Release Complete" not in result.stdout
    assert not any(call.startswith("stapler") for call in calls())
    assert not (root / "release/appcast.xml").exists()

    # Exercise the real packaging wrapper: retry only Finder busy, cap retries,
    # and never replace an existing DMG with failed/unverified output.
    shutil.copy2(SOURCE / "scripts/create-dmg.sh", root / "scripts/create-dmg.sh")
    stub("bin/ditto", 'cp -R "$1" "$2"')
    stub("bin/sleep", 'exit 0')
    stub("bin/hdiutil", 'exit "${CHECK_VERIFY_STATUS:-0}"')
    stub("bin/create-dmg", '''attempt=0
[[ ! -f "$CHECK_ATTEMPTS" ]] || attempt=$(cat "$CHECK_ATTEMPTS")
attempt=$((attempt + 1))
echo "$attempt" > "$CHECK_ATTEMPTS"
if [[ $attempt -le "$CHECK_FAILURES" ]]; then
    echo "$CHECK_ERROR" >&2
    exit "$CHECK_DMG_STATUS"
fi
printf new-dmg > "${@: -2:1}"''')
    for failures, error, status, verify, expected_attempts, expected_status in (
        (0, "", 64, 0, 1, 0),
        (1, "Finder is busy. (-15260)", 64, 0, 2, 0),
        (9, "Finder is busy. (-15260)", 64, 0, 3, 64),
        (1, "Not authorized (-1743)", 64, 0, 1, 64),
        (1, "Finder is busy. (-15260); detach failed", 16, 0, 1, 16),
        (0, "", 64, 1, 1, 1),
    ):
        (root / "attempts").write_text("0")
        dmg.write_text("previous release")
        result = run("bash", "scripts/create-dmg.sh", ".build/release/BetterWispr.app", str(dmg),
                     CHECK_FAILURES=str(failures), CHECK_ERROR=error,
                     CHECK_DMG_STATUS=str(status), CHECK_VERIFY_STATUS=str(verify))
        assert result.returncode == expected_status, result.stdout + result.stderr
        assert int((root / "attempts").read_text()) == expected_attempts
        assert dmg.read_text() == ("new-dmg" if expected_status == 0 else "previous release")
        assert not list((root / "release").glob(".dmg-build.*"))

print("Release script checks passed (stub tools; no live Apple submission).")
