# Projection Mapping project instructions

- This folder is the main working location for the project. Keep source code in app/, plans and progress in docs/, project-owned media in assets/, and build outputs in builds/.
- Read docs/PROJECT_DEVELOPMENT.md and the applicable milestone plan before making changes.
- The required toolchain for the entire project is **Xcode 27.0 beta 5 (27A5237l)**. Verify the exact installed build and use it for builds and checks. Do not silently migrate to another version.
- Implement the interface entirely in Swift code using SwiftUI and programmatic AppKit where needed. No storyboards or XIBs, and no required visual interface construction.
- Preserve Test Mode in the roadmap: output selection in v1.02, a separate resizable output window in v1.03, and a renderer shared with projector mode in v1.04.
- Keep docs/PROGRESS.md accurate after meaningful project work. Distinguish planned work from implemented and verified work.
- The original ChatGPT project mirror and its synced sources are read-only references. Do not edit, move, rename, or delete them.

## GitHub workflow

- Repository: https://github.com/Chosencode25/projection-mapper (private).
- Read docs/GITHUB_WORKFLOW.md before version-control or release work.
- Keep main as the latest tested milestone; use a feature branch for subsequent milestones.
- Keep CHANGELOG.md and progress/verification notes accurate. Preserve published milestone tags and release assets.
- Keep generated builds, caches, test-result bundles, and personal Xcode state out of commits. Store downloadable app archives as release assets.
