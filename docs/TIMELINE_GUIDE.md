# Using the playback timeline

The bottom panel is resizable: drag the divider between the mapping editor and timeline. Each connected object has one row; independent faces have their own rows. Hidden targets retain rows with a hidden icon so you can still edit their sequence.

1. Choose a row and set its content, colors and effect settings in Edit.
2. Scrub the seconds ruler to a start time. Click **+** beside the row to capture its current content into a five-second clip. Double-click an empty part of a row to add there instead.
3. Select a clip to change its effect, start or length in the bottom strip. Drag its middle to move; drag either edge to trim. Snap uses whole seconds; turn it off for finer edits. Clips must be at least 0.1 seconds long, fit within 0–3600 seconds and cannot overlap another clip on their row.
4. To update a clip's colors, image or generator settings, select its row, edit content in Edit, then choose **Capture Current** for the clip. Clips capture the current resolved palette colors. Right-click a clip to capture, duplicate after it or delete it.
5. Use Play/Pause, return-to-start, one-second step buttons and the speed menu. Clicking/dragging the ruler pauses and seeks. Zoom controls horizontal scale; Follow scrolls to the moving playhead while playing. Turn Follow off to inspect another part of the sequence.
6. Save the project normally. Clips, content and their image assets are portable in format 8. Opening an older project creates empty tracks and preserves its existing live content. Opening never starts playback.

Empty tracks continue their live content indefinitely. Once a row contains clips, it displays those clips and goes dark between them. Each clip starts its animation phase at its own beginning. The global clock drives every connected face and both preview/Test Output. Geometry, masks, appearance and calibration stay separate. Individual owner pause/restart buttons are disabled for sequenced tracks; use the timeline transport. Removing the last clip restores the row's live content.

Duplicated objects and detached faces copy their sequence with independent clip IDs. Joining a face to an existing object adopts that object's sequence; grouping faces uses the first face in project order's content owner. Removing a target removes its clips. The bounded 2000-clip project limit can prevent copying a sequence; the timeline reports this explicitly.

User visual checks pending: resize the bottom panel; verify long horizontal and vertical scrolling; scrub across two differently colored clips and a gap; drag/trim/duplicate/delete; test Follow and zoom; open Test Output; Save/Open and confirm the sequence stays in place. Music, waveform, crossfades, layered effects and undo transactions remain later show-editor work.

## v1.14 delivery update

This earlier effect/image timeline is included in the completed v1.14 milestone, extended to video ranges and explicit embedded audio. Installed app is now 1.14/build 11, format 9. See [video guide](VIDEO_IMPORT_GUIDE.md) and [current verification](V1.14_VERIFICATION.md). User acceptance remains separate from automated checks.
