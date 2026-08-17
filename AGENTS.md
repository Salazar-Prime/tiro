# Repository instructions

These instructions apply to the entire Tiro repository, including work that updates the Android submodule.

## Public Git branches

- `main` is the only public working and integration branch for this repository.
- Push repository changes only to `main` unless the maintainer explicitly gives different instructions for a specific operation.
- Do not create or push `beta`, `alpha`, release, feature, or agent branches. A beta version name or release label is not a branch name.
- Treat any existing non-`main` local or remote branches as legacy state. Do not use, update, delete, merge, or publish them unless the maintainer explicitly asks.
- Do not force-push, push all branches, or publish tags or releases without explicit maintainer authorization.

## Android submodule

- The Android app is a separate public repository: `https://github.com/Salazar-Prime/tiro-android.git`.
- It is linked into this repository as the Git submodule at `android`, as declared in `.gitmodules`.
- Keep Android source changes inside `android`. Do not create a second `android-tiro` clone or copy inside the parent repository.
- The Android repository also uses `main` as its only public working branch.
- For an Android change, commit and push the Android repository's `main` first. Then update the parent repository's `android` gitlink to that exact published commit, commit the gitlink on the parent `main`, and push the parent `main`.
- Never record an unpublished Android commit in the parent repository.
- Do not replace the submodule with vendored files, a symlink, or a normal directory.

## Submodule checks

Before committing a parent gitlink update, verify:

```sh
git -C android status --short --branch
git -C android remote -v
git -C android rev-parse HEAD
git -C android rev-parse origin/main
git submodule status --recursive
```

The Android worktree must be clean, its `origin` must be `tiro-android`, and its `HEAD` must be present on `origin/main`. After the parent commit, `git submodule status` must not show a leading `+` or `-`.

For a new checkout, initialize the link with:

```sh
git clone --recurse-submodules https://github.com/Salazar-Prime/tiro.git
# Or, in an existing checkout:
git submodule sync --recursive
git submodule update --init --recursive
```

## Working tree safety

- Preserve unrelated maintainer changes in both repositories.
- Do not switch branches, rewrite history, clean untracked files, or reset either repository merely to make the worktree look clean.
- Stage the Android code in the Android repository and the submodule gitlink in the parent repository; never mix their commits.
