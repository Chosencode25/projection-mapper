# Project Progress

Last updated: October 5, 2026.

## Current state

v1.03.1 Basic Test Window is implemented and locally verified with Xcode 27.0 beta 5 (27A5237l). All 28 tests pass. A standalone Apple Silicon Release app is in builds/v1.03.1/ProjectionMapper.app. The user has deferred projector output implementation and physical hardware checks; they do not block this Test Mode milestone.

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

## Current acceptance and next milestone

v1.03.1 is ready for its development release and merge into main. Next: v1.03.2 simulated resolution presets and aspect-preserving scaling, followed by v1.03.3 window persistence/navigation polish. See V1_ROADMAP.md for the approved split.

## Scope and limitations

Projects stay in memory. Output selection and preferences are implemented; the basic Test Window is implemented. Projector output is deferred; media import, surfaces, rendering, and saving are later milestones. Runtime checks used the development Mac on macOS 27.0; older macOS versions and Intel hardware have not been runtime-tested. The included standalone build is for Apple Silicon; the Xcode project can be used to build for the selected Mac destination.

See V1.03.1_VERIFICATION.md for current evidence and limitations, V1.01_VERIFICATION.md for the earlier milestone, and BUILD_AND_RUN.md for instructions.

## GitHub version history

Private repository: https://github.com/Chosencode25/projection-mapper. The initial source snapshot is v1.01; its release notes are in releases/v1.01.md. Follow GITHUB_WORKFLOW.md for future milestone history.

## v1.02 implementation

- [x] Shared toolbar/inspector destination selection and Test Window default.
- [x] AppKit/Core Graphics display snapshots, names, UUIDs, metadata, mirroring and editor-screen eligibility.
- [x] App-owned coalesced discovery with screen changes, activation, wake, and manual refresh.
- [x] Explicit preference persistence, startup restoration, safe fallback, and reconnect without automatic switching.
- [x] Aspect-aware empty canvas, output details/status, scrollable inspector, version 1.02/build 2.
- [x] Sixteen focused output tests plus the existing five session tests passed.
- [x] No-external-display runtime, project reset protections, packaged app, About, panel shortcut, and synthetic minimum-size portrait/long-name layout checks.
- [x] Build and signature verification; preview ZIP and checksum published in the private v1.02-preview.1 prerelease.
- [ ] Deferred: physical extended-display metadata, unplug/reconnect, saved external preference relaunch, mirroring, editor movement, scaling/rotation.
- [ ] Final v1.02 hardware acceptance remains deferred. Its preview tag/assets are preserved while Test Mode development proceeds.

The plan is [V1.02_PLAN.md](V1.02_PLAN.md). Current verification is [V1.02_VERIFICATION.md](V1.02_VERIFICATION.md). Preview notes are [releases/v1.02-preview.1.md](releases/v1.02-preview.1.md).

## v1.03.1 implementation

- [x] One app-owned observable Test Output window; normal native controls and plain black content.
- [x] Toolbar/inspector/Window menu open/close actions and shared open/closed status.
- [x] Duplicate prevention, minimize restoration, native close/reopen, external destination guard.
- [x] Project reset independent of output; successful editor close/quit cleanup, Cancel preserving both windows.
- [x] Seven focused AppKit window tests plus all 21 regressions passed.
- [x] Local runtime checks and pinned-Xcode Release build/signature verification.
- [ ] Publish v1.03.1 app/checksum and advance main to the accepted Test Mode milestone.

Plan: [V1.03.1_PLAN.md](V1.03.1_PLAN.md). Verification: [V1.03.1_VERIFICATION.md](V1.03.1_VERIFICATION.md).
