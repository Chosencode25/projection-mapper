# GitHub and Version History

Repository: https://github.com/Chosencode25/projection-mapper

Visibility: **Private**. Local working folder: `/Users/keith/Documents/Projection Mapping`.

## What is tracked

Track source code, Xcode project configuration, shared schemes, tests, project-owned assets, plans, verification notes, and progress. Local binaries, build caches, test-result bundles, and personal Xcode state are excluded by the root .gitignore.

Runnable builds belong in GitHub Releases as zipped assets, while local copies remain under builds/. Empty folders do not appear in Git history until they contain a tracked file.

## Branches and milestones

- `main` is the latest delivered, tested x.xx app milestone. Intermediate planning, fixes and implementation slices stay local until a new x.xx milestone is completed.
- Develop the next milestone on a branch such as `feature/v1.02-output-selection`.
- At the completed x.xx milestone boundary, make clear commits explaining the accumulated verified changes. Do not make intermediate commits solely for planning edits, small fixes or x.xx.x slices under the current user policy.
- Verify code changes with **Xcode 27.0 beta 5 (27A5237l)** before merging into main; choose checks appropriate to the change. Documentation-only changes do not require an app build.
- Keep docs/PROGRESS.md accurate after meaningful work. Update verification notes and CHANGELOG.md when the change warrants them; avoid release paperwork for tiny changes.
- User policy effective October 5, 2026: perform Git commits/pushes and GitHub uploads only for a newly completed app version at the x.xx milestone level (such as v1.08 or v2.01), unless the user explicitly requests an exception. Keep intermediate files local; do not bump versions to manufacture an upload boundary. Read-only Git inspection and local feature-branch setup remain available. Record pending delivery accurately in progress notes.
- Eligibility for milestone delivery does not automatically authorize a release/tag/asset upload. When a release is requested or included in the approved milestone delivery, publish notes and a verified runnable app archive with an annotated tag. An explicit user request can override the normal cadence.
- Preserve existing milestone tags and release assets; corrections get a new version instead of replacing an old snapshot.

The first preserved milestone is **v1.01 — App Skeleton**, a development prerelease. It includes the code and a local Apple Silicon build. Saving, media import, mapping, and output windows are later milestones.

## Known remote state

The user states this agent is the only person changing GitHub. Rely on local repository history and the last confirmed remote state for work created in this project. Do not routinely browse GitHub, fetch, pull or poll merely to rediscover known commits, plans, tags or releases. A successful push result confirms that delivery without a separate GitHub inspection.

Use remote checks when required information is not known locally, a command reports a conflict/failure, there is concrete evidence of outside changes, or the user explicitly asks. Preserve the x.xx-only delivery cadence; this preference does not authorize intermediate commits or uploads.

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
