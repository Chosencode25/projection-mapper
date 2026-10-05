# GitHub and Version History

Repository: https://github.com/Chosencode25/projection-mapper

Visibility: **Private**. Local working folder: `/Users/keith/Documents/Projection Mapping`.

## What is tracked

Track source code, Xcode project configuration, shared schemes, tests, project-owned assets, plans, verification notes, and progress. Local binaries, build caches, test-result bundles, and personal Xcode state are excluded by the root .gitignore.

Runnable builds belong in GitHub Releases as zipped assets, while local copies remain under builds/. Empty folders do not appear in Git history until they contain a tracked file.

## Branches and milestones

- `main` is the latest verified project state; small verified changes can advance it without a release.
- Develop the next milestone on a branch such as `feature/v1.02-output-selection`.
- Make small commits explaining meaningful changes.
- Verify code changes with **Xcode 27.0 beta 5 (27A5237l)** before merging into main; choose checks appropriate to the change. Documentation-only changes do not require an app build.
- Keep docs/PROGRESS.md accurate after meaningful work. Update verification notes and CHANGELOG.md when the change warrants them; avoid release paperwork for tiny changes.
- Commit and push meaningful completed changes so the user can recover previous source versions through Git history. This is sufficient for small fixes and minuscule changes; do not automatically bump versions, tag, package an app, or publish a release.
- For substantial milestones or when the user asks for a release, create an annotated tag and publish notes with a verified runnable app archive.
- Preserve existing milestone tags and release assets; corrections get a new version instead of replacing an old snapshot.

The first preserved milestone is **v1.01 — App Skeleton**, a development prerelease. It includes the code and a local Apple Silicon build. Saving, media import, mapping, and output windows are later milestones.

## Accessing a past version

Use the repository's Releases page to download its source snapshot or runnable app archive. Every pushed commit preserves a recoverable source snapshot, even without a tag or release. Browse the repository commit history or use git log to find it. For experimentation with old source, create a separate worktree or branch from its commit or tag so current work remains intact. Rebuilding an unarchived version requires the pinned toolchain.

## Toolchain checks

The current GitHub setup does not use a cloud build runner because the project requires a specific Xcode beta. Verification is performed locally with the pinned toolchain. A later CI setup must first establish that the required Xcode build is available.

## Useful commands

Run from the local working folder:

```sh
git status
git log --oneline --decorate
git tag --list
git push origin main
git push origin v1.02
```

Commit changes before pushing. Push a milestone tag only after verifying that it points to the intended tested commit.
