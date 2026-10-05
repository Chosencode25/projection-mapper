# Project Progress

Last updated: October 5, 2026.

## Current state

v1.04.1 Metal Foundation is implemented and locally verified with Xcode 27.0 beta 5 (27A5237l). All 38 tests pass. The tested Apple Silicon Debug app is in builds/v1.04.1/ProjectionMapper.app. The last published Release remains v1.03.1. Test Output now draws a blue diagnostic color through Metal; the editor preview remains empty until v1.04.3. Projector implementation and physical checks remain deferred.

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

v1.03.1 is merged into main and published as a [private development prerelease](https://github.com/Chosencode25/projection-mapper/releases/tag/v1.03.1), including the app and checksum. v1.03.2 adds verified simulated resolution presets and aspect-preserving scaling as a source update without a new release or tag. v1.03.3 completes Test Window persistence/navigation. v1.04.1 Metal Foundation is now verified. Next: v1.04.2 First Rectangle. Projector implementation remains deferred. See [v1.04 plan](V1.04_PLAN.md) and [roadmap](V1_ROADMAP.md) for the approved split.

## Scope and limitations

Projects stay in memory. Output selection and preferences are implemented; the Test Window and Metal diagnostic clear are implemented. Projector output is deferred; shared editor rendering, media import, surfaces, and saving are later milestones. Runtime checks used the development Mac on macOS 27.0; older macOS versions and Intel hardware have not been runtime-tested. The included standalone build is for Apple Silicon; the Xcode project can be used to build for the selected Mac destination.

See V1.04.1_VERIFICATION.md and the v1.04.1 implementation record below for current evidence, V1.03.1_VERIFICATION.md for the previous milestone, V1.01_VERIFICATION.md for the earlier milestone, and BUILD_AND_RUN.md for instructions.

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
- [x] Published v1.03.1 app/checksum and advanced main to the accepted Test Mode milestone.

Plan: [V1.03.1_PLAN.md](V1.03.1_PLAN.md). Verification: [V1.03.1_VERIFICATION.md](V1.03.1_VERIFICATION.md).

## Version-history preference — October 5, 2026

Small changes are preserved by commits pushed to the private repository. Full releases, version bumps, tags, and downloadable archives are reserved for substantial milestones or explicit requests. Existing published versions remain preserved. This workflow-only update requires no app build.

## v1.03.2 implementation

- [x] HD, Full HD, 4:3, Portrait, and 4K presets in the Test Window inspector.
- [x] Resolution preference saved separately from project data; HD default and invalid-value fallback.
- [x] Editor preview/details and existing output window update immediately without changing the window size or project state.
- [x] Centered aspect-preserving black output surface and black margins; native window resizing preserves simulated resolution.
- [x] All 31 tests passed with the pinned Xcode toolchain, including preset persistence, fitted geometry, live window updates, resizing, reset, and session restoration.
- [x] Native runtime checks: Portrait/Full HD selection, minimized output restoration, live window title/canvas metadata, and relaunch restoring Full HD with output closed.
- [x] Tested Debug app copied to builds/v1.03.2/ProjectionMapper.app and its signature verified.

Plan: [V1.03.2_PLAN.md](V1.03.2_PLAN.md). Test evidence: builds/v1.03.2/test.log and Tests.xcresult (local, excluded from Git). This is a source-history update; no version bump, tag, archive, or release. Bundle version remains the last published v1.03.1/build 3. Rendering remains scheduled for v1.04; window geometry persistence/navigation for v1.03.3.

## v1.03.3 implementation

- [x] Normal Test Output frame saved on move/resize/close, separately from project state and simulated resolution.
- [x] Reopen and new-coordinator restoration; launch remains closed.
- [x] Invalid stored values fall back to the default window; offscreen and oversized frames fit a current screen's visible area. Multi-screen selection, removed-screen recovery, and minimum dimensions verified with synthetic screen frames.
- [x] Show Output naming throughout toolbar/inspector/menu; Control–Command–O shows/restores output and Control–Command–E raises the editor.
- [x] Minimize and zoom preserve the normal saved frame. Zoom transition event ordering is guarded; fullscreen transitions use the same guard.
- [x] All 35 tests passed with Xcode 27.0 beta 5 (27A5237l), including native AppKit move/resize callbacks, close/reopen, new-coordinator restoration, minimize/show, zoom/close restoration, preference validation, and existing regressions.
- [x] Native running-app checks confirmed both new shortcuts, minimized-output restoration, consistent controls, panel shortcuts, and closed startup with the existing 4K preference preserved.
- [x] Refreshed builds/v1.03.3/ProjectionMapper.app from the tested Debug build and verified its signature.

Plan: [V1.03.3_PLAN.md](V1.03.3_PLAN.md). Final evidence: builds/v1.03.3/test.log and Tests-zoom-fix.xcresult (local, excluded from Git). Native pointer-driven move/resize checks were inconclusive in the automation surface; actual NSWindow frame changes and restoration passed the AppKit tests. Fullscreen animation and physical display removal have not been runtime-tested. Earlier minimum-layout checks remain applicable; no editor layout structure changed. The fitted output surface needs no further restructuring before v1.04. No version bump, tag, archive, or release; the bundle remains v1.03.1/build 3.

## v1.04 planning — October 5, 2026

The five-slice renderer breakdown and completion criteria are saved in [V1.04_PLAN.md](V1.04_PLAN.md), individual slice plans, and the roadmap. Relative milestone difficulty estimates are recorded in the roadmap as subjective estimates. This documentation update changes no app behavior; the latest verified app remains v1.03.3 with 35 passing tests.

- [x] v1.04.1 — Metal Foundation (implemented and locally verified).
- [ ] v1.04.2 — First Rectangle.
- [ ] v1.04.3 — Shared Editor Preview.
- [ ] v1.04.4 — Rendering Lifecycle.
- [ ] v1.04.5 — Performance and Acceptance.

v1.04.1 is implemented and locally verified; the other four remain planned. Test and push each completed slice; no automatic release/tag/version bump. Physical projector implementation/reconnect checks remain deferred.

## v1.04.1 implementation

- [x] Independent Metal renderer initializes the device/command queue and clears the fitted Test Output surface to a fixed blue diagnostic color.
- [x] On-demand MTKView drawing; simulated resolution remains independent of native drawable size. Existing black margins, preferences, window ownership, and navigation are preserved.
- [x] App-visible initialization error text with injected device/queue failure verification.
- [x] All 38 tests pass with the exact pinned toolchain, including actual GPU texture readback and native Metal window preset/resize/close/reopen checks.
- [x] Running-app checks confirmed visible output and margins at 4K and Portrait, live resolution changes, close/reopen, minimize/restore, and both navigation shortcuts. Original 4K preference restored.
- [x] Tested Debug app copied to builds/v1.04.1/ProjectionMapper.app; ad-hoc signature verified.

Plan: [V1.04.1_PLAN.md](V1.04.1_PLAN.md). Verification: [V1.04.1_VERIFICATION.md](V1.04.1_VERIFICATION.md). No frame-rate/4K-performance claim; actual performance measurement is v1.04.5. The rectangle and shared editor preview remain planned. No bundle version bump, tag, archive, or release.

## v1.04.2 development — steps 1–2

On `codex/v1.04.2-first-rectangle`, based on tested v1.04.1 commit `ba34723`. Exact Xcode build reverified. Apple Metal Toolchain component **27A5237l** installed for shader compilation.

- [x] Step 1: verify toolchain and create feature branch from tested main.
- [x] Step 2: compiled vertex/fragment shaders and initialized BGRA8 render pipeline, with visible library/function/pipeline errors. All **40 tests pass**, including actual shader GPU pixel readback and injected failure handling.
- [ ] Steps 3–7: rectangle drawing, normalized scene geometry, sizing integration, full acceptance, and advancement of tested main.

The running output remains the v1.04.1 blue diagnostic clear; shader/pipeline creation is ready for step 3. `main` remains the completed v1.04.1 milestone. Interim tested app: `builds/v1.04.2/step2/ProjectionMapper.app`. Evidence: [V1.04.2_VERIFICATION.md](V1.04.2_VERIFICATION.md). This is partial feature-branch work, not completed v1.04.2 acceptance. No release/tag/version bump.

## v1.04.2 development — step 3

- [x] Draw a temporary orange rectangle on black using the compiled Metal pipeline and two triangles. Temporary clip-space vertices precede normalized scene storage in step 4.
- [x] All 40 tests pass with the exact pinned Xcode, including every-pixel GPU rectangle/background verification and existing native window/preset regressions.
- [x] Running step-3 app visibly draws the rectangle at Full HD and after native close/reopen. Signature verified; local app is `builds/v1.04.2/step3/ProjectionMapper.app`.
- [ ] Steps 4–7 and full v1.04.2 acceptance remain pending; main remains v1.04.1. Work preserved on the feature branch without release/tag/bundle bump.

Latest feature-branch output is now the rectangle rather than the step-2 diagnostic clear. See [V1.04.2_VERIFICATION.md](V1.04.2_VERIFICATION.md).

## v1.04.2 development — step 4

- [x] Four immutable normalized scene corners with top-left origin, converted to Metal clip positions and two triangles at render time.
- [x] All 42 tests pass with pinned Xcode, including off-center GPU pixel checks, coordinate extents/center, and stored geometry unchanged through preset/window changes.
- [x] Running app confirms the centered rectangle retains its appearance. Local signed/tested app: `builds/v1.04.2/step4/ProjectionMapper.app`.
- [ ] Steps 5–7 remain pending; full v1.04.2 acceptance and advancement of main have not occurred.

Latest feature-branch geometry now uses normalized corners; the step-3 appearance is preserved. See [V1.04.2_VERIFICATION.md](V1.04.2_VERIFICATION.md). Intermediate work is saved on the feature branch without release/tag/version bump.
