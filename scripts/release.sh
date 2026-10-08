#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
cd "$PROJECT_DIR"

NOTARY_PROFILE="${NOTARY_PROFILE:-betterwispr-notary}"
if [[ "${1:-}" == --setup-notary ]]; then
    read -r -p "Apple ID email: " apple_id
    if [[ -z "$apple_id" ]]; then
        echo "Apple ID email is required." >&2
        exit 1
    fi
    # notarytool prompts securely for the app-specific password and validates it.
    exec xcrun notarytool store-credentials "$NOTARY_PROFILE" \
        --apple-id "$apple_id" --team-id 8JL39GK2DC
fi

VERSION="${1:-$(tr -d '[:space:]' < VERSION)}"
SIGNING_IDENTITY="${SIGNING_IDENTITY:-Developer ID Application: Kartik Labhshetwar (8JL39GK2DC)}"
ENTITLEMENTS="Resources/BetterWispr.entitlements"
RELEASE_DIR="$PROJECT_DIR/release"

echo "=== BetterWispr v$VERSION Release Build ==="
echo "Checking notarization access ($NOTARY_PROFILE)..."
if ! notary_output="$(xcrun notarytool history --keychain-profile "$NOTARY_PROFILE" 2>&1)"; then
    printf '%s\n' "$notary_output" >&2
    case "$notary_output" in
        *"required agreement"*|*"in-effect agreement"*)
            echo "Apple is blocking notarization until your team's developer agreement is current." >&2
            echo "The Account Holder must review it at https://developer.apple.com/account/." >&2
            echo "After resolving the agreement, rerun make ship. Keep the existing Keychain credentials." >&2
            ;;
        *"No Keychain password item found"*|*"HTTP status code: 401"*)
            echo "Notarization credentials are missing or invalid. Run make setup-notary to save or update them." >&2
            ;;
        *)
            echo "Notarization access check failed. Resolve the error above, then rerun make ship." >&2
            ;;
    esac
    exit 1
fi

rm -rf "$RELEASE_DIR"
mkdir -p "$RELEASE_DIR"

build_arch() {
    local arch="$1" label="$2"
    local app_path dmg_path="$RELEASE_DIR/BetterWispr-$arch.dmg"

    echo "[$label] Building..."
    # Use ad-hoc signing for packaging; Developer ID is applied once below.
    app_path="$(CODESIGN_IDENTITY=- ./scripts/build-app.sh release "$arch" | tail -1)"
    if [[ "$(lipo -archs "$app_path/Contents/MacOS/BetterWispr")" != "$arch" ]]; then
        echo "Expected $arch executable in $app_path." >&2
        return 1
    fi
    /usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $VERSION" -c "Set :CFBundleVersion $VERSION" "$app_path/Contents/Info.plist"

    echo "[$label] Signing..."
    codesign --deep --force --options runtime --timestamp \
        --sign "$SIGNING_IDENTITY" --entitlements "$ENTITLEMENTS" "$app_path"
    codesign --verify --deep --strict "$app_path"
    echo "[$label] Signature verified."

    echo "[$label] Creating DMG..."
    bash "$SCRIPT_DIR/create-dmg.sh" "$app_path" "$dmg_path"
    codesign --timestamp --sign "$SIGNING_IDENTITY" "$dmg_path"

    echo "[$label] Notarizing..."
    xcrun notarytool submit "$dmg_path" --keychain-profile "$NOTARY_PROFILE" --wait

    echo "[$label] Stapling..."
    xcrun stapler staple "$dmg_path"
    spctl --assess --type open --context context:primary-signature --verbose "$dmg_path"
}

build_arch arm64 "Apple Silicon"
build_arch x86_64 "Intel"

echo "Writing appcast for both architectures..."
cat > "$RELEASE_DIR/appcast.xml.tmp" <<EOF
<?xml version="1.0" encoding="utf-8"?>
<rss version="2.0" xmlns:sparkle="http://www.andymatuschak.org/xml-namespaces/sparkle">
    <channel>
        <title>BetterWispr</title>
EOF
# Sparkle selects the first compatible item at the same version. Intel rejects
# the arm64 requirement; Apple Silicon (including Rosetta) prefers the first item.
for arch in arm64 x86_64; do
    dmg_path="$RELEASE_DIR/BetterWispr-$arch.dmg"
    signature="$(.build/artifacts/sparkle/Sparkle/bin/sign_update --account betterwispr "$dmg_path")"
    hardware_requirement=""
    if [[ "$arch" == arm64 ]]; then
        hardware_requirement='<sparkle:hardwareRequirements>arm64</sparkle:hardwareRequirements>'
    fi
    cat >> "$RELEASE_DIR/appcast.xml.tmp" <<EOF
        <item>
            <title>Version $VERSION ($arch)</title>
            <pubDate>$(LC_ALL=C date -u '+%a, %d %b %Y %H:%M:%S +0000')</pubDate>
            <link>https://github.com/opennookorg/betterwispr/releases/tag/v$VERSION</link>
            <sparkle:version>$VERSION</sparkle:version>
            <sparkle:shortVersionString>$VERSION</sparkle:shortVersionString>
            <sparkle:minimumSystemVersion>14.0</sparkle:minimumSystemVersion>
            $hardware_requirement
            <enclosure url="https://github.com/opennookorg/betterwispr/releases/download/v$VERSION/$(basename "$dmg_path")" type="application/octet-stream" $signature/>
        </item>
EOF
done
cat >> "$RELEASE_DIR/appcast.xml.tmp" <<EOF
    </channel>
</rss>
EOF
mv "$RELEASE_DIR/appcast.xml.tmp" "$RELEASE_DIR/appcast.xml"

echo ""
echo "=== Release Complete ==="
ls -lh "$RELEASE_DIR"/*.dmg "$RELEASE_DIR/appcast.xml"
echo ""
echo "Next steps:"
echo "  git add -A && git commit -m 'release: v$VERSION'"
echo "  git push origin main"
echo "  gh release create v$VERSION \"$RELEASE_DIR/BetterWispr-arm64.dmg\" \"$RELEASE_DIR/BetterWispr-x86_64.dmg\" \"$RELEASE_DIR/appcast.xml\" --title \"BetterWispr $VERSION\" --generate-notes"
