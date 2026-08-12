#!/bin/zsh

set -euo pipefail

SCRIPT_DIR=${0:A:h}
PROJECT_DIR=${SCRIPT_DIR:h}
APP_BUNDLE="$PROJECT_DIR/dist/Tiro.app"
CONTENTS_DIR="$APP_BUNDLE/Contents"
FRAMEWORKS_DIR="$CONTENTS_DIR/Frameworks"

cd "$PROJECT_DIR"
swift build -c release

rm -rf "$APP_BUNDLE"
mkdir -p "$CONTENTS_DIR/MacOS" "$CONTENTS_DIR/Resources" "$FRAMEWORKS_DIR"
cp "$PROJECT_DIR/.build/release/VoiceType" "$CONTENTS_DIR/MacOS/VoiceType"
cp "$PROJECT_DIR/Resources/Info.plist" "$CONTENTS_DIR/Info.plist"
cp "$PROJECT_DIR/Resources/AppIcon.icns" "$CONTENTS_DIR/Resources/AppIcon.icns"
cp "$PROJECT_DIR/Resources/ThirdPartyNotices.txt" "$CONTENTS_DIR/Resources/ThirdPartyNotices.txt"

SPARKLE_FRAMEWORK=$(find "$PROJECT_DIR/.build" -path '*/release/Sparkle.framework' -print -quit)
if [[ -z "$SPARKLE_FRAMEWORK" ]]; then
    echo "Sparkle.framework was not produced by Swift Package Manager" >&2
    exit 1
fi
ditto "$SPARKLE_FRAMEWORK" "$FRAMEWORKS_DIR/Sparkle.framework"

WHISPER_FRAMEWORK=$(find "$PROJECT_DIR/.build" -path '*/release/whisper.framework' -print -quit)
if [[ -z "$WHISPER_FRAMEWORK" ]]; then
    echo "whisper.framework was not produced by Swift Package Manager" >&2
    exit 1
fi
ditto "$WHISPER_FRAMEWORK" "$FRAMEWORKS_DIR/whisper.framework"

if [[ -n "${TIRO_SIGNING_IDENTITY:-}" ]]; then
    SIGNING_IDENTITY="$TIRO_SIGNING_IDENTITY"
elif [[ -n "${VOICE_TYPE_SIGNING_IDENTITY:-}" ]]; then
    SIGNING_IDENTITY="$VOICE_TYPE_SIGNING_IDENTITY"
elif security find-identity -v -p codesigning | grep -Fq '"Voice Type Local Signing"'; then
    SIGNING_IDENTITY="Voice Type Local Signing"
else
    SIGNING_IDENTITY="-"
    echo "Warning: no stable signing identity found; macOS permissions may not survive updates." >&2
fi
codesign --force --deep --sign "$SIGNING_IDENTITY" "$APP_BUNDLE"

echo "$APP_BUNDLE"
