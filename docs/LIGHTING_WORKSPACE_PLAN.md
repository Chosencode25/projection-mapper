# Dedicated Lighting workspace — concept plan

November 17, 2026. Saved at the user's request after discussing a lighting-focused editor in the same application. Originally planning only. The user subsequently invoked Build for the first section; implementation is now local in v2.09/build 33. No dedicated milestone version has been assigned. This extends the existing fixture and shared-timeline foundations.

## Implementation status — November 17, 2026

Section 1 is implemented and automatically verified locally: dedicated workspace, fixture/group selection, supported manual/look controls, existing cue editing, schematic and shared timeline. Full Release succeeded with 368 tests reported; focused Debug passed 48 checks. User visual/listening acceptance remains pending. See [verification](LIGHTING_WORKSPACE_VERIFICATION.md) and [rehearsal](LIGHTING_WORKSPACE_GUIDE.md). Section 2 was subsequently implemented locally in build 34; see the November 19 status below. Section 3 was subsequently implemented in build 35. Applications retains build 32; Build does not include installation or GitHub backup.

## Movement status — November 19, 2026

Section 2 is implemented locally in **v2.09/build 34**: per-head position keys, incoming curves, an editable pan/tilt path chart in the schematic, per-head position timeline lanes and precise inspector values. Shared-clock simulation, validation, undo, save/reopen/recovery and Playground clearing are covered by new automated checks. Project format is now 15; older projects migrate. See [movement plan](LIGHTING_MOVEMENT_PLAN.md), [verification](LIGHTING_MOVEMENT_VERIFICATION.md) and [rehearsal](LIGHTING_MOVEMENT_GUIDE.md). User visual/listening acceptance remains pending. Section 3 followed in build 35.

## Reusable effects status

Section 3 is implemented in the local build 35 preview. The Lighting Effects editor saves project presets, loads them into independent fixture-group placements and previews active steps in the schematic. See [the rehearsal guide](LIGHTING_EFFECTS_GUIDE.md) for the workflow. User rehearsal remains pending.

## Experience

Add a Lighting workspace alongside Edit and Show. It opens the same project, song, transport and undo/autosave state. Its working area contains lighting tools and fixture tracks. Projection remains synchronized through the existing shared clock and can be shown as timing-reference tracks when needed.

## Layout

- Left: fixtures and named groups, with selection, visibility/preview status, and contextual creation.
- Center: a large 2D schematic for positioning moving heads, strips and other supported fixtures, with animated beam direction, movement, brightness and strip-color preview.
- Right: controls for the selected fixture, group, look or cue: supported colors, dimmer, pan/tilt, fades, movement curves and precise values. Show only controls the fixture profile supports.
- Bottom: the existing shared timeline, focused on lighting lanes, with the song waveform, markers, playback, snapping, zoom and loop rehearsal. Projection lanes are optional timing references.
- Separate setup panel: controller profiles, fixture patching, addresses and connections. Retain clear simulation/connection status where it affects preview interpretation.

## Workflow

1. Add or select fixtures and arrange them in the schematic.
2. Select a fixture or group and compose a look.
3. Place looks, positions or effects on the song timeline.
4. Adjust durations, fades and movement between positions.
5. Rehearse lighting by itself or together with projection using the same playhead.

Position keyframes, visible motion paths and smooth movement curves are the central movement-design direction. Reusable chases and repeating effects can follow. Preview capabilities stay consistent with supported profiles: discrete relays, color wheels and binary RGB outputs do not gain continuous dimming or addressed-pixel capabilities merely through a new interface. The schematic is not a photometric or collision simulation.

## Initial build order

1. Dedicated workspace layout, fixture/group selection, existing cue editing, and the existing simulated preview on the shared timeline.
2. Focused movement-path/keyframe editing with precise values and undo.
3. Reusable lighting effects and a more expressive preview, as supported by fixture models.

Preserve project identities and synchronization across workspaces. Reuse autosave, drafts and keyboard routing. Verify selection targets, seek/loop reconstruction, workspace navigation and synchronized simulated playback. Physical fixture acceptance remains separate.

Use [Playgrounds](REUSABLE_SETUPS_PLAN.md) to start multiple songs with the same house and fixture configuration.
