#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
cd "$PROJECT_DIR"

VERSION="${1:-$(tr -d '[:space:]' < VERSION)}"
SIGNING_IDENTITY="${SIGNING_IDENTITY:-Developer ID Application: Kartik Labhshetwar (8JL39GK2DC)}"
NOTARY_PROFILE="${NOTARY_PROFILE:-bettershot-notary}"
ENTITLEMENTS="Resources/BetterWispr.entitlements"
RELEASE_DIR="$PROJECT_DIR/release"
APP_PATH="$PROJECT_DIR/.build/release/BetterWispr.app"
DMG_PATH="$RELEASE_DIR/BetterWispr.dmg"

echo "=== BetterWispr v$VERSION Release Build ==="
rm -rf "$RELEASE_DIR"
mkdir -p "$RELEASE_DIR"

echo "[Apple Silicon] Building..."
rm -rf "$APP_PATH"
./scripts/build-app.sh release >/dev/null
/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $VERSION" -c "Set :CFBundleVersion $VERSION" "$APP_PATH/Contents/Info.plist"

echo "[Apple Silicon] Signing..."
codesign --deep --force --options runtime --timestamp \
    --sign "$SIGNING_IDENTITY" \
    --entitlements "$ENTITLEMENTS" \
    "$APP_PATH"
codesign --verify --deep --strict "$APP_PATH"
echo "[Apple Silicon] Signature verified."

echo "[Apple Silicon] Creating DMG..."
bash "$SCRIPT_DIR/create-dmg.sh" "$APP_PATH" "$DMG_PATH"
codesign --timestamp --sign "$SIGNING_IDENTITY" "$DMG_PATH"

echo "[Apple Silicon] Notarizing..."
xcrun notarytool submit "$DMG_PATH" --keychain-profile "$NOTARY_PROFILE" --wait

echo "[Apple Silicon] Stapling..."
xcrun stapler staple "$DMG_PATH"
spctl --assess --type open --context context:primary-signature --verbose "$DMG_PATH"

echo "[Apple Silicon] Writing appcast..."
SIGNATURE="$(.build/artifacts/sparkle/Sparkle/bin/sign_update --account betterwispr "$DMG_PATH")"
cat > "$RELEASE_DIR/appcast.xml" <<EOF
<?xml version="1.0" encoding="utf-8"?>
<rss version="2.0" xmlns:sparkle="http://www.andymatuschak.org/xml-namespaces/sparkle">
    <channel>
        <title>BetterWispr</title>
        <item>
            <title>Version $VERSION</title>
            <pubDate>$(LC_ALL=C date -u '+%a, %d %b %Y %H:%M:%S +0000')</pubDate>
            <link>https://github.com/opennookorg/betterwispr/releases/tag/v$VERSION</link>
            <sparkle:version>$VERSION</sparkle:version>
            <sparkle:shortVersionString>$VERSION</sparkle:shortVersionString>
            <sparkle:minimumSystemVersion>14.0</sparkle:minimumSystemVersion>
            <enclosure url="https://github.com/opennookorg/betterwispr/releases/download/v$VERSION/$(basename "$DMG_PATH")" type="application/octet-stream" $SIGNATURE/>
        </item>
    </channel>
</rss>
EOF

echo ""
echo "=== Release Complete ==="
ls -lh "$DMG_PATH" "$RELEASE_DIR/appcast.xml"
echo ""
echo "Next steps:"
echo "  git add -A && git commit -m 'release: v$VERSION'"
echo "  git push origin main"
echo "  gh release create v$VERSION \"$DMG_PATH\" \"$RELEASE_DIR/appcast.xml\" --title \"BetterWispr $VERSION\" --generate-notes"
