# V2 Roadmap — Music and Show Playback

Status: planned only, October 5, 2026. The user requested revising V1 foundations and planning V2 after research into projection mapping, Christmas sequencing and show control. v1.08 remains the latest implemented/locally accepted app (local-only delivery). These milestone numbers describe implementation order; they do not authorize implementation, version bumps or publication now.

V2 turns the V1 mapper into a native Mac workspace for building repeatable projection shows to music, rehearsing them, coordinating with an existing lighting system and running playlists. Map the display once, reuse it across songs, and keep Test Mode available for editing without hardware. Preserve connected object faces and their shared content coordinates.

Read [V1 remaining plan](V1_REMAINING_PLAN.md), [development requirements](PROJECT_DEVELOPMENT.md), [GitHub workflow](GITHUB_WORKFLOW.md) and the [detailed V2 steps](V2_IMPLEMENTATION_PLAN.md) before implementation. The project remains pinned to Xcode 27.0 beta 5 (27A5237l); a future toolchain change requires an explicit project decision.

## Ordered milestones

| Milestone | Scope | Acceptance outcome |
|---|---|---|
| 2.01 — Projector Output and Calibration | One fullscreen external output; display identity/reconnect; device calibration and timing measurements; existing renderer/masks. | Test Mode stays independent; real projector operation is claimed only after recorded physical checks. |
| 2.02 — Music and Show Transport | Portable song assets, waveform, audio routing, one song clock, play/pause/stop/restart/seek and rehearsal loops. | Seek/pause/restart keeps generators, video and music at the intended song position. |
| 2.03 — Timeline and Cues | Named object/tag tracks, timed clips, beat/lyric/section markers, parameter curves and manual cue triggering. | A song can be choreographed, saved and replayed with repeatable results. |
| 2.04 — Holiday Choreography | Snow/twinkle/candy-cane effects, object chases, spatial waves, palette changes, transitions and optional audio reaction. | Coordinated looks work across separate objects and connected faces without disturbing alignment. |
| 2.05 — Layers, Regions and Text | Bounded visual layer stacks, masks/named regions, outlines, countdowns and projected singing-face animation. | A window border, center and overlay can be composed and sequenced independently. |
| 2.06 — Reusable Shows and Layouts | Display roles, selection groups, layout-target assignment, templates, effect packs and recording manual cue performances. | A song template can be assigned to another house layout without moving its mapping. |
| 2.07 — External Synchronization and Lighting Integration | One verified xLights/FPP workflow first; external clock follow versus triggers; MIDI/OSC controls and latency adjustment. | A reference projection/music/light sequence stays aligned on the tested systems, including seeks and sync loss. |
| 2.08 — Show Mode and Readiness | Editing lock, preload, readiness report, live status, stop/blackout/audio mute, identification and recovery policies. | A rehearsed show can run with predictable operator controls and visible failure states. |
| 2.09 — Playlists and Scheduling | Intro/main/closing sections, idle scenes, nightly/holiday rules, graceful finish, timezone/DST and restart behavior. | A simulated and physical nightly schedule starts/stops correctly without duplicate playback. |
| 2.10 — Local Remote Control | Local-network phone/browser controls and status; explicit pairing/access; optional tested hardware-button bindings. | Authorized controls operate the same show state; loss of remote connectivity does not stop local controls. |
| 2.11 — Export and Portable Delivery | Collect assets; render projection video from explicit show time; distinguish content-canvas versus mapped-output exports. | Export timing and appearance match the chosen output; the portable show opens without its original asset folders. |
| 2.12 — Acceptance, Packaging and Release | Long-session rehearsal, migration/undo/recovery regressions, measured timing/resource limits, documentation and verified packaging/upload. | Published claims match the tested app, integration versions and actual hardware coverage. |

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
