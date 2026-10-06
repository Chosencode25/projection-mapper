# V1 Roadmap — Core Mapper

V1 is a native Mac app for projecting images, videos, and built-in animations onto multiple surfaces using four-corner mapping. Faces can form objects with shared content coordinates so animations and media continue across joined faces. The editor stays on the Mac; clean output appears in a separate test window or on a projector.

See [ordered implementation steps for every remaining milestone](V1_REMAINING_PLAN.md). Those steps are planned, not implemented.

| Stage | Scope |
|---|---|
| 1.01 — App Skeleton | Control window, toolbar, sidebar, empty canvas, project model. |
| 1.02 — Output Selection | Choose Test Window or a connected display; detect displays; show display properties; default to Test Window without a projector. |
| 1.03 — Test Output Window | Delivered in three slices below. Fullscreen projector implementation and physical checks are deferred. |
| 1.04 — Metal Renderer | Five slices below: Metal foundation, rectangle, shared preview, lifecycle, performance. Renderer reusable for both output modes; projector implementation/physical reconnect checks deferred. |
| [1.05 — First Surface](V1.05_PLAN.md) | Implemented and locally accepted: one project-owned surface, four normalized corners, initial rectangle, sidebar selection and inspector. |
| [1.06 — Corner Nodes](V1.06_PLAN.md) | Implemented and locally accepted: draggable handles, live output updates, focused arrow-key nudging, larger Shift nudges. |
| [1.07 — Perspective Warp](V1.07_PLAN.md) | Implemented and locally accepted: projective diagnostic textures, trapezoids, safe invalid geometry and recovery. |
| 1.08 — Multiple Surfaces | Add/select/rename/duplicate/delete/reorder surfaces and toggle visibility; object groups, shared-canvas input maps and static edge alignment. Next active milestone. |
| 1.09 — Built-In Animations | Gradients, plasma, noise, checkers, moving lines, particles/starfield; speed, scale, color, intensity controls; shared object generators and continuous motion across linked faces. |
| 1.10 — Save & Load | Versioned project files; surface geometry, object membership, input maps/edge links, generator settings, output configuration; autosave and recent projects. Extend saved media references when import arrives. |
| 1.11 — Surface Controls | Opacity, brightness, crop, flipping, resets, and locking; object/face scope, inherited locks and group movement. |
| 1.12 — Mapping Tools | Grid, checkerboard, crosshairs, white/black output, global blackout, handle visibility; object/edge continuity diagnostics. |
| 1.13 — Images | PNG/JPEG import and drag/drop; fit/fill/stretch; aspect ratio; shared images spanning object faces; replace/remove; integrate media references with saved projects. |
| 1.14 — Video | System-supported video import; AVFoundation frames into Metal; play/pause, restart, loop, speed; shared player/frame across object faces; integrate media references/playback settings with saved projects. |
| 1.15 — Polish & Release | Undo/redo including object edits, continuity demo/checks, shortcuts, error and missing-media handling, disconnect warning, welcome/demo, profiling, icon, signing, DMG, final verification and release upload. |

The first major mapping milestone is 1.07. A temporary developer test texture or pattern can exercise warping before image/video import, now scheduled after the core mapping tools; full calibration tools remain planned for 1.12.

Later major versions cover richer mesh/mask/effect tools, camera-assisted mapping and live control, and professional 3D or multi-projector features.

## v1.03 slices — approved October 5, 2026

| Slice | Scope |
|---|---|
| 1.03.1 — Basic Test Window | Open/close controls, one normal resizable black output window, shared status, safe window ownership and cleanup. |
| 1.03.2 — Resolution and Scaling | Simulated resolution presets, aspect-preserving display with black margins, matching editor preview, remembered resolution independent of window size. |
| 1.03.3 — Window Behavior and Polish | Remember size/position, offscreen recovery, Show Output/navigation, shortcuts/layout checks, preparation for the shared renderer. |

The user will not have a projector for a while. Projector-window implementation and physical checks are deferred and do not block these Test Mode milestones. Existing display discovery remains available; earlier external hardware checks remain unverified.

## v1.04 slices — approved October 5, 2026

See [master plan](V1.04_PLAN.md) for requirements, acceptance, and delivery. All five slices are implemented and locally accepted for Test Mode. See [final performance/acceptance](V1.04.5_VERIFICATION.md). Physical display/projector and backing-scale transitions remain deferred. v1.05 is also [implemented and locally accepted](V1.05_VERIFICATION.md). v1.06 is also [implemented and locally accepted](V1.06_VERIFICATION.md). v1.07 is also [implemented and locally accepted](V1.07_VERIFICATION.md). Next active development milestone: v1.08 Multiple Surfaces. See the reordered remaining roadmap below.

| Slice | Scope | Finished when |
|---|---|---|
| [v1.04.1 — Metal Foundation](V1.04.1_PLAN.md) | Metal device/queue and drawing view, fixed-color clear, initialization failure handling. | Output reliably draws through resize, close, and reopen. |
| [v1.04.2 — First Rectangle](V1.04.2_PLAN.md) | Shader pipeline and temporary rectangle in normalized coordinates; resolution-independent geometry. | The rectangle keeps its intended position and proportions across presets and window sizes. |
| [v1.04.3 — Shared Editor Preview](V1.04.3_PLAN.md) | Same renderer and scene data in editor and Test Output; clean output excludes editor UI. | Both views consistently show the same content. |
| [v1.04.4 — Rendering Lifecycle](V1.04.4_PLAN.md) | Drawable changes, hidden/minimized/closed views, resume behavior, resource cleanup. | Repeated window operations behave correctly without accumulating resources. |
| [v1.04.5 — Performance and Acceptance](V1.04.5_PLAN.md) | Frame pacing/GPU measurements across presets, targeted tuning, final regressions. | We have a stable renderer and documented performance on the development Mac. |

Test each slice as it is developed. Commit and push completed verified slices without automatically creating releases. Projector implementation/testing remains deferred. After v1.04, v1.05 turns the temporary rectangle into the first actual mapping surface.

## Relative difficulty estimates — October 5, 2026

These are subjective implementation/testing-complexity estimates relative to this project, not measured effort or time commitments. v1.04's 8/10 describes the complete renderer milestone; individual slices narrow its scope.

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
| 1.08 — Multiple Surfaces | 6/10 | Selection, ordering, object membership, input maps, edge alignment, multiple draws. |
| 1.09 — Built-In Animations | 7/10 | Several shaders, shared object coordinates/timing, cross-face motion, performance. |
| 1.10 — Save & Load | 8/10 | Reliable files, generator settings, autosave, migrations, recovery; later media extensions. |
| 1.11 — Surface Controls | 5/10 | Controls interacting with content and mapping. |
| 1.12 — Mapping Tools | 4/10 | Patterns and output controls on established rendering. |
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
