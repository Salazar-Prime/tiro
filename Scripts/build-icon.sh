#!/bin/zsh

set -euo pipefail

SCRIPT_DIR=${0:A:h}
PROJECT_DIR=${SCRIPT_DIR:h}
SOURCE_ICON=${1:-"$PROJECT_DIR/Resources/AppIcon.svg"}
MASTER_ICON="$PROJECT_DIR/Resources/AppIcon.png"
OUTPUT_ICON="$PROJECT_DIR/Resources/AppIcon.icns"
OUTPUT_ICONSET_DIR="$PROJECT_DIR/Resources/AppIcon.iconset"
VOICE_TYPE_TEMP_DIR=$(mktemp -d "${TMPDIR:-/tmp}/voice-type-icon.XXXXXX")
ICONSET_DIR="$VOICE_TYPE_TEMP_DIR/AppIcon.iconset"

cleanup() {
    rm -rf "$VOICE_TYPE_TEMP_DIR"
}
trap cleanup EXIT

if [[ ! -f "$SOURCE_ICON" ]]; then
    echo "Icon source not found: $SOURCE_ICON" >&2
    exit 1
fi

RASTER_SOURCE="$SOURCE_ICON"
if [[ "${SOURCE_ICON:e:l}" == "svg" ]]; then
    sips -s format png "$SOURCE_ICON" --out "$MASTER_ICON" >/dev/null
    RASTER_SOURCE="$MASTER_ICON"
fi

mkdir -p "$ICONSET_DIR"

sips -z 16 16 "$RASTER_SOURCE" --out "$ICONSET_DIR/icon_16x16.png" >/dev/null
sips -z 32 32 "$RASTER_SOURCE" --out "$ICONSET_DIR/icon_16x16@2x.png" >/dev/null
sips -z 32 32 "$RASTER_SOURCE" --out "$ICONSET_DIR/icon_32x32.png" >/dev/null
sips -z 64 64 "$RASTER_SOURCE" --out "$ICONSET_DIR/icon_32x32@2x.png" >/dev/null
sips -z 128 128 "$RASTER_SOURCE" --out "$ICONSET_DIR/icon_128x128.png" >/dev/null
sips -z 256 256 "$RASTER_SOURCE" --out "$ICONSET_DIR/icon_128x128@2x.png" >/dev/null
sips -z 256 256 "$RASTER_SOURCE" --out "$ICONSET_DIR/icon_256x256.png" >/dev/null
sips -z 512 512 "$RASTER_SOURCE" --out "$ICONSET_DIR/icon_256x256@2x.png" >/dev/null
sips -z 512 512 "$RASTER_SOURCE" --out "$ICONSET_DIR/icon_512x512.png" >/dev/null
sips -z 1024 1024 "$RASTER_SOURCE" --out "$ICONSET_DIR/icon_512x512@2x.png" >/dev/null

iconutil -c icns "$ICONSET_DIR" -o "$OUTPUT_ICON"
mkdir -p "$OUTPUT_ICONSET_DIR"
ditto "$ICONSET_DIR" "$OUTPUT_ICONSET_DIR"
echo "$OUTPUT_ICON"
