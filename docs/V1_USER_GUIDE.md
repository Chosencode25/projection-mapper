# Projection Mapper V1 guide

Current V1 app: 1.15/build 12, portable format 9, macOS 15 or later. Test Mode is the supported V1 output. Fullscreen projector output and physical acceptance are scheduled for v2.01.

## Start and map

Open Help → Welcome, Guide or Open V1 Demo. The bundled demo is a new unsaved document with its own project identity. Opening it uses Save / Discard / Cancel for existing edits; Save asks for a personal destination. Demo media includes a generated house reference illustration, checker image and self-generated SDR video, with audio muted. It contains a masked house, a connected three-face object and an independent video owner. The illustration is an alignment example, not a photograph or automatic 3D reconstruction.

Add a surface from Add. Click a face in the editor or sidebar, then drag corner handles. Focus a corner and use arrow keys; Shift increases the step. Geometry locks protect corner/group movement. Invalid corners suppress the affected face; repair corners or use a scoped geometry reset.

Check faces in the sidebar and Group them to share content. Continuous mode uses separate input regions within one shared canvas. Align edge links deliberately; mark unavoidable seams. Repeat shows the whole source on each face with one shared time/player. Grouping alone does not establish continuity. Select an object and drag its center handle to move all members. Detach produces an independent owner.

Masks and holes remain face-local as content changes. The house reference is editor-only; it never enters clean Test Output. Import your own house photograph through Reference Photo, then adjust placement/position/scale/opacity.

## Content and timeline

Edit chooses generators, PNG/JPEG images or SDR H.264/HEVC MP4/MOV. Replace/remove/relink preserves mapping. Object replacement affects all member faces; choose detach to give a face separate content. Fit preserves the whole source, Fill crops, Stretch changes proportions.

Each object/standalone face has a timeline row. An empty row displays live content. Once a row contains clips, gaps are dark. + captures the current content at the playhead; double-click a lane to add at that time. Drag a clip to move it, drag its edges to trim, or enter precise values in the clip editor. Moving a video preserves selected footage; leading trims adjust the in-point or loop phase. Clips cannot overlap within an owner. Playback, ruler scrubbing, stop, speed, zoom, snap and follow use the shared transport. Horizontal controls scroll on narrower windows.

Video audio has two deliberate gates: owner/clip mute and Enable Audio in Show. Choose output and volume before enabling. Pause, stop, scrubbing and gaps are silent; projects reopen paused and audio-disabled. Supported effective audio rate is 0.5×–2×; other rates mute with a diagnostic. Unplugged selected devices require rearming. Blackout controls visual output separately from audio.

## Undo, files and recovery

Command-Z undoes project edits; Shift-Command-Z redoes. Native text fields retain text undo while typing. The toolbar Edit menu acts on project history. Mapping drags, mask drags and saved-setting sliders form one undo action. Stable IDs, clips, membership, maps, masks, tags, looks, palettes and media are restored. Selection, transport, zoom/follow, calibration, blackout and decoder frames are outside project history. Save retains history; New/Open/recovery clear it. History is session-only and bounded to 100 steps, conservatively counted 256 MiB image/poster data and 2 GiB retained video originals; older steps are released with a notice. These limits are separate from total app memory and the active project limits.

Command-S saves a .projectionmap package including referenced assets; Shift-Command-S chooses another location. Command-O opens a project. Recovery updates after editing settles and protects the last good file when saving fails. Undo back to the saved content clears dirty state, including same-ID relinked media. Undo assets are staged separately so saving over a package does not destroy them. Missing media remains actionable: relink before saving a complete portable project.

## Readiness and clean output

Show → Playback Readiness or the Show inspector checks geometry, masks/joins, live/look/timeline media, clip ranges, available audio device and reported decoder failures. Fix items are blockers; warnings and information are distinct. Select Face jumps to a geometry/mask/join issue. Reports are bounded snapshots: Check Again after edits or output/device changes. Readiness never starts playback or enables audio and does not guarantee smooth playback or physical compatibility.

Identify Selected isolates that owner's faces in white without changing mapping or saved content. Finish restores the existing runtime calibration and other owners; the status bar keeps Finish reachable. Blackout remains highest priority. Use Show Output for the resizable clean Test Window; its size does not change mapping coordinates. The reference photo, handles and labels stay out of clean output.

At 4K, dense overlapping particle layers can exceed the measured frame budget. Use Full HD or reduce density/overlap for heavier scenes; readiness does not certify a frame rate. The bounded profiling results are in V1.15_VERIFICATION.md.

## User visual and listening checks

Open the demo, play/scrub mixed clips, inspect the connected faces, try a mapping drag and undo/redo, relink media, Save As and reopen. Check narrow-window controls and Show readiness/identification restoration. Deliberately test audio routing, perceived sync/pitch and device unplug only when desired. Routine visuals/listening are performed by the user; automated offscreen evidence is recorded separately.

V2 adds physical fullscreen output, music/song transport, waveforms/beat editing, advanced sequences/choreography, layered content and later show operation/integration. V1 does not advertise those as implemented.
