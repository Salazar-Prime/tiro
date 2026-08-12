# App publishing directive

`alpha` is a local-only archive and must never be pushed. The local `beta` branch is only for preparing releases: merge it into `main`, and publish release source and appcasts from `main`.

Public Beta 1–3 were shipped with a legacy `/beta/appcast.xml` URL. A frozen remote `beta` compatibility branch mirrors Public Beta 4 so those installations can reach the corrected updater. Do not use or advance that remote branch for development; builds from Public Beta 4 onward read the feed from `main`.

For every beta:

1. Use `0.x.0-beta.N` for `CFBundleShortVersionString` and increment `CFBundleVersion`.
2. Write `RELEASE_NOTES.md` in plain language: one short opening line and no more than three bullets.
3. Run `swift test`, then `./Scripts/prepare-update.sh` from the local `beta` branch. It creates a ZIP for Sparkle updates and a DMG for first-time/manual installation.
4. Verify the app signature, ZIP, DMG, and generated `appcast.xml`, then commit the release on `beta`.
5. Merge `beta` into `main`, push only `main`, and create the GitHub prerelease from `main` with `RELEASE_NOTES.md`.
6. Confirm the release assets are live before treating `main` as published. Keep only the latest public release and tag; the Sparkle feed also keeps only its latest item.

Do not use generated release notes. Sparkle release notes must stay brief and readable.

The GitHub prerelease must include both generated assets. Sparkle continues to use the ZIP; do not replace its enclosure with the DMG.

Never push `alpha` or the local `beta` development history, and never target a GitHub release at either local branch. The frozen remote `beta` compatibility branch is the sole exception described above.
