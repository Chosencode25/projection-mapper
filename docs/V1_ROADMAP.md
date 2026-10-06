# V1 Roadmap — Core Mapper

V1 targets a native Mac mapping workspace for images, videos and built-in animations on multiple surfaces. Faces can form objects with shared content coordinates so content continues across joined faces. Reusable looks/palettes, masks, time-based playback, an editor-only house photo and portable projects prepare it for musical shows. V1 acceptance remains Test Mode; fullscreen projector implementation and physical acceptance are scheduled for v2.01.

See [ordered implementation steps for every remaining milestone](V1_REMAINING_PLAN.md). v1.08 is implemented and locally accepted; v1.09 is implemented and automatically verified with user visual acceptance pending; v1.10 Save & Load is implemented locally and automatically verified; v1.11 Surface Controls is implemented and automatically verified, with user visuals pending; v1.12 onward remains planned. See [V2 music/show roadmap](V2_ROADMAP.md) and [detailed V2 implementation steps](V2_IMPLEMENTATION_PLAN.md) for the next major version.

| Stage | Scope |
|---|---|
| 1.01 — App Skeleton | Control window, toolbar, sidebar, empty canvas, project model. |
| 1.02 — Output Selection | Choose Test Window or a connected display; detect displays; show display properties; default to Test Window without a projector. |
| 1.03 — Test Output Window | Delivered in three slices below. Fullscreen projector implementation and physical checks are deferred. |
| 1.04 — Metal Renderer | Five slices below: Metal foundation, rectangle, shared preview, lifecycle, performance. Renderer reusable for both output modes; projector implementation/physical reconnect checks deferred. |
| [1.05 — First Surface](V1.05_PLAN.md) | Implemented and locally accepted: one project-owned surface, four normalized corners, initial rectangle, sidebar selection and inspector. |
| [1.06 — Corner Nodes](V1.06_PLAN.md) | Implemented and locally accepted: draggable handles, live output updates, focused arrow-key nudging, larger Shift nudges. |
| [1.07 — Perspective Warp](V1.07_PLAN.md) | Implemented and locally accepted: projective diagnostic textures, trapezoids, safe invalid geometry and recovery. |
| [1.08 — Multiple Surfaces](V1.08_PLAN.md) | Ordered surfaces, named object groups/tags, separate layout/content ownership, shared input maps, manual edge alignment and visibility. Implemented and locally accepted; see [verification](V1.08_VERIFICATION.md). |
| [1.09 — Built-In Animations](V1.09_PLAN.md) | Gradients, plasma, noise, checkers, moving lines, particles; deterministic elapsed-time playback/seek, shared object generators and reusable generator presets. |
| 1.10 — Save & Load | Versioned portable layout/content/preset data, objects/tags/input maps, output settings, autosave and recovery; explicit later-feature and V2 migration contracts. |
| 1.11 — Surface Controls | Opacity/brightness/crop/flip/locks/resets; object/face scope; reusable looks/palettes; master brightness/fade/restore and immediate blackout. |
| 1.12 — Mapping Tools | Calibration integrated with existing blackout, editor handles and join diagnostics; saved basic face-local polygon masks/cutout holes. |
| 1.13 — Images | PNG/JPEG import/drop, placement and shared object textures; portable assets; separate editor-only house/display reference photo. |
| 1.14 — Video | AVFoundation video into Metal; deterministic requested-time playback and shared object player/frame; explicit embedded-audio routing/mute; portable media/preferences. |
| 1.15 — Polish & Release | Undo/redo and recovery for all new data, playback-readiness report, object identification, portable demos, profiling and accurate Test Mode packaging/upload. |

The first major mapping milestone is 1.07. A temporary developer test texture or pattern can exercise warping before image/video import, now scheduled after the core mapping tools; full calibration tools remain planned for 1.12.

V2 adds actual projector output, music/song transport, timelines/cues, holiday choreography, layers/regions/text, reusable show roles/templates, external synchronization, Show Mode, scheduling, local remote controls and export. Multi-projector blending, mesh/3D tools, camera-assisted mapping, direct fixture/pixel output and standalone playback remain an explicit later backlog in the V2 plan.

## v1.03 slices — approved October 5, 2026

| Slice | Scope |
|---|---|
| 1.03.1 — Basic Test Window | Open/close controls, one normal resizable black output window, shared status, safe window ownership and cleanup. |
| 1.03.2 — Resolution and Scaling | Simulated resolution presets, aspect-preserving display with black margins, matching editor preview, remembered resolution independent of window size. |
| 1.03.3 — Window Behavior and Polish | Remember size/position, offscreen recovery, Show Output/navigation, shortcuts/layout checks, preparation for the shared renderer. |

The user will not have a projector for a while. Projector-window implementation and physical checks are deferred and do not block these Test Mode milestones. Existing display discovery remains available; earlier external hardware checks remain unverified.

## v1.04 slices — approved October 5, 2026

See [master plan](V1.04_PLAN.md) for requirements, acceptance, and delivery. All five slices are implemented and locally accepted for Test Mode. See [final performance/acceptance](V1.04.5_VERIFICATION.md). Physical display/projector and backing-scale transitions remain deferred. v1.05 is also [implemented and locally accepted](V1.05_VERIFICATION.md). v1.06 is also [implemented and locally accepted](V1.06_VERIFICATION.md). v1.07 is also [implemented and locally accepted](V1.07_VERIFICATION.md). v1.08 is also [implemented and locally accepted](V1.08_VERIFICATION.md). Next active development milestone after v1.11 delivery: v1.12 Mapping Tools. See the reordered remaining roadmap below.

| Slice | Scope | Finished when |
|---|---|---|
| [v1.04.1 — Metal Foundation](V1.04.1_PLAN.md) | Metal device/queue and drawing view, fixed-color clear, initialization failure handling. | Output reliably draws through resize, close, and reopen. |
| [v1.04.2 — First Rectangle](V1.04.2_PLAN.md) | Shader pipeline and temporary rectangle in normalized coordinates; resolution-independent geometry. | The rectangle keeps its intended position and proportions across presets and window sizes. |
| [v1.04.3 — Shared Editor Preview](V1.04.3_PLAN.md) | Same renderer and scene data in editor and Test Output; clean output excludes editor UI. | Both views consistently show the same content. |
| [v1.04.4 — Rendering Lifecycle](V1.04.4_PLAN.md) | Drawable changes, hidden/minimized/closed views, resume behavior, resource cleanup. | Repeated window operations behave correctly without accumulating resources. |
| [v1.04.5 — Performance and Acceptance](V1.04.5_PLAN.md) | Frame pacing/GPU measurements across presets, targeted tuning, final regressions. | We have a stable renderer and documented performance on the development Mac. |

Test each slice as it is developed. Commit and push completed verified slices without automatically creating releases. Projector implementation/testing remains deferred. After v1.04, v1.05 turns the temporary rectangle into the first actual mapping surface.

## Relative difficulty estimates — October 5, 2026

These are subjective implementation/testing-complexity estimates relative to this project, not measured effort or time commitments. Remaining-stage estimates include the approved object-continuity and show-foundation expansion. v1.04's 8/10 describes the complete renderer milestone; individual slices narrow its scope.

| Step | Estimate | Main complexity |
|---|---|---|
| 1.01 — App Skeleton | 3/10 | Interface, project state, window lifecycle. |
| 1.02 — Output Selection | 5/10 | Display identity, reconnects, mirroring, safe fallback; physical acceptance deferred. |
| 1.03.1 — Basic Test Window | 3/10 | Window ownership, controls, cleanup. |
| 1.03.2 — Resolution and Scaling | 3/10 | Presets, preference persistence, aspect fitting. |
| 1.03.3 — Window Behavior and Polish | 3/10 | Frame persistence, offscreen recovery, navigation. |
| 1.04 — Metal Renderer | 8/10 | Graphics foundation, sizing, synchronization, performance. |
| 1.05 — First Surface | 3/10 | Geometry model and selection on the renderer. |
| 1.06 — Corner Nodes | 6/10 | Dragging, coordinate conversion, nudging, live updates. |
| 1.07 — Perspective Warp | 8/10 | Mapping math, texture correctness, extreme shapes. |
| [1.08 — Multiple Surfaces](V1.08_PLAN.md) | 8/10 | Selection, ordering, object membership, input maps, edge alignment, multiple draws. |
| [1.09 — Built-In Animations](V1.09_PLAN.md) | 8/10 | Several shaders, shared object coordinates/timing, cross-face motion, performance. |
| 1.10 — Save & Load | 8/10 | Reliable files, generator settings, autosave, migrations, recovery; later media extensions. |
| 1.11 — Surface Controls | 7/10 | Scoped appearance, looks/palettes, master fades and saved references. |
| 1.12 — Mapping Tools | 7/10 | Calibration priority, polygon/hole validation, mask coordinate correctness and persistence. |
| 1.13 — Images | 5/10 | Import, GPU textures, fit/fill/stretch, replacement, saved media references. |
| 1.14 — Video | 9/10 | Playback timing, decoding, Metal integration, resource management, saved settings. |
| 1.15 — Polish & Release | 9/10 | Undo/redo, error handling, profiling, packaging, release verification and upload. |

## v1.05 acceptance — October 5, 2026

All seven steps complete. 60 correctness tests passed in Debug and Release plus authorized actual-app checks; source and local app updated. See [verification](V1.05_VERIFICATION.md). v1.06 introduces corner dragging and keyboard nudging; v1.07 perspective mapping.

## v1.06 acceptance — October 5, 2026

All five steps complete. 68 correctness tests passed in Debug and Release plus authorized actual-app checks; tested source and local app updated. See [verification](V1.06_VERIFICATION.md). Next: v1.07 perspective-correct texture mapping.

## Earlier media deferral — October 5, 2026 (superseded by reorder below)

The user requested skipping custom image and video import for now. Defer v1.08 Images and v1.09 Video rather than removing them or marking them complete. Keep existing milestone numbers. The next active roadmap milestone is v1.10 Built-In Animations, which generates content inside the app without imported files. No animation implementation has started. Multiple surfaces, surface controls, mapping tools and saving remain subsequent milestones; Test Mode and shared rendering remain required.

## Remaining roadmap reordered — approved October 5, 2026

The user explicitly requested this sequence and renumbering: multiple surfaces, animations, saving, remaining core tools in their prior relative order, image import, video import, then polishing and upload. Completed v1.01–v1.07 milestones, historical plans, verification records, Git tags and release assets retain their original identities. Only future milestones are renumbered. The earlier deferral above records the previous decision and numbering.

| Previous number | New number | Milestone |
|---|---|---|
| 1.11 | 1.08 | Multiple Surfaces |
| 1.10 | 1.09 | Built-In Animations |
| 1.14 | 1.10 | Save & Load |
| 1.12 | 1.11 | Surface Controls |
| 1.13 | 1.12 | Mapping Tools |
| 1.08 | 1.13 | Images |
| 1.09 | 1.14 | Video |
| 1.15 | 1.15 | Polish & Release |

Saving begins with the content supported at v1.10; subsequent surface settings and imported media extend that versioned format as their milestones arrive. Image/video import is scheduled later, rather than permanently removed. Physical projector output/testing remains separately deferred; Test Mode and shared rendering remain required. This is an approved roadmap update, not implementation of v1.08 or authorization to publish a release now.

## Connected object faces — approved October 5, 2026

Added throughout the remaining plan: group faces into one object, align their regions on a shared content canvas, and use one content source and timeline across those faces. Continuous mode spans joined faces; Repeat repeats full content with shared timing. Each face retains its output corner geometry. Manual edge alignment and explicit seams are part of v1.08; animated continuity follows in v1.09, persistence in v1.10, then scoped controls, calibration, shared images/video and final acceptance. Full 3D reconstruction is future scope. See the [complete requirements and milestone steps](V1_REMAINING_PLAN.md). Planning only: v1.07 remains the implemented app.

## V1 show foundations and V2 plan — October 5, 2026

The user requested adjusting all V1 planning and planning V2 after the software comparison. The current future scope is reflected in the table and [remaining steps](V1_REMAINING_PLAN.md): preserve layout/content separation, stable targets, deterministic time/seek, generator presets, looks/palettes, master visual control, basic masks, editor reference photos, embedded-video audio policy and playback readiness. Keep the approved v1.08–v1.15 order and completed historical identities.

[V2](V2_ROADMAP.md) owns song sequencing and show operation. Physical output is explicitly scheduled at v2.01 while retaining the user's hardware deferral; a V1 Test Mode release must not claim projector/fullscreen or real Christmas-show verification. Each added foundation includes persistence, resource ownership and acceptance checks. This is planning only; no app changes or release.

The first animation slice v1.09.1 is implemented and accepted with user-confirmed visuals. v1.09.2 is automatically verified; v1.09.3 remains planned. See [slice evidence](V1.09.1_VERIFICATION.md).

v1.09.1 visual acceptance was confirmed by the user. v1.09.2 is implemented and automatically verified with user visual feedback pending; v1.09.3 remains planned. Routine screen checks now belong to the user. See [current slice evidence](V1.09.2_VERIFICATION.md).

All three v1.09 slices are now implemented and automatically verified; full visual acceptance belongs to the user. See [final animation evidence](V1.09.3_VERIFICATION.md). Next build milestone is v1.10 Save & Load. Full milestone version/Git delivery remains pending acceptance.

## Current delivery — October 5, 2026

v1.09 source is backed up on GitHub main at 9e64c0a. v1.10 Save & Load is implemented locally and automatically verified; it remains off GitHub as requested. See [verification](V1.10_VERIFICATION.md). Native visual checks belong to the user. Next: v1.11 Surface Controls. Earlier chronological entries above remain historical.

## v1.11 staged implementation — October 5, 2026

v1.10 is backed up on GitHub main at 55d242c. The local v1.11.1 slice adds appearance/crop/flips and explicit object/face overrides with persistence. v1.11.2 covers locks/group movement/scoped resets; v1.11.3 covers looks/palettes/master controls/fades. See [slice plan](V1.11_PLAN.md) and [current verification](V1.11.1_VERIFICATION.md). User visuals are pending; intermediate slices stay local.

## v1.11.2 local implementation — October 5, 2026

Locks, bounded object translation and scoped resets are implemented locally. All 150 Debug/Release correctness tests passed; visual acceptance belongs to the user. Schema 4 adds lock persistence/migration. See [verification](V1.11.2_VERIFICATION.md). No intermediate Git upload or bundle bump. Next: v1.11.3 looks/palettes/master controls.

## v1.11 completed implementation — October 6, 2026

All three slices are implemented; all 184 Debug/Release correctness tests passed. The 1.11/build 8 universal app is delivered locally; tested source backup was successfully pushed to main at 87459a8. See [verification](V1.11.3_VERIFICATION.md). User visuals remain pending. Next: v1.12 Mapping Tools, extending the same global blackout to calibration and face-local masks. No new release/tag/assets requested.
