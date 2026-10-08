#!/bin/bash
set -euo pipefail

if [[ $# != 2 || ! -d "$1/Contents" || "$2" != *.dmg ]]; then
    echo "Usage: bash scripts/create-dmg.sh BetterWispr.app output.dmg" >&2
    exit 1
fi
if ! command -v create-dmg >/dev/null; then
    echo "DMG packaging requires create-dmg: brew install create-dmg" >&2
    exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
APP_PATH="$(cd "$1" && pwd)"
mkdir -p "$(dirname "$2")"
OUTPUT_DIR="$(cd "$(dirname "$2")" && pwd)"
OUTPUT_PATH="$OUTPUT_DIR/$(basename "$2")"
WORK_DIR="$(mktemp -d "$OUTPUT_DIR/.dmg-build.XXXXXX")"
trap 'rm -rf "$WORK_DIR"' EXIT
mkdir "$WORK_DIR/staging"
ditto "$APP_PATH" "$WORK_DIR/staging/BetterWispr.app"
xcrun swift "$SCRIPT_DIR/dmg-background.swift" "$WORK_DIR/background.tiff"

create-dmg \
    --volname "BetterWispr" \
    --background "$WORK_DIR/background.tiff" \
    --window-pos 200 140 \
    --window-size 642 406 \
    --icon-size 128 \
    --text-size 13 \
    --icon "BetterWispr.app" 164 160 \
    --hide-extension "BetterWispr.app" \
    --app-drop-link 478 160 \
    "$WORK_DIR/BetterWispr.dmg" "$WORK_DIR/staging"

hdiutil verify "$WORK_DIR/BetterWispr.dmg"
mv -f "$WORK_DIR/BetterWispr.dmg" "$OUTPUT_PATH"
echo "Created $OUTPUT_PATH"
