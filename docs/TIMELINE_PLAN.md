# Playback timeline — October 9, 2026

User requested a video-editor-style bottom timeline with object rows, timed effects and scrolling playback. This is a local enhancement to the current 1.13 app; do not invent a milestone to trigger Git delivery. Read PROJECT_DEVELOPMENT.md and V2_IMPLEMENTATION_PLAN.md before implementation. Exact Xcode 27.0 beta 5 (27A5237l) verified.

- Add a resizable bottom timeline, persistent object/standalone-face tracks, seconds ruler, moving playhead, scrub, play/pause/stop, stepping, speed, zoom, snap and follow scrolling. Select tracks to edit the matching object/face.
- Capture current content into timed clips; move/trim/select/duplicate/delete and edit start/duration/effect. Reject overlaps on a single owner. Connected faces use one owner/track. Empty tracks keep existing live content; sequenced tracks are black in gaps; clip phase starts at its beginning. No music/audio is added.
- Evaluate clips at the shared renderer clock, preserving geometry/masks/crop/calibration. Retain clip image assets. Store bounded clips in format 8 with migration from 1–7; prune removed owners, retain stable IDs, protect save/recovery.
- Verify boundary/seek/phase, shared owners, edits/overlaps, migration/assets and GPU output with automated tests; deliver a tested Release app to app/ with prior binary preserved. Routine visual acceptance remains with the user. No Git commit/push/release for this enhancement.

Implementation and local delivery complete. Final Debug/Release each passed 245 correctness tests; routine user visual acceptance pending. See [verification](TIMELINE_VERIFICATION.md). No Git delivery performed.

## v1.14 delivery update

This earlier effect/image timeline is included in the completed v1.14 milestone, extended to video ranges and explicit embedded audio. Installed app is now 1.14/build 11, format 9. See [video guide](VIDEO_IMPORT_GUIDE.md) and [current verification](V1.14_VERIFICATION.md). User acceptance remains separate from automated checks.
