# Project Progress

Last updated: October 5, 2026.

## Current state

v1.01 editor skeleton implemented and verified with Xcode 27.0 beta 5 (27A5237l). The project lives in app/ProjectionMapper/; a runnable local Apple Silicon build lives in builds/v1.01/ProjectionMapper.app.

## Completed

- [x] Recover V1 roadmap and v1.01 scope from earlier project chats.
- [x] Record code-based interface, Test Mode, and exact Xcode requirements.
- [x] Verify /Applications/Xcode-beta.app matches the required build.
- [x] Create Xcode project and shared ProjectionMapper scheme.
- [x] Set and document macOS 15.0 minimum deployment target.
- [x] Implement project model, naming, timestamps, and session state.
- [x] Build toolbar, sidebar, 16:9 empty canvas, inspector, and status area.
- [x] Connect New Project, panel toggles, menus, shortcuts, and About.
- [x] Implement Cancel/Discard protection for reset, close, and quit.
- [x] Verify editor reopening and default, minimum, and larger layouts.
- [x] Pass five focused model/session tests.
- [x] Produce an ad-hoc signed local development build.
- [x] Add build/run instructions and acceptance record.

## Next milestone

v1.02: choose Test Window or a connected display, detect displays, and display output information. The separate output window follows in v1.03; rendering follows in v1.04.

## Scope and limitations

Projects stay in memory. Media import, surfaces, rendering, output windows, and saving are later milestones. Runtime checks used the development Mac on macOS 27.0; older macOS versions and Intel hardware have not been runtime-tested. The included standalone build is for Apple Silicon; the Xcode project can be used to build for the selected Mac destination.

See V1.01_VERIFICATION.md for evidence and BUILD_AND_RUN.md for instructions.

## GitHub version history

Private repository: https://github.com/Chosencode25/projection-mapper. The initial source snapshot is v1.01; its release notes are in releases/v1.01.md. Follow GITHUB_WORKFLOW.md for future milestone history.

## v1.02 planning

The specific plan is saved in [V1.02_PLAN.md](V1.02_PLAN.md) on `feature/v1.02-output-selection`. It covers output selection, display discovery, preference restoration, hot plugging, mirroring, and verification. Implementation has not started; the app remains v1.01. No v1.02 release or tag has been created.
