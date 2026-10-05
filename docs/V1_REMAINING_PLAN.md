# Remaining V1 milestones — ordered implementation plan

Status: planned only, October 5, 2026. User approved this order and renumbering, then requested the steps for every milestone. v1.07 remains the latest implemented/accepted app. This document does not authorize implementing all milestones or publishing now.

Use Xcode 27.0 beta 5 (27A5237l), verified before implementation, and code-only SwiftUI/programmatic AppKit. Preserve Test Mode and shared preview/output rendering. Work on feature branches; use files/automated checks first and screen only for vital final acceptance. Each implemented milestone ends with appropriate Debug/Release checks, progress/verification records, recoverable GitHub history and the requested local app copy. Keep builds/caches out of commits; preserve prior source, tags and assets. Releases are separate milestone decisions, with final package/upload planned for v1.15.

## v1.08 — Multiple Surfaces

1. Replace the single surface in the project with an ordered collection. Give each surface its own stable ID, name, corners, content and visibility; start new projects with one default surface. Prepare collection-based immutable render snapshots.
2. Add an Add Surface action. Create independent default geometry/content, assign a unique readable name and select the new surface. Adding must not change existing surfaces.
3. Expand sidebar selection and renaming. Inspector and handles address the selected ID; validate stale events after deletion/reset. Only the selected surface shows corner controls. Empty space can deselect without modifying the project.
4. Duplicate and delete. Duplicates copy geometry/content/visibility but get a new ID and name. Deletion releases resources and chooses a predictable neighboring selection; deleting the last surface leaves a supported empty project and black output. No silent recreation except New Project.
5. Reorder surfaces and establish overlap behavior. Sidebar top is visually frontmost; renderer draws back-to-front. Use consistent compositing in preview/output, ready for opacity in v1.11.
6. Add per-surface visibility. Hidden surfaces remain in the project and can be selected to restore visibility, but are omitted from clean output. One invalid surface is skipped without suppressing other valid surfaces.
7. Integrate geometry/content edits, duplication, deletion, ordering and visibility with timestamps and discard protection. Selection remains editor-only. Presets/output reopen/reset operate on the entire collection. Update obsolete future-version UI labels while touching the interface.
8. Verify independent editing/IDs, duplicate isolation, selection after deletion, empty projects, overlapping order, hide/show, invalid-shape isolation, shared GPU output and resource cleanup. Visually check multiple overlapping warped surfaces and clean output, then deliver the tested milestone.

## v1.09 — Built-In Animations

1. Introduce a generator content model with a typed pattern choice, bounded parameters and reproducible seed where needed. Each surface owns independent settings; preserve existing grid and solid content.
2. Implement a gradient generator with useful color/direction controls. Feed generated content through the existing perspective/corner mapping.
3. Implement moving checkers and moving lines with speed, scale/spacing and direction controls.
4. Implement plasma and noise with appropriate scale, speed, color and intensity controls. Keep settings meaningful to each generator rather than showing irrelevant controls.
5. Implement bounded particle/starfield content with density, speed and deterministic initialization. Avoid allocating new GPU resources every frame or allowing unbounded particle counts.
6. Add generator selection, parameter editing and pause/resume controls. Changing the content must preserve geometry, order, visibility and selection; resetting parameters only resets that generator's settings.
7. Introduce a shared animation clock so preview and output agree on phase. Animate visible active views only when needed; static scenes retain on-demand rendering. Suspend GPU work for unavailable/minimized/occluded views, resume at the shared phase, and stop timers/resources when closing output or removing content.
8. Verify deterministic frames, parameter bounds, independent generators, same-time preview/output pixels, pause/resume, hidden/static idle behavior, close/reopen and resource ownership. Measure representative mixed-surface workloads across presets; visually check smooth mapped motion, then deliver.

## v1.10 — Save & Load

1. Define a versioned project package with a manifest describing project identity/name, ordered surfaces, stable IDs, geometry, content/generator settings and output configuration. Reserve an asset location for later imports. Separate persistent project data from selection, focus, window ownership and animation timers.
2. Build encoding/decoding with finite coordinate/settings validation, ID consistency, content-type validation and schema-version handling. Reject corrupt/incompatible files clearly; define migrations as the format evolves. Physical-display preferences restore safely rather than assuming runtime screen IDs survive.
3. Implement Save and Save As with native panels, extension handling and document location/title updates. Write through staging/atomic replacement so a failed save leaves the last good project intact. Mark saved only after successful completion.
4. Implement Open and recent projects. Decode/validate into temporary state before replacing the current session, then rebuild renderer resources and editor selection. Reopening the file must reproduce all supported project content.
5. Replace default-content dirty detection with a saved-state baseline. Treat edits, add/delete/reorder and generator changes as unsaved changes; selecting a corner or a passing animation frame is not an edit.
6. Add Save/Discard/Cancel protection for New, Open, Close and Quit. Cancelled/failed saves keep the current project and action pending/cancelled appropriately; never discard merely because a save was attempted.
7. Add debounced autosave and recovery, including untitled projects, with bounded retained recovery files and a clear recovery choice. Keep manual-save and recovery state understandable; distinguish settings persistence from continuously changing animation phase.
8. Verify round trips, malformed/newer files, migration fixtures, failed/partial writes, overwrite recovery, dirty baselines, cancelled panels, lifecycle prompts and autosave recovery. Visually save/reopen a multi-surface animated project, then deliver.

## v1.11 — Surface Controls

1. Add typed per-surface appearance, crop/flip and lock settings with explicit defaults and bounds. Extend/migrate the saved format; older projects receive defaults.
2. Implement opacity and correct layered compositing. A translucent upper surface reveals lower surfaces, and zero opacity produces no contribution. Preview/output share the same calculation.
3. Implement brightness with defined bounds and clipping behavior. It changes content appearance without changing the geometry or the chosen colors/settings themselves.
4. Add horizontal/vertical flipping and normalized crop controls. Compose the content-coordinate transform consistently with the existing homography; guard empty/invalid crop regions. Test on grid/generators before imported media exists.
5. Add locking. Block geometry drag/nudge and accidental manipulation of locked surfaces while retaining selection and a reachable Unlock action. Define which non-geometry controls remain editable.
6. Add scoped resets for geometry, appearance, crop/flip and generator parameters, plus an explicit full-surface reset. A scoped reset must preserve unrelated settings and other surfaces.
7. Integrate all persistent changes with saved-state dirty detection, autosave, load/migration and shared render snapshots. Inspector controls follow selection and clearly show locking/default values.
8. Verify blended GPU pixels/order, brightness extremes, crop/flip coordinates, lock enforcement across mouse/keyboard paths, reset scope and saved round trips. Visually check overlapping animated surfaces, then deliver.

## v1.12 — Mapping Tools

1. Introduce editor/output calibration state with explicit scope. Calibration temporarily overrides normal content without overwriting the project. Per-surface diagnostic grid content remains distinct from global calibration.
2. Add selectable grid, checkerboard and crosshair calibration patterns. Preserve mapping and fitted output coordinates; expose only useful pattern settings.
3. Add white and black test output modes, clearly distinguishable from ordinary content and from unavailable/invalid rendering.
4. Implement global blackout that takes priority over surfaces and calibration, while the editor keeps accessible controls to restore output. Define restore behavior and a visible blackout indicator.
5. Add handle/outline visibility controls for the editor. Hiding handles does not modify geometry, visibility or clean output; controls stay recoverable through menus/toolbar.
6. Add discoverable toolbar/menu actions and keyboard shortcuts without stealing typing or conflicting with corner nudges. Keep temporary calibration/blackout/handle state separate from persistent project changes; launch/open defaults restore normal safe control state.
7. Integrate calibration and blackout with animation scheduling, preset changes, output close/reopen and the shared renderer. Avoid unnecessary animation when an override makes underlying motion invisible; restore the agreed shared animation phase afterward.
8. Verify override priority, restoration of original content/settings, blackout across both views, clean-output decorations, shortcut focus routing, persistence boundaries and idle behavior. Visually check patterns and immediate blackout/restore, then deliver.

## v1.13 — Image Import

1. Add native PNG/JPEG import for the selected surface. Validate/decode dimensions/content off the main thread where appropriate; report unsupported, corrupt or unreadable input without replacing existing content.
2. Add drag/drop with explicit targeting: replace the image on the selected/dropped-on surface, or create a surface when no target exists. Use the same import pipeline and stale-target checks as the picker.
3. Normalize orientation and define color/alpha handling. Build and cache Metal textures with appropriate filtering/mipmaps; handle large images with documented limits/downsampling rather than unbounded allocation.
4. Add Fit, Fill and Stretch placement. Fit keeps the whole image with unused space, Fill crops to cover, and Stretch changes proportions. Compose these with per-surface crop/flip and perspective geometry in one consistent coordinate path.
5. Add replace/remove actions that preserve the surface's geometry/order/appearance. Removing restores a clear default content choice, such as diagnostic grid. Release replaced resources when no longer referenced.
6. Extend the project package to retain image assets and references. Plan copies of imported images into package assets for portable saved projects; stage unsaved assets safely, deduplicate where useful and avoid deleting assets still used by duplicated surfaces. Migrate existing projects without media.
7. Add missing/damaged-asset handling and relinking/replacement, including copied/moved project packages. Failed imports or saves preserve existing content and the last good file; media changes participate in dirty state/autosave.
8. Verify orientation, transparency, placement/crop/flip, warped GPU pixels, large/bad imports, independent and duplicated media surfaces, repeated replacement cleanup and package round trips. Visually drag/drop, map and reopen images in clean output, then deliver.

## v1.14 — Video Import

1. Add import and inspection for formats supported by the pinned SDK/runtime through AVFoundation. Detect readable video tracks/duration/orientation and give useful failure states; do not promise unsupported codecs.
2. Create a per-video playback owner and bridge decoded frames into Metal through managed reusable texture resources. Respect frame lifetime and safe producer/consumer ownership; preserve independent surface playback.
3. Implement play/pause, restart, looping and bounded playback speed. Define end-of-clip behavior and reliable seek/restart transitions without stale frames or duplicated observers.
4. Synchronize preview/output against the same player time and frame choice. Coordinate video with generator timing and view eligibility; avoid continuously decoding/rendering content that cannot contribute to visible output.
5. Apply the same fit/fill/stretch, crop/flip, appearance and perspective paths used by images. Handle video orientation, aspect changes and color conversion consistently.
6. Add replace/remove actions and teardown for players, observers, frame caches and textures. Surface duplication has an explicit independent playback policy; delete/close/reset release all associated resources.
7. Extend saved packages with video assets and playback settings; reopen without unintended automatic playback. Define whether paused position is retained, migrate older files and support missing-media replacement/relinking. Account for large asset copies, cancellation and failed saves.
8. Verify deterministic fixture clips, decoding/frame selection, shared output, playback controls, loop boundaries, speed/seek changes, hidden/blackout states, package round trips and repeated replacement/deletion. Profile representative simultaneous videos with animated surfaces; visually verify playback, then deliver.

## v1.15 — Polish, Package & Upload

1. Add undo/redo across project edits. Group continuous drags/sliders as coherent actions, preserve stable surface IDs/assets and avoid recording selection or animation frames. Integrate history with saved-state dirty detection and reset/load boundaries.
2. Audit shortcuts, keyboard focus, accessibility labels, selection cues, empty states and layout at supported window sizes/presets. Improve inspector organization without changing mapping coordinates.
3. Consolidate actionable error and recovery flows for invalid geometry, failed imports/saves, missing media and unavailable output. Keep projector behavior/claims consistent with the still-deferred physical implementation and testing.
4. Add a useful welcome/demo project using built-in content, complete the app icon/About/help, and write clear save/import/mapping instructions. Verify demo actions cannot overwrite a user's unsaved project.
5. Profile realistic mixed workloads and long sessions: multiple surfaces, effects, images/videos, hide/show, minimize/restore, blackout, save/load and repeated resource replacement. Fix measured responsiveness, memory or GPU problems; document actual hardware/OS coverage.
6. Run final end-to-end acceptance and regressions with pinned Xcode. Verify files from earlier save versions, recovery behavior, architecture slices and available supported OS/hardware. Explicitly record any untested platforms or deferred projector work.
7. Finalize release version/build number and distribution channel. Prepare a signed app and DMG/ZIP; if Developer ID public distribution is intended, establish account/certificate availability and notarization capability before claiming completion. Otherwise identify the locally signed development artifact accurately.
8. Prepare changelog/release notes, installation instructions, checksums and source commit/tag. Preserve previously published releases. Check that the packaged app matches the tested build and contains no development-only files.
9. Perform the separately authorized upload/release publication, then verify source/tag identity, uploaded assets and a clean install/download where feasible. Update progress with the actual release link and verification results. Publishing destination/visibility must be settled before this final action; the current repository is private and no public visibility change is assumed.

## Dependency boundaries

- v1.08 establishes ordered surface identity and compositing used by every later milestone.
- v1.09 introduces dynamic content and shared timing; animation phase alone never dirties a project.
- v1.10 saves existing surfaces/generators first. v1.11 adds settings migrations, and v1.13/v1.14 add assets/media migrations rather than delaying initial saving.
- v1.12 calibration/blackout overrides must restore normal content and remain independent of persistent media settings.
- v1.13 establishes common media placement/resource/package infrastructure reused by v1.14.
- Undo/redo and release packaging are intentionally final; avoid implementation choices that prevent coherent edit transactions or stable asset ownership.
- Physical projector/fullscreen-output work remains separately deferred; Test Mode is permanent.
