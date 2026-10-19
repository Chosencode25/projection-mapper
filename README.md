# Projection Mapper

Native Mac projection-mapping editor for independent surfaces and connected object
faces, with effects, images, video, a timeline, portable saves, undo/redo and readiness checks.
**Current app: v2.01/build 14**, macOS 15 or later, universal arm64/x86_64.
Test Mode and external fullscreen output share one Metal renderer and media owners.
Physical projector/optical timing and user visual/listening acceptance remain pending.

## Use and develop

- Open `app/ProjectionMapper.app` to use the current app.
- Open `app/ProjectionMapper/ProjectionMapper.xcodeproj` in **Xcode 27.0 beta 5 (27A5237l)** to develop it.
- [Build and test](docs/BUILD_AND_RUN.md): simple repeatable commands and safe cache cleanup.
- [Authoring guide](docs/V1_USER_GUIDE.md): surfaces, connected faces, media, timeline and saving.
- [Output guide](docs/V2.01_USER_GUIDE.md): Test Window, external output and calibration.
- [Current verification](docs/V2.01_VERIFICATION.md): automated evidence and pending hardware acceptance.
- [Progress](docs/PROGRESS.md), [changelog](CHANGELOG.md) and [development requirements](docs/PROJECT_DEVELOPMENT.md).
- [V2 roadmap](docs/V2_ROADMAP.md) and [implementation plan](docs/V2_IMPLEMENTATION_PLAN.md): next is v2.02 music/song transport and waveforms.
- [Cleanup record](docs/PROJECT_CLEANUP_2026-10-19.md): retained files, removed builds and recovery locations.

The app is locally ad-hoc signed; Developer ID signing/notarization remain unestablished.
Quit/reopen an older running instance to load updated app bytes.
Help → Open V1 Demo opens a protected unsaved copy of the bundled portable demo.
Format 9 migrates formats 1–8; project open starts paused/audio-disabled with output closed.

## Folder organization

| Folder | Contents |
|---|---|
| `app/` | Current runnable app, Xcode sources/tests and development helper |
| `docs/` | Current guides, plans and historical verification records |
| `assets/` | Project media/demo fixtures; local-only rescued projects in `local-projects/` |
| `builds/current/` | Current local app ZIP and identity/checksum |
| `builds/cache/` | One disposable Xcode build cache |
| `builds/checks/` | Current automated check logs/results |
| `builds/evidence/` | Lightweight historical verification reports and cleanup audit |

## GitHub and old versions

Private repository: [Chosencode25/projection-mapper](https://github.com/Chosencode25/projection-mapper).
The newer v2.01 source and cleanup work were backed up on GitHub main at **0f8b517**;
see [GitHub workflow](docs/GITHUB_WORKFLOW.md) for confirmed delivery status.
Latest published app download remains [v1.15.1](https://github.com/Chosencode25/projection-mapper/releases/tag/v1.15.1).
Earlier releases/tags/source history are preserved on GitHub. Redundant local old
app copies and version-specific caches are removed; local Git history stays available
for development. Historical documents describe their original deliveries, even when
the generated files they referenced have since been cleaned up.

The original ChatGPT project mirror at
`/Users/keith/.codex/.chatgpt-projects/g-p-6ac32a4ca5b08191bfcf6bd28eb66008`
and its synced sources remain read-only references.
