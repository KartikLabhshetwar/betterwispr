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
DMG_PATH="$RELEASE_DIR/BetterWispr-${VERSION}_arm64.dmg"

echo "=== BetterWispr v$VERSION Release Build ==="
rm -rf "$RELEASE_DIR"
mkdir -p "$RELEASE_DIR"

echo "[Apple Silicon] Building..."
rm -rf "$APP_PATH"
./scripts/build-app.sh release >/dev/null
/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $VERSION" "$APP_PATH/Contents/Info.plist"

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

echo ""
echo "=== Release Complete ==="
ls -lh "$DMG_PATH"
echo ""
echo "Next steps:"
echo "  git add -A && git commit -m 'release: v$VERSION'"
echo "  git tag v$VERSION"
echo "  git push origin main && git push origin v$VERSION"
