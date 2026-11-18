# Playgrounds rehearsal

Local Playgrounds preview: v2.09/build 32, implementing the first part of v2.10. The milestone version is unchanged because broader v2.10 work remains planned.

## Start two shows from one house

1. Open an existing mapped show. From **Project → Save Playground…**, enter a name such as My House and an optional note. Save it. The current show stays open.
2. Choose **Project → New Show from Playground…**. Select My House, name the new show Halloween, leave **Choose a song after opening** checked and click **Create Show**. Choose an audio file, or cancel to leave the show without a song.
3. Confirm the mapping, masks, connected faces, layers/region shapes and fixture setup remain. The timeline should contain no old clips, markers or lighting cues; projected words/countdowns and programmed movement should be cleared. Base targets are black, overlays/regions transparent, fixtures dark, and playback paused at zero. Output and phone remote should be off.
4. Program a small effect or cue, use Test Mode and simulated fixtures for rehearsal, then save or allow the draft to autosave.
5. Create another show from My House with a different name and song. Its programming should again be empty. Reopen the first draft and the original show to confirm they keep their own programming and songs.

The shortcut **Project → New Show from This Playground…** starts from the current show's setup without first adding it to the library. In the library chooser, **From Project File…** extracts a setup from another supported project package. An audio file alone does not contain mapping or fixtures.

## Manage saved setups

**Project → Manage Playgrounds…** lists local setups. Select one to rename it, edit its note, duplicate it, export it, or import a portable playground. **Update from Current Setup…** asks before replacing that library entry with the open show's current mapping and fixture configuration. Existing shows keep their own copies.

The local library is `~/Library/Application Support/ProjectionMapper/Playgrounds/`. Exported playgrounds use `.projectionplayground`; complete shows continue to use `.projectionmap`. Library operations and new-show creation report invalid or missing assets and retain existing work on failure.

## Acceptance record

Automated verification is recorded separately in [the verification notes](V2.10_PLAYGROUNDS_VERIFICATION.md). User visual/listening acceptance of the chooser, library controls and two-song Test Mode rehearsal is pending. Physical projector and fixture acceptance stays deferred.
