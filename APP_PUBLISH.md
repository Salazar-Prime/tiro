# App publishing directive

`main` is Tiro’s only working, integration, and public release branch. Do not create, switch to, or push `alpha`, `beta`, release, feature, or agent branches. Any existing non-`main` branches are legacy state and must not be changed unless the maintainer explicitly requests it.

Public Beta 1–3 were shipped with a legacy `/beta/appcast.xml` URL. A frozen remote `beta` compatibility branch mirrors Public Beta 4 so those installations can reach the corrected updater. Do not use or advance that branch; builds from Public Beta 4 onward read the feed from `main`.

For every beta:

1. Work on `main`. Preserve unrelated maintainer changes and make one release commit containing the finished source, documentation, version metadata, and update feed.
2. Use `0.x.0-beta.N` for `CFBundleShortVersionString` and increment `CFBundleVersion`.
3. Write `RELEASE_NOTES.md` in plain language: one short opening line and no more than three bullets.
4. Run `swift test`, then `./Scripts/prepare-update.sh`. It creates a ZIP for Sparkle updates and a DMG for first-time or manual installation.
5. Verify the app signature, ZIP, DMG, and generated `appcast.xml`, then commit the finished release state on `main`.
6. Run `./Scripts/promote-release.sh` to validate the clean `main` release commit and create the matching version tag.
7. Review the commit and tag, push only `main` and that tag, and create the GitHub prerelease with `RELEASE_NOTES.md`.
8. Confirm both release assets and the update feed are public before treating the release as published. Keep every public version tag; the Sparkle feed itself keeps only its latest item.

Do not use generated release notes. Sparkle release notes must stay brief and readable.

The GitHub prerelease must include both generated assets. Sparkle uses the ZIP enclosure; do not replace it with the DMG.

Preparation does not authorize publication. Push `main`, create the version tag, upload assets, and publish the GitHub prerelease only when the maintainer explicitly requests a release.
