# Edit, Lighting and Show workspaces

Use the workspace switch above the project window. All three views use the same project, playhead, playback, output and fixture state.

- **Edit** contains the canvas, surface list, inspector, fixture setup and editable timeline. Existing zoom, Snap and Follow settings persist across workspace switches during the session.
- **Lighting** (local build 33) contains fixture/group/look selection, a schematic, supported contextual controls and the shared timeline focused on fixtures. See [Lighting rehearsal](LIGHTING_WORKSPACE_GUIDE.md). Movement paths/keyframes remain planned.
- **Show** contains a read-only projection or fixture preview, a playhead readout, upcoming timed cues, manual GO and release, separate projection and fixture blackout, audio mute, output selection and readiness. Project editing commands and project undo/redo are disabled here.

For the first rehearsal, open the v2.06 sample, pause at 4.5 seconds, and switch to Show → Fixtures. The head should be halfway through its move. Check that the playhead and output do not reset. Switch back to Edit and confirm the selected cue is still available for editing.

## Canvas and timeline navigation

In build 23, pinch the Edit canvas or use the zoom buttons. **Fit** restores the whole canvas. **100%** scales the preview to the output pixel size within the zoom limits. **Selection** frames the selected face or linked object. In build 24, hover over the zoomed canvas and scroll with two fingers to pan horizontally and vertically together. The Pan toggle is optional for trackpad scrolling. Turn it on to drag with the pointer without moving a mapping handle, then turn it off to edit. The editor zoom is independent of the projector and Test Window.

Timeline zoom centers the playhead when there is room on either side. **Fit** fits the song or sequence. **Zoom To → Selection** frames the chosen clip or cue. **Zoom To → Loop** frames the loop region. Canvas zoom and position and timeline zoom and scroll are retained when switching workspaces.

For a visual check, zoom to a face, pan, turn off Pan and adjust a corner. Confirm the selected corner tracks the pointer in the zoomed canvas and that the Test Window shows the same mapping edit at normal scale. On the timeline, zoom around 4.5 seconds or frame the rehearsal loop. Full Show Mode arming and operational readiness remain separate work.

Build 22 passed 27 focused Release checks with Xcode 27.0 beta 5 (27A5237l), including switching during playback and blocking editing shortcuts in Show. The local app contains both architectures and passed strict signature verification. Visual rehearsal is pending.

Build 23 passed 29 focused Release checks, including pan bounds, selection framing, playhead centering, timeline controls and workspace switching. The local universal copy passed strict signature verification. Trackpad and pointer acceptance remains a user check.

## Show rehearsal controls

Build 25 highlights the next timed cue and its countdown. When a loop is active, cues outside it are omitted and cues after wrap are labeled. Manual-only cues remain in the manual picker. Use **Check Readiness** to inspect current media and output without starting playback. Projection Fade, Projection Blackout, Fixture Blackout and song mute are separate controls.

While playback is running, select **Edit → Pause and Edit** to pause at the current position and unlock the editor. **Keep Rehearsing** leaves the show running. A paused rehearsal can return to Edit immediately. Output remains open through the switch. The readiness report is advisory during rehearsal. Live fixture arming and hardware acceptance remain separate.
