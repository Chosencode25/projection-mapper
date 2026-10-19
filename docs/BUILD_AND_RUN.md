# Build and Run

Required toolchain: **Xcode 27.0 beta 5 (27A5237l)** at `/Applications/Xcode-beta.app`.
Minimum macOS: **15.0**. SwiftUI and programmatic AppKit; no storyboards or XIBs.
Local signing is ad-hoc; Developer ID signing/notarization remain unestablished.

## Current app and source

Current source: **2.01/build 16 — workspace polish and keyboard editing**.
In the maintained local workspace, open `app/ProjectionMapper.app`. A fresh clone
contains source rather than generated apps; build it with the helper below and open
the Release product path printed on success.
Open `app/ProjectionMapper/ProjectionMapper.xcodeproj` in Xcode-beta to develop it;
select ProjectionMapper / My Mac, then Command-R.

The user explicitly authorized source delivery on October 19. The latest downloadable
release remains v1.15.1; build 16 is available from source. See [all keyboard shortcuts](KEYBOARD_SHORTCUTS.md),
[app improvements](LOCAL_APP_GUIDE.md), [shortcut verification](LOCAL_SHORTCUTS_VERIFICATION.md)
and [earlier polish evidence](LOCAL_APP_POLISH_2026-10-19.md).

Test Mode remains a separate resizable output window sharing the renderer with
Projector Mode. Physical projector/optical timing acceptance remains pending.
See [output guide](V2.01_USER_GUIDE.md), [authoring guide](V1_USER_GUIDE.md),
[verification](V2.01_VERIFICATION.md) and [cleanup record](PROJECT_CLEANUP_2026-10-19.md).

## Repeatable commands

From the project root, use the bundled Python helper (Python 3, no extra packages):

```sh
python3 app/scripts/project.py doctor
python3 app/scripts/project.py build
python3 app/scripts/project.py test --configuration Debug
python3 app/scripts/project.py test --configuration Release
```

Every build/test checks the exact Xcode build first and sets DEVELOPER_DIR only
for its own process. It does not change the system developer selection. Builds
produce both arm64 and x86_64 slices; tests execute on the current Mac architecture.
A successful build leaves its app under
`builds/cache/DerivedData/Build/Products/Release/ProjectionMapper.app`.
It does not replace the installed app automatically.

Tests exclude the two legacy checks that present visible native windows:
`TestOutputCoordinatorTests/normalFrameRestoresAcrossCloseAndNewCoordinator()` and
`MetalRendererTests/nativeMetalOutputSurvivesPresetsResizeAndReopen()`.
Four optional benchmarks normally skip. Command-U in Xcode runs the full suite,
including visible-window tests; routine visual acceptance is user-performed.
The helper writes dated logs, result bundles and JSON summaries under `builds/checks/`.

## Keep disk use bounded

One disposable cache serves all local configurations, rather than a separate
DerivedData tree for each version. Preview removal, then apply when wanted:

```sh
python3 app/scripts/project.py clean
python3 app/scripts/project.py clean --apply
```

Only `builds/cache/` is removed. Source, installed app, archives, reports and saved
projects are preserved. Xcode recreates its cache on the next build. Do not save
mapping projects in `builds/`: use your normal project location or the local-only
`assets/local-projects/` folder. Historical verification text/JSON reports rescued
in October 2026 live under `builds/evidence/history/`; older raw caches/result
bundles and app copies have been removed. Prior released applications can be
retrieved from [GitHub Releases](https://github.com/Chosencode25/projection-mapper/releases).
Keep local Git history and milestone tags for development.

## Demo and performance checks

Help → Open V1 Demo protects unsaved work and opens an unsaved template from the
single bundled resource. Its source is
`app/ProjectionMapper/ProjectionMapper/Resources/V1-Demo.projectionmap`.
Local project copies rescued from old builds are under `assets/local-projects/`
and excluded from Git; see the cleanup record before removing anything there.

Opt-in performance fixtures and their exact environment variables, exclusions,
workloads and measurement limits are documented in
[V2.01 verification](V2.01_VERIFICATION.md),
[V1.14 verification](V1.14_VERIFICATION.md) and
[renderer performance verification](V1.04.5_VERIFICATION.md).
Use a fresh evidence directory and run timed workloads separately.
GPU submission/execution durations do not establish physical projector FPS or latency.

## Metal compiler component

If the pinned Xcode reports a missing Metal compiler component, restore its
matching component (without migrating Xcode):

```sh
DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer \
xcodebuild -downloadComponent MetalToolchain
```

A tool sandbox may block access to an already installed component or local test
services; rerun with the required local permissions before treating this as a
missing installation.
