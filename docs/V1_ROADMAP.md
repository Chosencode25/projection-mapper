# V1 Roadmap — Core Mapper

V1 is a native Mac app for projecting images, videos, and built-in animations onto multiple surfaces using four-corner mapping. The editor stays on the Mac; clean output appears in a separate test window or on a projector.

| Stage | Scope |
|---|---|
| 1.01 — App Skeleton | Control window, toolbar, sidebar, empty canvas, project model. |
| 1.02 — Output Selection | Choose Test Window or a connected display; detect displays; show display properties; default to Test Window without a projector. |
| 1.03 — Output Window | Separate resizable test output or borderless fullscreen projector output; configurable simulated test resolution. |
| 1.04 — Metal Renderer | Shared renderer for both output modes, basic rectangle, output sizing, performance target, disconnect/reconnect handling. |
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
