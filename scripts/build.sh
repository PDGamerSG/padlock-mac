#!/bin/bash
set -euo pipefail

PADLOCK_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PADLOCK_BUILD="$PADLOCK_ROOT/build"
PADLOCK_DIST="$PADLOCK_ROOT/dist"
PADLOCK_APP="$PADLOCK_DIST/Padlock.app"
PADLOCK_VERSION="$(tr -d '\n\r' < "$PADLOCK_ROOT/VERSION")"
PADLOCK_ARCH="${1:-universal}"
PADLOCK_IDENTITY="${PADLOCK_SIGNING_IDENTITY:--}"

case "$PADLOCK_ARCH" in
    universal) PADLOCK_ARCHS=(arm64 x86_64) ;;
    arm64|x86_64) PADLOCK_ARCHS=("$PADLOCK_ARCH") ;;
    *) printf 'Usage: %s [universal|arm64|x86_64]\n' "$0" >&2; exit 2 ;;
esac
if [[ ! "$PADLOCK_VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    printf 'VERSION must contain a numeric major.minor.patch version.\n' >&2
    exit 2
fi

cd "$PADLOCK_ROOT"
mkdir -p "$PADLOCK_BUILD" "$PADLOCK_DIST"
PADLOCK_BINARIES=()
for PADLOCK_SLICE in "${PADLOCK_ARCHS[@]}"; do
    printf 'Building Padlock %s for %s (macOS 13+)...\n' "$PADLOCK_VERSION" "$PADLOCK_SLICE"
    PADLOCK_SCRATCH="$PADLOCK_BUILD/spm-$PADLOCK_SLICE"
    /usr/bin/xcrun swift build --build-system native --configuration release \
        --scratch-path "$PADLOCK_SCRATCH" --triple "$PADLOCK_SLICE-apple-macosx13.0"
    PADLOCK_BIN_DIR="$(/usr/bin/xcrun swift build --build-system native --configuration release \
        --scratch-path "$PADLOCK_SCRATCH" --triple "$PADLOCK_SLICE-apple-macosx13.0" --show-bin-path)"
    PADLOCK_BINARIES+=("$PADLOCK_BIN_DIR/Padlock")
done

# Only replace this script's generated bundle, after both compilations succeed.
if [[ -e "$PADLOCK_APP" ]]; then rm -rf "$PADLOCK_APP"; fi
mkdir -p "$PADLOCK_APP/Contents/MacOS" "$PADLOCK_APP/Contents/Resources"
if [[ ${#PADLOCK_BINARIES[@]} -gt 1 ]]; then
    /usr/bin/xcrun lipo -create "${PADLOCK_BINARIES[@]}" -output "$PADLOCK_APP/Contents/MacOS/Padlock"
else
    cp "${PADLOCK_BINARIES[0]}" "$PADLOCK_APP/Contents/MacOS/Padlock"
fi
chmod 755 "$PADLOCK_APP/Contents/MacOS/Padlock"
cp "$PADLOCK_ROOT/Resources/Info.plist" "$PADLOCK_APP/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $PADLOCK_VERSION" "$PADLOCK_APP/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleVersion $PADLOCK_VERSION" "$PADLOCK_APP/Contents/Info.plist"

if [[ ! -f "$PADLOCK_ROOT/Resources/Padlock.icns" ]]; then
    /usr/bin/xcrun swift "$PADLOCK_ROOT/scripts/generate-icon.swift" "$PADLOCK_BUILD/Padlock.iconset"
    /usr/bin/iconutil -c icns "$PADLOCK_BUILD/Padlock.iconset" -o "$PADLOCK_ROOT/Resources/Padlock.icns"
fi
cp "$PADLOCK_ROOT/Resources/Padlock.icns" "$PADLOCK_APP/Contents/Resources/Padlock.icns"
for PADLOCK_DOC in LICENSE THIRD-PARTY-NOTICES.md README.md; do
    cp "$PADLOCK_ROOT/$PADLOCK_DOC" "$PADLOCK_APP/Contents/Resources/$PADLOCK_DOC"
done
cp "$PADLOCK_ROOT/docs/FEATURE-PARITY.md" "$PADLOCK_APP/Contents/Resources/FEATURE-PARITY.md"
cp "$PADLOCK_ROOT/docs/MANUAL-TESTING.md" "$PADLOCK_APP/Contents/Resources/MANUAL-TESTING.md"
mkdir -p "$PADLOCK_APP/Contents/Resources/docs"
for PADLOCK_DOC in ARCHITECTURE.md FEATURE-PARITY.md MANUAL-TESTING.md; do
    cp "$PADLOCK_ROOT/docs/$PADLOCK_DOC" "$PADLOCK_APP/Contents/Resources/docs/$PADLOCK_DOC"
done

if [[ "$PADLOCK_IDENTITY" == "-" ]]; then
    /usr/bin/codesign --force --sign - --identifier io.github.pdgamersg.padlock "$PADLOCK_APP"
else
    /usr/bin/codesign --force --options runtime --timestamp --sign "$PADLOCK_IDENTITY" "$PADLOCK_APP"
fi
/usr/bin/plutil -lint "$PADLOCK_APP/Contents/Info.plist"
/usr/bin/codesign --verify --strict --verbose=2 "$PADLOCK_APP"
/usr/bin/xcrun lipo -info "$PADLOCK_APP/Contents/MacOS/Padlock"
printf 'Built %s\nNo application launch or runtime tests were performed.\n' "$PADLOCK_APP"
