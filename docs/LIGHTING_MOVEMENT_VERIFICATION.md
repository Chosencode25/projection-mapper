# Lighting movement — build 34 verification

November 19, 2026. Authorized Lighting section 2, implemented over the local build 33 work on `codex/lighting-workspace`. Source: `builds/worktrees/v2.09/app/ProjectionMapper/`. Preview **v2.09/build 34**, project format **15**, Playground metadata schema **1**. No dedicated milestone version assignment, installation, Git commit/push, release/tag or upload.

## Implemented

- Stable per-moving-head song-time position keys with normalized pan/tilt and incoming Snap, Linear or Ease In/Out. Before the first key, ordinary cue positions remain in control; afterward keys override only pan/tilt and the final key holds. Snap holds until the destination's exact timestamp.
- Indexed shared-time evaluation in the existing simulation, retaining cue dimmer/color/gobo, choreography, manual/GO priority, blackout and stopped-position behavior. No additional transport or device events are recorded.
- Editable pan/tilt path chart inset in the schematic, with bounded axes, key selection/position dragging, Snap segments and an intended-position indicator. The chart is explicitly a parameter-space authoring guide. The existing beam/aim schematic continues to preview the resulting fixture state.
- Cyan Positions timeline lanes for heads, key capture/time dragging and exact inspector fields; seek, duplicate, delete, group capture and shared undo/redo. Completed gestures commit once, with captured-project checks to discard a drag if another model edit intervenes. Keyboard and Escape respect Lighting key selection without touching stale projection targets.
- Validation limits of 256 distinct key times per head and 4096 per project, finite time/pan/tilt, unique IDs and supported head references. Fixture deletion removes keys; save/autosave/recovery preserve them and Playground extraction clears them.
- Project-format 15 writes and migration of formats 1–14. Existing shows acquire no keys during migration. Old builds reject the newer format rather than silently dropping programming. Use a rehearsal copy when retaining compatibility with build 32/33.

## Automated evidence

Required Xcode reverified before work: **27.0 beta 5, build 27A5237l**. Minimum macOS remains 15.0. SwiftUI/programmatic AppKit; no storyboards/XIBs. Shared Test Mode/projector renderer and parked hardware work preserved.

Initial focused Release: **8 new HeadPositionTests passed**. Final complete **Release** suite succeeded with **376 tests reported across 40 suites**, zero failures, approximately **23.7 seconds**. Four optional performance cases skipped and the two established legacy visible-window cases excluded. Evidence: `builds/lighting-paths/Release.log` and `Release.xcresult`.

Affected **Debug** verification: **56 tests across five suites passed**, zero failures, approximately **4.7 seconds**. Suites: HeadPositionTests, LightingEditingTests, PlaygroundTests, EditorShortcutTests and ProjectPersistenceTests. Evidence: `Debug-focused.log`/`.xcresult`. This is focused Debug verification, not a full Debug run. The chart's intended-state read was moved into the observed view body after the complete Release run; this final view adjustment compiled with the passing Debug run and the final universal Release delivery build (`Release-delivery.log`). Model/persistence code was unchanged after the complete suite.

New checks cover:

1. Exact first/last key boundaries, linear/eased interpolation, Snap hold behavior and preservation of dimmer/color/gobo.
2. Shared-clock simulation across forward/backward seeks and repeated loop-wrap timestamps, manual override/release, blackout and Stop. Wrapped time is exercised deterministically; this does not claim a new physical or listening rehearsal.
3. Group capture targeting heads only, same-time key updates with stable identity and atomic undo/redo.
4. Collision/nonfinite edit rejection, precision edits, duplicate/delete/Escape keyboard routing, Show locks and fixture-removal cleanup.
5. Wrong fixture types/references, duplicate times and excessive keys.
6. Format-14 migration, format-15 round trip, newer-format rejection and removal of position programming from Playgrounds.
7. Autosave, recovery snapshots and portable reopen with paused/unarmed state.
8. Pan/tilt chart coordinate round trips at edges and different sizes, clamping and invalid-viewport rejection.

Logs include existing Apple media/service diagnostics and the pinned SDK's optional x86_64 testing-framework warning. No claim of zero framework diagnostics or physical timing follows from passing tests.

## Verified local artifact

- App: `builds/lighting-paths/ProjectionMapper.app`.
- Archive: `builds/lighting-paths/ProjectionMapper-Lighting-Paths-build34-macOS-universal.zip`.
- SHA-256: `1cd31fffcfccf6a50a8c1392b307b4b65252120a9693c326f674e63c18063a0d`.
- File/source identities and checksums: `Build-identity.json`, `SHA256SUMS.txt` alongside the app.

All **11 app files** match the final Release product and extracted archive. Strict/deep ad-hoc code-signature checks passed for product, local app and extracted archive. Executable has **arm64 and x86_64**; Intel is cross-built, not runtime-tested. Applications remains build 32; the prior local build 33 artifact is preserved separately.

## Acceptance and remaining scope

User visual/listening acceptance remains pending. No screen control or app launch was performed. Use [the rehearsal guide](LIGHTING_MOVEMENT_GUIDE.md) to check chart motion, resizing, path/time drags, exact fields, cue interaction and a short song/Test Mode loop. Physical moving-head/projector/Arduino acceptance remains deferred. New reusable lighting effects and preview expansion are the next section; broader v2.10 roles/templates/recording remain planned.
