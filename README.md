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

Created October 5, 2026. v1.09 animations are backed up on GitHub main at 9e64c0a. v1.10 Save & Load is implemented locally and automatically verified; it is explicitly off GitHub. Routine visual acceptance belongs to the user. Projector output and physical checks remain deferred.

Open `app/ProjectionMapper/ProjectionMapper.xcodeproj` in required Xcode-beta and press Command–R. The local app is delivered at `app/ProjectionMapper.app`, with v1.10 product/evidence under `builds/v1.10/`. Use File > Save/Open to keep .projectionmap projects; loads start paused. See [v1.10 verification](docs/V1.10_VERIFICATION.md) and [progress](docs/PROGRESS.md).

The original ChatGPT project mirror at `/Users/keith/.codex/.chatgpt-projects/g-p-6ac32a4ca5b08191bfcf6bd28eb66008` remains a reference location. Do not edit its synced files.

## GitHub version history

Private repository: [Chosencode25/projection-mapper](https://github.com/Chosencode25/projection-mapper).

The first milestone is `v1.01`. Follow [GitHub workflow](docs/GITHUB_WORKFLOW.md) for branches, commits, milestone tags, and release downloads. See [Changelog](CHANGELOG.md) for completed version changes.

v1.09 source backup includes the accumulated multiple-surface and animation work, presets and seeking. No new release/tag/assets were published. v1.10 source and app remain local, without commits or uploads. Next: v1.11 Surface Controls.
