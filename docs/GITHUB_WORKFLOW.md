# GitHub and Version History

Repository: https://github.com/Chosencode25/projection-mapper

Visibility: **Private**. Local working folder: `/Users/keith/Documents/Projection Mapping`.

## What is tracked

Track source code, Xcode project configuration, shared schemes, tests, project-owned assets, plans, verification notes, and progress. Local binaries, build caches, test-result bundles, and personal Xcode state are excluded by the root .gitignore.

Runnable builds belong in GitHub Releases as zipped assets, while local copies remain under builds/. Empty folders do not appear in Git history until they contain a tracked file.

## Branches and milestones

- `main` is the latest tested milestone.
- Develop the next milestone on a branch such as `feature/v1.02-output-selection`.
- Make small commits explaining meaningful changes.
- Build and test with **Xcode 27.0 beta 5 (27A5237l)** before merging into main.
- Update docs/PROGRESS.md, the verification record, and CHANGELOG.md.
- Push main and create an annotated milestone tag such as `v1.02`.
- Publish a release for that tag with notes and the verified runnable app archive.
- Preserve existing milestone tags and release assets; corrections get a new version instead of replacing an old snapshot.

The first preserved milestone is **v1.01 — App Skeleton**, a development prerelease. It includes the code and a local Apple Silicon build. Saving, media import, mapping, and output windows are later milestones.

## Accessing a past version

Use the repository's Releases page to download its source snapshot or runnable app archive. In Git, a tag identifies the exact saved commit. For experimentation with old source, create a separate worktree or branch from the tag so current work remains intact.

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
