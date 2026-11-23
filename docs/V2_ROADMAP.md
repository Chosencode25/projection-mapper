# V2 Roadmap — Projection, Lighting and Show Playback

Updated November 17, 2026. Applications now contains verified **v2.11/build 36** with Show Mode and the three Lighting sections, project format 16 and Playground schema 1. Build 35 is preserved. See [Playgrounds verification](V2.10_PLAYGROUNDS_VERIFICATION.md) and [progress](PROGRESS.md). Physical projector/optical acceptance remains pending; latest published download remains v1.15.1.

v2.05 song sync is available for local rehearsal using Mac audio, Test Mode and simulated fixtures. Native moving-head and Arduino control and physical checks are deferred until equipment is available. A local phone editor follows the desktop cue foundation. Projection, fixtures and music share show time, and the existing Test Mode remains available. The v2.03 encoder and adapter discovery are preserved as local development work. Read the [detailed implementation steps](V2_IMPLEMENTATION_PLAN.md), [development requirements](PROJECT_DEVELOPMENT.md) and [GitHub workflow](GITHUB_WORKFLOW.md) before implementing or delivering a milestone.

## Core milestones

| Milestone | Scope |
|---|---|
| v2.01 · Projector Output and Calibration | Fullscreen single-projector output, reconnect and calibration. Implemented and automatically verified. Physical checks remain pending. |
| v2.02 · Fixture Patching and Simulation | Patch moving heads, plugs and RGB strips. Edit looks and timeline cues with simulated outputs, an intended-state monitor and a 2D fixture preview. Implemented and [automatically verified](V2.02_VERIFICATION.md). User rehearsal pending. |
| v2.03 · Native USB-DMX Moving Head | Add selectable USB-DMX profiles and documented 9-/11-channel controls. Deferred. Resume when the adapter and moving head are available. |
| v2.04 · Native Arduino Relay and RGB Control | Add serial profiles and settings, switched plugs and binary RGB strips. Deferred. Resume when the board and firmware are available. |
| v2.05 · Music and Show Transport | Implemented and [automatically verified](V2.05_VERIFICATION.md). User rehearsal pending. |
| v2.06 · Timeline and Cues | Adds song-aware marker lanes, fixture curves and fades, group targeting, and manual cues. See the [rehearsal guide](V2.06_REHEARSAL.md). |
| v2.07 · Phone Browser Editor and Remote | Local HTTPS remote and editor implemented. Browser pairing with a supplied trusted identity passed automated loopback checks. Phone rehearsal is pending. See the [verification record](V2.07_VERIFICATION.md). |
| v2.08 · Holiday Choreography | Add holiday effects, chases, waves, crossfades, beat-aligned triggers and optional live audio reaction. See the [v2.08 verification record](V2.08_VERIFICATION.md). |
| v2.09 · Layers, Regions and Text | Add layered visuals, target regions, text, countdowns and authored singing-face animation. See the [v2.09 verification record](V2.09_VERIFICATION.md). |
| v2.10 · Reusable Shows and Layouts | Playgrounds implemented locally; user rehearsal pending. Layout roles, programmed templates/packs and cue-performance recording remain planned. |
| v2.11 · Show Mode and Readiness | Implemented, automatically verified and installed in build 36. User and hardware rehearsal pending. |
| v2.12 · External Synchronization and Lighting Integration | Verify a specific xLights/FPP workflow and MIDI/OSC controls. Measure trigger/follow behavior and timing offsets. |
| v2.13 · Playlists and Scheduling | Implemented and verified locally in build 37 with Project Home. Live rehearsal pending. |
| v2.14 · Phone Timeline and Preview | Implemented and verified locally in build 38. Physical phone rehearsal pending. |
| v2.15 · Export and Portable Delivery | Collect portable show assets and export mapped output or unmapped content with explicit audio and timing. |
| v2.16 · Acceptance, Packaging and Release | Rehearse the full show, measure timing, record compatibility, and prepare a release for separately authorized publication. |

## New workflow concepts — November 17, 2026

- [Dedicated Lighting workspace](LIGHTING_WORKSPACE_PLAN.md): all three planned sections are implemented locally through build 35, including fixture authoring, motion keys and reusable lighting effects. User rehearsal remains pending. No dedicated milestone version is assigned.
- [Playgrounds](REUSABLE_SETUPS_PLAN.md): implemented locally as the first part of v2.10; save placement/configuration and create independent blank shows. User visual/listening rehearsal remains pending. Existing role assignment, programmed templates and recording scope remains planned.

## Hardware that is still unidentified

Start in **Simulation** for each unknown controller. Fixture controls, saved patches and cues, playback and output monitoring work against simulated devices. Distinguish simulated sends, actual writes and any device acknowledgment. Show that a protocol is unknown or unsupported and leave physical output disarmed. Let the user select a port and choose among implemented DMX profiles or configure documented serial settings and a supported command format. Bring up a verified transport when the adapter or firmware is identified. Confirm each supported combination on real hardware before claiming compatibility. See the [moving-head reference](NATIVE_DMX_FIXTURE_REFERENCE.md).

Direct fixture output works independently of Lightkey or xLights/FPP once a supported transport is available. The separate external-sync milestone tests interoperability. Published tags and prior milestone records retain their original meaning.

## Optional follow-ons

These have numbered steps and acceptance checks. Each can proceed independently once its prerequisites are available.

| Milestone | Scope |
|---|---|
| v2.17 · Private VPN Phone Access | Extend the paired phone editor to a private VPN. Verify a phone connecting from outside the local network. |
| v2.18 · Expanded DMX and Pixel Output | Add more fixture profiles and effects, plus addressed pixels with bounded output rates. |
| v2.19 · Multiple Projectors and Edge Blending | Route and calibrate multiple projectors, blend overlaps and match color. |
| v2.20 · Mesh and Curved-Surface Mapping | Author and validate warped meshes for curved surfaces. |
| v2.21 · Camera-Assisted Alignment | Use measured camera correspondences to suggest editable alignment corrections. |
| v2.22 · 3D Import and Surface Reconstruction | Import supported 3D meshes and evaluate reconstruction from calibrated capture. |
| v2.23 · Live Video Inputs | Evaluate camera, capture-device, NDI and Syphon sources, with measured latency. |
| v2.24 · Projector Power and Input Control | Add documented power/input commands and readiness handling. |
| v2.25 · Assisted Music and Cue Authoring | Evaluate editable beat, lyric, phoneme and stem analysis for cue authoring. |
| v2.26 · Standalone Show Player | Test a portable show package on a dedicated playback platform. |
| v2.27 · Native Phone Companion | Evaluate a native companion using the Mac’s existing permissions and commands. |
| v2.28 · Bluetooth Remote Fallback | Evaluate a paired fallback for basic status and operator actions. |
| v2.29 · Hosted Remote Access | Evaluate an explicitly enabled, authenticated hosted relay. |
| v2.30 · Public Template and Effect Library | Evaluate publishing and discovering compatible templates and effects. |

## Research that informed this plan

These are design references, not dependencies or promises of compatibility. Capabilities/license distinctions and protocol details must be rechecked at implementation time.

- [MadMapper features](https://madmapper.com/madmapper/features): reusable cue looks, transitions, timelines, mapping and lighting workflows.
- [Resolume parameter animation](https://www.resolume.com/support/parameter-animation) and [Autopilot](https://resolume.com/support/en/autopilot): musical parameter control and automatic clip progression.
- [Millumin features](https://www.millumin.com/v5/): timelines/cues, visual layers, mapping and show integration.
- [xLights timing tracks](https://manual.xlights.org/xlights/chapters/chapter-four-sequencer/timing-tracks) and [submodels](https://manual.xlights.org/xlights/chapters/chapter-four-tabs/sub-models): musical markers and addressable prop regions.
- [Light-O-Rama workflow](https://store.lightorama.com/pages/im-new-what-do-i-do): reusable display previews, prop groups and scheduled musical shows.
- [Falcon Player playlists](https://manual.falconplayer.com/036-playlists/), [scheduler](https://manual.falconplayer.com/038-scheduler/) and [MultiSync](https://manual.falconplayer.com/018-multisync/): show operation and player coordination.
- [QLab overview](https://qlab.app/overview/): coordinated cues and a clear operator workflow.
