# V2 Roadmap — Projection, Lighting and Show Playback

Updated November 8, 2026. The local rehearsal build is **v2.05/build 20**, with portable format 11 and automated verification. v2.05/build 20 is installed in Applications. Physical projector and optical timing acceptance remain pending. The latest published download remains v1.15.1. See [progress](PROGRESS.md), [current verification](LOCAL_SHORTCUTS_VERIFICATION.md) and [projector verification](V2.01_VERIFICATION.md).

v2.05 song sync is available for local rehearsal using Mac audio, Test Mode and simulated fixtures. Native moving-head and Arduino control and physical checks are deferred until equipment is available. A local phone editor follows the desktop cue foundation. Projection, fixtures and music share show time, and the existing Test Mode remains available. The v2.03 encoder and adapter discovery are preserved as local development work. Read the [detailed implementation steps](V2_IMPLEMENTATION_PLAN.md), [development requirements](PROJECT_DEVELOPMENT.md) and [GitHub workflow](GITHUB_WORKFLOW.md) before implementing or delivering a milestone.

## Core milestones

| Milestone | Scope |
|---|---|
| v2.01 · Projector Output and Calibration | Fullscreen single-projector output, reconnect and calibration. Implemented and automatically verified. Physical checks remain pending. |
| v2.02 · Fixture Patching and Simulation | Patch moving heads, plugs and RGB strips. Edit looks and timeline cues with simulated outputs, an intended-state monitor and a 2D fixture preview. Implemented and [automatically verified](V2.02_VERIFICATION.md). User rehearsal pending. |
| v2.03 · Native USB-DMX Moving Head | Add selectable USB-DMX profiles and documented 9-/11-channel controls. Deferred. Resume when the adapter and moving head are available. |
| v2.04 · Native Arduino Relay and RGB Control | Add serial profiles and settings, switched plugs and binary RGB strips. Deferred. Resume when the board and firmware are available. |
| v2.05 · Music and Show Transport | Implemented and [automatically verified](V2.05_VERIFICATION.md). User rehearsal pending. |
| v2.06 · Timeline and Cues | Add song-aware tracks, beat/lyric/section markers, curves, fades and manual cues. |
| v2.07 · Phone Browser Editor and Remote | Pair over local Wi-Fi by QR code. Edit corners, masks and effects, operate playback, see fixture status, undo and save. |
| v2.08 · Holiday Choreography | Add holiday effects, chases, waves, crossfades, beat-aligned triggers and optional live audio reaction. |
| v2.09 · Layers, Regions and Text | Add layered visuals, target regions, text, countdowns and authored singing-face animation. |
| v2.10 · Reusable Shows and Layouts | Assign reusable layout roles, share templates and record cue performances against song time. |
| v2.11 · Show Mode and Readiness | Preload and validate media and fixtures, lock edits, and add operator controls, separate blackouts and failure recovery. |
| v2.12 · External Synchronization and Lighting Integration | Verify a specific xLights/FPP workflow and MIDI/OSC controls. Measure trigger/follow behavior and timing offsets. |
| v2.13 · Playlists and Scheduling | Build playlists, idle scenes, schedule rules, graceful endings and restart handling. |
| v2.14 · Phone Timeline and Preview | Move and trim clips, edit cue timing and view a lightweight Mac-generated preview. |
| v2.15 · Export and Portable Delivery | Collect portable show assets and export mapped output or unmapped content with explicit audio and timing. |
| v2.16 · Acceptance, Packaging and Release | Rehearse the full show, measure timing, record compatibility, and prepare a release for separately authorized publication. |

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
