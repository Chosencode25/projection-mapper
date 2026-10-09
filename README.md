# Projection Mapping

This is the main working folder for the Projection Mapping Mac app.

The planned app maps images, videos and built-in animations onto independent surfaces or connected object faces. V1 builds a reusable mapping workspace with Test Mode; V2 adds music sequencing and show playback. Fullscreen projector implementation/physical acceptance is scheduled for v2.01, preserving the current hardware deferral.

## Start here

- [Development requirements](docs/PROJECT_DEVELOPMENT.md): exact Xcode version and code-based interface requirements.
- [v1.01 plan](docs/V1.01_PLAN.md): first milestone scope, implementation steps, and completion criteria.
- [V1 roadmap](docs/V1_ROADMAP.md): all 15 milestones, including Test Mode and show foundations.
- [Remaining V1 steps](docs/V1_REMAINING_PLAN.md): v1.08 completion and planned work from v1.09 through v1.15.
- [V2 roadmap](docs/V2_ROADMAP.md): music, choreography, integration and show operation.
- [V2 implementation steps](docs/V2_IMPLEMENTATION_PLAN.md): ordered work, acceptance gates and later backlog.
- [v1.02 plan](docs/V1.02_PLAN.md): output selection and display discovery; implemented, physical acceptance pending.
- [v1.03.1 plan](docs/V1.03.1_PLAN.md): basic Test Window, controls, and lifecycle.
- [v1.03.2 plan](docs/V1.03.2_PLAN.md): saved resolution presets and aspect-preserving scaling.
- [v1.03.3 plan](docs/V1.03.3_PLAN.md): saved window frame, recovery, and navigation.
- [v1.04 plan](docs/V1.04_PLAN.md): five renderer slices, from Metal foundation through performance acceptance.
- [Progress tracker](docs/PROGRESS.md): current status, completed work, and next steps.

## Folder organization

- `app/`: Xcode project and source code.
- `docs/`: plans, decisions, and progress notes.
- `assets/`: project-owned icons, images, and example media.
- `builds/`: local development builds and later packaged releases.

Required toolchain: **Xcode 27.0 beta 5 (27A5237l)**.

Created October 5, 2026. **v1.12 Mapping Tools is implemented and automatically verified:** appearance/looks/palettes and master output controls from v1.11, plus calibration, polygon masks/cutouts, editor guide visibility/labels and shared-canvas join inspection. All **225 offscreen correctness tests passed in Debug and Release**; four optional benchmarks skipped and two visible-window tests excluded. User visual acceptance remains pending. Physical projector output remains deferred.

Open app/ProjectionMapper/ProjectionMapper.xcodeproj in required Xcode-beta and press Command–R, or use the tested **1.12/build 9** app at app/ProjectionMapper.app. Archived app: builds/v1.12/ProjectionMapper.app; evidence: builds/v1.12.3/. Quit/reopen a running older app to use the new binary. The toolbar eye menu controls handles/outlines/names/edge labels; the object inspector offers stripe/checker join inspection. Masks and calibration remain shared between preview and Test Window. Save/Open uses format 6 .projectionmap packages, migrates formats 1–5, and restores safe runtime defaults. Older app copies cannot open new format 6 packages. See [current verification](docs/V1.12.3_VERIFICATION.md) and [progress](docs/PROGRESS.md).

The original ChatGPT project mirror at `/Users/keith/.codex/.chatgpt-projects/g-p-6ac32a4ca5b08191bfcf6bd28eb66008` remains a reference location. Do not edit its synced files.

## GitHub version history

Private repository: [Chosencode25/projection-mapper](https://github.com/Chosencode25/projection-mapper).

The first milestone is `v1.01`. Follow [GitHub workflow](docs/GITHUB_WORKFLOW.md) for branches, commits, milestone tags, and release downloads. See [Changelog](CHANGELOG.md) for completed version changes.

Completed v1.12 tested source is backed up on GitHub main at b786f55, successfully pushed from 03c9a45. Delivery documentation follows that source commit. Earlier v1.11 at 87459a8 and v1.10 at 55d242c remain preserved. No new release/tag/assets are authorized. Next: v1.13 Image Import.


## Current app — v1.13 Image Import

Open app/ProjectionMapper.app (version 1.13/build 10). Quit/reopen an older running instance to use it. PNG/JPEG imports, linked-face image placement, portable image saves and the editor-only reference photo are implemented, alongside the improved top bar and Edit/Show/Project inspector. All 239 offscreen correctness tests passed in Debug/Release; user visual checks remain pending. See [image instructions](docs/IMAGE_IMPORT_GUIDE.md), [verification](docs/V1.13_VERIFICATION.md) and [milestone plan](docs/V1.13_PLAN.md). Next: v1.14 Video Import. No new release requested.
