# Playback timeline verification — October 9, 2026

Implemented the user-requested video-editor-style bottom timeline as a local enhancement to bundle 1.13/build 10. This is not a new numbered milestone or a Git delivery. Source remains local and uncommitted; confirmed GitHub milestone history remains preserved.

## Implementation

Resizable bottom VSplitView panel; one lane per connected object or standalone face, including hidden-target indicators; time ruler and moving playhead; Play/Pause, Stop/return-to-start, one-second steps, speed, zoom, snap and follow scrolling. Capture current effect/image into clips; select, move, trim, edit effect/start/duration, recapture settings, duplicate and delete. Single-owner clips cannot overlap, have a minimum 0.1-second length, a maximum end time of 3600 seconds and a 2000-clip project bound. Empty tracks preserve live content; sequenced tracks are dark in gaps. Clip-local animation phase uses the shared clock in both preview and output. Calibration, masks, geometry and master output remain separate.

Project format 8 migrates 1–7, validates owner/clip/asset identity, preserves clip images in portable saves/recovery and prunes removed targets. Copying objects or detaching faces copies clip IDs independently; joining adopts the destination sequence and grouping takes the first face in project order. Colors are captured from their resolved palette values. Individual owner pause/restart UI is disabled when the owner is sequenced. Editor selection, zoom, snap/follow and transport remain runtime state.

## Automated evidence

Exact required Xcode 27.0 beta 5, build 27A5237l, verified. Final Debug and Release each passed **245 correctness tests**, zero failures, four optional benchmarks skipped (249 declarations, 24 suites). Two existing visible-window tests were explicitly excluded. Universal arm64/x86_64 app and test sources compile; GPU/runtime checks ran on Apple Silicon. No screen control or app launch used.

Six new tests cover boundary inclusion/exclusion, gap darkness, clip-local phase, calibration priority, edits/overlap rejection/dirty state, seeking, copying/detaching/deleting shared objects, format 7 migration/format 8 round trip, retained clip-only images, unknown owners, scheduling static future clips and GPU red/blue/black boundaries including backward seek. The first full run found a legacy image migration assertion hardcoded to format 7; it now follows ProjectDocument.currentVersion. Final regression suites passed. Existing offscreen AppKit constraint and test-service connection diagnostics remain recorded in the result bundles.

Evidence: builds/timeline/Debug-final.log/.xcresult, Release-final.log/.xcresult, Debug-summary.json, Release-summary.json and Release-file-hashes.json. Release app deep/strict code signature verified, universal architecture checked and every file SHA256 matched between tested product, archive and installed copy.

Delivered app/ProjectionMapper.app; archive builds/timeline/ProjectionMapper.app; previous installed app preserved as builds/timeline/Previous-installed.app. Original v1.13 archive remains unchanged. Running older instances need Quit/Reopen.

## User visual acceptance pending

Routine visual checks belong to the user. Verify panel resizing, horizontal/vertical scrolling, Follow/zoom, clip picking/move/trim, content capture, playback and Test Output, plus Save/Open. See [timeline guide](TIMELINE_GUIDE.md). No visual acceptance is claimed. This foundation does not include music, waveform, layered overlaps, crossfades, loop ranges or timeline undo; full V2 show workflow remains planned. No Git commit/push/tag/release performed.

## v1.14 delivery update

This earlier effect/image timeline is included in the completed v1.14 milestone, extended to video ranges and explicit embedded audio. Installed app is now 1.14/build 11, format 9. See [video guide](VIDEO_IMPORT_GUIDE.md) and [current verification](V1.14_VERIFICATION.md). User acceptance remains separate from automated checks.
