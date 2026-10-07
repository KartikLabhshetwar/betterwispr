#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
configuration="${1:-debug}"
if [[ "$configuration" != debug && "$configuration" != release ]]; then
    echo 'Usage: scripts/build-app.sh [debug|release]' >&2
    exit 2
fi
swift build -c "$configuration" --product BetterWispr
binary_dir="$(swift build -c "$configuration" --show-bin-path)"
app="$PWD/.build/$configuration/BetterWispr.app"
mkdir -p "$app/Contents/MacOS" "$app/Contents/Resources"
# SwiftPM checkout licenses/resources can be read-only after the first copy.
chmod -R u+w "$app"
cp "$binary_dir/BetterWispr" "$app/Contents/MacOS/BetterWispr"
cp Resources/Info.plist "$app/Contents/Info.plist"
version="$(tr -d '[:space:]' < VERSION)"
/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $version" "$app/Contents/Info.plist"
icon_sources=(Sources/BetterWispr/Design/BrandMark.swift scripts/render-app-icon.swift)
icon=.build/AppIcon.icns
if [[ ! -f "$icon" || "${icon_sources[0]}" -nt "$icon" || "${icon_sources[1]}" -nt "$icon" ]]; then
    iconset="$(mktemp -d)/AppIcon.iconset"
    swiftc -parse-as-library "${icon_sources[@]}" -o .build/render-app-icon
    .build/render-app-icon "$iconset"
    iconutil -c icns "$iconset" -o "$icon"
fi
cp "$icon" "$app/Contents/Resources/AppIcon.icns"
rm -rf "$app/Contents/Resources/Licenses" "$app/Contents/MacOS/FluidAudio_FluidAudio.bundle"
mkdir -p "$app/Contents/Resources/Licenses"
cp LICENSE "$app/Contents/Resources/Licenses/BetterWispr-Apache-2.0.txt"
cp .build/checkouts/argmax-oss-swift/LICENSE "$app/Contents/Resources/Licenses/Argmax-MIT.txt"
cp .build/checkouts/argmax-oss-swift/NOTICES "$app/Contents/Resources/Licenses/Argmax-NOTICES.txt"
cp .build/checkouts/FluidAudio/LICENSE "$app/Contents/Resources/Licenses/FluidAudio-Apache-2.0.txt"
cp .build/checkouts/swift-argument-parser/LICENSE.txt "$app/Contents/Resources/Licenses/Swift-Argument-Parser-Apache-2.0.txt"
# SwiftPM resources from speech/tokenizer dependencies must travel with the app.
for resource in "$binary_dir"/*.bundle; do
    [[ -d "$resource" ]] || continue
    cp -R "$resource" "$app/Contents/Resources/"
    [[ "$(basename "$resource")" == FluidAudio_* ]] && continue
    cp -R "$resource" "$app/Contents/MacOS/"
done
identity="${CODESIGN_IDENTITY:-$(security find-identity -v -p codesigning 2>/dev/null | awk '/\)/ {print $2; exit}' || true)}"
if [[ -z "$identity" ]]; then
    identity=-
    echo 'warning: ad-hoc signing changes on every build, so macOS revokes Accessibility (paste) each time. Set CODESIGN_IDENTITY to keep it.' >&2
fi
codesign --force --deep --sign "$identity" --entitlements Resources/BetterWispr.entitlements "$app"
echo "$app"
