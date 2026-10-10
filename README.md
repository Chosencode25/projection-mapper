# Projection Mapping

This is the main working folder for the Projection Mapping Mac app.

The V1 app maps images, videos and built-in animations onto independent surfaces or connected object faces. V1 builds a reusable mapping workspace with Test Mode; V2 adds music sequencing and show playback. Fullscreen projector implementation/physical acceptance is scheduled for v2.01, preserving the current hardware deferral.

## Start here

- [Development requirements](docs/PROJECT_DEVELOPMENT.md): exact Xcode version and code-based interface requirements.
- [v1.01 plan](docs/V1.01_PLAN.md): first milestone scope, implementation steps, and completion criteria.
- [V1 roadmap](docs/V1_ROADMAP.md): all 15 milestones, including Test Mode and show foundations.
- [V1 guide](docs/V1_USER_GUIDE.md): mapping, timeline, undo, readiness, demo and portable files.
- [V1 verification](docs/V1.15_VERIFICATION.md): completed implementation, automated evidence and pending user acceptance.
- [V1 implementation contracts](docs/V1_REMAINING_PLAN.md): completed milestone scope and separate publication gates.
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

**Current app: Projection Mapper V1 — v1.15.1/build 13.** Open app/ProjectionMapper.app, or download the universal app from the [full V1 release](https://github.com/Chosencode25/projection-mapper/releases/tag/v1.15.1). macOS 15 or later; locally ad-hoc signed, not Apple-notarized. Quit/reopen an older running copy.

V1 includes independent/connected faces, mapping/masks/calibration, animations, looks/palettes, image/reference-photo and video import, explicit video audio, object timeline, portable saves/recovery, undo/redo, readiness and a protected demo. Format 9 migrates formats 1–8. Both Debug and Release passed 269 correctness tests; user visual/listening acceptance remains pending. See the [V1 guide](docs/V1_USER_GUIDE.md) and [verification](docs/V1.15_VERIFICATION.md). Next development: v2.01 physical projector output; music/show features follow in V2.

The original ChatGPT project mirror at `/Users/keith/.codex/.chatgpt-projects/g-p-6ac32a4ca5b08191bfcf6bd28eb66008` remains a reference location. Do not edit its synced files.

## GitHub version history

Private repository: [Chosencode25/projection-mapper](https://github.com/Chosencode25/projection-mapper).

The first milestone is `v1.01`. Follow [GitHub workflow](docs/GITHUB_WORKFLOW.md) for branches, commits, milestone tags, and release downloads. See [Changelog](CHANGELOG.md) for completed version changes.

The v1.15.1 patch corrects missing Show readiness/audio controls and includes the short acceptance record. The original v1.15 snapshot is preserved. Prior milestones, tags and releases are preserved. Repository visibility remains private.
