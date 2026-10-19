# V2 Roadmap — Music and Show Playback

Status updated October 14, 2026: **v2.01 is implemented locally and automatically verified; physical projector acceptance remains pending.** Local app is 2.01/build 14, portable format 9; Debug/Release each passed 284 correctness tests. No GitHub delivery is authorized for this build. Latest published app remains v1.15.1. v2.02–v2.12 remain planned; next independent development is music/song transport and waveforms in v2.02. V1 listening/device-unplug and long-session acceptance remain unverified. v2.10 includes the approved mobile web editor. See [v2.01 verification](V2.01_VERIFICATION.md).

V2 turns the V1 mapper into a native Mac workspace for building repeatable projection shows to music, rehearsing them, coordinating with an existing lighting system and running playlists. Map the display once, reuse it across songs, and keep Test Mode available for editing without hardware. Preserve connected object faces and their shared content coordinates.

Read [V1 remaining plan](V1_REMAINING_PLAN.md), [development requirements](PROJECT_DEVELOPMENT.md), [GitHub workflow](GITHUB_WORKFLOW.md) and the [detailed V2 steps](V2_IMPLEMENTATION_PLAN.md) before implementation. The project remains pinned to Xcode 27.0 beta 5 (27A5237l); a future toolchain change requires an explicit project decision.

## Ordered milestones

The first milestone has a dedicated [v2.01 projector output and calibration plan](V2.01_PLAN.md) with implementation slices and separate automated/physical acceptance gates.

| Milestone | Scope | Acceptance outcome |
|---|---|---|
| 2.01 — Projector Output and Calibration | One fullscreen external output; display identity/reconnect; device calibration and timing measurements; existing renderer/masks. | Test Mode stays independent; real projector operation is claimed only after recorded physical checks. |
| 2.02 — Music and Show Transport | Portable song assets, waveform, audio routing, one song clock, play/pause/stop/restart/seek and rehearsal loops. | Seek/pause/restart keeps generators, video and music at the intended song position. |
| 2.03 — Timeline and Cues | Extend V1 owner tracks/clips with song-aware named object/tag tracks, beat/lyric/section markers, parameter curves and manual cue triggering. | A song can be choreographed, saved and replayed with repeatable results. |
| 2.04 — Holiday Choreography | Snow/twinkle/candy-cane effects, object chases, spatial waves, palette changes, transitions and optional audio reaction. | Coordinated looks work across separate objects and connected faces without disturbing alignment. |
| 2.05 — Layers, Regions and Text | Bounded visual layer stacks, masks/named regions, outlines, countdowns and projected singing-face animation. | A window border, center and overlay can be composed and sequenced independently. |
| 2.06 — Reusable Shows and Layouts | Display roles, selection groups, layout-target assignment, templates, effect packs and recording manual cue performances. | A song template can be assigned to another house layout without moving its mapping. |
| 2.07 — External Synchronization and Lighting Integration | One verified xLights/FPP workflow first; external clock follow versus triggers; MIDI/OSC controls and latency adjustment. | A reference projection/music/light sequence stays aligned on the tested systems, including seeks and sync loss. |
| 2.08 — Show Mode and Readiness | Editing lock, preload, readiness report, live status, stop/blackout/audio mute, identification and recovery policies. | A rehearsed show can run with predictable operator controls and visible failure states. |
| 2.09 — Playlists and Scheduling | Intro/main/closing sections, idle scenes, nightly/holiday rules, graceful finish, timezone/DST and restart behavior. | A simulated and physical nightly schedule starts/stops correctly without duplicate playback. |
| 2.10 — Mobile Web Editor and Remote Control | Mac-hosted phone editor: local Wi-Fi/QR pairing first; face/object selection, mapping/masks, effects and playback; then mobile timeline and bounded preview. Later optional internet access through a private VPN reuses the same editor. | Authorized phone edits use Mac validation, undo and saves; Show Mode locks remain enforced. Disconnects preserve Mac rendering and local control. Actual iPhone/Android browser acceptance is required. |
| 2.11 — Export and Portable Delivery | Collect assets; render projection video from explicit show time; distinguish content-canvas versus mapped-output exports. | Export timing and appearance match the chosen output; the portable show opens without its original asset folders. |
| 2.12 — Acceptance, Packaging and Release | Long-session rehearsal, migration/undo/recovery regressions, measured timing/resource limits, documentation and verified packaging/upload. | Published claims match the tested app, integration versions and actual hardware coverage. |

## Mobile editing direction — October 14, 2026

The approved first approach is a mobile web editor hosted by the running Mac app, opened by scanning a QR code on the Mac. Phone and Mac join the same local Wi-Fi network; internet is not required. A dedicated router is an alternative when venue/guest Wi-Fi isolates clients. Hotspot operation is a separately tested setup, not assumed compatibility.

Keep the existing milestone order: expand v2.10 into three stages—local editing/controls, mobile timeline and preview, then optional private-VPN internet access. The Mac owns rendering, audio/show timing, validation, undo/recovery and project files; the phone sends edits and receives confirmed state. Native phone apps, Bluetooth fallback and our own cloud relay remain later alternatives, not initial dependencies or V2 release blockers. See [detailed stages](V2_IMPLEMENTATION_PLAN.md#v210--mobile-web-editor-and-remote-control).

## Scope boundaries

The first lighting integration uses an existing sequencer/player rather than building a full pixel/fixture sequencer inside V2. Choose the precise interoperable path in v2.07 after a protocol/export feasibility check. An exported movie, OSC trigger or matching file name is not by itself proof of synchronization or format compatibility. Do not advertise direct XSQ/FSEQ support without implementation and fixtures.

Single-projector support comes first. Multiple projector outputs, edge blending/color matching, mesh/3D mapping, camera calibration, direct pixel/DMX control, live video capture and autonomous playback hardware are a prioritized later backlog, not V2 release blockers. Basic V1 polygon masks remain in V1; more elaborate compositing/regions arrive in v2.05.

Hardware deferral is preserved. v2.01 can implement and verify non-hardware behavior while physical checks remain pending; later editing work can proceed in Test Mode. Actual projected-show and synchronized-lighting claims must wait for the corresponding hardware gates. No hardware purchase is assumed.

## Research that informed this plan

These are design references, not dependencies or promises of compatibility. Capabilities/license distinctions and protocol details must be rechecked at implementation time.

- [MadMapper features](https://madmapper.com/madmapper/features): reusable cue looks, transitions, timelines, mapping and lighting workflows.
- [Resolume parameter animation](https://www.resolume.com/support/parameter-animation) and [Autopilot](https://resolume.com/support/en/autopilot): musical parameter control and automatic clip progression.
- [Millumin features](https://www.millumin.com/v5/): timelines/cues, visual layers, mapping and show integration.
- [xLights timing tracks](https://manual.xlights.org/xlights/chapters/chapter-four-sequencer/timing-tracks) and [submodels](https://manual.xlights.org/xlights/chapters/chapter-four-tabs/sub-models): musical markers and addressable prop regions.
- [Light-O-Rama workflow](https://store.lightorama.com/pages/im-new-what-do-i-do): reusable display previews, prop groups and scheduled musical shows.
- [Falcon Player playlists](https://manual.falconplayer.com/036-playlists/), [scheduler](https://manual.falconplayer.com/038-scheduler/) and [MultiSync](https://manual.falconplayer.com/018-multisync/): show operation and player coordination.
- [QLab overview](https://qlab.app/overview/): coordinated cues and a clear operator workflow.
