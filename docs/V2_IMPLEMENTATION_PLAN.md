# V2 — Ordered Implementation and Acceptance Plan

Status: show milestones planned, October 5, 2026; early timeline foundation added October 9, 2026. See [V2 roadmap](V2_ROADMAP.md) for scope and research, and [V1 foundations](V1_REMAINING_PLAN.md) for prerequisites. v2.01 code is now implemented locally and automatically verified, with physical acceptance pending; v2.02 onward remain planned. The early timeline foundation below is already implemented in V1. Each milestone can be split into smaller implementation slices before coding; keep its number and acceptance contract consistent across documents.

## Early timeline foundation — October 9, 2026

The user requested bottom video-editor-style playback controls before the remaining V1 work. A local enhancement now supplies object/standalone-owner rows, captured effect/image clips, move/trim/duplicate/delete, ruler scrubbing, zoom/snap/follow and shared-clock rendering. The initial format 8 timeline supplied effect/image blocks; v1.14 extends it to portable format 9 video ranges, shared-owner playback and explicit embedded-video audio. It remains one active block per owner with dark gaps. See [timeline plan](TIMELINE_PLAN.md) and [guide](TIMELINE_GUIDE.md). Reuse/migrate this foundation in v2.02–v2.03; V1.15 adds project/timeline/media undo and readiness. Song/waveform models, music audio authority, layered overlaps, curves, markers and crossfades remain planned; extend the existing edit transactions to those new show models. This does not complete v2.03 or physical output acceptance.

## Common contracts

Use the required Xcode 27.0 beta 5 (27A5237l), rechecked before implementation, SwiftUI/programmatic AppKit, Metal and supported AVFoundation APIs. Use files, simulations and automated checks before vital screen/hardware checks. Feature branches start from tested main. Each completed slice receives appropriate checks and honest verification notes; intermediate work stays local. Git commits/pushes and GitHub uploads wait for a completed x.xx app milestone unless explicitly requested. Deliver the requested local app copy at the applicable milestone; milestone labels are not automatic releases. Preserve published tags/assets and read-only mirrors.

A persistent layout owns output geometry, masks, input maps, joins and optional reference photo. A show owns songs, tracks, clips, curves, cues and target-role assignments. Both retain stable IDs; layout selection/zoom, live playheads, decoder frames, sync health and operator overrides stay runtime-only. V2 opens V1 packages through explicit migration and preserves their media/mapping. Opening a file never silently starts playback or arms scheduling.

One authoritative transport supplies song position and discontinuity events (seek/restart/loop) to evaluation. Audio playback is the local clock authority while running; external follow mode chooses one external authority explicitly. Avoid independent free-running clocks for each surface/video. Provide audio-only rehearsal, Test Mode and hardware operation without changing persistent coordinates. Define whether embedded-video audio is a show audio source or muted, preventing duplicate music and feedback.

Simulation tests use known beats/cue timestamps, frame-number video and deterministic seeds. Before timing acceptance, choose a supported resolution/frame cadence and document a measurable error budget for the tested system. Record steady offset, jitter and cumulative drift separately. Use a one-output-frame alignment target after calibration where feasible; report measured results/limits instead of promising zero latency or universal frame accuracy. Timing budgets for hardware/network workflows are established before claiming support.

## v2.01 — Projector Output and Calibration

Detailed staged work, operator behavior and acceptance gates: [v2.01 milestone plan](V2.01_PLAN.md), created October 14, 2026. Implementation is locally verified; physical acceptance is pending. See [verification](V2.01_VERIFICATION.md) and [output guide](V2.01_USER_GUIDE.md).

1. Confirm V1 acceptance and migration prerequisites. Define Test Window versus physical-display output routing explicitly; preserve selected display identity and normalized mapping. Plan one projector/output first.
2. Implement a programmatic fullscreen output on the selected eligible external display using the same renderer/content snapshot. Handle resolution, backing scale, screen coordinates, mirroring/eligibility, focus and clean output; editor decorations/reference photos remain excluded.
3. Handle unplug/replug, sleep/wake, changed display modes and app relaunch. Loss makes physical output unavailable with a reachable warning; do not move show output onto the operator's screen or silently resume on a different display. Define explicit re-arm/reopen behavior and preserve layout.
4. Add persistent output calibration preferences and runtime identification patterns. Measure rendering cadence and projector delay for a known fixture; record a user-adjustable visual delay setting for later show synchronization. Keep actual hardware/display mode in the verification record.
5. Verify synthetic display/lifecycle cases, Test Mode regression, GPU equivalence and resource teardown first. Then physically check fullscreen routing, clean output, masks/joins, resize/mode changes and reconnect. If hardware is unavailable, mark those checks pending; allow Test Mode editing milestones to proceed without claiming projector readiness.

## v2.02 — Music and Show Transport

1. Add versioned show/song models alongside V1 layout data. Import supported audio off the main thread, inspect duration and retain portable package assets; decode waveform data with bounded caching. Preserve original media on failed import/save.
2. Add explicit audio-device/channel routing, volume/mute and an audio-only rehearsal option. Define device loss/recovery and embedded-video audio priority so one song does not play twice through linked faces or output views.
3. Implement authoritative Play/Pause/Stop/Restart/Seek, time display and loop-region controls. Define seek completion, end-of-song state, speed/pitch support, fade behavior and audio underrun handling. Stop, pause and visual blackout remain distinct actions.
4. Drive V1 generators and video from transport time, with explicit offsets and discontinuity resets. Avoid applying an external delay twice. Preload/seek video, choose frames for requested song time and define behavior when decode cannot keep up. Minimized editor views suspend their drawing while a running show/audio/output continues as explicitly required.
5. Verify waveform bounds, device changes, package migration, seeks forward/backward, pause/resume, speed/loop/end and same-time generated/video frames. Measure synchronization over full fixture songs and repeated loops; record steady offset and drift. Visual checks use Test Mode first, then available projector/audio hardware.

## v2.03 — Timeline and Cues

1. Migrate and extend V1 format 9 owner-addressed clips into song/show tracks targeting stable face/object IDs or named target sets. Preserve existing content-owner resolution, clip IDs, effect/image/video settings, times and asset references; explicitly map owners when grouping/detaching. Clips contain effect/media/look references, start/duration/offset and bounded parameters; tracks do not copy geometry. Define overlap/compositing priority, end-state and missing/deleted-target handling.
2. Extend the existing bottom timeline selection, zoom, trim/move/copy/delete, snapping and follow controls with waveform/song editing; reuse V1 final-polish undo transactions. Keep timeline zoom/selection separate from saved edits. Add named beat, lyric and section marker tracks with manual tapping/import first; automatic beat suggestions remain editable.
3. Add parameter curves with defined interpolation and typed bounds, plus cue start/stop/fade actions. Continuous object content still has one owner; define conflicts between object-level and face-specific clips visibly rather than producing hidden overrides.
4. Add a manual cue list/GO action, marker navigation and loop rehearsal. Timed playback and manual triggers have explicit priority/reset rules; seek reconstructs the intended current state without firing unrelated network actions. Crossfades/advanced holiday transitions follow in v2.04.
5. Save tracks/cues/markers/curves portably and migrate older packages. Verify boundary timestamps, gaps/overlaps, deleted targets, seek reconstruction, dirty/history behavior and preview/output equivalence. Accept a short fully choreographed song that repeats after save/reopen without remapping.

## v2.04 — Holiday Choreography

1. Add bounded holiday generator presets: snowfall, twinkle, candy-cane stripes, stars, icicles and ornament motifs. Build on V1 time/seed and palette contracts; keep counts and GPU allocation bounded.
2. Implement explicit ordered chases with forward/reverse/bounce and per-target staggering. Define spatial whole-display waves using an authored layout canvas or target positions; projection-output coordinates alone must not be mistaken for real-world distances across arbitrary layouts.
3. Add look/clip crossfades and palette transitions with defined duration/easing and ownership. Both sides of a transition share a song time reference. Keep geometry/input maps stable and preserve linked-face continuity; define how conflicting palette updates resolve.
4. Add beat/bar-aligned queued triggering and optional audio-reactive parameter modulation. Let users choose song playback or a selected input, frequency range, gain/smoothing and bounded modulation. Authored timing remains repeatable; live input reaction is explicitly a separate playback mode. Optional beat analysis suggests markers without overriding manual work.
5. Verify chase order, spatial wave coordinates, deterministic holidays, transitions during seeks/loops, palette isolation and resource bounds. Accept a chorus with coordinated separate objects plus a continuous three-face effect, and measure the added workload.

## v2.05 — Layers, Regions and Text

1. Introduce bounded visual layer stacks per content owner with explicit blend modes, opacity, transform and precedence. Map the shared composition onto object faces after compositing; do not create separate unsynchronized layer engines for each face.
2. Add named face-local regions/subtargets and reusable mask assignments, retaining V1 polygon behavior. Define scope when a region is an output-local cutout versus a shared-canvas region; prohibit ambiguous double transforms. Add edge/outline effects with documented thickness coordinates.
3. Add dynamic text, song titles, greetings and countdowns with font/layout fallback and output-safe clipping. Define countdown time sources (song or schedule), and keep operator status separate from intended projected text.
4. Add projected singing-face animation from explicit mouth-shape/lyric markers, with manual authoring or a verified supported timing import. Treat automatic phoneme generation as a later enhancement; no promise of automatic accurate lip sync. Provide a small project-owned demo asset set.
5. Extend package migrations/undo/preflight for layers and regions. Verify mask/alpha blending, border-versus-center tracks, missing fonts/assets, seek/loop text state and deterministic mouth shapes. Profile representative layered scenes and preserve one shared media/audio owner.

## v2.06 — Reusable Shows and Layouts

1. Add display roles/selection groups, distinct from connected-face object membership: windows, roofline, garage or custom user roles. Define multiple membership, explicit target ordering and eligibility for shared versus independent content.
2. Add a target-assignment screen for applying a show to another layout. Preview unresolved roles, validate missing assignments and require deliberate resolution without modifying the receiving layout's corners, masks or input maps.
3. Add song-section/effect templates, presets/palette packs and portable import/export of reusable definitions. Namespace/rewrite imported IDs, define asset dependencies and preserve existing data on conflicts. Do not bundle songs or external media without project-authorized assets.
4. Record manual cue/parameter performance against song timestamps, with quantization optionally applied after recording. Playback uses the same timeline model; editing/re-recording does not duplicate network side effects. Persist recording results, not raw device events.
5. Verify one template on two differently arranged house-photo layouts, role reassignment, deleted groups, ID collisions, package assets and undo. Accept a recorded/revised cue performance and show that adding a window next season can be done through assignment rather than rebuilding its song.

## v2.07 — External Synchronization and Lighting Integration

1. Select a concrete first workflow using official xLights/FPP documentation/source and the available platform/device versions. Run a bounded feasibility slice: choose external playback following, supported rendered-video playback/export, or a documented control bridge. Record exact formats/protocols, licensing dependencies and required hardware before committing the implementation. Direct XSQ/FSEQ import is not assumed.
2. Define control adapters separately for one-shot triggers and continuous song-position following. Implement one authoritative mode with start/stop/seek/loop, monotonic sequence/event IDs, bounded buffers and reconnect rules. A trigger-only path must be labeled as such and cannot pass continuous-follow acceptance by merely starting at the same instant.
3. Add clock/source status, offset/latency calibration and explicit sync-loss policy (pause/blackout/continue for a bounded interval). Disarm external control when editing or changing sources. Define reconnect/time jumps without firing a backlog of stale cues; recover only through a visible supported policy.
4. Add bounded MIDI/OSC bindings for approved show actions/parameters using supported implementations. Map controls with editable bindings, input limits and explicit network enablement; routes go through the same command model as local controls. External timecode (for example LTC) is a separate adapter requiring its own decoding/input tests and can follow after the first proven workflow.
5. Verify with recorded/synthetic clock packets and a reference song first, including loss/reorder/duplication, drift, seeks, source changes and malformed input. Then test the actual projection/audio/light systems and publish a compatibility matrix with versions, timing measurements and limits. If only an export/trigger path is feasible, record that result and keep unsupported clock-follow work pending rather than claiming integration complete.

## v2.08 — Show Mode and Readiness

1. Separate editable workspace state from running show state. Entering Show Mode locks geometry/timeline edits and makes selected show/output/audio/clock source obvious. Closing/unlocking while running has a deliberate controlled transition; normal launch/open remains unarmed.
2. Extend V1 readiness checks to target assignments, timelines, layers, codec/device availability, output routing, sync source and resource preload. Classify blockers versus warnings; missing critical assets block arming. Readiness checks must not unexpectedly turn on output or start audio.
3. Provide large Play/Pause/Stop, immediate visual blackout, independent audio mute and master brightness/fade controls. Define stop/end/blackout precedence and recovery consistently for local and remote commands. Add one-object identification that restores previous runtime state.
4. Add bounded live diagnostics/logs for dropped frames, late decode, audio underruns, asset errors and sync interruption. Define response to sleep, display/audio loss, resource loading failure and app restart. Never silently restart a song after a crash; recovery resumes editing unarmed unless a later explicitly configured scheduling policy applies.
5. Rehearse a complete playlist-equivalent set manually, test fault injection and compare readiness checks with real failures. Verify operator controls remain reachable, mapping stays unchanged and runtime activity creates no project edits. Record supported workloads rather than claiming unlimited surfaces/video.

## v2.09 — Playlists and Scheduling

1. Define versioned playlists with lead-in, main and lead-out items, song/scene references, intermission/idle scene and transition behavior. Specify repeat/shuffle, duration, no-repeat policy and graceful versus immediate stop.
2. Add schedule rules for dates, weekdays, holiday exceptions, timezone and local start/end times. Preview conflicting rules and define priority. Keep sunset-based scheduling as an optional extension requiring explicit location, not an initial requirement.
3. Specify DST, clock changes, midnight crossing, overlapping windows and missed starts after downtime. A schedule has stable occurrence IDs so clock adjustments/relaunch cannot trigger the same occurrence twice. Define cutoff: finish current song or stop now, including a bounded completion policy.
4. Add explicit arming and readiness gates, persistent schedule configuration and conservative restart recovery. Scheduling works only with supported app-running/power conditions; clearly expose whether the app must remain open. Do not promise OS launch/wake/always-on behavior without implementing and testing it.
5. Test using an injected clock over DST/holiday/midnight/conflict scenarios, then perform a multi-night rehearsal on available hardware. Verify preload, intros/outros, idle scenes, graceful endings, manual overrides and restart behavior. Reject or flag schedules whose required dependencies are missing.

## v2.10 — Mobile Web Editor and Remote Control

Approved October 14, 2026. Expand the existing remote-control milestone without renumbering other V2 work. The phone is a separate browser client; the Mac interface stays native SwiftUI/programmatic AppKit. All stages below are planned, not implemented. No native phone app, public server or Bluetooth connection is required for the first delivery.

### Stage 1 — Local Wi-Fi editor and controls

1. Add an explicitly enabled Mac-hosted web service and bundled responsive phone interface. Show connection status, a QR code and a manual address fallback. Support a phone and Mac on the same local network without internet. Bind only approved interfaces; make disabling remote access and revoking a phone reachable on the Mac. Investigate discovery/address changes, firewall/local-network permission behavior and secure browser-compatible pairing/session transport before selecting the implementation. Do not require users to bypass certificate warnings or expose an unauthenticated editor.
2. Pair deliberately with an expiring invitation and Mac approval or equivalent verified code exchange. Separate viewer, editor and operator permissions; start with one authorized editing controller. Validate origins, session expiry, request size/rate and target IDs. A QR invitation must not grant permanent unrestricted access. Route every edit/action through the same validated Mac command path as local controls; do not expose arbitrary files or operating-system commands.
3. Supply face/object lists, selected-owner identification/Finish, corner dragging, magnified corner editing and precise nudge buttons. Use normalized mapping coordinates, preserve shared membership/input maps and expose geometry locks. Add face-local boundary/hole mask editing with the same validity rules and intentional gesture completion as on the Mac. Selection/identification stays runtime-only; a completed mapping/mask gesture is one undo action.
4. Add effect parameters, colors/palettes, brightness, Play/Pause/Stop/Seek, visual blackout/restore, deliberate audio enable/mute and readiness/status. Keep blackout separate from audio mute. Show Mode permits operator actions but rejects geometry/timeline edits; remote access must not bypass those locks or automatically arm a show. Mac validation and acknowledgment determine what the phone displays as applied.
5. Add project Undo/Redo and Save through Mac document/recovery handling. Save updates the existing Mac document; an unsaved project requests a destination on the Mac and shows that pending state on the phone. Do not assume a phone browser can operate native Save As dialogs. New/Open/destructive project changes are outside the first phone scope. Asset import/relink remains on the Mac initially.
6. Define state revisions, request/gesture IDs, acknowledgments and controller ownership. Reject stale edits and duplicate commands; broadcast Mac edits to the phone. Coalesce high-frequency drags and bound queues so remote interaction cannot starve rendering/audio. Define gesture timeout/disconnect completion or rollback explicitly, retaining a coherent undo boundary. Reconnect loads current Mac state and never replays old edits or Play commands. Show connection loss visibly; existing output continues under Mac policy and local controls remain available.
7. Verify protocol/authorization/validation/conflict/rate-limit cases automatically before phone checks. Accept a practical task: stand away from the Mac, pair, identify a face, align its corners/mask, change an effect, undo/redo and save, then reopen on the Mac with the same mapping/media. Test actual iPhone Safari and Android Chrome, portrait/landscape and touch/scroll interactions; no cross-platform claim before those checks. Measure edit acknowledgment latency and confirm playback/output remains stable during drags and disconnects. Test a normal LAN and, when available, a dedicated-router setup. Guest-network isolation, hotspot and permissions failures receive clear guidance rather than a compatibility assumption.

### Stage 2 — Mobile timeline and preview

1. Extend the phone client with compact object lanes, clip selection, move/trim, source-range editing and useful zoom/snap controls. Reuse stable owner/clip IDs, shared song time and existing undo transactions; preserve geometry and connected-face media ownership. Defer advanced desktop-equivalent authoring until explicit scope is chosen.
2. Add an optional bounded preview generated by the Mac, starting with snapshots or a modest refresh rate. Keep source assets/files on the Mac and avoid a second renderer/player/audio clock on the phone. Expose preview age/latency; a delayed phone preview is not evidence of physical projector/music synchronization. Higher-rate streaming is optional only after measuring bandwidth, encode overhead and output impact.
3. Verify gesture cancellation, stale/deleted clips, transitions, connected ownership, save/reopen, browser background/foreground and multiple read-only clients. Accept timeline edits made on a phone and confirmed on the Mac, with preview enabled/disabled and under network loss. Maintain the single-editor/conflict policy and Show Mode restrictions.

### Stage 3 — Optional internet access through a private VPN

1. Reuse the same editor and authenticated command protocol over a deliberately configured private VPN, such as Tailscale. Require the Mac to remain running and reachable and both devices to have authorized network access. Provide address/QR guidance for the chosen private route; VPN setup is explicit, not automatic enrollment or a cloud dependency for local editing.
2. Keep pairing, revocation, permissions and Show Mode locks in force over the VPN. A VPN alone does not authorize app editing. Do not add automatic router port forwarding, public tunnels or our own hosted relay. Handle higher latency and changing connectivity without stale command replay or unwanted show starts.
3. Verify phone access from a genuinely different network/cellular connection, private access boundaries, disconnect/reconnect and unchanged local operation. Record setup/version/network limitations. Internet support remains optional/pending if unavailable, rather than blocking the verified local V2 release or being advertised without acceptance.

Optional tested hardware-button bindings can still reuse v2.07 adapters; they are independent of the phone editor and do not require hardware purchases. A native companion app, Bluetooth/Bluetooth LE fallback and a hosted internet relay remain later alternatives requiring separate feasibility, security, distribution and hardware/browser acceptance plans.

## v2.11 — Export and Portable Delivery

1. Extend collect-assets validation to music, media, reference photos, templates, fonts where legally/packageably supported and any timing dependencies. Define external controller/device settings as references/configuration, not portable hardware. Stage copies with cancellation and rollback.
2. Define two explicit video exports: unmapped shared content canvas and mapped pixels for a specified output resolution/layout. Explain which downstream player needs which export. Freeze show settings/time evaluation for an export and keep editor changes isolated.
3. Render at an explicit frame rate and time range using deterministic transport, bounded buffering and AVFoundation-supported encoding. Choose audio inclusion/mix policy, offsets, codec/color/alpha limits and end-frame rounding. Export is independent of real-time screen refresh; cancel/failure leaves the last completed output intact.
4. Add export readiness/resource estimates and reproducibility metadata (show/layout identity, duration, cadence, resolution and render settings). Generic video export does not imply xLights/FPP package compatibility; validate any integration-specific format through the v2.07 contract.
5. Verify frame-number/timecode fixtures, first/last frame and loop boundaries, audio alignment, masks/joins and matching mapped output. Open collected projects from a different folder and replay the export in the intended supported player. Document any frame/codec limitations and prevent accidental overwrites.

## v2.12 — Acceptance, Packaging and Release

1. Finish migration/undo/autosave/recovery regression coverage from V1 through every V2 schema revision. Verify old layouts retain their mapping, media and mute defaults, and all malformed/incompatible files fail without destroying the current session.
2. Run a realistic house/prop show through authoring, templates, manual recording, music timing, export, integration, operator controls, schedules and mobile web editing/local remote control. Cover phone mapping/timeline edits, pairing/revocation and confirmed Mac saves; exercise internet access only if that optional stage is delivered. Include long sessions, repeated loops, missing media, device/network loss and recovery. Recheck pinned Xcode and target architectures/OS availability.
3. Measure CPU/GPU/memory, timing error/jitter/drift, media decode headroom and resource teardown under documented workloads. Set supported hardware/OS/integration expectations from measured results; distinguish unavailable physical tests from passing simulations.
4. Prepare demonstrations, setup/rehearsal/install instructions, compatibility matrix, known limits and actionable errors. A real Christmas-show example must have physical projection/audio/light evidence before being advertised as verified; a Test Mode demonstration is labeled accordingly.
5. Finalize version/build, signing/distribution/notarization requirements, matching source/tag and immutable archives/checksums. Perform publication under the established user-authorized destination/visibility; private GitHub remains the default and public exposure is a separate decision. Verify uploaded/downloaded artifacts and record the actual release link/results.

## Dependency gates and staged delivery

- v2.01 establishes physical output readiness; v2.02–v2.06 can be developed in Test Mode while unavailable hardware checks remain pending.
- v2.02 is the clock foundation for v2.03–v2.04 and for continuous following in v2.07. Do not implement synchronization by counting rendered frames.
- v2.05 defines composition/region targets before v2.06 template assignment. Existing V1 tags are metadata; target-role assignment is explicit.
- v2.07 compatibility is proven per workflow. A limited export/control bridge can ship accurately labeled; unsupported follow adapters remain pending work.
- v2.08 readiness is required before v2.09 unattended operation or v2.10 remote arming. v2.10 phone editing reuses v2.03 edit transactions and v2.08 locks; local editing does not require the optional VPN stage. v2.11 generic export uses timeline determinism even if a hardware adapter is unavailable.
- The final show release is gated on its advertised physical/integration capabilities. Test-only slices do not erase pending hardware work, and pending hardware does not prevent independent editing progress.

## Later feature backlog and admission criteria

| Priority | Feature | Why it is later / prerequisite |
|---|---|---|
| First after core show workflow | Multiple projectors, edge blending and per-output color matching | Requires measured single-output timing, explicit multi-output routing and actual overlap hardware. |
| First after core show workflow | Mesh/curved-surface mapping | Requires stable mask/layer coordinate contracts, editable meshes and geometry/resource limits. |
| First after core show workflow | Direct pixel/DMX controller output | Requires fixture/channel patching, collision checks, bounded network rates and hardware tests; integration with an existing sequencer comes first. |
| Subsequent enhancement | Camera-assisted alignment/calibration | Requires capture permissions, calibration fixtures, confidence/error reporting and a manual fallback. |
| Subsequent enhancement | Live camera, NDI/Syphon or capture-device input | Requires a specifically supported ingest path, frame ownership/color/timing and reconnect testing. |
| Subsequent enhancement | Projector power/input control | Requires documented device protocols and explicit startup/shutdown/acknowledgment rules; display output support alone is insufficient. |
| Subsequent enhancement | 3D import and surface reconstruction | Requires coordinate conventions, UV/seam authoring, camera calibration and a distinct 3D workflow. |
| Subsequent enhancement | Standalone player/export target | Requires an actual supported platform, deterministic renderer/media support and independent deployment/recovery testing. |
| Subsequent enhancement | Automatic lyric/phoneme extraction, stem analysis and assisted sequencing | Requires accuracy controls, editable results, media processing/privacy decisions and measured usefulness; manual/imported timing works first. |
| Subsequent enhancement | Public effect-pack/template library or marketplace | Requires packaging/version compatibility, asset rights, moderation and a deliberate hosted-service scope; local sharing comes first. |

Promote a backlog item only through an explicit scope update with implementation and verification steps. This list preserves brainstormed possibilities without treating every feature as a V2 release obligation.
