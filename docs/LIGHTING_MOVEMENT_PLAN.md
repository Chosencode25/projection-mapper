# Lighting section 2 — movement paths and position keys

November 19, 2026. Authorized by the user's “build that” request following the saved section-2 status. Extends the uncommitted first Lighting section on `codex/lighting-workspace`; active source remains `builds/worktrees/v2.09/app/ProjectionMapper/`. No new milestone version is assigned. Local preview: v2.09/build 34.

## Contract

- Save per-moving-head position keys with stable ID, fixture ID, song time (0–3600 s), normalized pan/tilt (0–1) and incoming Snap/Linear/Ease In/Out curve.
- The segment arriving at a key uses that key's curve. Linear and Ease In/Out interpolate from the preceding key. Snap holds the preceding position until the target key's exact timestamp. Before the first key, ordinary cue positions apply; from the first key onward, authored keys control pan/tilt and the final key holds.
- Keep brightness, color, gobo and dimmer fades on the existing cue evaluator. Position evaluation changes pan/tilt only. Manual overrides and manual GO remain higher-priority audition states; release them to resume authored motion. Blackout and Stop retain their existing precedence.
- Use one indexed, point-in-time evaluator inside LightingSimulation. Playback, seek, backward seek and loop-wrap timestamps evaluate identically, with no second clock or replayed device events.
- Show an editable pan/tilt chart inset inside the schematic for the selected moving head (the first head for a group), with cyan keys/segments and an orange intended-position marker. The chart uses normalized pan/tilt axes, not physical beam-hit or photometric coordinates. All legal key positions fit in the chart. Dashed segments indicate Snap jumps.
- Capture one key per selected moving head at the snapped playhead. Capture at an occupied time updates that fixture's existing key. Group capture is one undoable edit and leaves non-head fixtures unchanged. Chart drags and timeline time drags commit once at gesture end; model changes during a drag invalidate that gesture's snapshot.
- Add cyan Positions lanes beneath moving heads, with key selection, timing drags and capture at double-click. Inspector supplies exact time/pan/tilt, incoming curve, seek, duplicate, delete and manual-override release. Keyboard duplicate/delete/Escape follow key selection and cannot affect a stale projection selection.
- Bound programming at 256 distinct key times per head and 4096 keys per project. Validate finite bounds, identities, fixture kinds and references before saving. Fixture deletion removes dependent keys. Undo/redo, autosave, recovery and portable saves preserve keys; Playground extraction clears them.

## Persistence

Portable project format is now **15**. Formats 1–14 migrate through the existing reader; older shows acquire no position programming. New format-15 writes prevent old builds from silently dropping keys. Playground metadata schema remains 1; its embedded project manifest writes format 15 and older playground manifests migrate normally. Use a rehearsal copy when preserving a show for build 32/33.

## Completion

Section 2 implementation is complete locally, with automated verification recorded in [verification](LIGHTING_MOVEMENT_VERIFICATION.md). User visual/listening rehearsal and hardware acceptance remain separate. See [the guide](LIGHTING_MOVEMENT_GUIDE.md). Section 3 (new reusable lighting effects and preview expansion) remains planned. Build does not install, commit, push or publish.
