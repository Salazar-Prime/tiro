# App publishing directive

`alpha` is a local-only archive and must never be pushed. Prepare public betas on `beta`; keep `main` at the latest published release.

For every beta:

1. Use `0.x.0-beta.N` for `CFBundleShortVersionString` and increment `CFBundleVersion`.
2. Write `RELEASE_NOTES.md` in plain language: one short opening line and no more than three bullets.
3. Run `swift test`, then `./Scripts/prepare-update.sh` from `beta`.
4. Verify the app signature, archive, and generated `appcast.xml` before committing.
5. Push `beta`, create a GitHub prerelease with `RELEASE_NOTES.md`, then update `main` only after the release asset is live.
6. Keep only the latest public release and tag. The Sparkle feed also keeps only its latest item.

Do not use generated release notes. Sparkle release notes must stay brief and readable.
