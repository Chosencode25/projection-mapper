# Keyboard shortcuts

These shortcuts apply to **v2.01/build 16**, available in the latest source.
The downloadable v1.15.1 app has an earlier shortcut set. Open **Help → Keyboard
Shortcuts…** with **Command-/** for the searchable reference in build 16.

**Key:** ⌘ Command · ⌥ Option · ⌃ Control · ⇧ Shift · ↩ Return · ⌫ Delete.
Home/End on compact Mac keyboards are usually fn-Left/fn-Right.

## Playback

| Action | Shortcut |
|---|---|
| Play / Pause | **Space / ⌘↩** |
| Stop and Return to Beginning | **⇧⌘↩** |
| Step Back 1/30 Second | **⌥←** |
| Step Forward 1/30 Second | **⌥→** |
| Step Back One Second | **⌥⇧←** |
| Step Forward One Second | **⌥⇧→** |
| Go to Beginning | **Home (fn-←)** |
| Go to Sequence End | **End (fn-→)** |

## Surfaces and objects

| Action | Shortcut |
|---|---|
| Add Surface | **⇧⌘N** |
| Duplicate Selection | **⌘D** |
| Delete Selection | **Delete / ⌘⌫** |
| Deselect | **⇧⌘A** |
| Group Faces | **⌘G** |
| Ungroup Selected Object | **⇧⌘G** |
| Lock / Unlock Geometry | **⌘L** |
| Show / Hide Selection | **⇧⌘H** |
| Bring Face Forward | **⌘]** |
| Send Face Backward | **⌘[** |
| Select Previous Surface | **⌥⌘↑** |
| Select Next Surface | **⌥⌘↓** |

## Media imports

| Action | Shortcut |
|---|---|
| Import Image as New Surface… | **⇧⌘I** |
| Import Video as New Surface… | **⌥⌘I** |

## Timeline

| Action | Shortcut |
|---|---|
| Add Current Content at Playhead | **⇧⌘K** |
| Apply Edited Content to Selected Clip | **⌥⌘K** |
| Split Selected Video Clip at Playhead | **⌘B** |
| Move Clip Earlier by 0.1 Seconds | **⌥⌘←** |
| Move Clip Later by 0.1 Seconds | **⌥⌘→** |
| Move Clip Earlier by One Second | **⌥⇧⌘←** |
| Move Clip Later by One Second | **⌥⇧⌘→** |
| Zoom In on Timeline | **⌘=** |
| Zoom Out on Timeline | **⌘-** |
| Fit Complete Timeline | **⌘0** |
| Reveal Playhead | **⇧⌘P** |
| Toggle Timeline Snapping | **⌥⌘S** |
| Toggle Follow Playhead | **⌥⌘F** |

## Inspectors

| Action | Shortcut |
|---|---|
| Edit Inspector | **⌥⌘1** |
| Show Inspector | **⌥⌘2** |
| Project Inspector | **⌥⌘3** |

## Output and audio

| Action | Shortcut |
|---|---|
| Close Output | **⌃⌘W** |
| Mute Video Audio | **⇧⌘M** |

## Files and history

| Action | Shortcut |
|---|---|
| New project | **⌘N** |
| Open project | **⌘O** |
| Save project | **⌘S** |
| Save project as | **⇧⌘S** |
| Undo project edit / native text undo while typing | **⌘Z** |
| Redo project edit / native text redo while typing | **⇧⌘Z** |

## Panels, guides and windows

| Action | Shortcut |
|---|---|
| Show / hide sidebar | **⌃⌘S** |
| Show / hide inspector | **⌃⌘I** |
| Show / hide timeline | **⌃⌘T** |
| Show editor window | **⌃⌘E** |
| Show / hide editor handles | **⌃⌘H** |
| Show / hide face and object names | **⌃⌘L** |
| Enter / exit calibration grid | **⌃⌘C** |
| Open selected output explicitly | **⌃⌘O** |
| Immediate visual blackout | **⇧⌘B** |
| Restore visual output | **⇧⌘R** |
| Open searchable Keyboard Shortcuts reference | **⌘/** |

## Direct editing and standard Mac keys

| Action | Shortcut |
|---|---|
| Nudge selected corner or object handle | **Arrow keys** |
| Nudge with a larger step | **Shift + Arrow keys** |
| Cancel mask drawing/grouping, exit mask editing, then clear clip/corner/face selection in stages | **Escape** |
| Close focused physical projector output | **Escape** |
| Cut / copy / paste / select all in text fields | **⌘X / ⌘C / ⌘V / ⌘A** |
| Close current window / quit app | **⌘W / ⌘Q** |

## How selection and typing work

- Space works in the editor, Test Output and focused projector output. Normal typing retains spaces, Delete, arrow navigation and native text undo; editor actions are suspended in text fields, sheets and modal dialogs.
- Duplicate/Delete follow the selected clip, face or object. Selecting a face in the canvas/sidebar clears the old clip selection. Selecting a timeline track exits mask editing.
- In mask mode, Delete removes the selected point or last draft point, never the whole face. Existing minimum-point and geometry-lock guards remain enforced.
- Holding Space/Delete does not repeatedly toggle playback or delete successive faces. Arrow nudges require the selected corner/object handle to have keyboard focus.
- Command-G opens grouping; check faces, then Command-G creates the object. Shift-Command-G ungroups the selected object.
- Option-arrows pause and seek by a nominal 1/30 second; Shift-Option-arrows step one second. These are time steps, not decoded-video-frame guarantees.
- Video split requires at least 0.1 seconds on each side of the playhead and preserves source position, rate and loop phase. Procedural effect clips cannot be split because their saved format has no phase offset.
- Clip moves and duplication obey the existing overlap/range checks and undo history. New shortcut actions never bypass explicit output opening or enable audio automatically. Visual blackout and audio mute remain separate.
- Surface/object clipboard cut/paste, ripple editing, music waveforms and crossfades are not implemented by these shortcuts.
