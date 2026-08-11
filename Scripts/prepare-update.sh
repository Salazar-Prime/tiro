#!/bin/zsh

set -euo pipefail

SCRIPT_DIR=${0:A:h}
PROJECT_DIR=${SCRIPT_DIR:h}
APP_BUNDLE="$PROJECT_DIR/dist/Tiro.app"
PUBLISH_DIR="$PROJECT_DIR/dist/publish"
INFO_PLIST="$PROJECT_DIR/Resources/Info.plist"
SPARKLE_TOOLS="$PROJECT_DIR/.build/artifacts/sparkle/Sparkle/bin"
RELEASE_NOTES="$PROJECT_DIR/RELEASE_NOTES.md"
RELEASE_BRANCH=${TIRO_RELEASE_BRANCH:-${VOICE_TYPE_RELEASE_BRANCH:-beta}}

VERSION=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$INFO_PLIST")
BUILD=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' "$INFO_PLIST")
DISPLAY_VERSION=${VERSION/-beta./ Public Beta }
ARCHIVE_NAME="Tiro-$VERSION.zip"
NOTES_NAME="Tiro-$VERSION.md"
TAG="v$VERSION"

CURRENT_BRANCH=$(git -C "$PROJECT_DIR" branch --show-current)
if [[ "$CURRENT_BRANCH" != "$RELEASE_BRANCH" ]]; then
    echo "Updates must be prepared from the $RELEASE_BRANCH branch (currently $CURRENT_BRANCH)." >&2
    exit 1
fi

if [[ ! -s "$RELEASE_NOTES" ]]; then
    echo "Write short, human-readable notes in $RELEASE_NOTES first." >&2
    exit 1
fi

"$SCRIPT_DIR/build-app.sh"

mkdir -p "$PUBLISH_DIR"
find "$PUBLISH_DIR" -mindepth 1 -maxdepth 1 -delete
ditto -c -k --sequesterRsrc --keepParent "$APP_BUNDLE" "$PUBLISH_DIR/$ARCHIVE_NAME"
cp "$RELEASE_NOTES" "$PUBLISH_DIR/$NOTES_NAME"

if [[ -f "$PROJECT_DIR/appcast.xml" ]]; then
    cp "$PROJECT_DIR/appcast.xml" "$PUBLISH_DIR/appcast.xml"
fi

"$SPARKLE_TOOLS/generate_appcast" \
    --download-url-prefix "https://github.com/Salazar-Prime/tiro/releases/download/$TAG/" \
    --link "https://github.com/Salazar-Prime/tiro" \
    --versions "$BUILD" \
    --embed-release-notes \
    --maximum-versions 1 \
    "$PUBLISH_DIR"

cp "$PUBLISH_DIR/appcast.xml" "$PROJECT_DIR/appcast.xml"

echo "Prepared build $BUILD ($VERSION):"
echo "  $PUBLISH_DIR/$ARCHIVE_NAME"
echo "  $PROJECT_DIR/appcast.xml"
echo
echo "Publish after committing and pushing the source and appcast:"
echo "  gh release create $TAG '$PUBLISH_DIR/$ARCHIVE_NAME' --target '$RELEASE_BRANCH' --title 'Tiro $DISPLAY_VERSION' --prerelease --notes-file '$RELEASE_NOTES'"
