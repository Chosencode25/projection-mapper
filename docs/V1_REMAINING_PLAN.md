# Remaining V1 milestones — ordered implementation plan

Status: planned only, October 5, 2026. User approved this order and renumbering, then requested the steps for every milestone. v1.07 remains the latest implemented/accepted app. This document does not authorize implementing all milestones or publishing now.

Use Xcode 27.0 beta 5 (27A5237l), verified before implementation, and code-only SwiftUI/programmatic AppKit. Preserve Test Mode and shared preview/output rendering. Work on feature branches; use files/automated checks first and screen only for vital final acceptance. Each implemented milestone ends with appropriate Debug/Release checks, progress/verification records, recoverable GitHub history and the requested local app copy. Keep builds/caches out of commits; preserve prior source, tags and assets. Releases are separate milestone decisions, with final package/upload planned for v1.15.

## Connected object faces — approved October 5, 2026

Multiple surfaces can be faces of one named object, such as the front, side and top of a box. Keep standalone surfaces supported. Each object has a stable ID, member surface IDs and a shared content owner; each face keeps its own four output corners. Grouping alone does not establish content continuity.

Define a shared two-dimensional content canvas and a separate input mapping for each face. Provide manual placement, orientation and size controls, plus edge links recording which face edges meet and their direction. Matching linked boundaries sample matching content coordinates, with consistent content scale. Each face retains its perspective transform to output coordinates. A closed object can require deliberate seams in a flat layout: record those seams and validate linked edges. Automatic 3D reconstruction is future scope.

Offer explicit **Continuous** and **Repeat** modes. Continuous assigns each face a region of the shared canvas so a stripe, image or particle can cross joined faces. Repeat shows the whole content on each face with shared timing. Linked faces use one generator seed/time or video player/frame. Detaching a face creates independent content under an explicit copy policy; editing linked content clearly applies to the object. These are planned requirements, not existing app features.

## v1.08 — Multiple Surfaces

1. Replace the single surface in the project with an ordered collection. Give each surface its own stable ID, name, corners, content and visibility; start new projects with one default surface. Prepare collection-based immutable render snapshots.
2. Add named object groups with stable IDs, membership, group/ungroup and object selection. Make face/object edit scope clear. Keep global surface draw order authoritative within groups. Object duplication assigns new object/face IDs and rewrites links; face deletion/detachment cleans up references. Group visibility inherits without erasing individual face visibility. Include these edits in dirty state and discard protection.
3. Add shared-canvas input mapping, Continuous/Repeat mode and manual edge alignment. Use the static diagnostic grid to verify matching boundary coordinates, orientation and scale before animation. Input-layout edits do not move output corners. Show invalid joins and deliberate seams in the editor. Verify membership, grouping/ungrouping, duplicate isolation, deletion, static shared-canvas GPU pixels and reversed-edge joins alongside the original acceptance checks.
4. Add an Add Surface action. Create independent default geometry/content, assign a unique readable name and select the new surface. Adding must not change existing surfaces.
5. Expand sidebar selection and renaming. Inspector and handles address the selected ID; validate stale events after deletion/reset. Only the selected surface shows corner controls. Empty space can deselect without modifying the project.
6. Duplicate and delete. Duplicates copy geometry/content/visibility but get a new ID and name. Deletion releases resources and chooses a predictable neighboring selection; deleting the last surface leaves a supported empty project and black output. No silent recreation except New Project.
7. Reorder surfaces and establish overlap behavior. Sidebar top is visually frontmost; renderer draws back-to-front. Use consistent compositing in preview/output, ready for opacity in v1.11.
8. Add per-surface visibility. Hidden surfaces remain in the project and can be selected to restore visibility, but are omitted from clean output. One invalid surface is skipped without suppressing other valid surfaces.
9. Integrate geometry/content edits, duplication, deletion, ordering and visibility with timestamps and discard protection. Selection remains editor-only. Presets/output reopen/reset operate on the entire collection. Update obsolete future-version UI labels while touching the interface.
10. Verify independent editing/IDs, duplicate isolation, selection after deletion, empty projects, overlapping order, hide/show, invalid-shape isolation, shared GPU output and resource cleanup. Visually check multiple overlapping warped surfaces and clean output, then deliver the tested milestone.

## v1.09 — Built-In Animations

1. Introduce a generator content model with a typed pattern choice, bounded parameters and reproducible seed where needed. Standalone surfaces own independent settings; linked faces share an object content owner; preserve existing grid and solid content.
2. Extend generator ownership: standalone faces remain independent; linked faces reference one object generator/settings owner. Evaluate Continuous patterns in shared canvas coordinates; Repeat uses the whole pattern per face. Object-level parameter edits and pause/restart affect all linked faces. Define linking/detaching and duplication phase behavior. Particles live in the shared canvas and cross valid joins without being recreated. Reuse generated resources across linked faces where appropriate.
3. Implement a gradient generator with useful color/direction controls. Feed generated content through the existing perspective/corner mapping.
4. Implement moving checkers and moving lines with speed, scale/spacing and direction controls.
5. Implement plasma and noise with appropriate scale, speed, color and intensity controls. Keep settings meaningful to each generator rather than showing irrelevant controls.
6. Implement bounded particle/starfield content with density, speed and deterministic initialization. Avoid allocating new GPU resources every frame or allowing unbounded particle counts.
7. Add generator selection, parameter editing and pause/resume controls. Changing the content must preserve geometry, order, visibility and selection; resetting parameters only resets that generator's settings.
8. Introduce a shared animation clock so preview and output agree on phase. Animate visible active views only when needed; static scenes retain on-demand rendering. Suspend GPU work for unavailable/minimized/occluded views, resume at the shared phase, and stop timers/resources when closing output or removing content.
9. Add acceptance for moving stripes/checkers and deterministic particles crossing two and three faces with matching boundary samples, scale, direction, seed and phase. Include reversed edges, deliberate seams, Continuous/Repeat differences, detach isolation and multiple independently animated objects in matching preview/output.
10. Verify deterministic frames, parameter bounds, independent generators, same-time preview/output pixels, pause/resume, hidden/static idle behavior, close/reopen and resource ownership. Measure representative mixed-surface workloads across presets; visually check smooth mapped motion, then deliver.

## v1.10 — Save & Load

1. Persist stable object/face IDs, membership, shared content owners, per-face input maps, edge links/directions, deliberate seams and Continuous/Repeat mode. Validate finite maps, owner/membership references and edge identities before replacing current state; distinguish invalid references from editable join diagnostics. Rebuild runtime ownership after loading. These edits affect the saved baseline; selection and animation frames do not.
2. Define a versioned project package with a manifest describing project identity/name, ordered surfaces, stable IDs, geometry, content/generator settings and output configuration. Reserve an asset location for later imports. Separate persistent project data from selection, focus, window ownership and animation timers.
3. Build encoding/decoding with finite coordinate/settings validation, ID consistency, content-type validation and schema-version handling. Reject corrupt/incompatible files clearly; define migrations as the format evolves. Physical-display preferences restore safely rather than assuming runtime screen IDs survive.
4. Implement Save and Save As with native panels, extension handling and document location/title updates. Write through staging/atomic replacement so a failed save leaves the last good project intact. Mark saved only after successful completion.
5. Implement Open and recent projects. Decode/validate into temporary state before replacing the current session, then rebuild renderer resources and editor selection. Reopening the file must reproduce all supported project content.
6. Replace default-content dirty detection with a saved-state baseline. Treat edits, add/delete/reorder and generator changes as unsaved changes; selecting a corner or a passing animation frame is not an edit.
7. Add Save/Discard/Cancel protection for New, Open, Close and Quit. Cancelled/failed saves keep the current project and action pending/cancelled appropriately; never discard merely because a save was attempted.
8. Add debounced autosave and recovery, including untitled projects, with bounded retained recovery files and a clear recovery choice. Keep manual-save and recovery state understandable; distinguish settings persistence from continuously changing animation phase.
9. Round-trip grouped and standalone faces, duplicated objects and detached content. Verify the restored animation still crosses the same joined edges, with settings/seed preserved; test malformed membership and stale links, migrations and autosave recovery.
10. Verify round trips, malformed/newer files, migration fixtures, failed/partial writes, overwrite recovery, dirty baselines, cancelled panels, lifecycle prompts and autosave recovery. Visually save/reopen a multi-surface animated project, then deliver.

## v1.11 — Surface Controls

1. Define object-level controls and visible face overrides with explicit inspector scope. Apply shared object crop/flip before per-face input mapping to preserve joins; face-specific overrides can intentionally break continuity and must be visible. Object locks protect member geometry while preserving individual face locks when unlocked. Group movement transforms all member output corners in one bounded transaction, preserving relative layout and input maps. Distinguish face resets, object content/appearance resets and shared-layout resets.
2. Add typed per-surface appearance, crop/flip and lock settings with explicit defaults and bounds. Extend/migrate the saved format; older projects receive defaults.
3. Implement opacity and correct layered compositing. A translucent upper surface reveals lower surfaces, and zero opacity produces no contribution. Preview/output share the same calculation.
4. Implement brightness with defined bounds and clipping behavior. It changes content appearance without changing the geometry or the chosen colors/settings themselves.
5. Add horizontal/vertical flipping and normalized crop controls. Compose the content-coordinate transform consistently with the existing homography; guard empty/invalid crop regions. Test on grid/generators before imported media exists.
6. Add locking. Block geometry drag/nudge and accidental manipulation of locked surfaces while retaining selection and a reachable Unlock action. Define which non-geometry controls remain editable.
7. Add scoped resets for geometry, appearance, crop/flip and generator parameters, plus an explicit full-surface reset. A scoped reset must preserve unrelated settings and other surfaces.
8. Integrate all persistent changes with saved-state dirty detection, autosave, load/migration and shared render snapshots. Inspector controls follow selection and clearly show locking/default values.
9. Verify control inheritance, overrides, lock enforcement, group movement and reset scope without erasing membership/links through unrelated resets. Check shared crop/flip boundary pixels and saved round trips.
10. Verify blended GPU pixels/order, brightness extremes, crop/flip coordinates, lock enforcement across mouse/keyboard paths, reset scope and saved round trips. Visually check overlapping animated surfaces, then deliver.

## v1.12 — Mapping Tools

1. Introduce editor/output calibration state with explicit scope. Calibration temporarily overrides normal content without overwriting the project. Per-surface diagnostic grid content remains distinct from global calibration.
2. Add selectable grid, checkerboard and crosshair calibration patterns. Preserve mapping and fitted output coordinates; expose only useful pattern settings.
3. Add white and black test output modes, clearly distinguishable from ordinary content and from unavailable/invalid rendering.
4. Implement global blackout that takes priority over surfaces and calibration, while the editor keeps accessible controls to restore output. Define restore behavior and a visible blackout indicator.
5. Add handle/outline visibility controls for the editor. Hiding handles does not modify geometry, visibility or clean output; controls stay recoverable through menus/toolbar.
6. Add discoverable toolbar/menu actions and keyboard shortcuts without stealing typing or conflicting with corner nudges. Keep temporary calibration/blackout/handle state separate from persistent project changes; launch/open defaults restore normal safe control state.
7. Integrate calibration and blackout with animation scheduling, preset changes, output close/reopen and the shared renderer. Avoid unnecessary animation when an override makes underlying motion invisible; restore the agreed shared animation phase afterward.
8. Add shared-canvas stripes/checkers and editor-only object/face/edge labels to inspect linked-edge orientation, scale and continuity. Keep labels out of clean output. Calibration and blackout restore membership, input maps, shared content/settings and timing. Verify three-face calibration, reversed joins, deliberate seams and blackout restoration without modifying saved project data.
9. Verify override priority, restoration of original content/settings, blackout across both views, clean-output decorations, shortcut focus routing, persistence boundaries and idle behavior. Visually check patterns and immediate blackout/restore, then deliver.

## v1.13 — Image Import

1. Make picker/drop targeting explicitly face or object. Replacing object content updates all linked faces; independent face replacement requires an explicit detach choice. In Continuous mode, Fit/Fill/Stretch applies to the shared canvas once, then faces sample their regions; Repeat uses the full image per face. Linked faces reuse the object texture and packaged asset. Removing one face does not release content still referenced by others.
2. Add native PNG/JPEG import for the selected surface. Validate/decode dimensions/content off the main thread where appropriate; report unsupported, corrupt or unreadable input without replacing existing content.
3. Add drag/drop with explicit targeting: replace the image on the selected/dropped-on surface, or create a surface when no target exists. Use the same import pipeline and stale-target checks as the picker.
4. Normalize orientation and define color/alpha handling. Build and cache Metal textures with appropriate filtering/mipmaps; handle large images with documented limits/downsampling rather than unbounded allocation.
5. Add Fit, Fill and Stretch placement. Fit keeps the whole image with unused space, Fill crops to cover, and Stretch changes proportions. Compose these with per-surface crop/flip and perspective geometry in one consistent coordinate path.
6. Add replace/remove actions that preserve the surface's geometry/order/appearance. Removing restores a clear default content choice, such as diagnostic grid. Release replaced resources when no longer referenced.
7. Extend the project package to retain image assets and references. Plan copies of imported images into package assets for portable saved projects; stage unsaved assets safely, deduplicate where useful and avoid deleting assets still used by duplicated surfaces. Migrate existing projects without media.
8. Add missing/damaged-asset handling and relinking/replacement, including copied/moved project packages. Failed imports or saves preserve existing content and the last good file; media changes participate in dirty state/autosave.
9. Verify one image spans joined faces, object replacement versus detach, shared resource cleanup, asset references and restored input maps after save/reopen. Include reversed face orientation and deliberately repeated images.
10. Verify orientation, transparency, placement/crop/flip, warped GPU pixels, large/bad imports, independent and duplicated media surfaces, repeated replacement cleanup and package round trips. Visually drag/drop, map and reopen images in clean output, then deliver.

## v1.14 — Video Import

1. Add import and inspection for formats supported by the pinned SDK/runtime through AVFoundation. Detect readable video tracks/duration/orientation and give useful failure states; do not promise unsupported codecs.
2. Use one playback owner and decoded frame for all linked object faces, sampled through their input maps; a shared clock alone is insufficient. Object play/pause/restart/seek/loop/speed and replacement affect every linked face. Continuous placement uses the shared canvas; Repeat uses the full frame. Duplicating a face within an object retains its shared playback reference; duplicating a standalone face or entire object creates an independent owner with a defined initial-position policy. Detach explicitly copies settings. Release shared resources only when their final owner/reference is removed.
3. Create a per-video playback owner and bridge decoded frames into Metal through managed reusable texture resources. Respect frame lifetime and safe producer/consumer ownership; preserve independent surface playback.
4. Implement play/pause, restart, looping and bounded playback speed. Define end-of-clip behavior and reliable seek/restart transitions without stale frames or duplicated observers.
5. Synchronize preview/output against the same player time and frame choice. Coordinate video with generator timing and view eligibility; avoid continuously decoding/rendering content that cannot contribute to visible output.
6. Apply the same fit/fill/stretch, crop/flip, appearance and perspective paths used by images. Handle video orientation, aspect changes and color conversion consistently.
7. Add replace/remove actions and teardown for players, observers, frame caches and textures. Standalone surface/object duplication has an explicit independent playback policy; member-face duplication retains the shared object player; delete/close/reset release all associated resources.
8. Extend saved packages with video assets and playback settings; reopen without unintended automatic playback. Define whether paused position is retained, migrate older files and support missing-media replacement/relinking. Account for large asset copies, cancellation and failed saves.
9. Verify video crossing linked edges with identical frame selection, group controls/replacement, Continuous/Repeat placement, detach/duplicate isolation and saved ownership. Profile shared playback separately from several independent players.
10. Verify deterministic fixture clips, decoding/frame selection, shared output, playback controls, loop boundaries, speed/seek changes, hidden/blackout states, package round trips and repeated replacement/deletion. Profile representative simultaneous videos with animated surfaces; visually verify playback, then deliver.

## v1.15 — Polish, Package & Upload

1. Add undo/redo across project edits. Group continuous drags/sliders as coherent actions, preserve stable surface IDs/assets and avoid recording selection or animation frames. Integrate history with saved-state dirty detection and reset/load boundaries.
2. Audit shortcuts, keyboard focus, accessibility labels, selection cues, empty states and layout at supported window sizes/presets. Improve inspector organization without changing mapping coordinates.
3. Consolidate actionable error and recovery flows for invalid geometry, failed imports/saves, missing media and unavailable output. Keep projector behavior/claims consistent with the still-deferred physical implementation and testing.
4. Add a useful welcome/demo project using built-in content, complete the app icon/About/help, and write clear save/import/mapping instructions. Verify demo actions cannot overwrite a user's unsaved project.
5. Profile realistic mixed workloads and long sessions: multiple surfaces, effects, images/videos, hide/show, minimize/restore, blackout, save/load and repeated resource replacement. Fix measured responsiveness, memory or GPU problems; document actual hardware/OS coverage.
6. Include object grouping/ungrouping, input maps, edge links, shared content edits and group movement in coherent undo/redo transactions. Add a built-in three-face box demo with a moving stripe and instructions for grouping, edge alignment, deliberate seams and Continuous/Repeat modes. Profile shared generators/textures/players to avoid full per-face content duplication, and verify cleanup after detach/delete.
7. Run final Test Mode acceptance through grouping → input alignment → continuous animation → save/reopen → shared image/video replacement → undo/redo. Check matching preview/output boundary samples, reversed joins, seams, resize and multiple independent objects. Record physical projector testing separately as deferred; this test does not claim automatic 3D mapping.
8. Run final end-to-end acceptance and regressions with pinned Xcode. Verify files from earlier save versions, recovery behavior, architecture slices and available supported OS/hardware. Explicitly record any untested platforms or deferred projector work.
9. Finalize release version/build number and distribution channel. Prepare a signed app and DMG/ZIP; if Developer ID public distribution is intended, establish account/certificate availability and notarization capability before claiming completion. Otherwise identify the locally signed development artifact accurately.
10. Prepare changelog/release notes, installation instructions, checksums and source commit/tag. Preserve previously published releases. Check that the packaged app matches the tested build and contains no development-only files.
11. Perform the separately authorized upload/release publication, then verify source/tag identity, uploaded assets and a clean install/download where feasible. Update progress with the actual release link and verification results. Publishing destination/visibility must be settled before this final action; the current repository is private and no public visibility change is assumed.

## Dependency boundaries

- v1.08 establishes ordered surface identity/compositing, object membership, shared input maps and static edge continuity used by every later milestone.
- v1.09 introduces dynamic content, shared object generators and cross-face continuity; animation phase alone never dirties a project.
- v1.10 saves surfaces, objects, shared input maps/edge links and generators first. v1.11 adds settings migrations, and v1.13/v1.14 add assets/media migrations rather than delaying initial saving.
- v1.12 calibration/blackout overrides must restore normal content and remain independent of persistent media settings.
- v1.13 establishes common media placement/resource/package infrastructure reused by v1.14.
- Undo/redo and release packaging are intentionally final; avoid implementation choices that prevent coherent edit transactions or stable asset ownership.
- Physical projector/fullscreen-output work remains separately deferred; Test Mode is permanent.
