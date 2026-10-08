#!/usr/bin/env python3
"""Check release control flow with stub tools; no Keychain, network or mounts."""

import os
from pathlib import Path
import plistlib
import shutil
import subprocess
import tempfile
import xml.etree.ElementTree as ET


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
    'notarytool history'|'notarytool store-credentials')
        echo "${CHECK_AUTH_ERROR:-}" >&2
        exit "${CHECK_AUTH_STATUS:-0}" ;;
    'notarytool submit')
        [[ "$3" != *"${CHECK_SUBMIT_FAIL_ARCH:-none}"* ]] || exit 1 ;;
esac''')
    stub("scripts/build-app.sh", '''echo "build $* signing=$CODESIGN_IDENTITY" >> "$CHECK_LOG"
app="$PWD/.build/$2-apple-macosx/release/BetterWispr.app"
mkdir -p "$app/Contents/MacOS"
cp app.plist "$app/Contents/Info.plist"
touch "$app/Contents/MacOS/BetterWispr"
echo "$app"''')
    (root / "app.plist").write_bytes(plistlib.dumps({
        "CFBundleVersion": "0", "CFBundleShortVersionString": "0"}))
    stub("scripts/create-dmg.sh", 'printf new-dmg > "$2"')
    for tool in ("codesign", "spctl"):
        stub(f"bin/{tool}", 'exit 0')
    stub("bin/lipo", '''if [[ -n "${CHECK_WRONG_ARCH:-}" ]]; then echo wrong
elif [[ "$2" == *x86_64* ]]; then echo x86_64
else echo arm64; fi''')
    stub(".build/artifacts/sparkle/Sparkle/bin/sign_update",
         '''echo "sign-update $*" >> "$CHECK_LOG"
[[ "$3" != *"${CHECK_SIGN_FAIL_ARCH:-none}"* ]] || exit 1
echo 'sparkle:edSignature="test-signature" length="7"' ''')

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

    # Preflight failures preserve artifacts and report the relevant recovery,
    # without treating agreements or network failures as bad credentials.
    (root / "release").mkdir()
    dmg = root / "release/BetterWispr.dmg"
    dmg.write_text("previous release")
    for error, recovery in (
        ("Error: No Keychain password item found for profile: betterwispr-notary", "make setup-notary"),
        ("Error: HTTP status code: 401. Invalid credentials.", "make setup-notary"),
        ("Error: HTTP status code: 403. A required agreement is missing or has expired.", "Account Holder"),
        ("Error: HTTP status code: 403. Access denied.", "Resolve the error above"),
        ("Error: The network connection was lost.", "Resolve the error above"),
    ):
        result = run("make", "-s", "ship", CHECK_AUTH_STATUS="1", CHECK_AUTH_ERROR=error)
        assert result.returncode != 0 and error in result.stderr and recovery in result.stderr
        assert ("make setup-notary" in result.stderr) == (recovery == "make setup-notary")
        assert calls() == ["notarytool history --keychain-profile betterwispr-notary"]
        assert dmg.read_text() == "previous release"

    for profile in ("betterwispr-notary", "custom profile"):
        result = run("make", "-s", "ship", NOTARY_PROFILE=profile)
        assert result.returncode == 0, result.stderr
        expected = [f"notarytool history --keychain-profile {profile}"]
        for arch in ("arm64", "x86_64"):
            artifact = root / f"release/BetterWispr-{arch}.dmg"
            expected += [f"build release {arch} signing=-",
                         f"notarytool submit {artifact} --keychain-profile {profile} --wait",
                         f"stapler staple {artifact}"]
            assert artifact.read_text() == "new-dmg"
        expected += [f"sign-update --account betterwispr {root}/release/BetterWispr-{arch}.dmg"
                     for arch in ("arm64", "x86_64")]
        assert calls() == expected, calls()
        assert "Release Complete" in result.stdout
        items = ET.parse(root / "release/appcast.xml").findall("./channel/item")
        assert len(items) == 2
        ns = {"sparkle": "http://www.andymatuschak.org/xml-namespaces/sparkle"}
        for item, arch in zip(items, ("arm64", "x86_64")):
            assert item.find("enclosure").attrib["url"].endswith(f"/BetterWispr-{arch}.dmg")
            assert item.findtext("sparkle:hardwareRequirements", namespaces=ns) == ("arm64" if arch == "arm64" else None)
    for arch in ("arm64", "x86_64"):
        result = run("make", "-s", "ship", CHECK_SUBMIT_FAIL_ARCH=arch)
        assert result.returncode != 0 and "Release Complete" not in result.stdout
        assert not any(call.startswith("stapler") and f"BetterWispr-{arch}.dmg" in call for call in calls())
        assert not (root / "release/appcast.xml").exists()
    result = run("make", "-s", "ship", CHECK_SIGN_FAIL_ARCH="x86_64")
    assert result.returncode != 0 and not (root / "release/appcast.xml").exists()
    result = run("make", "-s", "ship", CHECK_WRONG_ARCH="1")
    assert result.returncode != 0 and "Expected arm64 executable" in result.stderr
    assert not any(call.startswith("notarytool submit") for call in calls())
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
        result = run("bash", "scripts/create-dmg.sh", ".build/arm64-apple-macosx/release/BetterWispr.app", str(dmg),
                     CHECK_FAILURES=str(failures), CHECK_ERROR=error,
                     CHECK_DMG_STATUS=str(status), CHECK_VERIFY_STATUS=str(verify))
        assert result.returncode == expected_status, result.stdout + result.stderr
        assert int((root / "attempts").read_text()) == expected_attempts
        assert dmg.read_text() == ("new-dmg" if expected_status == 0 else "previous release")
        assert not list((root / "release").glob(".dmg-build.*"))

print("Release script checks passed (stub tools; no live Apple submission).")
