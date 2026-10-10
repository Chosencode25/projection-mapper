# Changelog

## v1.15 — V1 Completion — October 10, 2026

- Add bounded project/media undo and redo, coherent mapping/mask/slider edits, stable target/clip identities and save-aware dirty tracking, including same-ID media relinks. Retain staged video originals through saved-package replacement and release obsolete history/resources.
- Add bounded readiness diagnostics for geometry/masks/joins, live/library/timeline media/ranges, decoded-resource problems, audio selection and Test Mode; checks never start playback. Temporary selected-owner identification preserves saved content/runtime transport with a reachable Finish action.
- Polish narrow-window timeline control scrolling, native text undo, accessible actions and zero-width renderer-error layout; supply protected unique-identity demo loading, Welcome/Guide/About and code-generated app icon.
- Bundle a portable mixed-content demo with a house reference illustration/masks, connected object and independent video. Preserve schema 9 and migrations 1–8. Prepare locally ad-hoc signed universal 1.15/build 12 app and development ZIP/checksum/instructions.
- Final Debug/Release each passed 269 correctness tests, zero failures and zero runtime warnings. Bounded mixed HD profile and effects matrix evidence is recorded separately. User visual/listening, Intel/older-macOS, physical projector and Developer ID/notarization acceptance remain pending. No release/tag publication is included.

## v1.14 — Video Import and Timeline Integration — October 9, 2026

- Import/drop SDR H.264/HEVC MP4/MOV, inspect orientation/audio, stage originals with cancellation and expose posters/replace/remove/relink.
- Extend existing object timeline blocks with video In/Out, source speed, looping/mute/placement; preserve footage on moves and trim source range or loop phase on edge trims.
- Share one AVFoundation player/frame per content owner across mapped faces and preview/Test Output, with host-clock reconciliation, paused-frame generation, stale-seek guards, bounded preloading and frame caches. Preserve masks/crops/flips/perspective and Continuous/Repeat.
- Add explicit default-muted video audio, master volume/output selection, silent scrubbing and device-loss latch. Reopen safely muted.
- Save/recover portable format 9 with formats 1–8 migration, timeline/look-only video retention, chunked background copy, cancellation and last-good-package protection. Include the previously local effect/image timeline and planning updates in this milestone.
- 258 correctness tests passed in each Debug/Release configuration; the dedicated 13-test Release video run and 1080p profile passed. Signed universal 1.14/build 11 app installed with previous app preserved; user visual/listening acceptance remains pending. No GitHub release publication is included.

## Local playback timeline — October 9, 2026

- Add a resizable bottom timeline with connected-object/standalone-face lanes, effect/image clips and a seconds ruler. Add play/pause/stop, stepping, speed, zoom, snap, scrubbing and automatic playhead-follow scrolling.
- Move/trim/select/edit/capture/duplicate/delete clips. Use one shared transport for clip boundaries and local phase in preview/Test Output; dark gaps on sequenced tracks and live content on empty tracks.
- Save bounded clips in portable format 8, migrate formats 1–7, retain clip image assets and copy/prune sequences with owner lifecycle. Bundle remains 1.13/build 10; originally a local enhancement; included in the v1.14 milestone source backup. Automated verification and user visual status are recorded in TIMELINE_VERIFICATION.md.

## v1.13 — Image Import — October 9, 2026

- Import PNG/JPEG onto independent faces or shared objects; explicit detach import, drag/drop, Fit/Fill/Stretch, replace/remove and relink. Normalize orientation/sRGB/alpha with bounded image allocations.
- Reuse image textures across linked faces; preserve masks, input maps, crop/flips, projective output, fades and calibration. Include image assets in portable format 7 saves/recovery with migrations and last-good-file protection.
- Add an editor-only house/reference photo with placement, position, scale, opacity, lock and temporary visibility. Clean output and surface coordinates remain independent.
- Include the local top-bar menus, focused inspector tabs and collapsible controls. Final Debug/Release each passed 239 correctness checks; universal signed 1.13/build 10 installed locally with previous app preserved. Completed source backed up on GitHub main at 6dfd076. User visuals pending; no release published.

## Local UI usability polish — October 7, 2026

- Split the inspector into Edit, Show and Project; place content near the top and collapse advanced surface/object tools into named sections. Widen the inspector and return to Edit when selecting a face or object.
- Add top-bar Project/Open/Save and Add/Group menus, labeled Guides/Calibrate/Show controls and quick Play/Pause. Keep Blackout directly available.
- Final Debug/Release each passed 226 correctness checks; tested universal app installed locally and used for workflow checks. Previous app and user mapping preserved. Version stays 1.12/build 9; local work only, no commit or upload.

## v1.12 — Mapping Tools — October 7, 2026

- Complete temporary calibration, hard polygon face masks/cutout holes and format 6 saves/migration/recovery. Preserve layout/content owners, sampling, clocks and master fade/blackout priorities.
- Add temporary editor handles/outlines/names/edge visibility controls with reachable toolbar/View menu actions and safe defaults. Hide handles without enabling invisible drag/nudge; retain face picking and text focus.
- Add shared-canvas vertical/horizontal stripe and checker join inspection, projected edge traversal arrows and joined/seam/mismatch labels. Decorations stay out of clean output and saved projects.
- All 225 offscreen correctness checks passed in Debug/Release; four benchmarks skipped and two visible-window tests excluded. Exact Xcode 27A5237l; universal signed 1.12/build 9 app delivered locally, previous preview preserved.
- Completed source successfully backed up on GitHub main at b786f55; user visuals pending. No new release/tag/assets authorized. Next: v1.13 Image Import.

## Local preview — v1.12.2 Face Masks and Cutouts — October 7, 2026

- Add face-local polygon boundaries and up to seven hard cutout holes, drawing and drag/numeric point editing, edge insertion/deletion and enable/remove controls.
- Clip before every content/calibration branch in the shared renderer; preserve lower layers, projective mapping, source sampling, owner clocks, masks under looks/resets and master output priorities.
- Validate bounded polygons, crossings and hole containment; enabled invalid drafts suppress the face with recoverable diagnostics. Format 6 saves/recovery include masks and migrate formats 1–5.
- Final Debug/Release runs each passed 217 offscreen correctness tests; four opt-in benchmarks skipped and two visible-window tests excluded. Exact Xcode 27A5237l; tested signed universal preview delivered with previous app preserved. User visuals pending. Bundle stays 1.11/build 8; no intermediate commit/upload.

## Local preview — v1.12.1 Calibration Patterns — October 7, 2026

- Add temporary mapped-face Grid, Checkerboard, Crosshair, White/Black Test and Normal Content controls in inspector/toolbar/Show menu; Control-Command-C toggles Grid/Normal.
- Preserve geometry, input maps, visibility, locks, sources/libraries and clocks; opaque patterns bypass source appearance while existing master brightness/fades/blackout still apply.
- Share owner-canvas patterns across Continuous/Repeat faces; face-local crosshairs and bounded antialiased line widths support resize. Static calibration idles; fades complete and output reopen retains elapsed state.
- Keep calibration runtime-only and schema 5 unchanged. All 202 correctness tests pass in Debug/Release; universal signed local preview delivered, user visuals pending. Bundle stays 1.11/build 8; no intermediate commit/upload.

## v1.11 — Surface Controls milestone — October 6, 2026

- Complete appearance/crop/flips, object/face overrides, geometry locks, bounded object movement and scoped resets from the first two local slices.
- Add project-owned reusable looks that preserve mapping/locks/playback and report missing/regrouped targets; add named palettes with stable color bindings and reference-safe deletion.
- Add saved master brightness/fade duration and temporary playback-independent fade/restore plus immediate latched blackout, shared across preview and Test Window. Toolbar/menu restore remains accessible; Command-Shift-B/Command-Shift-R control blackout/restore.
- Schema 5 stores libraries/bindings/master settings and migrates schemas 1–4. Preserve colors/source IDs and failed-save safety; enforce manifest-size limits.
- Bundle 1.11/build 8. All 184 correctness tests passed in Debug/Release; signed universal local app delivered. User visuals remain pending. Milestone source backup successfully pushed to main at 87459a8; no release/tag/assets requested or published.

## Local preview — v1.11.2 Locks, Movement and Resets — October 5, 2026

- Add persistent output-geometry locks with preserved member locks, protected drag/nudge/reset/deletion, reachable unlock and lock-aware overlays/sidebar controls.
- Move all object corners by one bounded offset via center drag, focused arrows or inspector controls; preserve shared mapping/content/playback and block partial moves when a member is locked.
- Add scoped face/object resets and explicit full-face/shared-input-layout confirmations, preserving identity, membership, links and unrelated settings.
- Save lock flags in schema 4; older formats migrate unlocked. 150 Debug/Release correctness tests passed; user visuals pending. Keep slice local/uncommitted and bundle 1.10/build 7.

## Local preview — v1.11.1 Appearance, Crop and Flips — October 5, 2026

- Add opacity/brightness/crop/flips, scoped object inheritance and explicit face overrides; preserve output mapping and generator values.
- Share final RGB/alpha compositing and content transforms across preview/output; preserve joined sampling and report divergent overrides.
- Persist appearance in schema 3 with schema 1/2 defaults; include saved baselines, recovery and copy/detach/group policies.
- All 138 correctness tests passed in Debug/Release. User visuals pending. Intermediate slice stays local/uncommitted with bundle 1.10/build 7.

## v1.10 — Save & Load source milestone — October 5, 2026

- Add native Save/Save As/Open/Recent commands and portable validated .projectionmap packages preserving grouped/standalone layouts, content, presets and stable identities.
- Add atomic replacement, saved baselines and Save/Discard/Cancel lifecycle protection; failed saves retain the last good project.
- Add debounced untitled/saved recovery with restore/later/delete and ten-copy retention. Reload paused with fresh clocks and safe output fallback.
- Bundle 1.10/build 7. All 128 Debug/Release correctness tests passed; native visual acceptance belongs to the user. GitHub source backup successfully pushed to main at 55d242c before v1.11.1; no release/tag/assets requested.

## v1.09 — Source milestone — October 5, 2026

- Preserve accumulated multiple-surface and six-effect animation implementation, presets, seeking and scoped playback on GitHub at the user’s explicit request.
- Bundle 1.09/build 6; automated acceptance covers 111 correctness tests. Routine visual checks belong to the user.
- Source-history delivery only: no release/tag/assets requested. Subsequent v1.10 Save & Load work remains local.

## Local preview — v1.09.3 Presets, Seeking and Final Checks — October 5, 2026

- Add bounded named generator presets with save/apply/update/delete/reset, preserving layout and runtime ownership.
- Add 0–3600-second seeking, first-minute scrub slider and time readout; owner-scoped pause/resume/restart with copied phase and cleanup policies.
- All 111 correctness tests pass in final Debug/Release runs; all-effect backward seek/preset replay and independently paused/moving owners verified.
- Profile mixed and heavy-overlap scenes across presets; 4K GPU pair p95 2.1578 ms mixed / 44.5873 ms eight overlapping particle faces per view. Timings are not visible FPS.
- Signed universal app installed locally; user visuals pending. Bundle remains 1.08/build 5 until acceptance; no Git/version delivery yet. Presets/projects remain in memory until v1.10.

## Local preview — v1.09.2 More Effects and Settings — October 5, 2026

- Add procedural plasma, seeded animated value noise and deterministic wrapped particles (16–256), preserving shared-canvas face continuity and global transport.
- Add per-source effect speed, scale/spacing, eight directions, contrast, particle density/size and seed where relevant; bounds prevent unsafe settings.
- Three new correctness tests and expanded GPU coverage; 105 correctness tests pass in Debug/Release. Separate six-effect/two-view benchmark passes across presets (4K GPU pair p95 1.6783 ms; not visible FPS).
- User accepted v1.09.1 visuals and now owns routine visual checks. v1.09.2 visual feedback pending; no screen control performed.
- Universal signed local app updated in builds/v1.09.2/ and app/; prior app preserved. Bundle remains 1.08/build 5. No Git commit/upload or release.

## Local preview — v1.09.1 Playback Foundation — October 5, 2026

- Add shared global Play/Pause, Restart and bounded speed controls, separate from project dirty state.
- Add animated gradients, moving lines and checkers with two colors; preserve independent/shared ownership, perspective and Continuous/Repeat input maps.
- Evaluate effects from explicit elapsed time; run native display scheduling only for eligible playing views, retaining static/paused on-demand drawing.
- Five new model/GPU tests; all 102 correctness tests pass in Debug/Release. Vital visual playback acceptance pending because the Mac was locked.
- Universal signed local app updated in builds/v1.09.1/ and app/; prior app preserved. Bundle remains 1.08/build 5. No Git commit/upload or release.

## Local — v1.08 Multiple Surfaces — October 5, 2026

- Follow-up: click faces in the editor to select them; frontmost visible face wins overlaps, empty canvas deselects, and corner dragging remains intact. Release suite now passes 97 correctness tests; native click routing checks pass.

- Add ordered independent faces with stable IDs, names/tags, add/select/duplicate/delete, visibility and draw-order controls.
- Separate output layout from content ownership; add optional shared-content objects, grouping, detach/ungroup and isolated whole-object duplication.
- Add Continuous/Repeat input regions, rotation/mirroring, manual edge linking/alignment and join/seam diagnostics; render every valid visible face through shared preview/output.
- Seventeen new model/GPU tests; all 96 correctness tests pass in Debug and Release. Vital actual-app checks pass.
- Universal signed Release copies in builds/v1.08/ and app/ProjectionMapper.app, version 1.08/build 5. Entire delivery remains local: no commit, push, tag, archive or release.

## Unreleased — v1.07 Perspective Warp — October 5, 2026

- Add mipmapped diagnostic grid with orientation markers; new projects default to grid, with Solid fill available in the inspector.
- Map texture through one validated homography across both triangles in shared preview/output.
- Clear crossed/concave/collapsed/unsafe shapes to black, show stable editor warnings and support recovery of overlapping handles.
- Eleven new tests; all 79 correctness tests pass in Debug/Release. Vital actual-app warp, clean output, invalid/recovery, content, portrait and reset checks passed.
- Signed Release app copied to builds/v1.07/ and app/ProjectionMapper.app; source saved to GitHub. Bundle remains 1.04.2/build 4; no release/tag/archive.

## Unreleased — v1.06 Corner Nodes — October 5, 2026

- Add editor-only four-corner handles and outline with active-corner highlighting.
- Drag in fitted normalized coordinates, preserve grab offset, clamp to canvas, and update project geometry and shared render snapshots live.
- Native canvas focus routes arrow keys (0.001 normalized units) and Shift (0.01); text fields retain their own arrow handling.
- Selection/reset/dirty state and three-decimal inspector integration; eight new focused tests. All 68 correctness tests passed in Debug/Release; vital actual-app checks passed.
- Signed Release app copied to builds/v1.06/ and app/ProjectionMapper.app; source saved to GitHub. Bundle stays 1.04.2/build 4; no release/tag/archive.

## Unreleased — v1.05 First Surface — October 5, 2026

- Replace the diagnostic scene as project data with one project-owned Surface 1: identity, name, four normalized corners and orange fill.
- Add sidebar selection/deselection and selected-surface corner details in the scrollable inspector; selection does not change clean output or dirty state.
- Derive both render scenes from the project and refresh existing/future output and preview after reset; preserve suspended/on-demand drawing.
- Six new focused tests; all 60 correctness tests pass in Debug and Release. Actual-app selection, portrait/output/reopen and reset protection checks passed.
- Signed Release app copied to builds/v1.05/ and app/ProjectionMapper.app, source preserved on GitHub. Bundle stays 1.04.2/build 4; no new release/tag/archive.

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
