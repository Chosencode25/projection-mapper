# Editor workflow polish

Approved for implementation November 17, 2026, following the initial planning-only request. Baseline was v2.09/build 30; the local implementation is build 31. The implementation and verification record is in [EDITOR_WORKFLOW_POLISH_VERIFICATION.md](EDITOR_WORKFLOW_POLISH_VERIFICATION.md). User acceptance is recorded separately from automated and agent screen checks.

## Intended editing experience

Open a project or start a local draft, select an item, make an edit, and see the result immediately. The inspector follows the selection, the timeline makes timing and relationships visible, and saving happens in the background. Edit opens with an organized scene list, a large canvas, a contextual inspector, and a resizable timeline.

## 1. Establish the layout and selection behavior

- Keep the main Edit and Show workspace switch. Use one project title and compact save indicator in the window header.
- Use the left sidebar for a single expandable hierarchy of objects, faces, layers, and regions. Retain search, selection, ordering, visibility, and locks. Show layer and region relationships where they belong in that hierarchy.
- Use the right inspector for the selected face, object, layer, region, clip, fixture, cue, or mouth key. Put its primary controls first. Move project-wide settings, palette/look libraries, output configuration, and calibration into deliberate destinations available from the toolbar or menus.
- Consolidate the current Edit/Show/Project inspector navigation into those contextual controls and project settings. Keep one obvious route to each common action.
- Define one authoritative selection shared by the sidebar, canvas, timeline, inspector, and keyboard actions. Clicking a clip reveals that clip's controls. Selecting a region reveals its shape and content. A compact scope label identifies shared-object edits, such as “Panorama · 3 faces.”
- Preserve the current mode, selection, canvas zoom/pan, timeline zoom/scroll, and panel sizes when visiting Show and returning to Edit. Adapt the layout to the app's supported minimum window size and provide a reset-layout action.

## 2. Remove persistent explanatory copy

- Audit the inspector, timeline, sidebar, fixture workspace, output panels, and phone remote. Remove repeated headings, workflow paragraphs, duplicated project names, and instructions that repeat a nearby control's purpose.
- Replace the permanent image Fit/Fill/Stretch explanation with labeled choices and hover help. Move video-audio setup paragraphs, shared-content explanations, and mask-editing tutorials into optional help.
- Keep visible field labels, units, selected state, and meaningful scope. Use consistent native icons with tooltips and accessibility names for familiar actions. Give uncommon actions a short text label.
- Give an empty area one primary action, such as Add Surface or Add Song. Show short drawing guidance only while actively drawing. Place advanced settings in compact disclosures without multiple nested cards.
- Keep status concise. A save failure belongs beside save status, a missing asset beside that asset, and an invalid field beside that field. Let the user open details or readiness when they need them. Consolidate repeated reports of the same problem.

## 3. Make edits act directly on their visible target

- When a clip is selected, changing its effect, color, media, or timing updates that clip immediately through the normal undo path. When the base content is selected, the same controls edit the base. Retain an explicit copy/capture action for intentionally transferring content between targets.
- Commit names and numeric fields on Return and focus loss. Restore the previous valid value on Escape. Preserve in-progress text when the view updates. Use consistent validation, units, and reasonable defaults.
- Make duplicate, remove, rename, hide, and reorder behavior consistent across faces, objects, layers, regions, clips, and cues. Keyboard actions follow the active selection and preserve native text editing behavior.
- Make media drops target the item under the pointer, with visible feedback before applying the drop. Show import progress on that item. Default a drop onto unused canvas to creating a new surface.
- Keep contextual creation reachable beside the work. Add Layer beside layers, Add Region beside a selected face, and Add Clip on its track. Create a valid editable item with a useful default name and select it immediately.
- Use undo for completed reversible edits. Reserve confirmations for operations with meaningful loss or changes to a running show. Maintain a visible route to blackout and output controls during editing.

## 4. Improve the canvas and timeline together

- Keep the canvas prominent. Use selection outlines and handles to explain what can be manipulated. Show region geometry and layer placement handles when those items are selected. Retain a compact tool choice for selecting, panning, mapping corners, and drawing shapes.
- Group timeline lanes under their object or face and expand only the layers, regions, lighting, or mouth keys needed for the current task. Match sidebar selection and timeline highlighting.
- Keep Play/Pause, Stop, time, Snap, and zoom directly accessible. Put marker editing, choreography creation, audio routing, and other occasional controls in focused popovers or menus. Keep the waveform and loop range accessible when a song exists.
- Put clip properties in the contextual inspector and simplify the cramped bottom clip editor. Support dragging and precise numeric edits through the same model operations.
- Show selection, drag previews, snap feedback, loop boundaries, and transition handles clearly. Keep view navigation stable when a clip is edited or a track expands. Provide useful track heights and resizable panels.
- In fixtures, make selection in the schematic reveal the fixture's controls. Keep controller setup and detailed simulated channel monitoring in their dedicated panels. Label simulation where it affects the user's interpretation of output.

## 5. Add actual project autosave and managed drafts

- Create a uniquely identified local draft when the user starts a new project. Retain it across closing and relaunching. Expose recent projects and drafts with useful names and thumbnails where available. The existing bundled demo opens as an independent editable draft.
- For a named project, autosave committed edits to its project package after about two idle seconds. Add a maximum interval of about ten seconds between durable snapshots while edits continue. Take a coherent snapshot of the last committed edit while a drag or text edit remains in progress.
- For an unnamed project, save to its managed local draft location. Command-S on a draft asks for a name and destination. Command-S on a named project flushes its pending save. Save As creates a separate project at the chosen location.
- Keep editing responsive during autosave. Use a serialized background save coordinator, coalesce pending revisions, and reuse the existing transactional package writer and media leases. Preserve the last valid package on failure.
- Avoid re-inspecting and copying unchanged media for every small edit. Validate media when imported or changed and stage a consistent package with its referenced assets. Design the immutable media reuse strategy before altering package writes.
- Track the exact document and media revision saved. An older save completing after a new edit must leave the newer edit pending. Late work for a previous project or Save As destination must finish against its captured document without changing the current document's save status.
- Route phone edits, undo/redo, imports, relinks, and Mac edits through the same save coordinator. Keep crash recovery coordinated with autosave and retain bounded checkpoints for restoring a prior version.
- Use a compact Editing/Saving/Saved indicator and an actionable save-failure state. Show Saved only when the current committed revision and its assets are durable. Successful autosaves should be quiet.
- On close, Open, or Quit, finish the pending save and preserve recoverable work. A save failure offers Retry or Save a Copy. Reopening should resolve a newer recovery snapshot against the saved document by revision. Restore editing paused with output and remote connections under the existing explicit-start rules.

Build 30 provided a debounced recovery copy and explicit media-aware saves. Build 31 adds serialized background document autosave and managed drafts on the transactional writer. The saved project snapshot and media stamps define durability; newer edits remain pending when an older save finishes. See the verification record for coverage and limits.

## 6. Make problems easy to resolve

- Prevent invalid edits where feasible, with drag limits, constrained values, and coherent defaults. Show a short local explanation when an operation is unavailable.
- Give a missing-media item a Relink action, an unavailable output a Choose Output action, and a save problem Retry and Save a Copy actions. Keep detailed diagnostics available through an expandable detail view.
- Keep readiness as an intentional pre-show check. Retain actionable feedback for blocked output, lost devices, and unsafe operations. Show only current, relevant problems in the editing workspace.
- Keep Show focused on playback, next cue, output, blackout, mute, and remote status. Make temporary connection failures understandable and recoverable within the existing session rules.

## Build order and acceptance

1. Produce the proposed Edit layout and selection/control map, and an inventory of text to remove or move into help. Review the hierarchy using the existing Encore project and a new blank project.
2. Implement the shared selection model, sidebar hierarchy, and contextual inspector. Verify that selection and keyboard actions consistently target the same item.
3. Remove redundant copy and consolidate toolbars and panels. Check keyboard accessibility, meaningful labels, and the supported small-window layout.
4. Implement direct clip edits, field commits, creation, and media-drop behavior. Preserve model identities, linked-face behavior, undo transactions, and existing project compatibility.
5. Implement autosave and drafts using the save coordinator. Exercise failed writes, full disks, missing or unwritable destinations, imports during saves, edits during saves, Save As, undo, project switching, close, and crash recovery.
6. Refine timeline, canvas, fixture selection, and actionable problem feedback. Check representative large projects, long timelines, and media-heavy saves for responsive editing.
7. Run focused regression checks for those risks and the full suite before delivering the completed pass. Use Xcode 27.0 beta 5 (27A5237l). Ask the user to perform the visual workflow checks, recording those separately from automated evidence.

Acceptance tasks are to create a project, map three faces, add and edit a video clip, layer a title, draw a region, undo and redo, close and reopen with the work intact, and run the result in Show. Repeat with phone edits and a deliberately failed save. Confirm that common tasks are reachable from the selection without reading a permanent instruction paragraph, saving keeps the editor responsive, and a failed operation offers a clear recovery action.

Planning is local. Version assignment and delivery follow the project's existing milestone cadence when implementation is authorized and verified.
