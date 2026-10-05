# V1 Roadmap — Core Mapper

V1 is a native Mac app for projecting images, videos, and built-in animations onto multiple surfaces using four-corner mapping. The editor stays on the Mac; clean output appears in a separate test window or on a projector.

| Stage | Scope |
|---|---|
| 1.01 — App Skeleton | Control window, toolbar, sidebar, empty canvas, project model. |
| 1.02 — Output Selection | Choose Test Window or a connected display; detect displays; show display properties; default to Test Window without a projector. |
| 1.03 — Test Output Window | Delivered in three slices below. Fullscreen projector implementation and physical checks are deferred. |
| 1.04 — Metal Renderer | Five slices below: Metal foundation, rectangle, shared preview, lifecycle, performance. Renderer reusable for both output modes; projector implementation/physical reconnect checks deferred. |
| 1.05 — First Surface | One surface with four stored normalized corners, initial rectangle, selection state. |
| 1.06 — Corner Nodes | Draggable handles, live output updates, arrow-key nudging, larger Shift nudges. |
| 1.07 — Perspective Warp | Correct perspective mapping, texture coordinates, trapezoids, and extreme-position handling. |
| 1.08 — Images | PNG/JPEG import and drag/drop; fit/fill/stretch; aspect ratio; replace/remove. |
| 1.09 — Video | System-supported video import; AVFoundation frames into Metal; play/pause, restart, loop, speed. |
| 1.10 — Built-In Animations | Gradients, plasma, noise, checkers, moving lines, particles/starfield; speed, scale, color, intensity controls. |
| 1.11 — Multiple Surfaces | Add/select/rename/duplicate/delete/reorder surfaces and toggle visibility. |
| 1.12 — Surface Controls | Opacity, brightness, crop, flipping, resets, and locking. |
| 1.13 — Mapping Tools | Grid, checkerboard, crosshairs, white/black output, global blackout, handle visibility. |
| 1.14 — Save & Load | Versioned project files; geometry, media references, generator settings, output configuration; autosave and recent projects. |
| 1.15 — Polish & Release | Undo/redo, shortcuts, error and missing-media handling, disconnect warning, welcome/demo, profiling, icon, signing, DMG. |

The first major mapping milestone is 1.07. A temporary developer test texture or pattern can exercise warping before user-facing image import arrives in 1.08 and full calibration tools in 1.13.

Later major versions cover richer mesh/mask/effect tools, camera-assisted mapping and live control, and professional 3D or multi-projector features.

## v1.03 slices — approved October 5, 2026

| Slice | Scope |
|---|---|
| 1.03.1 — Basic Test Window | Open/close controls, one normal resizable black output window, shared status, safe window ownership and cleanup. |
| 1.03.2 — Resolution and Scaling | Simulated resolution presets, aspect-preserving display with black margins, matching editor preview, remembered resolution independent of window size. |
| 1.03.3 — Window Behavior and Polish | Remember size/position, offscreen recovery, Show Output/navigation, shortcuts/layout checks, preparation for the shared renderer. |

The user will not have a projector for a while. Projector-window implementation and physical checks are deferred and do not block these Test Mode milestones. Existing display discovery remains available; earlier external hardware checks remain unverified.

## v1.04 slices — approved October 5, 2026

See [master plan](V1.04_PLAN.md) for requirements, acceptance, and delivery. v1.04.1–v1.04.3 are implemented and locally verified; v1.04.4 is implemented with automated verification (interactive acceptance pending); v1.04.5 remains planned. See [v1.04.1 verification](V1.04.1_VERIFICATION.md).

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
| 1.08 — Images | 5/10 | Import, GPU textures, fit/fill/stretch, replacement. |
| 1.09 — Video | 9/10 | Playback timing, decoding, Metal integration, resource management. |
| 1.10 — Built-In Animations | 7/10 | Several shaders, controls, consistent performance. |
| 1.11 — Multiple Surfaces | 6/10 | Selection, ordering, duplication, visibility, multiple draws. |
| 1.12 — Surface Controls | 5/10 | Controls interacting with media and mapping. |
| 1.13 — Mapping Tools | 4/10 | Patterns and output controls on established rendering. |
| 1.14 — Save & Load | 8/10 | Reliable files, media references, autosave, migrations, recovery. |
| 1.15 — Polish & Release | 9/10 | Undo/redo, error handling, profiling, packaging, release verification. |
