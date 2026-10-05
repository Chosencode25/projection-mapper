# Projection Mapping

This is the main working folder for the Projection Mapping Mac app.

The app will let you map images, videos, and built-in animations onto physical surfaces using draggable corner nodes, with a separate test or projector output window.

## Start here

- [Development requirements](docs/PROJECT_DEVELOPMENT.md): exact Xcode version and code-based interface requirements.
- [v1.01 plan](docs/V1.01_PLAN.md): first milestone scope, implementation steps, and completion criteria.
- [V1 roadmap](docs/V1_ROADMAP.md): all 15 milestones, including Test Mode.
- [v1.02 plan](docs/V1.02_PLAN.md): output selection and display discovery; implemented, physical acceptance pending.
- [v1.03.1 plan](docs/V1.03.1_PLAN.md): basic Test Window, controls, and lifecycle.
- [v1.03.2 plan](docs/V1.03.2_PLAN.md): saved resolution presets and aspect-preserving scaling.
- [v1.03.3 plan](docs/V1.03.3_PLAN.md): saved window frame, recovery, and navigation.
- [Progress tracker](docs/PROGRESS.md): current status, completed work, and next steps.

## Folder organization

- `app/`: Xcode project and source code.
- `docs/`: plans, decisions, and progress notes.
- `assets/`: project-owned icons, images, and example media.
- `builds/`: local development builds and later packaged releases.

Required toolchain: **Xcode 27.0 beta 5 (27A5237l)**.

Created October 5, 2026. v1.03.3 adds saved window position/size, offscreen recovery, and navigation shortcuts to the Test Window. Projector output and physical checks are deferred. Earlier milestone tags and releases remain preserved.

Open `app/ProjectionMapper/ProjectionMapper.xcodeproj` in Xcode-beta and press Command–R. The current preview build is in `builds/v1.03.3/ProjectionMapper.app`; the earlier v1.01 build is preserved. See [Build and run](docs/BUILD_AND_RUN.md) and [Current verification](docs/PROGRESS.md#v1033-implementation).

The original ChatGPT project mirror at `/Users/keith/.codex/.chatgpt-projects/g-p-6ac32a4ca5b08191bfcf6bd28eb66008` remains a reference location. Do not edit its synced files.

## GitHub version history

Private repository: [Chosencode25/projection-mapper](https://github.com/Chosencode25/projection-mapper).

The first milestone is `v1.01`. Follow [GitHub workflow](docs/GITHUB_WORKFLOW.md) for branches, commits, milestone tags, and release downloads. See [Changelog](CHANGELOG.md) for completed version changes.
