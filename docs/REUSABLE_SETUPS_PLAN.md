# Playgrounds — concept plan

November 17, 2026. Originally saved as a user-requested concept, then authorized for implementation. This is the first workflow in the existing v2.10 Reusable Shows and Layouts scope; see the implementation status below. See also the [Lighting workspace concept](LIGHTING_WORKSPACE_PLAN.md).

User-facing name chosen November 17, 2026: **Playgrounds**. Each playground is a reusable arrangement of the house, mapped surfaces and lighting; each song becomes its own independent show. The filename remains stable for existing links.

## Implementation status — November 17, 2026

The user subsequently authorized this workflow. Playgrounds extraction, local library/management/import/export and independent new-show drafts are implemented locally. See the [implementation plan](V2.10_PLAYGROUNDS_PLAN.md), [verification](V2.10_PLAYGROUNDS_VERIFICATION.md) and [rehearsal guide](PLAYGROUNDS_GUIDE.md). The original concept below records the planned direction; broader v2.10 and the Lighting workspace remain separate.

## Purpose

At any time, extract a reusable physical playground from the current project or another supported project file—even a finished show. Save it locally as a named playground such as My House. Start independent new shows from it with the house and lights already arranged, empty content and timing, and an optional new song.

A playground is the arrangement/configuration; each show is an independent use of that playground with its own song and programming. Creating or updating a playground never clears the source show, and editing a derived show does not change the saved playground or other shows.

## What a playground keeps

- Surface and object names, grouping, ordering, visibility/geometry locks, output corners, input maps, connected-face links and mapping mode.
- Masks, crop/flips, static appearance/calibration, the house reference photo and its alignment, and output format/resolution preferences.
- Layer and region containers, their names, geometry, placement and static styling, ready for new content on their existing target lanes.
- Fixtures, supported profiles, controller/patch configuration, addresses, groups, schematic placements, and physical orientation/limits/calibration supported by the model.
- Saved output/controller preferences as configuration hints; actual device availability is checked when a new show is opened.

## What starts empty

- Song and soundtrack waveform, song-specific audio/video content, projected words and countdown targets.
- Generator assignments, effect/media clips, lighting looks/cues/choreography, movement and mouth keyframes, fades, and manual-cue programming.
- Beat/lyric/section markers, loops, offsets and other show timing; playlists/schedules when those features exist.
- Runtime overrides, selection/history, playback positions, active blackout/fade/GO state, armed connections and phone pairing credentials.

Static fixture calibration may remain; programmed movement positions, colors and brightness do not become a new show's starting output. Projection targets are visibly unprogrammed/neutral, fixtures start dark, playback starts paused at zero, and output/remote connections use the existing explicit-start rules. A playground containing only lighting or only projection is valid.

## Simple interface

- Project → Save Playground… captures the current committed playground without modifying the current show. Give it a name and optionally a short note. Capturing while playback runs does not record the live effect/output state.
- Project → New Show from Playground… opens a local playground chooser. Select My House, name the new show, optionally choose a new song, and enter a fresh autosaved draft with empty tracks.
- Project → New Show from This Playground is the shortcut from any open show; it applies the same extraction rules without first requiring a library entry.
- In the chooser, From Project File… extracts the playground from a chosen supported project package. Importing an audio file alone cannot recover house mapping or fixture configuration.
- Manage Playgrounds provides rename, duplicate, deliberate update, and local import/export. Choose projection Edit or Lighting as the workspace when beginning the new show.

Example: finish Halloween Show → Save Playground as My House → New Show from Playground → choose a Christmas song. All mapped faces, masks, groups and patched lights are ready; the timeline is empty.

## Data and build direction

1. Define and test one playground-extraction operation used by all entry points. Enumerate every saved field so base effects, hidden layers, cues, text and timing cannot leak into a new show. Preserve all geometry and patch relationships.
2. Store independent local playground packages with a schema version and only required playground assets, such as the reference photo. Validate packages and keep current supported-project migration behavior. Reuse identities coherently within a playground; new shows get their own project identity, remapping dependent IDs where required.
3. Add Save Playground and New Show from This Playground, then the local library chooser and optional song import. Integrate new-show creation with autosave/drafts and the current save-before-switch behavior. On extraction/import failure, retain the original show and saved playground intact.
4. Add export/import and deliberate library updates. Existing shows retain their own playground snapshot. Automatic linked updates to all shows are a separate future feature.
5. Verify extraction from blank, lighting-only, projection-only and mixed finished projects. Check mapping/masks/shared input regions, regions/layers, fixture patches, asset collection, removal of all content/timing, independent edits to two shows, save/reopen, failure handling and paused/unarmed opening. Rehearse two different songs on one playground using Test Mode and simulated fixtures.

## Relationship to v2.10

Build reusable local playgrounds first. Retain the existing later v2.10 work for layout roles, applying programmed show templates to different layouts, reusable effect/palette packs and recording cue performances. Those reuse programming; this playground workflow intentionally starts a new show with empty programming. Do not renumber milestones or claim implementation from this planning update.
