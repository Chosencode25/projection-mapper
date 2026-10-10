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

## Latest confirmed source milestone — October 6, 2026

v1.11 Surface Controls (bundle 1.11/build 8) is tested and backed up on main at **87459a8**, successful push from 55d242c. All 184 correctness tests passed in Debug and Release; user visuals remain pending. A documentation-only delivery record follows that tested source commit. No new release/tag/app assets were published; latest release remains v1.04.2. Next milestone v1.12 starts on a new codex/ feature branch.

## Latest confirmed source milestone — October 7, 2026

v1.12 Mapping Tools (bundle 1.12/build 9, package format 6) is tested and backed up on main at **b786f55**, successfully pushed from 03c9a45 after fast-forwarding codex/v1.12-mapping-tools. All 225 offscreen correctness tests passed in Debug/Release; four benchmarks skipped and two visible-window tests excluded. Tested universal signed app installed locally and previous preview preserved. User visuals remain pending. A documentation-only delivery record follows the tested source commit; no release/tag/assets published. Latest published release remains v1.04.2. Next milestone is v1.13 Image Import; start a codex/ feature branch before implementing it, retaining the milestone-only Git cadence.


## Latest confirmed source milestone — October 9, 2026

v1.13 Image Import (bundle 1.13/build 10, package format 7), including the earlier local UI improvements, is tested and backed up on main at **6dfd076**, successfully pushed from 4e92123 after fast-forwarding codex/v1.13-image-import. All 239 correctness tests passed in Debug/Release; four optional benchmarks skipped and two legacy visible-window checks excluded. Tested universal signed app installed locally; prior installed app preserved. User visuals remain pending. Documentation-only delivery notes follow the tested source commit. No new release/tag/assets published; latest published release remains v1.04.2. Next milestone: v1.14 Video Import, on a new codex/ feature branch.

## Latest confirmed source milestone — October 9, 2026 — v1.14

v1.14 Video Import and Timeline Integration (bundle 1.14/build 11, portable format 9), including the earlier local object timeline and planning changes, is tested and backed up on main at **ccb5df2**, successfully pushed from 7c84178 after fast-forwarding codex/v1.14-video-timeline. Final Debug/Release each passed 258 correctness tests; four optional benchmarks skipped and two visible-window tests excluded. A dedicated final 13-test Release video run passed with 30-second shared/independent 1080p workloads. Tested signed universal app installed locally; previous installed app preserved; portable self-generated demo tracked under assets/demos/. User visual/listening checks remain pending. Documentation-only delivery notes follow the tested source commit. No release/tag/app assets published; latest release remains v1.04.2. Next milestone is v1.15 undo/redo, readiness and polish; start a codex/ feature branch from tested main and keep slices local.

## Latest confirmed source milestone — October 10, 2026 — v1.15

v1.15 V1 Completion (bundle 1.15/build 12, portable format 9) is tested and backed up on main at **60e838d**, successfully pushed from 29ad795 after fast-forwarding codex/v1.15-final-polish. Final Debug/Release each passed 269 correctness tests, zero failures/runtime warnings, with four optional benchmarks skipped and two legacy visible-window tests excluded. Sustained mixed HD playback (two 60-second cases) and the full-resolution effects/overlap matrix passed. Strict signatures, universal slices, all app/ZIP extraction file hashes and canonical bundled demo were verified. Installed app and local development ZIP are under app/ and builds/v1.15/; v1.14 is preserved. User visuals/listening, Intel/older-macOS runtime, physical projector and Developer ID/notarization remain pending/unverified. Documentation-only delivery records follow this tested source commit. No release/tag/app upload or visibility change was made; latest published release remains v1.04.2. V1 implementation is complete; next development is v2.01 on a new codex/ feature branch.

## Full V1 release finalization — October 10, 2026

Published [Projection Mapper V1 — v1.15](https://github.com/Chosencode25/projection-mapper/releases/tag/v1.15) at 2026-10-10 22:29:38 UTC as the latest full release (not draft or prerelease). The private repository visibility is verified unchanged. Annotated tag **v1.15** points to **17a4647**, whose app sources match tested **60e838d**; 1.15/build 12 and format 9 are unchanged. Earlier tags/releases/assets are preserved.

Assets: ProjectionMapper-v1.15-macOS-universal.zip, SHA256SUMS.txt, V1_USER_GUIDE.md and Build-identity.json. All four were downloaded from GitHub before publication and matched their local bytes. Archive SHA-256: **f32cc9731ff0c3e93a3202c2c09dfb82be8ceb0560d23177b27fe67a22310a26**. Extracted app files matched every tested Release file and strict signature verification passed. Universal slices and bundle identity were checked. Local evidence is under builds/v1.15/V1-release/, including Published-release.json, Remote-tag.json and Repository-visibility.json. The verified app copy was restored to app/ProjectionMapper.app without launching it or using screen control. No code changed, so existing 269 passing tests per configuration and profile results remain applicable.

Developer ID/notarization, Intel/older-macOS runtime and user visual/listening acceptance remain unestablished. Physical fullscreen output and music/show features remain V2. The separate canonical demo has local deletions that are preserved unstaged; its tracked bytes match the intact bundled demo. Release documentation was committed separately without those deletions.
