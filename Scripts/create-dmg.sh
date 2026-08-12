#!/bin/zsh

set -euo pipefail

SCRIPT_DIR=${0:A:h}
PROJECT_DIR=${SCRIPT_DIR:h}
DEFAULT_APP_BUNDLE="$PROJECT_DIR/dist/Tiro.app"
INFO_PLIST="$PROJECT_DIR/Resources/Info.plist"

APP_BUNDLE=${1:-$DEFAULT_APP_BUNDLE}
VERSION=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$INFO_PLIST")
OUTPUT_PATH=${2:-"$PROJECT_DIR/dist/Tiro-$VERSION.dmg"}

if [[ ! -d "$APP_BUNDLE" ]]; then
    echo "App bundle not found: $APP_BUNDLE" >&2
    echo "Run ./Scripts/build-app.sh first." >&2
    exit 1
fi

if [[ "$OUTPUT_PATH" != *.dmg ]]; then
    echo "DMG output path must end in .dmg: $OUTPUT_PATH" >&2
    exit 1
fi

STAGING_DIR=$(mktemp -d -t tiro-dmg)
DMG_ROOT="$STAGING_DIR/Tiro"

cleanup() {
    rm -rf "$STAGING_DIR"
}
trap cleanup EXIT

mkdir -p "$DMG_ROOT" "${OUTPUT_PATH:h}"
ditto "$APP_BUNDLE" "$DMG_ROOT/Tiro.app"
ln -s /Applications "$DMG_ROOT/Applications"

rm -f "$OUTPUT_PATH"
hdiutil create \
    -volname "Tiro" \
    -srcfolder "$DMG_ROOT" \
    -format UDZO \
    -ov \
    "$OUTPUT_PATH"
hdiutil verify "$OUTPUT_PATH"

echo "$OUTPUT_PATH"
