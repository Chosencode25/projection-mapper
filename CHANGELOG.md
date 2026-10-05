# Changelog

## Unreleased — v1.04.5 Performance and Acceptance — October 5, 2026

- Add optional bounded renderer diagnostics (off by default) and three opt-in performance/lifecycle benchmarks; preserve asynchronous on-demand drawing.
- All 54 correctness tests pass in Debug and Release. Measure 9,000 exact-resolution single/pair samples, native drawable sizes, idle behavior, ownership stress and synthetic redraw completion.
- Exact 4K rectangle GPU p95: 0.1527 ms; two-view GPU sum p95: 0.4089 ms on Apple M4. No measured issue required tuning; these are workload timings, not visible FPS.
- Complete authorized local visual lifecycle, layout, navigation, discard and quit checks; v1.04 Test Mode accepted. Physical projector/backing transitions remain deferred.
- Signed Release app copied to builds/v1.04.5/ and app/ProjectionMapper.app; source saved on GitHub. Bundle stays 1.04.2/build 4; no new release/tag/archive.

## v1.04.4 onscreen verification follow-up — October 5, 2026

- Both deferred onscreen tests pass: native minimize/restore/zoom/frame persistence and drawable resizing/presets/reopen.
- Honor actual occlusion in drawable-test expectations; restrict scene-view observer removal to its lifecycle notifications.
- Remaining 48 headless regressions pass again, covering all 50 tests across complementary runs. App copies refreshed; no release or version bump.

## Unreleased — v1.04.4 Rendering Lifecycle — October 5, 2026

- Gate drawing by view/window availability and request redraw on restoration/backing changes, preserving on-demand rendering.
- Release output content/delegate and cached drawables on close; clear editor hosting content on close/termination.
- Add headless window presentation injection and six lifecycle/GPU/resource tests. 48 automated Debug tests pass with pinned Xcode; two onscreen tests and interactive acceptance are deferred at the user’s request.
- Signed Debug app copied to builds/v1.04.4/ and app/ProjectionMapper.app. Source update only; bundle remains 1.04.2/build 4.

## Unreleased — v1.04.3 Shared Editor Preview — October 5, 2026

- Editor preview and Test Output draw the same session-owned scene through a reusable Metal view and renderer implementation.
- Preserve independent drawable resources, aspect fitting, output window behavior, and editor-only caption/border.
- All 44 Debug tests pass with Xcode 27A5237l, including hosted preview/output integration and GPU pixels across all five presets; runtime panel/reset/closed-output checks passed.
- Source update only; bundle remains 1.04.2/build 4 and the published v1.04.2 release is preserved.

## v1.04.2 — First Rectangle — October 5, 2026

- Compiled Metal shaders and pipeline draw a centered orange rectangle on black using four normalized corners.
- Preserve output aspect fitting, native drawable sizing independent of simulated resolution, window preferences, and navigation.
- All 43 tests passed in Debug and Release with Xcode 27A5237l; all five presets and window redraw checked in the running app.
- User-requested Apple Silicon development prerelease, version 1.04.2/build 4, with app ZIP and checksum. Shared editor preview follows in v1.04.3; projector implementation remains deferred.

## In development — v1.04.2 step 6 — October 5, 2026

- Local acceptance passed: all five resolution presets visually checked, output restore/redraw confirmed, and unchanged implementation's 43-test evidence reviewed.
- Acceptance/documentation checkpoint only; delivery and main advancement remain step 7. No app changes, release, tag, or bundle bump.

## In development — v1.04.2 step 5 — October 5, 2026

- Explicit automatic native drawable sizing; preserve aspect-fitted output independently of simulated resolution.
- All 43 tests pass, covering live preset switching in wide/tall/square windows, actual drawable dimensions, and GPU rectangle coverage across output aspects. Running 4K/Portrait/4:3 fitting checked.
- Final acceptance/main advancement remain pending; no release/tag/bundle bump.

## In development — v1.04.2 step 4 — October 5, 2026

- Store four normalized rectangle corners independently of output dimensions; convert top-left scene coordinates to Metal clip positions.
- Preserve the centered orange rectangle appearance. All 42 tests pass, including off-center GPU pixels, coordinate conversion, and geometry stability during window/preset changes.
- Feature-branch checkpoint; full acceptance and main advancement remain pending. No release/tag/bundle bump.

## In development — v1.04.2 step 3 — October 5, 2026

- Test Output draws a centered orange rectangle on black using the compiled pipeline and temporary clip-space geometry.
- All 40 tests pass, including every-pixel GPU rectangle/background checks; native visible output and close/reopen checked.
- Partial feature-branch work; normalized scene geometry/full acceptance remain pending and main stays v1.04.1. No release/tag/bundle bump.

## In development — v1.04.2 step 2 — October 5, 2026

- Compiled Metal vertex/fragment shaders and BGRA8 render pipeline; initialization reports missing library/functions or pipeline creation failures.
- All 40 tests pass, including a shader GPU readback probe and initialization failure checks. Blue diagnostic output remains until rectangle drawing in step 3.
- Partial work on the feature branch; main remains v1.04.1. No release, tag, or bundle bump.

## Unreleased — v1.04.1 Metal Foundation — October 5, 2026

- Metal device/command queue and on-demand drawing in the fitted Test Output area, showing a fixed blue diagnostic color with black margins.
- Visible initialization errors; preserve resolution presets, window preferences, close/reopen, and navigation behavior.
- All 38 tests pass with pinned Xcode, including GPU pixel readback and native Metal output checks; running-app visual/navigation checks passed.
- Source update only; no release, tag, or bundle version bump. Rectangle/shared preview and projector output remain later work.

## Unreleased — v1.03.3 window behavior/polish — October 5, 2026

- Remember Test Output's normal size/position independently of project data and simulated resolution; output still starts closed.
- Recover saved or open windows into a current screen's visible area, enforcing minimum size and fitting oversized frames.
- Consistent Show Output controls; Control–Command–O shows/restores output and Control–Command–E shows the editor.
- Preserve the normal frame through minimize, zoom, and fullscreen transitions.
- Source update only; no new release, tag, or bundle version bump.

## Unreleased — v1.03.2 resolution/scaling — October 5, 2026

- Five saved Test Window resolution presets: HD, Full HD, 4:3, Portrait, and 4K.
- Editor preview/details and open output update immediately; centered aspect-preserving output surface keeps the simulated resolution independent of window size.
- Preferences stay separate from project changes. All 31 tests passed plus native live-update/relaunch checks with the pinned Xcode toolchain.
- Source update only; no new release, tag, or bundle version bump.

## v1.03.1 — Basic Test Window — October 5, 2026

- Open/Close Output controls in the toolbar, inspector, and Window menu.
- One normal movable/resizable/minimizable black output window, with duplicate prevention and shared status.
- Native close preserves the editor/project; New Project preserves output; successful editor close and quit clean up output.
- Test Window only; projector implementation and physical checks deferred at the user’s request.
- All 28 tests passed and an Apple Silicon Release build was locally verified with the pinned Xcode toolchain.

## v1.02-preview.1 — Output Selection Preview — October 5, 2026

- Shared toolbar/inspector selection of Test Window or an eligible connected display.
- Display discovery, UUID preferences, refresh, wake/reactivation updates, and safe disconnect/mirroring/editor-screen fallback.
- Render pixels, desktop points, scaling, reported refresh, connection messages, and aspect-aware preview.
- Output preferences stay separate from project changes; bundle-derived version 1.02/build 2.
- 21 tests passed, pinned-Xcode Release build and local runtime checks completed.
- Physical external-display acceptance pending; preview remains on the feature branch and main stays v1.01.

## v1.01 — App Skeleton — October 5, 2026

- Native Mac editor implemented entirely in SwiftUI and programmatic AppKit.
- Toolbar, surface sidebar, 16:9 empty preview canvas, project inspector, and status area.
- Project naming, timestamps, and in-memory session state.
- New Project, Close, and Quit with Cancel/Discard protection for changes.
- Panel toggles, keyboard shortcuts, editor reopening, and About information.
- Five focused state tests passed; editor layout and lifecycle checks completed.
- Xcode 27.0 beta 5 (27A5237l); macOS 15.0 deployment target.
- Local Apple Silicon development build. Rendering, media, output windows, and persistence are later milestones.
