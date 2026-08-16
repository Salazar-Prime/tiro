#!/bin/zsh

set -euo pipefail

SCRIPT_DIR=${0:A:h}
PROJECT_DIR=${SCRIPT_DIR:h}
INFO_PLIST="$PROJECT_DIR/Resources/Info.plist"
DEVELOPMENT_BRANCH=${TIRO_DEVELOPMENT_BRANCH:-beta}
PUBLISH_BRANCH=${TIRO_PUBLISH_BRANCH:-main}

CURRENT_BRANCH=$(git -C "$PROJECT_DIR" branch --show-current)
if [[ "$CURRENT_BRANCH" != "$DEVELOPMENT_BRANCH" ]]; then
    echo "Release snapshots must be created from the local $DEVELOPMENT_BRANCH branch (currently $CURRENT_BRANCH)." >&2
    exit 1
fi

if [[ -n "$(git -C "$PROJECT_DIR" status --porcelain)" ]]; then
    echo "Commit or stash every change on $DEVELOPMENT_BRANCH before creating a release snapshot." >&2
    exit 1
fi

if ! git -C "$PROJECT_DIR" show-ref --verify --quiet "refs/heads/$PUBLISH_BRANCH"; then
    echo "The local $PUBLISH_BRANCH branch does not exist." >&2
    exit 1
fi

VERSION=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$INFO_PLIST")
DISPLAY_VERSION=${VERSION/-beta./ Public Beta }
TAG="v$VERSION"

if git -C "$PROJECT_DIR" show-ref --verify --quiet "refs/tags/$TAG"; then
    echo "The release tag $TAG already exists." >&2
    exit 1
fi

DEVELOPMENT_TREE=$(git -C "$PROJECT_DIR" rev-parse "$DEVELOPMENT_BRANCH^{tree}")
PUBLISHED_COMMIT=$(git -C "$PROJECT_DIR" rev-parse "$PUBLISH_BRANCH")
PUBLISHED_TREE=$(git -C "$PROJECT_DIR" rev-parse "$PUBLISHED_COMMIT^{tree}")
if [[ "$DEVELOPMENT_TREE" == "$PUBLISHED_TREE" ]]; then
    echo "$PUBLISH_BRANCH already contains this exact source snapshot." >&2
    exit 1
fi

RELEASE_COMMIT=$(
    echo "Release Tiro $DISPLAY_VERSION" |
        git -C "$PROJECT_DIR" commit-tree "$DEVELOPMENT_TREE" -p "$PUBLISHED_COMMIT"
)
RELEASE_TREE=$(git -C "$PROJECT_DIR" rev-parse "$RELEASE_COMMIT^{tree}")
if [[ "$RELEASE_TREE" != "$DEVELOPMENT_TREE" ]]; then
    echo "The release commit does not exactly match $DEVELOPMENT_BRANCH; no refs were changed." >&2
    exit 1
fi

{
    echo start
    echo "update refs/heads/$PUBLISH_BRANCH $RELEASE_COMMIT $PUBLISHED_COMMIT"
    echo "create refs/tags/$TAG $RELEASE_COMMIT"
    echo prepare
    echo commit
} | git -C "$PROJECT_DIR" update-ref --stdin

echo "Created public release snapshot:"
echo "  $PUBLISH_BRANCH: $RELEASE_COMMIT"
echo "  $TAG: $RELEASE_COMMIT"
echo
echo "$DEVELOPMENT_BRANCH remains checked out locally with its complete development history."
echo "Review the release commit, then publish only $PUBLISH_BRANCH and $TAG:"
echo "  git push origin $PUBLISH_BRANCH refs/tags/$TAG"
