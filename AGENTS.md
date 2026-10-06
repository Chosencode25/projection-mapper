# Projection Mapping project instructions

- This folder is the main working location for the project. Keep source code in app/, plans and progress in docs/, project-owned media in assets/, and build outputs in builds/.
- Read docs/PROJECT_DEVELOPMENT.md and the applicable milestone plan before making changes.
- The required toolchain for the entire project is **Xcode 27.0 beta 5 (27A5237l)**. Verify the exact installed build and use it for builds and checks. Do not silently migrate to another version.
- Implement the interface entirely in Swift code using SwiftUI and programmatic AppKit where needed. No storyboards or XIBs, and no required visual interface construction.
- Preserve Test Mode in the roadmap: output selection in v1.02, a separate resizable output window in v1.03, and a renderer shared with projector mode in v1.04.
- Keep docs/PROGRESS.md accurate after meaningful project work. Distinguish planned work from implemented and verified work.
- User preference: routine visual checks are performed by the user until they say otherwise. Make changes and run automated checks without screen control; use the screen only to investigate a specific expected bug. Record user-reported visual acceptance separately from automated verification.
- The original ChatGPT project mirror and its synced sources are read-only references. Do not edit, move, rename, or delete them.

## GitHub workflow

- Repository: https://github.com/Chosencode25/projection-mapper (private).
- Read docs/GITHUB_WORKFLOW.md before version-control or release work.
- The user states this agent is the only GitHub writer. Use local history and the last confirmed remote state for known contents; do not routinely browse GitHub, fetch or poll to rediscover work already created here. Check remotely only for unknown state, an operation failure/conflict, evidence of outside changes, or an explicit user request.
- Keep main as the latest tested milestone; use a feature branch for subsequent milestones.
- Keep CHANGELOG.md and progress/verification notes accurate. Preserve published milestone tags and release assets.
- Keep generated builds, caches, test-result bundles, and personal Xcode state out of commits. Store downloadable app archives as release assets.

- User policy updated October 5, 2026: keep intermediate work local. Perform Git commits/pushes and GitHub uploads only when a new app milestone at the x.xx level (for example v1.08 or v2.01) is completed, or when the user explicitly requests an exception. Planning edits, small fixes and x.xx.x slices do not trigger version-control delivery. Do not bump a version merely to permit an upload. An eligible milestone does not automatically authorize publishing a release. Preserve existing history.
