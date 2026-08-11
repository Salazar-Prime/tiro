# App publishing directive

Use `alpha` only as the frozen `0.4.4` snapshot. Prepare public betas on `beta`; keep `main` at the latest published release so older alpha builds can still find the new Sparkle update.

For every beta:

1. Use `0.x.0-beta.N` for `CFBundleShortVersionString` and increment `CFBundleVersion`.
2. Write `RELEASE_NOTES.md` in plain language: one short opening line and no more than three bullets.
3. Run `swift test`, then `./Scripts/prepare-update.sh` from `beta`.
4. Verify the app signature, archive, and generated `appcast.xml` before committing.
5. Push `beta`, create a GitHub prerelease with `RELEASE_NOTES.md`, then fast-forward `main` only after the release asset is live.

Do not use generated release notes. Sparkle release notes must stay brief and readable.
