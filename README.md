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

Created October 5, 2026. v1.09 Built-In Animations is implemented and automatically verified; final user visual acceptance is pending. v1.08 remains the last fully accepted x.xx milestone; v1.10 onward and V2 remain planned. Projector output and physical checks remain deferred. Earlier milestone tags and releases remain preserved.

Open `app/ProjectionMapper/ProjectionMapper.xcodeproj` in Xcode-beta and press Command–R. The current local app is the v1.09.3 preview in `app/ProjectionMapper.app` and `builds/v1.09.3/ProjectionMapper.app`; the accepted v1.08 product and earlier builds remain preserved. See [Build and run](docs/BUILD_AND_RUN.md), [v1.08 verification](docs/V1.08_VERIFICATION.md) and [current progress](docs/PROGRESS.md).

The original ChatGPT project mirror at `/Users/keith/.codex/.chatgpt-projects/g-p-6ac32a4ca5b08191bfcf6bd28eb66008` remains a reference location. Do not edit its synced files.

## GitHub version history

Private repository: [Chosencode25/projection-mapper](https://github.com/Chosencode25/projection-mapper).

The first milestone is `v1.01`. Follow [GitHub workflow](docs/GITHUB_WORKFLOW.md) for branches, commits, milestone tags, and release downloads. See [Changelog](CHANGELOG.md) for completed version changes.

The v1.08 delivery is local only, without Git commits or GitHub uploads, as requested. Next: v1.09 built-in animations.

The installed local app includes v1.09.2: six built-in effects, shared playback and effect-specific settings. All 105 Debug/Release correctness tests pass. The user accepted v1.09.1 visuals; routine v1.09.2 visual feedback belongs to the user. See [current verification](docs/V1.09.2_VERIFICATION.md). Earlier local products are preserved.

Current installed preview: v1.09.3, with presets/reset, seeking/scrubbing and owner playback. All 111 Debug/Release correctness tests pass. Full v1.09 implementation is ready for user visual acceptance; Git/version delivery remains pending. See [current verification](docs/V1.09.3_VERIFICATION.md). Next: v1.10 Save & Load.
