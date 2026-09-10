#!/bin/zsh

set -euo pipefail

SCRIPT_DIR=${0:A:h}
PROJECT_DIR=${SCRIPT_DIR:h}
INFO_PLIST="$PROJECT_DIR/Resources/Info.plist"
PUBLISH_BRANCH=${TIRO_PUBLISH_BRANCH:-main}

CURRENT_BRANCH=$(git -C "$PROJECT_DIR" branch --show-current)
if [[ "$CURRENT_BRANCH" != "$PUBLISH_BRANCH" ]]; then
    echo "Release tags must be created from $PUBLISH_BRANCH (currently $CURRENT_BRANCH)." >&2
    exit 1
fi

if [[ -n "$(git -C "$PROJECT_DIR" status --porcelain)" ]]; then
    echo "Commit every intended release change on $PUBLISH_BRANCH before creating the tag." >&2
    exit 1
fi

VERSION=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$INFO_PLIST")
DISPLAY_VERSION=${VERSION/-beta./ Public Beta }
TAG="v$VERSION"

if git -C "$PROJECT_DIR" show-ref --verify --quiet "refs/tags/$TAG"; then
    echo "The release tag $TAG already exists." >&2
    exit 1
fi

git -C "$PROJECT_DIR" tag "$TAG" HEAD

echo "Tagged the current $PUBLISH_BRANCH release commit:"
echo "  $TAG: $(git -C "$PROJECT_DIR" rev-parse HEAD)"
echo
echo "Review the release commit and tag, then publish them:"
echo "  git push origin $PUBLISH_BRANCH refs/tags/$TAG"
echo "  gh release create $TAG --verify-tag --title 'Tiro $DISPLAY_VERSION' --prerelease --notes-file '$PROJECT_DIR/RELEASE_NOTES.md'"
