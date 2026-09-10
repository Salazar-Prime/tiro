#!/bin/zsh

set -euo pipefail

SCRIPT_DIR=${0:A:h}
PROJECT_DIR=${SCRIPT_DIR:h}
APP_BUNDLE="$PROJECT_DIR/dist/Tiro.app"
PUBLISH_DIR="$PROJECT_DIR/dist/publish"
INFO_PLIST="$PROJECT_DIR/Resources/Info.plist"
SPARKLE_TOOLS="$PROJECT_DIR/.build/artifacts/sparkle/Sparkle/bin"
RELEASE_NOTES="$PROJECT_DIR/RELEASE_NOTES.md"
PREPARE_BRANCH=${TIRO_PREPARE_BRANCH:-${VOICE_TYPE_PREPARE_BRANCH:-main}}
PUBLISH_BRANCH=${TIRO_PUBLISH_BRANCH:-${VOICE_TYPE_PUBLISH_BRANCH:-main}}

VERSION=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$INFO_PLIST")
BUILD=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' "$INFO_PLIST")
DISPLAY_VERSION=${VERSION/-beta./ Public Beta }
ARCHIVE_NAME="Tiro-$VERSION.zip"
DMG_NAME="Tiro-$VERSION.dmg"
NOTES_NAME="Tiro-$VERSION.md"
TAG="v$VERSION"

CURRENT_BRANCH=$(git -C "$PROJECT_DIR" branch --show-current)
if [[ "$CURRENT_BRANCH" != "$PREPARE_BRANCH" ]]; then
    echo "Updates must be prepared from the local $PREPARE_BRANCH branch (currently $CURRENT_BRANCH)." >&2
    exit 1
fi

FEED_URL=$(/usr/libexec/PlistBuddy -c 'Print :SUFeedURL' "$INFO_PLIST")
EXPECTED_FEED_URL="https://raw.githubusercontent.com/Salazar-Prime/tiro/$PUBLISH_BRANCH/appcast.xml"
if [[ "$FEED_URL" != "$EXPECTED_FEED_URL" ]]; then
    echo "SUFeedURL must use the published $PUBLISH_BRANCH branch: $EXPECTED_FEED_URL" >&2
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

# Sparkle updates use the ZIP above. Build the DMG afterwards so it remains a
# separate first-time/manual-install asset and is not considered for the feed.
"$SCRIPT_DIR/create-dmg.sh" "$APP_BUNDLE" "$PUBLISH_DIR/$DMG_NAME"

echo "Prepared build $BUILD ($VERSION):"
echo "  $PUBLISH_DIR/$ARCHIVE_NAME"
echo "  $PUBLISH_DIR/$DMG_NAME"
echo "  $PROJECT_DIR/appcast.xml"
echo
echo "After verifying these files, commit the release state on $PREPARE_BRANCH and create its version tag:"
echo "  ./Scripts/promote-release.sh"
echo "Then push only $PUBLISH_BRANCH and $TAG, and publish the prerelease:"
echo "  git push origin $PUBLISH_BRANCH refs/tags/$TAG"
echo "  gh release create $TAG '$PUBLISH_DIR/$ARCHIVE_NAME' '$PUBLISH_DIR/$DMG_NAME' --verify-tag --title 'Tiro $DISPLAY_VERSION' --prerelease --notes-file '$RELEASE_NOTES'"
