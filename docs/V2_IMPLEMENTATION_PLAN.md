# V2 — Ordered Implementation and Acceptance Plan

Reordered November 8, 2026. v2.01 is implemented and automatically verified, with physical projector acceptance pending. v2.02–v2.16 are the core plan. v2.17–v2.30 are optional follow-on milestones with separate scope and acceptance decisions. See the [roadmap](V2_ROADMAP.md) and [V1 foundations](V1_REMAINING_PLAN.md).

## Early timeline foundation — October 9, 2026

The user requested bottom video-editor-style playback controls before the remaining V1 work. A local enhancement now supplies object/standalone-owner rows, captured effect/image clips, move/trim/duplicate/delete, ruler scrubbing, zoom/snap/follow and shared-clock rendering. The initial format 8 timeline supplied effect/image blocks; v1.14 extends it to portable format 9 video ranges, shared-owner playback and explicit embedded-video audio. It remains one active block per owner with dark gaps. See [timeline plan](TIMELINE_PLAN.md) and [guide](TIMELINE_GUIDE.md). Reuse/migrate this foundation in v2.05–v2.06; V1.15 adds project/timeline/media undo and readiness. Song/waveform models, music audio authority, layered overlaps, curves, markers and crossfades remain planned; extend the existing edit transactions to those new show models. This does not complete v2.06 or physical output acceptance.

## Common contracts

Use the required Xcode 27.0 beta 5 (27A5237l), rechecked before implementation, SwiftUI/programmatic AppKit, Metal and supported AVFoundation APIs. Use files, simulations and automated checks before vital screen/hardware checks. Feature branches start from tested main. Each completed slice receives appropriate checks and honest verification notes; intermediate work stays local. Git commits/pushes and GitHub uploads wait for a completed x.xx app milestone unless explicitly requested. Deliver the requested local app copy at the applicable milestone; milestone labels are not automatic releases. Preserve published tags/assets and read-only mirrors.

A persistent layout owns output geometry, masks, input maps, joins and optional reference photo. A show owns songs, tracks, clips, curves, cues and target-role assignments. Both retain stable IDs; layout selection/zoom, live playheads, decoder frames, sync health and operator overrides stay runtime-only. V2 opens V1 packages through explicit migration and preserves their media/mapping. Opening a file never silently starts playback or arms scheduling.

One authoritative transport supplies song position and discontinuity events (seek/restart/loop) to evaluation. Audio playback is the local clock authority while running; external follow mode chooses one external authority explicitly. Avoid independent free-running clocks for each surface/video. Provide audio-only rehearsal, Test Mode and hardware operation without changing persistent coordinates. Define whether embedded-video audio is a show audio source or muted, preventing duplicate music and feedback.

Simulation tests use known beats/cue timestamps, frame-number video and deterministic seeds. Before timing acceptance, choose a supported resolution/frame cadence and document a measurable error budget for the tested system. Record steady offset, jitter and cumulative drift separately. Use a one-output-frame alignment target after calibration where feasible; report measured results/limits instead of promising zero latency or universal frame accuracy. Timing budgets for hardware/network workflows are established before claiming support.

Fixture patches assign stable fixture IDs to specific controller outputs. The show evaluates intended fixture state independently of hardware transport. A controller is either in Simulation, identified but unsupported, disconnected, connected and disarmed, or live and armed. Physical verification is recorded separately by model, protocol, platform and tested behavior. Use a simulated controller with real fixture controls, a labeled monitor and deterministic connection/failure injection. Live and simulated controllers can coexist. Editing a patch, changing a port/profile, opening a document or reconnecting leaves the affected hardware disarmed. Maintain Test Mode and the user’s routine visual-check preference.

## v2.01 — Projector Output and Calibration

Detailed staged work, operator behavior and acceptance gates: [v2.01 milestone plan](V2.01_PLAN.md), created October 14, 2026. Implementation is locally verified; physical acceptance is pending. See [verification](V2.01_VERIFICATION.md) and [output guide](V2.01_USER_GUIDE.md).

1. Confirm V1 acceptance and migration prerequisites. Define Test Window versus physical-display output routing explicitly; preserve selected display identity and normalized mapping. Plan one projector/output first.
2. Implement a programmatic fullscreen output on the selected eligible external display using the same renderer/content snapshot. Handle resolution, backing scale, screen coordinates, mirroring/eligibility, focus and clean output; editor decorations/reference photos remain excluded.
3. Handle unplug/replug, sleep/wake, changed display modes and app relaunch. Loss makes physical output unavailable with a reachable warning; do not move show output onto the operator's screen or silently resume on a different display. Define explicit re-arm/reopen behavior and preserve layout.
4. Add persistent output calibration preferences and runtime identification patterns. Measure rendering cadence and projector delay for a known fixture; record a user-adjustable visual delay setting for later show synchronization. Keep actual hardware/display mode in the verification record.
5. Verify synthetic display/lifecycle cases, Test Mode regression, GPU equivalence and resource teardown first. Then physically check fullscreen routing, clean output, masks/joins, resize/mode changes and reconnect. If hardware is unavailable, mark those checks pending; allow Test Mode editing milestones to proceed without claiming projector readiness.

## v2.02 — Fixture Patching and Simulation

1. Add a fixture workspace with separate controller and fixture assignments. Start with moving head, switched plug and three-output binary RGB strip. Give each fixture a stable ID, editable label and group. Keep fixture patches with the layout and have show cues reference those IDs. Check DMX address ranges, relay-output bounds and conflicting assignments before applying a patch.
2. Add manual test controls, reusable looks and a basic fixture lane on the existing elapsed-time timeline. Capture complete fixture states, use discrete color/gobo/relay changes, and allow explicit pan/tilt lead time. Define precedence among manual overrides, cues, stop and fixture blackout. Keep projector blackout and audio mute independent.
3. Evaluate fixture state at the current timeline time. Seek and loop reconstruct the current look without replaying skipped cues. Save patches, looks and cues with migration/undo support. Keep live handles, arming and local port bindings outside portable show data.
4. Provide simulated DMX and Arduino outputs with a clearly marked live-state monitor showing intended values and any simulated sends. Show unsupported or unconfigured protocols explicitly. Test migration, assignment collisions, seek, loop, blackout, and fault isolation with both simulated controllers alongside Test Mode.

## v2.03 — Native USB-DMX Moving Head

1. Implement the documented 9- and 11-channel maps in the [moving-head reference](NATIVE_DMX_FIXTURE_REFERENCE.md). Offer pan, tilt, dimmer, fixed color/gobo choices and movement speed. Support fine pan/tilt in CH 11. Use defined inactive values for strobe, auto/sound and reset in this milestone.
2. Add USB interface enumeration and selection with identity details when available. Offer a selectable list of implemented adapter protocols and Simulation. Candidate buffered and host-timed transports each require documented behavior and targeted tests. Keep an unidentified adapter simulated or disarmed. Allow switching among implemented profiles while disarmed and require deliberate test arming.
3. Encode and send bounded DMX frames independently of rendering. Expose intended versus transmitted values and connection status. Blackout sets the dimmer off when output is reachable. Report loss visibly, keep the other outputs running under policy and require re-arm after reconnect.
4. Verify packet bytes and refresh behavior with synthetic sinks. Physically test 9-channel mode at address 001 first, followed by 11-channel precision, movement lead time, color/gobo, blackout and unplug/replug. Record the exact adapter and tested mode. This milestone can deliver a verified simulated fixture and adapter setup UI while the physical adapter is unidentified.

## v2.04 — Native Arduino Relay and RGB Control

1. Add USB serial port selection and configurable baud rate, framing, and supported command profiles. Inspect the existing .ino sketch or sender for command format, numbering, polarity and responses before implementing its profile. A documented text protocol can support configurable delimiters and command templates with validation. Unknown formats stay in Simulation until a matching profile is available.
2. Map a switched plug to one output and an RGB strip to three distinct outputs. Present on/off or eight discrete swatches including off. Use explicit desired states, coalesce changes at a bounded rate, and use a single update for RGB when the firmware supports grouped writes. Track writes and device acknowledgments separately where available.
3. Handle board startup, serial-open reset, disconnect and port changes. Open disarmed and avoid replaying stale commands. Test intended all-off on stop and blackout. A loss-of-connection timeout requires firmware support and hardware verification. Keep the existing sketch intact unless a separate firmware change is needed and approved.
4. Verify command encoding, retries, partial writes, reconnect, discrete cues and output collisions with a simulated serial peer. Physically test one plug and one strip, then the rest of the board. Record the actual board, sketch/profile, channel map and unplug behavior.

## v2.05 — Music and Show Transport

1. Add versioned show/song models alongside V1 layout data. Import supported audio off the main thread, inspect duration and retain portable package assets; decode waveform data with bounded caching. Preserve original media on failed import/save.
2. Add explicit audio-device/channel routing, volume/mute and an audio-only rehearsal option. Define device loss/recovery and embedded-video audio priority so one song does not play twice through linked faces or output views.
3. Implement authoritative Play/Pause/Stop/Restart/Seek, time display and loop-region controls. Define seek completion, end-of-song state, speed/pitch support, fade behavior and audio underrun handling. Stop, pause and visual blackout remain distinct actions.
4. Drive V1 generators, video and both fixture outputs from transport time, with explicit offsets and discontinuity resets. Apply the saved v2.01 projector compensation once at visual evaluation, with explicit seek and loop boundaries. Keep fixture movement lead time separate from projector compensation. Preload/seek video, choose frames for requested song time and define behavior when decode cannot keep up. Minimized editor views suspend their drawing while a running show/audio/output continues as explicitly required.
5. Verify waveform bounds, device changes, package migration, seeks forward/backward, pause/resume, speed/loop/end and same-time generated/video frames. Measure synchronization across projection, moving head and relay cues over full reference songs and repeated loops, using Simulation when devices are unavailable; record steady offset and drift. Visual checks use Test Mode first, then available projector/audio hardware.

## v2.06 — Timeline and Cues

1. Migrate and extend V1 format 9 owner-addressed clips into song/show tracks targeting stable face/object IDs or named target sets. Preserve existing content-owner resolution, clip IDs, effect/image/video settings, times and asset references; explicitly map owners when grouping/detaching. Clips contain effect/media/look references, start/duration/offset and bounded parameters; tracks do not copy geometry. Define overlap/compositing priority, end-state and missing/deleted-target handling.
2. Extend the existing bottom timeline selection, zoom, trim/move/copy/delete, snapping and follow controls with waveform/song editing; reuse V1 final-polish undo transactions. Keep timeline zoom/selection separate from saved edits. Add named beat, lyric and section marker tracks with manual tapping/import first; automatic beat suggestions remain editable.
3. Extend the basic fixture lane with named fixture groups and look cues. Keep relay, color wheel and gobo transitions discrete. Add parameter curves with defined interpolation and typed bounds, plus cue start/stop/fade actions. Continuous object content still has one owner; define conflicts between object-level and face-specific clips visibly rather than producing hidden overrides.
4. Add a manual cue list/GO action, marker navigation and loop rehearsal. Timed playback and manual triggers have explicit priority/reset rules; seek reconstructs the intended current state without firing unrelated network actions. Crossfades/advanced holiday transitions follow in v2.08.
5. Save tracks/cues/markers/curves portably and migrate older packages. Verify boundary timestamps, gaps/overlaps, deleted targets, seek reconstruction, dirty/history behavior and preview/output equivalence. Accept a short fully choreographed song that repeats after save/reopen without remapping.

## v2.07 — Phone Browser Editor and Remote

Mac-hosted local Wi-Fi is the first phone milestone. The Mac stays authoritative for validation, saving and timing. Establish a shared edit-lock and operator permission policy here. Full Show Mode later extends that policy.

1. Add an explicitly enabled Mac-hosted web service and bundled responsive phone interface. Show connection status, a QR code and a manual address fallback. Support a phone and Mac on the same local network without internet. Bind only approved interfaces; make disabling remote access and revoking a phone reachable on the Mac. Investigate discovery/address changes, firewall/local-network permission behavior and secure browser-compatible pairing/session transport before selecting the implementation. Do not require users to bypass certificate warnings or expose an unauthenticated editor.
2. Pair deliberately with an expiring invitation and Mac approval or equivalent verified code exchange. Separate viewer, editor and operator permissions; start with one authorized editing controller. Validate origins, session expiry, request size/rate and target IDs. A QR invitation must not grant permanent unrestricted access. Route every edit/action through the same validated Mac command path as local controls; do not expose arbitrary files or operating-system commands.
3. Supply face/object lists, selected-owner identification/Finish, corner dragging, magnified corner editing and precise nudge buttons. Use normalized mapping coordinates, preserve shared membership/input maps and expose geometry locks. Add face-local boundary/hole mask editing with the same validity rules and intentional gesture completion as on the Mac. Selection/identification stays runtime-only; a completed mapping/mask gesture is one undo action.
4. Add effect parameters, colors/palettes, brightness, Play/Pause/Stop/Seek, visual blackout/restore, deliberate audio enable/mute and readiness/status. Keep blackout separate from audio mute. Show Mode permits operator actions but rejects geometry/timeline edits; remote access must not bypass those locks or automatically arm a show. Mac validation and acknowledgment determine what the phone displays as applied.
5. Add project Undo/Redo and Save through Mac document/recovery handling. Save updates the existing Mac document; an unsaved project requests a destination on the Mac and shows that pending state on the phone. Do not assume a phone browser can operate native Save As dialogs. New/Open/destructive project changes are outside the first phone scope. Asset import/relink remains on the Mac initially.
6. Define state revisions, request/gesture IDs, acknowledgments and controller ownership. Reject stale edits and duplicate commands; broadcast Mac edits to the phone. Coalesce high-frequency drags and bound queues so remote interaction cannot starve rendering/audio. Define gesture timeout/disconnect completion or rollback explicitly, retaining a coherent undo boundary. Reconnect loads current Mac state and never replays old edits or Play commands. Show connection loss visibly; existing output continues under Mac policy and local controls remain available.
7. Verify protocol/authorization/validation/conflict/rate-limit cases automatically before phone checks. Accept a practical task: stand away from the Mac, pair, identify a face, align its corners/mask, change an effect, undo/redo and save, then reopen on the Mac with the same mapping/media. Test actual iPhone Safari and Android Chrome, portrait/landscape and touch/scroll interactions; no cross-platform claim before those checks. Measure edit acknowledgment latency and confirm playback/output remains stable during drags and disconnects. Test a normal LAN and, when available, a dedicated-router setup. Guest-network isolation, hotspot and permissions failures receive clear guidance rather than a compatibility assumption.
8. Expose fixture connection, simulation and current look status. Allow authorized show controls within the same Mac policy. Physical output arming and device/patch changes stay on the Mac for this milestone.

## v2.08 — Holiday Choreography

1. Add bounded holiday generator presets: snowfall, twinkle, candy-cane stripes, stars, icicles and ornament motifs. Build on V1 time/seed and palette contracts; keep counts and GPU allocation bounded.
2. Implement explicit ordered chases with forward/reverse/bounce and per-target staggering. Define spatial whole-display waves using an authored layout canvas or target positions; projection-output coordinates alone must not be mistaken for real-world distances across arbitrary layouts.
3. Add look/clip crossfades and palette transitions with defined duration/easing and ownership. Both sides of a transition share a song time reference. Keep geometry/input maps stable and preserve linked-face continuity; define how conflicting palette updates resolve.
4. Add beat/bar-aligned queued triggering and optional audio-reactive parameter modulation. Let users choose song playback or a selected input, frequency range, gain/smoothing and bounded modulation. Authored timing remains repeatable; live input reaction is explicitly a separate playback mode. Optional beat analysis suggests markers without overriding manual work.
5. Verify chase order, spatial wave coordinates, deterministic holidays, transitions during seeks/loops, palette isolation and resource bounds. Accept a chorus with coordinated separate objects plus a continuous three-face effect, and measure the added workload.

## v2.09 — Layers, Regions and Text

1. Introduce bounded visual layer stacks per content owner with explicit blend modes, opacity, transform and precedence. Map the shared composition onto object faces after compositing; do not create separate unsynchronized layer engines for each face.
2. Add named face-local regions/subtargets and reusable mask assignments, retaining V1 polygon behavior. Define scope when a region is an output-local cutout versus a shared-canvas region; prohibit ambiguous double transforms. Add edge/outline effects with documented thickness coordinates.
3. Add dynamic text, song titles, greetings and countdowns with font/layout fallback and output-safe clipping. Define countdown time sources (song or schedule), and keep operator status separate from intended projected text.
4. Add projected singing-face animation from explicit mouth-shape/lyric markers, with manual authoring or a verified supported timing import. Treat automatic phoneme generation as a later enhancement; no promise of automatic accurate lip sync. Provide a small project-owned demo asset set.
5. Extend package migrations/undo/preflight for layers and regions. Verify mask/alpha blending, border-versus-center tracks, missing fonts/assets, seek/loop text state and deterministic mouth shapes. Profile representative layered scenes and preserve one shared media/audio owner.

## v2.10 — Reusable Shows and Layouts

1. Add display roles/selection groups, distinct from connected-face object membership: windows, roofline, garage or custom user roles. Define multiple membership, explicit target ordering and eligibility for shared versus independent content.
2. Add a target-assignment screen for applying a show to another layout. Preview unresolved roles, validate missing assignments and require deliberate resolution without modifying the receiving layout's corners, masks or input maps.
3. Add song-section/effect templates, presets/palette packs and portable import/export of reusable definitions. Namespace/rewrite imported IDs, define asset dependencies and preserve existing data on conflicts. Do not bundle songs or external media without project-authorized assets.
4. Record manual cue/parameter performance against song timestamps, with quantization optionally applied after recording. Playback uses the same timeline model; editing/re-recording does not duplicate network side effects. Persist recording results, not raw device events.
5. Verify one template on two differently arranged house-photo layouts, role reassignment, deleted groups, ID collisions, package assets and undo. Accept a recorded/revised cue performance and show that adding a window next season can be done through assignment rather than rebuilding its song.

## v2.11 — Show Mode and Readiness

1. Separate editable workspace state from running show state. Entering Show Mode locks geometry/timeline edits and makes selected show/output/audio/clock source obvious. Closing/unlocking while running has a deliberate controlled transition; normal launch/open remains unarmed.
2. Extend V1 readiness checks to target assignments, timelines, layers, codec/device availability, output routing, sync source, fixture transport/arming and resource preload. Classify blockers versus warnings; missing critical assets block arming. Readiness checks must not unexpectedly turn on output or start audio.
3. Provide large Play/Pause/Stop, separate immediate visual and fixture blackouts, independent audio mute and master brightness/fade controls. Define stop/end/blackout precedence and recovery consistently for local and remote commands. Add one-object identification that restores previous runtime state.
4. Add bounded live diagnostics/logs for dropped frames, late decode, audio underruns, asset errors and sync interruption. Define response to sleep, display/audio loss, resource loading failure and app restart. Never silently restart a song after a crash; recovery resumes editing unarmed unless a later explicitly configured scheduling policy applies.
5. Rehearse a complete playlist-equivalent set manually, test fault injection and compare readiness checks with real failures. Verify operator controls remain reachable, mapping stays unchanged and runtime activity creates no project edits. Record supported workloads rather than claiming unlimited surfaces/video.

## v2.12 — External Synchronization and Lighting Integration

1. Select a concrete external interoperability workflow using official xLights/FPP documentation/source and the available platform/device versions. Run a bounded feasibility slice: choose external playback following, supported rendered-video playback/export, or a documented control bridge. Record exact formats/protocols, licensing dependencies and required hardware before committing the implementation. Direct XSQ/FSEQ import is not assumed.
2. Define control adapters separately for one-shot triggers and continuous song-position following. Implement one authoritative mode with start/stop/seek/loop, monotonic sequence/event IDs, bounded buffers and reconnect rules. A trigger-only path must be labeled as such and cannot pass continuous-follow acceptance by merely starting at the same instant.
3. Add clock/source status, offset/latency calibration and explicit sync-loss policy (pause/blackout/continue for a bounded interval). Disarm external control when editing or changing sources. Define reconnect/time jumps without firing a backlog of stale cues; recover only through a visible supported policy.
4. Add bounded MIDI/OSC bindings for approved show actions/parameters using supported implementations. Include optional tested hardware-button bindings. Map controls with editable bindings, input limits and explicit network enablement; routes go through the same command model as local controls. External timecode (for example LTC) is a separate adapter requiring its own decoding/input tests and can follow after the first proven workflow.
5. Verify with recorded/synthetic clock packets and a reference song first, including loss/reorder/duplication, drift, seeks, source changes and malformed input. Then test the actual projection/audio/light systems and publish a compatibility matrix with versions, timing measurements and limits. If only an export/trigger path is feasible, record that result and keep unsupported clock-follow work pending rather than claiming integration complete.
6. Optionally prototype LTC after the first supported workflow. Select an input, validate rate and discontinuities with recorded signals, then measure lock acquisition, loss and reacquisition with real playback hardware.

## v2.13 — Playlists and Scheduling

1. Define versioned playlists with lead-in, main and lead-out items, song/scene references, intermission/idle scene and transition behavior. Specify repeat/shuffle, duration, no-repeat policy and graceful versus immediate stop.
2. Add schedule rules for dates, weekdays, holiday exceptions, timezone and local start/end times. Preview conflicting rules and define priority. Keep sunset-based scheduling as an optional extension requiring explicit location, not an initial requirement.
3. Specify DST, clock changes, midnight crossing, overlapping windows and missed starts after downtime. A schedule has stable occurrence IDs so clock adjustments/relaunch cannot trigger the same occurrence twice. Define cutoff: finish current song or stop now, including a bounded completion policy.
4. Add explicit arming and readiness gates, persistent schedule configuration and conservative restart recovery. Scheduling works only with supported app-running/power conditions; clearly expose whether the app must remain open. Do not promise OS launch/wake/always-on behavior without implementing and testing it.
5. Test using an injected clock over DST/holiday/midnight/conflict scenarios, then perform a multi-night rehearsal on available hardware. Verify preload, intros/outros, idle scenes, graceful endings, manual overrides and restart behavior. Reject or flag schedules whose required dependencies are missing.
6. Optionally add sunset rules with an explicitly configured location. Verify date, timezone and daylight-saving transitions, and define a fallback when the chosen solar event is unavailable.

## v2.14 — Phone Timeline and Preview

1. Extend the phone client with compact object lanes, clip selection, move/trim, source-range editing and useful zoom/snap controls. Reuse stable owner/clip IDs, shared song time and existing undo transactions; preserve geometry and connected-face media ownership. Defer advanced desktop-equivalent authoring until explicit scope is chosen.
2. Add an optional bounded preview generated by the Mac, starting with snapshots or a modest refresh rate. Keep source assets/files on the Mac and avoid a second renderer/player/audio clock on the phone. Expose preview age/latency; a delayed phone preview is not evidence of physical projector/music synchronization. Higher-rate streaming is optional only after measuring bandwidth, encode overhead and output impact.
3. Add authorized fixture-look cue selection and time edits through the Mac command path. Confirm changes on the desktop and exercise local control during phone disconnect.
4. Verify gesture cancellation, stale/deleted clips, transitions, connected ownership, save/reopen, browser background/foreground and multiple read-only clients. Accept timeline edits made on a phone and confirmed on the Mac, with preview enabled/disabled and under network loss. Maintain the single-editor/conflict policy and Show Mode restrictions.

## v2.15 — Export and Portable Delivery

1. Extend collect-assets validation to music, media, reference photos, templates, fonts where legally/packageably supported and any timing dependencies. Define external controller/device settings as references/configuration, not portable hardware. Stage copies with cancellation and rollback.
2. Define two explicit video exports: unmapped shared content canvas and mapped pixels for a specified output resolution/layout. Explain which downstream player needs which export. Freeze show settings/time evaluation for an export and keep editor changes isolated.
3. Render at an explicit frame rate and time range using deterministic transport, bounded buffering and AVFoundation-supported encoding. Choose audio inclusion/mix policy, offsets, codec/color/alpha limits and end-frame rounding. Export is independent of real-time screen refresh; cancel/failure leaves the last completed output intact.
4. Add export readiness/resource estimates and reproducibility metadata (show/layout identity, duration, cadence, resolution and render settings). Generic video export does not imply xLights/FPP package compatibility; validate any integration-specific format through the v2.12 contract.
5. Verify frame-number/timecode fixtures, first/last frame and loop boundaries, audio alignment, masks/joins and matching mapped output. Open collected projects from a different folder and replay the export in the intended supported player. Document any frame/codec limitations and prevent accidental overwrites.

## v2.16 — Acceptance, Packaging and Release

1. Finish migration/undo/autosave/recovery regression coverage from V1 through every V2 schema revision. Verify old layouts retain their mapping, media and mute defaults, and all malformed/incompatible files fail without destroying the current session.
2. Run a realistic house/prop show through authoring, templates, manual recording, music timing, export, integration, operator controls, schedules and mobile web editing/local remote control. Include the moving head and Arduino where their protocols and hardware are available. Cover phone mapping/timeline edits, pairing/revocation and confirmed Mac saves; record private internet access as a separate optional follow-on. Include long sessions, repeated loops, missing media, device/network loss and recovery. Recheck pinned Xcode and target architectures/OS availability.
3. Measure CPU/GPU/memory, timing error/jitter/drift, media decode headroom and resource teardown under documented workloads. Set supported hardware/OS/integration expectations from measured results; distinguish unavailable physical tests from passing simulations.
4. Prepare demonstrations, setup/rehearsal/install instructions, compatibility matrix, known limits and actionable errors. A real Christmas-show example must have physical projection/audio/light evidence before being advertised as verified; a Test Mode demonstration is labeled accordingly.
5. Finalize version/build, signing/distribution/notarization requirements, matching source/tag and immutable archives/checksums. Publish only to the user-authorized destination. Repository visibility changes require separate authorization. Verify uploaded/downloaded artifacts and record the actual release link/results.

## Core delivery gates

- v2.02–v2.04 establish native fixture control and a useful simulation workflow before music. With hardware unavailable, ship clearly labeled simulation for that controller and keep physical acceptance open.
- v2.05 provides the song clock for all outputs. v2.06 expands the cue editor. v2.07 can deliver local phone editing with shared permissions and locks before v2.11 completes Show Mode.
- v2.11 readiness gates unattended scheduling and any future remote arming. v2.12 interoperability complements native output, and v2.15 generic export can proceed independently of any hardware-specific format.
- v2.16 release claims cover only measured capabilities. Keep physical projector, DMX, Arduino, phone and external sync acceptance separate from automated simulation. A later hardware result can extend the compatibility record.
- The following numbered milestones are optional. Each can be approved and verified independently after its prerequisites are available.

## v2.17 — Private VPN Phone Access

1. Reuse the same editor and authenticated command protocol over a deliberately configured private VPN, such as Tailscale. Require the Mac to remain running and reachable and both devices to have authorized network access. Provide address/QR guidance for the chosen private route; VPN setup is explicit, not automatic enrollment or a cloud dependency for local editing.
2. Keep pairing, revocation, permissions and Show Mode locks in force over the VPN. A VPN alone does not authorize app editing. Do not add automatic router port forwarding, public tunnels or our own hosted relay. Handle higher latency and changing connectivity without stale command replay or unwanted show starts.
3. Verify phone access from a genuinely different network/cellular connection, private access boundaries, disconnect/reconnect and unchanged local operation. Record setup/version/network limitations. Internet support remains optional/pending if unavailable, rather than blocking the verified local V2 release or being advertised without acceptance.

## v2.18 — Expanded DMX and Pixel Output

1. Add fixture profiles beyond the first moving head, including explicitly configured wheel effects and optional strobe, sound and maintenance actions. Keep reset behind a deliberate manual action and out of seek reconstruction.
2. Design addressed pixel groups and universe/channel patching with overlap detection, color-order configuration and bounded refresh. Choose a documented output protocol and a concrete test controller.
3. Simulate frames and packet loss, then measure real controller timing, network load and blackout/reconnect behavior. Keep relay RGB binary and use separate fixture types for dimmable outputs.

## v2.19 — Multiple Projectors and Edge Blending

1. Assign persistent layout outputs to displays and share one clock across them. Add test patterns, overlap masks, blend curves and per-output brightness and color correction.
2. Test reconnect and missing displays without silently rerouting projection. Calibrate a real overlap and measure drift, seams and color consistency across supported display modes.

## v2.20 — Mesh and Curved-Surface Mapping

1. Add editable mesh vertices and preserve existing planar corner mapping. Define coordinate and undo rules for masks, linked faces and mesh density.
2. Validate warped output, seams, degenerate meshes, performance and file round trips on curved fixtures.

## v2.21 — Camera-Assisted Alignment

1. Choose a supported camera and calibration pattern, define permission and coordinate requirements, and capture correspondences with confidence and error estimates.
2. Preview suggested adjustments with manual accept, undo and fallback. Measure alignment on real surfaces and test uneven lighting and occlusion.

## v2.22 — 3D Import and Surface Reconstruction

1. Select one supported mesh format and define units, transforms, UVs and seams. Preview assets and map selected faces back to stable layout targets.
2. Prototype reconstruction separately using calibrated capture. Measure geometry error and verify manual correction, save/reopen and rendering on a real prop.

## v2.23 — Live Video Inputs

1. Choose one supported input path first from camera, capture device, NDI or Syphon. Define permissions, licensing, frame timing, color conversion and shared ownership.
2. Measure end-to-end latency and resource usage. Test source loss, reconnect, format changes and how live frames appear in recording or export.

## v2.24 — Projector Power and Input Control

1. Select a documented device protocol and implement explicit power, input and status commands with timeouts and acknowledgment.
2. Integrate warm-up and cooldown with readiness. Verify manual override, reconnect and failure on a real projector.

## v2.25 — Assisted Music and Cue Authoring

1. Prototype beat, section, lyric and phoneme suggestions and optional stem analysis. Keep generated timing editable and define local or service processing and privacy boundaries.
2. Compare against hand-authored reference songs and measure correction effort. Support applying, undoing and saving only accepted changes.

## v2.26 — Standalone Show Player

1. Choose a target platform and define package capabilities, media/renderer limits, configuration and transfer.
2. Verify deterministic playback, arming, updates, restart, resource use and device recovery on actual target hardware.

## v2.27 — Native Phone Companion

1. Scope native features against the browser editor and reuse the same authenticated Mac command and permission model.
2. Test iOS/Android targets selected for delivery, pairing, app backgrounding, updates and disconnection before distribution.

## v2.28 — Bluetooth Remote Fallback

1. Choose a documented transport and scope compact operator actions and status. Reuse pairing, revocation and Mac-side validation.
2. Measure range and latency, verify disconnect/reconnect and reject duplicate or stale controls.

## v2.29 — Hosted Remote Access

1. Define hosting, encryption, privacy, access and revocation requirements. Prototype an authenticated relay with explicit enablement and no access beyond allowed app commands.
2. Verify external-network behavior, service outages, abuse limits and preservation of local operation.

## v2.30 — Public Template and Effect Library

1. Define package versions, rights, submissions, moderation and compatibility. Reuse local import validation and preview.
2. Pilot discovery and distribution with approved assets. Verify rollback, unsupported versions, accessibility and privacy before public launch.
