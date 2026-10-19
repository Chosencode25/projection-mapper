# App improvements — v2.01/build 16

These improvements are included in v2.01/build 16 source. The published app download
remains v1.15.1; this source delivery does not create a new release.
Quit and reopen Projection Mapper to use it; About shows **2.01 / build 16**.
Existing projects keep portable format 9 and the same mapping/media semantics.

## Workspace

Save is directly available in the top bar. Tools contains Editor Guides, Calibration
Patterns, timeline visibility and playback/output settings. Select Test Window or
an external display, then choose Open Output deliberately. Blackout becomes Restore
while output is blacked out or fading to black; Restore is also available in the
status bar. Playback/audio behavior is unchanged by blackout.

Surface names have more room and full-name hover text. Use Find a surface to filter
by face name, object name or face tag. Group faces opens the grouping checkboxes;
Create Object applies them and Cancel clears the temporary grouping selection.
The tag menu selects matching faces for grouping. Lock/visibility and Deselect
remain available. A shared face's inspector explains which object owns its content.

Edit errors and active image/video/save progress remain visible in the status bar,
including when the inspector is hidden. Missing-video problems also raise the canvas
warning. Canvas hints describe the current selection, masks or locked corners.

## Timeline

- **Space or Command-Return:** Play/Pause. **Control-Command-T:** hide/show the timeline.
- **Fit:** fit the complete sequence in the visible timeline.
- **Playhead:** scroll to the current playback position.
- **Click the time display:** jump to a specific time in seconds, from 0 to 3600.
- **Select a clip:** edit its start, length or content below the tracks. The clip
  editor scrolls to retain video controls when the panel is short.
- **Apply Edited Content:** copy the track's edited source settings/colors into the
  selected clip. Existing clip move/trim, snapping, source in-points and ownership
  policies are preserved.

The canvas receives more of the initial window height. The timeline remains
resizable; its static tracks/grid are separate from the animated time/playhead.
Labels adapt to narrow clips instead of competing with both trim handles.

## Picking and playback

Clicks in a transparent mask hole select the visible face underneath. Mask picking
uses original face coordinates under perspective, independent of content crop/flips.
Disabled masks permit picking the full quad; invalid enabled masks do not intercept
the canvas. Sidebar selection remains available for repairing a hidden/invalid face.

Playback reuses unchanged renderer vertices/matrices/mask payloads and sends one
scene snapshot to both output views. A regression checks one preparation pass over
120 frame/transport updates, plus offscreen pixel equivalence. This reduces repeated
CPU work; it is not a measured projector FPS or optical-latency result.

## Verification and review

Pinned Xcode **27.0 beta 5 (27A5237l)**. Debug and Release each passed **312 correctness
tests**, zero failures/recorded runtime warnings, four optional benchmarks skipped,
and two legacy visible-window tests excluded. See [keyboard verification](LOCAL_SHORTCUTS_VERIFICATION.md) and [earlier polish evidence](LOCAL_APP_POLISH_2026-10-19.md).

Routine visual review is still yours: check the toolbar at your usual window size,
surface search/grouping, timeline Fit/time jump/clip editing, and the larger canvas.
No new user visual/listening or hardware acceptance is claimed. Test Mode stays
available; physical projector and optical timing acceptance remain pending.


## Keyboard editing (build 16)

See the [complete shortcut guide](KEYBOARD_SHORTCUTS.md), also shown in the repository README.
Open **Help → Keyboard Shortcuts…** with **Command-/** for a searchable reference.
Shortcuts appear beside the corresponding File/Edit/Show/Timeline/View/Window menu
commands, and playback/timeline buttons show them on hover.

| Action | Shortcut |
| --- | --- |
| Play / Pause in editor or output | Space (also Command-Return) |
| Stop and return to beginning | Shift-Command-Return |
| Pause and step 1/30 second | Option-Left / Right |
| Pause and step one second | Shift-Option-Left / Right |
| Pause at beginning / sequence end | Home / End (fn-Left / Right) |
| Duplicate selected clip, face or object | Command-D |
| Delete selection | Delete (also Command-Delete) |
| Cancel drawing/grouping, then clear selection | Escape |
| Deselect | Shift-Command-A |
| Add surface | Shift-Command-N |
| Previous / next surface, wrapping at either end | Option-Command-Up / Down |
| Group faces / ungroup object | Command-G / Shift-Command-G |
| Lock / unlock geometry | Command-L |
| Show / hide selected face or object | Shift-Command-H |
| Bring face forward / send backward | Command-] / [ |
| Import image / video as new surface | Shift-Command-I / Option-Command-I |
| Add current content at playhead | Shift-Command-K |
| Apply edited track content to selected clip | Option-Command-K |
| Split selected video at playhead | Command-B |
| Move clip earlier / later by 0.1 seconds | Option-Command-Left / Right |
| Move clip earlier / later by one second | Shift-Option-Command-Left / Right |
| Timeline zoom in / out | Command-= / - |
| Fit complete timeline / reveal playhead | Command-0 / Shift-Command-P |
| Toggle timeline Snap / Follow | Option-Command-S / F |
| Edit / Show / Project inspector | Option-Command-1 / 2 / 3 |
| Toggle sidebar / inspector / timeline | Control-Command-S / I / T |
| Open / close clean output | Control-Command-O / W |
| Blackout / restore output | Shift-Command-B / R |
| Mute video audio | Shift-Command-M |

Existing New/Open/Save/Save As and Undo/Redo remain standard Mac shortcuts. Native
Cut/Copy/Paste apply in text fields. Arrow keys nudge a selected corner or object;
Shift takes a larger step. Geometry locking remains enforced. Command-G first opens
face grouping; check faces, then Command-G creates the object. Shortcut clip edits
follow the same overlap/range checks and undo history as mouse edits.

Typing retains spaces, Delete, arrow navigation and native undo. Editor shortcuts
are suspended in text fields, modal dialogs and sheets; no global event monitor is
installed. Held Space/Delete do not repeatedly toggle playback or delete successive
faces. Clicking the canvas/sidebar clears the old clip selection, so subsequent
Duplicate/Delete follows the new selection. In mask mode, Delete removes a point
(or the last draft point), never the face. Escape still closes focused physical
projector output.

Time steps are nominal 1/30 second, not a promise of source-frame accuracy. Video
split requires at least 0.1 seconds on each side and preserves in/out points, rate
and loop phase. Procedural effect clips cannot be split because their saved format
has no phase offset. Surface/object clipboard cut/paste, ripple edits, music
waveforms and crossfades are not implemented by these shortcuts.
