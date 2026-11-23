# Project Progress

Last updated: November 23, 2026.

## Current state

**November 23 in-app updates, local v2.16 build 46:** Added signed in-app download and restart-to-install for new full releases. The app uses normal autosave, checks show activity before restarting, validates the app, and replaces it atomically after exit. All eight targeted Release tests passed with Xcode 27A5237l. The build 46 helper installed and relaunched a disposable signed app, and a simulated relaunch error restored the old bundle. The universal ZIP and its detached signature were verified. Live delivery of a signed GitHub release and user visual acceptance are pending. See [the in-app update guide](IN_APP_UPDATES_GUIDE.md).

**November 23 build 45 installation and GitHub delivery:** Installed the verified universal build 45 in Applications, checked all 11 bundle files and the signature, and preserved the previous build 44 at `builds/update-notifications/Previous-Applications.app`. Published [build 45 as a GitHub prerelease](https://github.com/Chosencode25/projection-mapper/releases/tag/v2.16-build45) with tag `v2.16-build45` at `53081da`. All four downloaded release files and the extracted app matched. The latest full v2.16 release is build 44. Visual verification of the update notice is pending.

**November 23 GitHub update notifications, local v2.16 build 45:** Added automatic daily checks on launch or activation and a manual Check for Updates command. A newer full release with a universal Mac ZIP opens a notice in the editor or Project Home when the app is idle. Later delays that version and Download Update opens the GitHub release. The live checker read the published v2.16 release. Xcode 27A5237l passed all five targeted tests and produced a verified ad-hoc signed universal ZIP. User visual verification is pending. The build was initially prepared locally. See [the update guide](UPDATE_NOTIFICATIONS_GUIDE.md).

**November 23 v2.16 full release:** Published [v2.16 build 44](https://github.com/Chosencode25/projection-mapper/releases/tag/v2.16) as the latest GitHub release. Main and the annotated tag point to the tested source at `ffe7766`. All six uploaded files and all 11 extracted app files matched. The universal archive is ad-hoc signed. Visual, listening, phone-device, and hardware acceptance remain pending. See `builds/whole-show-layouts/github-delivery/Release-verification.json`.

**November 23 build 44 GitHub delivery and local cleanup:** Published [v2.16 preview, build 44](https://github.com/Chosencode25/projection-mapper/releases/tag/v2.16-preview.1) with the verified ad-hoc signed universal ZIP, checksum, build identity, and guides. The annotated tag points to `ffe7766` on `codex/whole-show-layouts`. Archived [builds 39–43](https://github.com/Chosencode25/projection-mapper/releases/tag/archive/macos-builds-39-43) separately. Every asset on both releases was downloaded and matched. Moved nine older app copies, five ZIPs, and two superseded test bundles to Trash (981 MiB total). Removed 861 MiB of disposable build and verification files. Kept build 44 in Applications, the active and previous source worktrees, local shows and drafts, parked USB-DMX, rehearsal files, and older logs. The itemized receipt is in `builds/whole-show-layouts/github-delivery/Cleanup-receipt.json`.

**November 23 build 44 installation:** The user chose the free local distribution option. Installed v2.16/build 44 in Applications and verified all 11 bundle files, the strict ad-hoc signature, and both Mac architectures. Build 40 is preserved in builds/whole-show-layouts/Previous-Applications.app. The installed build is ready for user visual and listening acceptance. The installation record is in builds/whole-show-layouts/Installation-verification.json.

**November 23 build 44 rehearsal:** The Mac’s silent playback probe passed. Xcode 27A5237l passed the original cue-recording regression and a new muted Encore rehearsal. The newly recorded cues survived remapping and reopening with the soundtrack and projection clips. In simulated Test Mode, the reassigned fixture switched on at 5.07 s and off at 5.50 s, and Metal rendered an offscreen frame inside the 4.90–6.40 s projection clip. Verified the ad-hoc signed universal ZIP and its checksum. Developer ID signing and notarization remain pending because no Developer ID Application identity was available. User visual and listening acceptance remain pending. The short run and disposable shows are in builds/whole-show-layouts/. See [the rehearsal guide](V2.16_REHEARSAL.md#build-44-cue-recording-and-layout-rehearsal).

**November 23 roadmap decision:** Retired the planned v2.12 external synchronization milestone, including xLights/FPP, MIDI/OSC controls, and external timecode.

**November 23 whole-show layout reuse, local v2.16 build 44:** Added ordered, persistent roles for projection targets and fixtures, with multiple membership and fixture group assignment. Roles travel with Playgrounds. The File menu opens a destination review that suggests matches and supports assigning one source to several compatible destinations or explicitly skipping it. It saves an independent copy using the receiving mapping and patch and the source programming and required media. Project format 17 reads earlier files. Xcode 27A5237l built the signed universal app. All 42 targeted Release tests passed across two runs, including independent package creation, role persistence, older project migration, and existing Playground and section reuse. User visual and whole-show rehearsal remain pending. The app and evidence are in builds/whole-show-layouts/. See [the guide](SHOW_LAYOUT_GUIDE.md).

**November 23 live lighting cue recording, local v2.16 build 43:** Record manual cues and saved looks against the soundtrack in Lighting. Review which cues to keep, adjust their song times or snap them to beat markers, and insert the selection as one undoable edit. The default recording is a snap cue at the trigger time. Xcode 27A5237l built the signed universal app and 29 lighting, timeline, and project-file tests passed. The recording integration and existing playback checks timed out on macOS audio. A separate silent-file playback probe timed out as well. The broader run was stopped after repeated audio timeouts. End-to-end recording and user visual verification remain pending. The local app, archive and verification logs are in builds/cue-recording/. See [the guide](CUE_RECORDING_GUIDE.md).

**November 23 effect and palette packs, local v2.16 build 42:** Added portable export and selective import for saved palettes, projection effect presets, and lighting effect presets. Keep Both is the default for matching names. Replace preserves links to uniquely name-matched palette slots and retains the prior color for links to removed or ambiguous slots. One Undo reverses an import. Xcode 27A5237l reported 406 tests in 45 Release suites with zero failures. Seven optional checks were skipped and two visible-window tests were excluded. The ad-hoc signed universal local app is in builds/effect-packs/. User visual verification is pending. See [the guide](EFFECT_PACKS_GUIDE.md).

**November 23 reusable show sections, local v2.16 build 41:** Added save and insert commands under Timeline. A section carries time-relative projection clips, timed fixture cues, and referenced images and videos. Review compatible role matches before inserting. The receiving project keeps its layout and fixture patch, and insertion is one undoable edit. Xcode 27A5237l reported 403 tests across 44 Release suites with zero failures, including the cross-layout package, media, and undo/redo checks. The signed universal local app is in builds/show-sections/. The user visual check is pending. See [the guide](SHOW_SECTIONS_GUIDE.md).

**November 23 v2.16 installation:** Installed build 40 in Applications and verified its 11 app files and signature against the tested candidate. The prior build 38 is preserved in builds/v2.16/Previous-Applications.app. Video inspection confirmed the mapped Encore MP4 has 720 frames over 24 seconds, with video and soundtrack both starting at zero. Visual and listening acceptance remain pending.

**November 23 v2.16 Winter Lights Encore, local release candidate build 40:** Fixed sustained soundtrack loop completion and added a bounded live-video frame fallback. Built the offscreen rehearsal for phone editing and revocation, output interruption, simulated fixture and video faults, failed-save recovery, package migrations, whole-show export, portable reopening, and playlist handoff. The final Release run reported 401 tests in 44 suites with zero failures. The separate 30-minute run completed 74 wraps and 53,913 renders, and verified output and media teardown. A video frame was unavailable at submission for 2.32% of video requests. Visual, listening, real-phone and hardware acceptance remain pending. The ad-hoc signed universal app, checksum and reports are in builds/v2.16/. See [rehearsal](V2.16_REHEARSAL.md) and [compatibility and metrics](V2.16_COMPATIBILITY.md).

**November 23 v2.15 Export and Portable Delivery, local build 39:** Added mapped projector and unmapped face/object canvas MP4 export, resolution and cadence settings, a show-time range, and an optional AAC project song. Collect Show Assets saves an independent editable package with its media. All output is staged and existing destinations are protected. Xcode 27A5237l reported 394 Release tests in 42 suites with zero failures. Four optional performance checks were skipped and two existing visible-window checks excluded. The user still has visual and listening checks to run. The tested local app is under builds/v2.15/. Applications has v2.14 build 38. See [guide](SHOW_EXPORT_GUIDE.md) and [verification](V2.15_PLAN.md).

**November 22 release:** Published [v2.14/build 38](https://github.com/Chosencode25/projection-mapper/releases/tag/v2.14) as the latest public GitHub release. The annotated tag points to `80350c5`, the tested source delivered to main. All five uploaded assets were downloaded and matched local files. The archive contains an ad-hoc signed universal app for macOS 15 or later. Applications still contains build 36.

**November 22 phone timeline and preview, v2.14/build 38:** Added time-windowed timeline lanes, drag and precise clip move/trim, video source ranges, and lighting cue selection/retiming. An optional Mac-rendered 480-pixel JPEG preview displays frame time and approximate age. The primary editor follows the existing permission and revision checks. Up to four additional approved viewers can see the timeline and preview. Xcode 27A5237l reported 390 tests in 42 suites with no failures, four optional performance skips and two established visible-window exclusions. The browser gesture harness checked cancel, one commit on release, and blocked stale and Show Mode edits. The universal app and archive under `builds/phone-timeline/` passed strict signature and file checks. Real phone and physical timing rehearsal remain pending. Applications contains build 36. See [phone rehearsal](PHONE_TIMELINE_GUIDE.md) and [verification](V2.14_PLAN.md).

**November 22 Project Home, Playlists and Scheduling, local v2.13/build 37:** Implemented the native Home browser with map preview cards for recent projects and autosaved drafts. Playlists run saved projects in Show Mode with intros, intermissions, outros, repeat or shuffle, and immediate or graceful stop. Calendar rules cover weekdays, date windows, holiday skips, timezone, priority and cutoff. Scheduling starts disarmed and requires the app to remain open and awake. Xcode 27A5237l reported 386 tests in 42 suites with zero failures, four optional performance skips and two established visible-window exclusions. The signed universal app and archive are under `builds/playlists-home/`. Visual and listening rehearsal, full show handoffs on real hardware, and live calendar rehearsal remain pending. Applications contains build 36. See [the guide](SHOW_PLAYLIST_GUIDE.md) and [verification](V2.13_PLAN.md).

**November 22 Show Mode, local v2.11/build 36:** Implemented the Show Mode milestone on `codex/v2.11-show-mode`. Prepare & Arm blocks critical readiness faults, samples up to 12 videos and warms nearby clips. The Mac, phone and keyboard share the playback gate. Show adds live brightness and fade controls, object identification and a bounded event log. Output, audio, simulated fixture and media faults hold the playhead, darken outputs and require rearming. Stop resets playback; natural ends hold the endpoint. Open and recovery start disarmed in Edit. The final Release run with Xcode 27A5237l reported 381 tests in 40 suites with zero failures, four optional performance skips and two established visible-window exclusions. Verified the signed universal app and archive under `builds/show-mode/`. User visual and listening checks, live device recovery and multi-show rehearsal remain pending. Build 36 is installed in Applications and matches all 11 verified Release files. Build 35 is preserved at `builds/show-mode/Previous-Applications.app`. The requested source backup uses `codex/v2.11-show-mode`. See [rehearsal](SHOW_MODE_GUIDE.md) and [verification](V2.11_PLAN.md).

**November 19 build 35 installation and GitHub backup:** Installed v2.09/build 35 in Applications at the user's request. Its 11 files match the verified universal Release product and its strict signature check passed. Preserved build 32 at `builds/lighting-effects/Previous-Applications.app`. The requested GitHub source backup uses `codex/lighting-workspace` and covers all three Lighting sections. Visual and listening rehearsal remain pending.

**November 19 reusable lighting effects, local build 35:** Implemented Lighting section 3. The project library saves Forward, Reverse, Bounce and Wave presets with their colors, step time, repeats and direction. Applying a preset creates an independent timeline clip with ordered fixture targets or a snapshot of their schematic positions. The schematic highlights active effect steps using effective simulated output while preserving cue and manual priority, blackout and moving-head paths. Portable format 16 migrates earlier projects and keeps presets out of blank Playground shows. Xcode 27A5237l reported 378 tests across 40 Release suites with zero failures, four optional performance skips and two established visible-window exclusions. Both new regression checks passed. The universal app and extracted ZIP match all 11 Release files and passed strict signature verification. Evidence and app are in `builds/lighting-effects/`. User visual and listening rehearsal remain pending. This Build command stayed local, with Applications on build 32. See [rehearsal](LIGHTING_EFFECTS_GUIDE.md).

**November 19 Lighting movement — local build 34:** Implemented authorized section 2 on `codex/lighting-workspace`, preserving local build 33 work. Added per-moving-head song-time position keys, incoming Snap/Linear/Ease In/Out curves, schematic pan/tilt path editing, position timeline lanes, exact inspector fields, group capture and safe keyboard/undo routing. Position evaluation shares the existing clock and preserves brightness/color cues, manual override priority and blackout/Stop behavior. Portable format 15 validates and persists keys; old projects migrate and Playgrounds clear the programming. Full Release succeeded with 376 tests reported in 40 suites; affected Debug passed 56 checks in five suites. Final universal app and ZIP passed strict signatures and 11-file product/archive comparisons under `builds/lighting-paths/`. Required Xcode 27A5237l verified. No screen control, installation, commit, push or publication; Applications remains build 32. User visual/listening and physical acceptance remain pending. Next is reusable lighting effects/preview expansion. See [plan](LIGHTING_MOVEMENT_PLAN.md), [verification](LIGHTING_MOVEMENT_VERIFICATION.md) and [rehearsal](LIGHTING_MOVEMENT_GUIDE.md).

**November 17 Lighting workspace — local build 33:** User invoked Build for the first saved Lighting section. Added the dedicated authoring workspace with fixture/group/look selection, supported contextual controls, the existing schematic and separate setup panel, shared waveform/timeline with per-fixture cue rows and optional read-only projection references, cue editing, shared undo and safe keyboard routing. Playground shows can start in Lighting. Full Release succeeded with 368 tests reported in 39 suites; focused Debug passed 48 checks in four suites. Exact Xcode 27A5237l verified. Universal local app/ZIP passed strict signature and 11-file comparisons under `builds/lighting-workspace/`. Applications remains build 32. No installation, commit, push or publication; user visual/listening rehearsal is pending. Movement paths/keyframes and new reusable effects remain planned. See [verification](LIGHTING_WORKSPACE_VERIFICATION.md) and [rehearsal](LIGHTING_WORKSPACE_GUIDE.md).

**November 17 build 32 installation and requested backup:** The user invoked **Install** and **Backup**, explicitly authorizing installation and a source commit/push exception for this intermediate Playgrounds slice. Installed verified v2.09/build 32 in Applications; all 11 files match the Release product and strict signature/universal-architecture checks passed. Build 31 is preserved at `builds/v2.10/playgrounds/Previous-Applications.app`; installation evidence is alongside it. Source backup commit **c6a7ce2** was successfully pushed to `origin/codex/v2.10-playgrounds`, including accumulated local phone/editor work and current plans/command reference. The successful push confirms delivery without remote polling. Main remains at the completed milestone, and no release/tag/app-asset upload is requested. Existing Release/Debug evidence applies; only documentation changed during installation/delivery. User visual/listening acceptance remains pending.

**November 17 chat-command reference:** Saved the proposed one-word command meanings in [Chat commands](CHAT_COMMANDS.md), linked from the docs index and development requirements. Documentation only; no app changes, build or Git delivery.

**November 17 Playgrounds implementation — build 32 preview:** Implemented the authorized first part of v2.10 on local `codex/v2.10-playgrounds`, preserving prior uncommitted build 31 work. Shared setup extraction, Save Playground, direct/library/project-file new shows, independent autosaved drafts, rename/note/duplicate/confirmed update/import/export and reference-photo-only packages are in place. Full Release succeeded with 362 tests reported in 38 suites, including seven new Playgrounds checks. Full Debug had two phone curl failures; all five phone checks passed in isolation and the other Debug checks passed. Final universal Release build 32 and strict signatures/11-file app-and-archive comparisons passed. The local app is under `builds/v2.10/playgrounds/`; Applications retains build 31. Exact Xcode 27A5237l verified. Marketing version remains 2.09; broader v2.10 roles/templates/recording remain planned. User visual/listening rehearsal is pending; no screen control, commit, push or publication. See [plan](V2.10_PLAYGROUNDS_PLAN.md), [verification](V2.10_PLAYGROUNDS_VERIFICATION.md) and [rehearsal](PLAYGROUNDS_GUIDE.md).

**November 17 lighting and Playgrounds concepts:** Saved the [dedicated Lighting workspace idea](LIGHTING_WORKSPACE_PLAN.md) and planned [Playgrounds](REUSABLE_SETUPS_PLAN.md): capture mapping, fixture placement and configuration from any supported project, then start independent autosaved shows with empty programming/timing and an optional new song. The Playgrounds workflow becomes the proposed first piece of existing v2.10; broader template/role/recording work remains planned. Planning only; no app changes, build, Git delivery or implementation acceptance.

**November 17 editor workflow polish — build 31:** Implemented the approved editor pass: expandable scene hierarchy, contextual clip/cue/layer/region/mouth-key controls, reduced persistent copy, direct clip edits, selection-aware keyboard actions, resizable panels and layer placement handles, per-owner timeline collapse, background document autosave, managed drafts, five bounded checkpoints, and actionable save failures. Corrected Snowfall and Particles antialiasing across wrapped coordinates. Final full Release: 355 tests passed in 37 suites, four optional performance skips and two legacy window exclusions, using Xcode 27A5237l. Full Debug had two phone curl timeouts; all five phone checks passed in isolation, and the other Debug checks passed. Final universal app-only rebuild and agent screen checks verified corrected panel sizes, Edit/Show retention, direct clip editing, keyboard layer deletion, inspector scroll reset, white snowfall playback, and draft save/reopen/quit. The Applications copy matches all 11 Release files and strict signature verification; build 30 is preserved under `builds/v2.09/editor-polish/Previous-Applications.app`. Source stays local. User visual/listening acceptance and the broader stress/fault matrix remain pending. See [verification and remaining refinements](EDITOR_WORKFLOW_POLISH_VERIFICATION.md).

**November 17 user acceptance of Local Remote:** The user confirmed that the build 30 Local Remote setup works on their iPhone over the home network. This records successful device setup and connection. Detailed control-by-control checks, sustained stability, Android, and operation without internet remain unverified.

**November 17 easy Local Remote:** The user approved unencrypted HTTP on the trusted home network. Build 30 adds automatic Wi-Fi/Ethernet private-address selection, Start Local Remote, and HTTP QR pairing, with HTTPS under Advanced. Five focused Release checks passed with Xcode 27A5237l, covering HTTP and HTTPS requests, automatic selection, served phone assets, Host/Origin enforcement, approval, replay rejection, revocation, and network stability. Automatic discovery found en0 at 192.168.1.142. The signed universal Applications copy matches all 11 tested Release files. Build 29 is backed up at `builds/v2.09/local-remote/Previous-Applications.app`. Source stays local. Real iPhone Safari and Android Chrome checks and rehearsal without internet are pending.

**November 17 phone remote stability correction:** Build 29 replaces whole-path diagnostic-string comparisons with the bound IPv4 endpoint's interface, address, and netmask. A two-second grace period tolerates a temporary endpoint interruption. Four focused Release checks passed with Xcode 27A5237l, covering real HTTPS pairing, preserved approval through repeated notifications and brief loss, and revocation after interface change or sustained loss. The signed universal app in Applications matches all 11 tested product files. The prior build 28 is backed up at `builds/v2.09/phone-stability/Previous-Applications.app`. Source stays local on `codex/phone-remote-network-stability`. Actual iPhone stability rehearsal is pending. Consumer pairing options are recorded in the local v2.07 plan.

**November 17 v2.09 installation:** Installed the tested v2.09/build 28 universal app in Applications. All 11 files match the Release product and strict signature verification passed. The previous v2.05/build 20 app is retained at `builds/v2.09/Previous-Applications.app`. Tested source, accumulated plans, and the Winter Lights demos were committed at **4f7d9b6** and pushed successfully to GitHub main under the user’s explicit request. The existing 342 passing Release checks apply. User visual and listening rehearsal and hardware acceptance remain pending.

**November 11 v2.09 implementation:** Added visual layers, face-local regions, projected titles and countdowns, and song-timed singing faces. Portable format 14 migrates older projects. The signed universal build 28 is under `builds/v2.09/`. 342 Release tests passed, including the Winter Lights Encore save-and-reopen check and a 1080p offscreen render comparison. User visual and listening rehearsal and physical output checks are pending. See the [verification record](V2.09_VERIFICATION.md) and [Encore rehearsal guide](V2.09_REHEARSAL.md).

**November 11 v2.08 implementation:** Added holiday presets, projection and fixture choreography, two-source crossfades and beat queues on the isolated v2.08 branch. 335 Release checks passed with the pinned Xcode. The signed universal app and chorus rehearsal are under `builds/v2.08/`. User rehearsal is pending. See the [chorus rehearsal](V2.08_REHEARSAL.md).

**November 11 v2.08 planning:** Drafted the [holiday choreography plan](V2.08_PLAN.md) for presets, ordered chases and layout waves, projection and palette crossfades, and queued beat and bar triggers. A chorus rehearsal will use Test Mode and simulated fixtures. Implementation and verification are pending.

**November 11 v2.07 implementation:** Added the local HTTPS remote and phone editor from the v2.06 baseline. The current setup uses a supplied certificate identity and local hostname. 3 focused Debug and 332 Release checks passed with the pinned Xcode. The signed universal local build and archive are under `builds/v2.07/`. Real phone rehearsal is pending. See the [rehearsal guide](V2.07_REHEARSAL.md).

**November 11 v2.07 planning:** Drafted the [phone browser remote and editor plan](V2.07_PLAN.md), starting with browser pairing and Show controls before phone mapping edits. Implementation and device verification are pending.

**November 9 Show rehearsal controls:** Build 25 adds a loop-aware next cue, readiness summary, projection fade and Pause and Edit when leaving a running rehearsal. The pinned Xcode passed 36 focused Release checks. The signed universal app is at `builds/v2.06/show-rehearsal/`. User visual acceptance is pending.

**November 9 two-finger panning:** Build 24 lets precise scrolling pan both axes together over the zoomed Edit canvas. Four focused Release checks passed with Xcode 27.0 beta 5 (27A5237l). The signed universal build is at `builds/v2.06/trackpad/`. Physical trackpad acceptance is pending.

**November 9 canvas and timeline navigation:** Added Edit canvas zoom and pan, Fit, 100% and selection framing. Timeline zoom follows the playhead and can frame the selected clip, cue or loop. 29 focused Release checks passed with the pinned Xcode. The signed universal build 23 is under `builds/v2.06/navigation/`. Visual acceptance is pending. See the [workspace guide](EDIT_SHOW_WORKSPACES.md).

**November 9 workspace split:** Added a top-level Edit and Show switch on the v2.06 branch, with shared playback and read-only Show previews. 27 focused Release checks passed with the pinned Xcode. Signed universal build 22 is under `builds/v2.06/workspaces/`. User visual acceptance is pending. See the [workspace guide](EDIT_SHOW_WORKSPACES.md).

**November 9 v2.06 implementation:** Added editable show markers, waveform loop drawing, fixture groups, timed moves and dimmer fades, and a manual cue list on the isolated v2.06 branch. 12 focused Debug and 324 Release checks passed. The signed universal build and rehearsal are available locally under `builds/v2.06/`. User visual and listening checks are pending. See the [timeline and cues rehearsal](V2.06_REHEARSAL.md).

**November 9 v2.05 delivery:** Installed the verified v2.05/build 20 in Applications and backed up the previous app. This source update includes the [song transport plan](V2.05_PLAN.md) and the revised roadmap that defers physical hardware work. The local app archive and user rehearsal project remain in the project build folder.

**November 8 v2.05 implementation:** Added soundtrack import, a waveform, song-clock playback and simulated lighting sync on the isolated v2.05 branch. Nine focused Debug tests and 321 Release tests passed with the pinned Xcode. The verified universal local app and click-track rehearsal are under `builds/v2.05/` in the main project folder. See the [plan](V2.05_PLAN.md) and [rehearsal steps](V2.05_REHEARSAL.md). Physical hardware acceptance remains deferred.

**November 8 v2.02 graphical preview:** Added a 2D schematic for moving-head beams, switched plugs and binary RGB strips to the fixture workspace. It follows the current simulation during playback and scrubbing. Fixture positions and strip endpoints are editable and save with the project. Build 18 passed 317 Release checks with the pinned Xcode. The signed universal rehearsal copy is under `builds/v2.02/fixture-preview/`. Build 18 is installed in Applications. The previous installed app is backed up under the same build folder. User visual acceptance of the preview is pending. The user confirmed delivery to the public repository. Tested source commit **c6a49a8** was pushed to GitHub main. The app archive is stored locally and no GitHub release was created.

**November 8 v2.02 implementation:** Added fixture patching, manual tests and look capture, a Lighting timeline lane, and per-controller simulated output on the existing elapsed-time clock. Package format 10 migrates earlier projects. Debug and Release each passed **317 tests** with the pinned Xcode. The signed universal **v2.02/build 17** rehearsal copy and ZIP are under `builds/v2.02/`. The source was developed on `codex/v2.02-fixtures`. User visual rehearsal and physical fixture acceptance are pending. See [verification](V2.02_VERIFICATION.md) and the [rehearsal steps](V2.02_REHEARSAL.md).

**November 8 v2.02 planning:** Drafted the [Fixture Patching and Simulation plan](V2.02_PLAN.md) with four implementation slices, proposed package migration, cue and output rules, and rehearsal acceptance. Confirmed installed Xcode 27.0 build 27A5237l. This entry records the planning baseline.

**November 8 V2 replanning:** The [roadmap](V2_ROADMAP.md) and [implementation plan](V2_IMPLEMENTATION_PLAN.md) now define v2.01–v2.16 core milestones and v2.17–v2.30 optional follow-ons. Next is v2.02 fixture patching and simulation, then native USB-DMX and Arduino serial, followed by the shared song clock in v2.05 and local phone editing in v2.07. Unidentified hardware can be simulated, with physical verification tracked separately. The user authorized GitHub delivery of this documentation update.

**November 8 native DMX reference:** Recorded the user-supplied moving-head manual’s 9- and 11-channel maps and a proposed first hardware check in the [fixture reference](NATIVE_DMX_FIXTURE_REFERENCE.md). USB adapter identification, native output implementation and hardware verification are pending.

**Previous installed app: v2.01/build 16 — local polish and keyboard editing, October 19, 2026.** Installed and verified in the workspace and Applications. Adds Space playback in editor/Test/projector windows, contextual duplicate/delete, surface editing/navigation, imports, clip capture/nudging/video split, timeline navigation/zoom/snap/follow, inspector shortcuts, explicit mute/output close and a searchable Help → Keyboard Shortcuts reference (Command-/). Normal typing, mask editing, locked geometry, native text editing/undo and focused projector Escape are preserved. Earlier build 15 toolbar/sidebar/timeline/performance improvements remain included; portable format stays 9. See the [local guide](LOCAL_APP_GUIDE.md), [shortcut verification](LOCAL_SHORTCUTS_VERIFICATION.md) and [earlier polish evidence](LOCAL_APP_POLISH_2026-10-19.md).

**Debug and Release each passed 312 correctness tests**, including 19 shortcut regressions, zero failures/recorded runtime warnings; four optional benchmarks skipped and two legacy visible-window tests excluded. Universal slices, strict ad-hoc signatures and all 11 app-file hashes match the tested Release product, both installed copies and extracted ZIP. Current archive/identity/checksum/local-source patch are under builds/current/; compact final evidence is under builds/keyboard-shortcuts/. One shared build cache remains for development. Build 15's 293-test and earlier build 14 evidence/profiles remain historical records; no new FPS/physical-performance claim is made.

The app was initially running; installation waited until the user explicitly reported saving and closing it. Both installed copies are now build 16. No app was launched or force-quit and no screen control was used. User visual/listening, projector/optical timing, Intel/older-macOS runtime and Developer ID/notarization acceptance remain pending/unestablished.

**GitHub source delivery confirmed — October 19:** under the user’s explicit request, the combined build 15 polish and build 16 keyboard changes plus the complete README/standalone shortcut reference were committed at **ed0e9f220dcf5ac3cf71122898677d2b8ea92512**. Main fast-forwarded from **58a7574** and was successfully pushed to origin. This push result confirms delivery without polling. The published app remains v1.15.1; no new release/tag or app asset upload was requested or performed. Future intermediate work remains local under normal policy.

**October 19 cleanup/source backup:** the user explicitly requested backing up the newer local version and removing redundant old local versions. This supersedes the prior local-only restriction for this delivery. v2.01 source, mobile-editor planning and cleanup improvements were successfully pushed to GitHub main at **0f8b517**. Latest published app download remains v1.15.1; no new release/tag is requested. The duplicated canonical demo is consolidated into the intact bundled regression fixture. Hardware acceptance remains separate. See [cleanup record](PROJECT_CLEANUP_2026-10-19.md).

**v2.01 detailed planning — October 14, 2026:** Created [Projector Output and Calibration plan](V2.01_PLAN.md), expanding the existing outline into routing/lifecycle, clean fullscreen rendering, recovery/UI, device calibration/timing and regression/local delivery slices. Defines explicit open/reopen, no live output relocation on disconnect, shared renderer/media ownership and separate automated/physical acceptance. Linked from the V2 roadmap/implementation plan. Documentation only; no implementation, app build/toolchain verification, version bump, screen use, commits or uploads. At that planning point, v2.01 remained planned.

**Latest published correction: v1.15.1/build 13.** The missing Show readiness/audio controls are fixed and passed automated and short onscreen checks. The user explicitly requested GitHub/release correction; the full patch release is published as latest, preserving v1.15. See [patch verification](V1.15.1_VERIFICATION.md) and [acceptance evidence](V1.15_ACCEPTANCE.md).

**v1.15 is the completed V1 app; the full GitHub release is published.** Universal **1.15/build 12**, portable format **9**. Adds bounded model/media undo/redo, coherent mapping/mask/slider transactions, saved-state media revision tracking, readiness diagnostics, temporary owner identification, scrollable narrow-window timeline controls, protected portable demo, help/welcome/About and app icon. **269 correctness tests passed in Debug and Release**, zero failures and zero runtime warnings; four opt-in benchmarks skipped and two legacy visible-window checks excluded. See [verification](V1.15_VERIFICATION.md) and [V1 guide](V1_USER_GUIDE.md).

V1 delivery record: signed app was installed at app/ProjectionMapper.app and archived in builds/v1.15/. Previous installed v1.14 preserved at builds/v1.15/Previous-installed.app. Full V1 ZIP, checksum and install/usage notes prepared. Packaged/installed files match the tested Release product; architecture and strict signature checks passed. No screen control or app launch used. User visual/listening acceptance is pending, including actual audio routing/device loss and perceived sync/pitch. Runtime tests used Apple Silicon/macOS 27; Intel/older-macOS execution and physical projector output remain unverified. Developer ID/notarization have not been established; the app is locally ad-hoc signed.

v1.14 source is already confirmed on GitHub at **ccb5df2** with delivery record **29ad795**. v1.15 tested source was successfully committed and pushed to GitHub main at **60e838d**, fast-forwarded from 29ad795; the full v1.15 release is now published with its annotated tag and four verified downloadable assets. V1 implementation is finished; user visual/listening acceptance remains pending. Repository visibility stays private. **v2.01 is locally implemented as recorded above.** Physical projector acceptance remains pending.

## GitHub version history

Private repository: https://github.com/Chosencode25/projection-mapper. The initial source snapshot is v1.01; its release notes are in releases/v1.01.md. Follow GITHUB_WORKFLOW.md for future milestone history.

## v1.02 implementation

- [x] Shared toolbar/inspector destination selection and Test Window default.
- [x] AppKit/Core Graphics display snapshots, names, UUIDs, metadata, mirroring and editor-screen eligibility.
- [x] App-owned coalesced discovery with screen changes, activation, wake, and manual refresh.
- [x] Explicit preference persistence, startup restoration, safe fallback, and reconnect without automatic switching.
- [x] Aspect-aware empty canvas, output details/status, scrollable inspector, version 1.02/build 2.
- [x] Sixteen focused output tests plus the existing five session tests passed.
- [x] No-external-display runtime, project reset protections, packaged app, About, panel shortcut, and synthetic minimum-size portrait/long-name layout checks.
- [x] Build and signature verification; preview ZIP and checksum published in the private v1.02-preview.1 prerelease.
- [ ] Deferred: physical extended-display metadata, unplug/reconnect, saved external preference relaunch, mirroring, editor movement, scaling/rotation.
- [ ] Final v1.02 hardware acceptance remains deferred. Its preview tag/assets are preserved while Test Mode development proceeds.

The plan is [V1.02_PLAN.md](V1.02_PLAN.md). Current verification is [V1.02_VERIFICATION.md](V1.02_VERIFICATION.md). Preview notes are [releases/v1.02-preview.1.md](releases/v1.02-preview.1.md).

## v1.03.1 implementation

- [x] One app-owned observable Test Output window; normal native controls and plain black content.
- [x] Toolbar/inspector/Window menu open/close actions and shared open/closed status.
- [x] Duplicate prevention, minimize restoration, native close/reopen, external destination guard.
- [x] Project reset independent of output; successful editor close/quit cleanup, Cancel preserving both windows.
- [x] Seven focused AppKit window tests plus all 21 regressions passed.
- [x] Local runtime checks and pinned-Xcode Release build/signature verification.
- [x] Published v1.03.1 app/checksum and advanced main to the accepted Test Mode milestone.

Plan: [V1.03.1_PLAN.md](V1.03.1_PLAN.md). Verification: [V1.03.1_VERIFICATION.md](V1.03.1_VERIFICATION.md).

## Version-history preference — October 5, 2026

Small changes are preserved by commits pushed to the private repository. Full releases, version bumps, tags, and downloadable archives are reserved for substantial milestones or explicit requests. Existing published versions remain preserved. This workflow-only update requires no app build.

## v1.03.2 implementation

- [x] HD, Full HD, 4:3, Portrait, and 4K presets in the Test Window inspector.
- [x] Resolution preference saved separately from project data; HD default and invalid-value fallback.
- [x] Editor preview/details and existing output window update immediately without changing the window size or project state.
- [x] Centered aspect-preserving black output surface and black margins; native window resizing preserves simulated resolution.
- [x] All 31 tests passed with the pinned Xcode toolchain, including preset persistence, fitted geometry, live window updates, resizing, reset, and session restoration.
- [x] Native runtime checks: Portrait/Full HD selection, minimized output restoration, live window title/canvas metadata, and relaunch restoring Full HD with output closed.
- [x] Tested Debug app copied to builds/v1.03.2/ProjectionMapper.app and its signature verified.

Plan: [V1.03.2_PLAN.md](V1.03.2_PLAN.md). Test evidence: builds/v1.03.2/test.log and Tests.xcresult (local, excluded from Git). This is a source-history update; no version bump, tag, archive, or release. Bundle version remains the last published v1.03.1/build 3. Rendering remains scheduled for v1.04; window geometry persistence/navigation for v1.03.3.

## v1.03.3 implementation

- [x] Normal Test Output frame saved on move/resize/close, separately from project state and simulated resolution.
- [x] Reopen and new-coordinator restoration; launch remains closed.
- [x] Invalid stored values fall back to the default window; offscreen and oversized frames fit a current screen's visible area. Multi-screen selection, removed-screen recovery, and minimum dimensions verified with synthetic screen frames.
- [x] Show Output naming throughout toolbar/inspector/menu; Control–Command–O shows/restores output and Control–Command–E raises the editor.
- [x] Minimize and zoom preserve the normal saved frame. Zoom transition event ordering is guarded; fullscreen transitions use the same guard.
- [x] All 35 tests passed with Xcode 27.0 beta 5 (27A5237l), including native AppKit move/resize callbacks, close/reopen, new-coordinator restoration, minimize/show, zoom/close restoration, preference validation, and existing regressions.
- [x] Native running-app checks confirmed both new shortcuts, minimized-output restoration, consistent controls, panel shortcuts, and closed startup with the existing 4K preference preserved.
- [x] Refreshed builds/v1.03.3/ProjectionMapper.app from the tested Debug build and verified its signature.

Plan: [V1.03.3_PLAN.md](V1.03.3_PLAN.md). Final evidence: builds/v1.03.3/test.log and Tests-zoom-fix.xcresult (local, excluded from Git). Native pointer-driven move/resize checks were inconclusive in the automation surface; actual NSWindow frame changes and restoration passed the AppKit tests. Fullscreen animation and physical display removal have not been runtime-tested. Earlier minimum-layout checks remain applicable; no editor layout structure changed. The fitted output surface needs no further restructuring before v1.04. No version bump, tag, archive, or release; the bundle remains v1.03.1/build 3.

## v1.04 planning — October 5, 2026

The five-slice renderer breakdown and completion criteria are saved in [V1.04_PLAN.md](V1.04_PLAN.md), individual slice plans, and the roadmap. Relative milestone difficulty estimates are recorded in the roadmap as subjective estimates. This documentation update changes no app behavior; the latest verified app remains v1.03.3 with 35 passing tests.

- [x] v1.04.1 — Metal Foundation (implemented and locally verified).
- [x] v1.04.2 — First Rectangle (implemented and locally accepted).
- [ ] v1.04.3 — Shared Editor Preview.
- [ ] v1.04.4 — Rendering Lifecycle.
- [ ] v1.04.5 — Performance and Acceptance.

v1.04.1 is implemented and locally verified; the other four remain planned. Test and push each completed slice; no automatic release/tag/version bump. Physical projector implementation/reconnect checks remain deferred.

## v1.04.1 implementation

- [x] Independent Metal renderer initializes the device/command queue and clears the fitted Test Output surface to a fixed blue diagnostic color.
- [x] On-demand MTKView drawing; simulated resolution remains independent of native drawable size. Existing black margins, preferences, window ownership, and navigation are preserved.
- [x] App-visible initialization error text with injected device/queue failure verification.
- [x] All 38 tests pass with the exact pinned toolchain, including actual GPU texture readback and native Metal window preset/resize/close/reopen checks.
- [x] Running-app checks confirmed visible output and margins at 4K and Portrait, live resolution changes, close/reopen, minimize/restore, and both navigation shortcuts. Original 4K preference restored.
- [x] Tested Debug app copied to builds/v1.04.1/ProjectionMapper.app; ad-hoc signature verified.

Plan: [V1.04.1_PLAN.md](V1.04.1_PLAN.md). Verification: [V1.04.1_VERIFICATION.md](V1.04.1_VERIFICATION.md). No frame-rate/4K-performance claim; actual performance measurement is v1.04.5. The rectangle and shared editor preview remain planned. No bundle version bump, tag, archive, or release.

## v1.04.2 development — steps 1–2

On `codex/v1.04.2-first-rectangle`, based on tested v1.04.1 commit `ba34723`. Exact Xcode build reverified. Apple Metal Toolchain component **27A5237l** installed for shader compilation.

- [x] Step 1: verify toolchain and create feature branch from tested main.
- [x] Step 2: compiled vertex/fragment shaders and initialized BGRA8 render pipeline, with visible library/function/pipeline errors. All **40 tests pass**, including actual shader GPU pixel readback and injected failure handling.
- [ ] Steps 3–7: rectangle drawing, normalized scene geometry, sizing integration, full acceptance, and advancement of tested main.

The running output remains the v1.04.1 blue diagnostic clear; shader/pipeline creation is ready for step 3. `main` remains the completed v1.04.1 milestone. Interim tested app: `builds/v1.04.2/step2/ProjectionMapper.app`. Evidence: [V1.04.2_VERIFICATION.md](V1.04.2_VERIFICATION.md). This is partial feature-branch work, not completed v1.04.2 acceptance. No release/tag/version bump.

## v1.04.2 development — step 3

- [x] Draw a temporary orange rectangle on black using the compiled Metal pipeline and two triangles. Temporary clip-space vertices precede normalized scene storage in step 4.
- [x] All 40 tests pass with the exact pinned Xcode, including every-pixel GPU rectangle/background verification and existing native window/preset regressions.
- [x] Running step-3 app visibly draws the rectangle at Full HD and after native close/reopen. Signature verified; local app is `builds/v1.04.2/step3/ProjectionMapper.app`.
- [ ] Steps 4–7 and full v1.04.2 acceptance remain pending; main remains v1.04.1. Work preserved on the feature branch without release/tag/bundle bump.

Latest feature-branch output is now the rectangle rather than the step-2 diagnostic clear. See [V1.04.2_VERIFICATION.md](V1.04.2_VERIFICATION.md).

## v1.04.2 development — step 4

- [x] Four immutable normalized scene corners with top-left origin, converted to Metal clip positions and two triangles at render time.
- [x] All 42 tests pass with pinned Xcode, including off-center GPU pixel checks, coordinate extents/center, and stored geometry unchanged through preset/window changes.
- [x] Running app confirms the centered rectangle retains its appearance. Local signed/tested app: `builds/v1.04.2/step4/ProjectionMapper.app`.
- [ ] Steps 5–7 remain pending; full v1.04.2 acceptance and advancement of main have not occurred.

Latest feature-branch geometry now uses normalized corners; the step-3 appearance is preserved. See [V1.04.2_VERIFICATION.md](V1.04.2_VERIFICATION.md). Intermediate work is saved on the feature branch without release/tag/version bump.

## v1.04.2 development — step 5

- [x] Record step-5 plan before implementation; explicitly enable automatic native drawable resizing. Existing aspect fitting required no fix.
- [x] All 43 tests pass: live five-preset switching in wide/tall/square native windows, actual backing drawable dimensions, window/geometry preservation, and GPU coverage across landscape/4:3/portrait shapes.
- [x] Running app checked 4K, Portrait, and 4:3 fitting; original 4K preference restored and output closed. Signed/tested local app: `builds/v1.04.2/step5/ProjectionMapper.app`.
- [ ] Steps 6–7 remain pending; full v1.04.2 acceptance and advancement of main have not occurred.

Simulated target resolution remains independent of drawable pixel dimensions. See [V1.04.2_VERIFICATION.md](V1.04.2_VERIFICATION.md). This feature-branch checkpoint has no release/tag/version bump.

## v1.04.2 development — step 6

- [x] Local rectangle acceptance passed: all five presets visually checked; running minimize/restore and native close/reopen redraw confirmed.
- [x] Reviewed unchanged implementation and its complete 43-test passing run for GPU geometry/pixels, failure handling, native wide/tall/square windows, and existing regressions. Required Xcode build rechecked; strict app signature verified.
- [ ] Step 7 delivery/main advancement remains pending. Main still contains completed v1.04.1; accepted feature implementation remains at `0ddacc1` with documentation checkpoints on the feature branch.

No app change or repeated test run was needed in this acceptance-only step. Tested app remains `builds/v1.04.2/step5/ProjectionMapper.app`. See [acceptance record](V1.04.2_VERIFICATION.md). Original 4K preference restored and output closed; no release/tag/version bump.

## v1.04.2 delivery — step 7

All seven steps are complete. The user explicitly requested a release during delivery, superseding the earlier source-only checkpoint plan. Bundle advanced to v1.04.2/build 4; all 43 Release tests passed with pinned Xcode. Signed Apple Silicon Release app copied to `builds/v1.04.2/ProjectionMapper.app`, runtime rendering/version checked, and ZIP/checksum prepared. Feature source is finalized for main and the v1.04.2 development prerelease; see [release notes](releases/v1.04.2.md). Earlier step entries are historical checkpoints.

Publication verified: non-draft development prerelease at [v1.04.2](https://github.com/Chosencode25/projection-mapper/releases/tag/v1.04.2), tag fixed at tested source `afd2440`. Both app ZIP and checksum assets report uploaded; GitHub archive digest matches the local SHA-256. Main advanced to tested source, with this subsequent documentation confirmation. Next: v1.04.3 Shared Editor Preview. Performance measurements and projector implementation remain deferred.


## v1.04.3 implementation

- [x] Session-owned immutable RenderScene contains normalized geometry and color; both views receive it.
- [x] Reusable MetalSceneView supports editor preview and Test Output with separate renderers/drawables, the same pipeline implementation, and aspect fitting.
- [x] Replaced the empty canvas with rendered content; editor caption/border stay outside clean output.
- [x] All 44 Debug tests pass, including hosted SwiftUI/AppKit preview and GPU pixel checks from both renderers with an injected green scene across all five presets.
- [x] Running app checked matching 4K/Portrait content, panel toggles, New Project, and preview with output closed. Restored 4K and both panels.
- [x] Tested Debug app copied to builds/v1.04.3/ProjectionMapper.app and strict signature verified.

Source delivery through codex/v1.04.3-shared-preview into main; no new release/tag/archive or bundle bump. Evidence: [V1.04.3_VERIFICATION.md](V1.04.3_VERIFICATION.md). Next: v1.04.4 Rendering Lifecycle; lifecycle stress and performance acceptance remain planned.


## v1.04.4 implementation

- [x] Gate on-demand drawing by attachment, visibility/occlusion, minimization, hiding, and valid surface size; re-invalidate when eligible.
- [x] Stop/release output drawables and detach content/delegate on close; clear editor hosting content on close/termination.
- [x] Add injectable presentation so automated window checks do not appear on the user's desktop.
- [x] Six new lifecycle/GPU/resource tests; 48 automated Debug tests passed, with two visible-window checks excluded.
- [x] Preserve separate editor/output rendering and verify weak view/renderer deallocation over 20 output cycles.
- [x] Deliver signed local Debug app in builds/v1.04.4/ and, as requested, app/ProjectionMapper.app; commit/push tested source into main without release/tag/version bump.
- [ ] Interactive minimize/restore, occlusion wakeup, navigation, backing transitions, and quit acceptance: not performed because the user prohibited onscreen app use.

Evidence and exclusions: [V1.04.4_VERIFICATION.md](V1.04.4_VERIFICATION.md). v1.04.5 performance/final acceptance remains planned.


## v1.04.4 onscreen follow-up

- [x] User authorized the two previously deferred onscreen tests; both passed with the pinned Xcode.
- [x] Verified native minimize/restore/zoom/frame persistence and native drawable dimensions across five presets, window shapes, and close/reopen.
- [x] Updated the drawable test’s obsolete always-enabled assumption to honor actual occlusion eligibility; narrowed observer cleanup to lifecycle notification names.
- [x] Remaining 48 headless regressions passed again; all 50 tests passed across the two runs. Refreshed signed app copies and saved changes to GitHub.
- [ ] Broader visible-frame occlusion wakeup, backing-scale transitions, editor navigation, and quit acceptance remain pending.

Evidence: [V1.04.4_VERIFICATION.md](V1.04.4_VERIFICATION.md). Previous exclusions above describe the original file-only delivery.


## v1.04.5 detailed planning

Expanded [V1.04.5_PLAN.md](V1.04.5_PLAN.md) into seven implementation/delivery steps with exact texture sizes, sampling counts, lifecycle stress workloads, measurement limits, and acceptance criteria. Plan only: no renderer changes, new build, or performance results. Preserve the user's file-only workflow; broader visual checks require user participation or specific authorization.


## v1.04.5 implementation and acceptance

- [x] Add optional bounded diagnostics, default off, without continuous production drawing.
- [x] Four new regular correctness tests; all 54 regular tests passed in Debug and Release. Three benchmarks are opt-in (57 declarations total).
- [x] Measure all five exact texture resolutions, one/two-view queues: 9,000 samples with GPU status and representative pixels verified.
- [x] Verify 30 native drawable records and zero submissions in five settled occluded idle states. Actual Release app idle samples supplement counters.
- [x] 150 window/view cycles and 15,000 preset changes release weak ownership; peak RSS stable across three batches.
- [x] 100 synthetic request-to-GPU completions passed; distinguish synthetic timing from OS restoration and display presentation.
- [x] Complete authorized actual-app restore/occlusion, shortcuts/panels, compact/larger portrait layouts, reset/close/quit protection and final process cleanup.
- [x] Deliver signed Release app copies and preserve source on GitHub; no bundle bump, tag, archive or release.
- [ ] Deferred: backing-scale transitions, projector/external-display physical acceptance, Intel and older macOS runtime checks.

All seven planned steps are complete for local Test Mode. Earlier entries describe historical checkpoints. Evidence: [V1.04.5_VERIFICATION.md](V1.04.5_VERIFICATION.md). Next: v1.05 First Surface.


## v1.05 implementation and acceptance

- [x] Read requirements and record [V1.05_PLAN.md](V1.05_PLAN.md); verify pinned Xcode and create feature branch from tested main.
- [x] Add project-owned MappingSurface with identity/name/four normalized corners/fill.
- [x] Derive and refresh shared render snapshots, including reset of existing preview/output.
- [x] One sidebar row with selection/deselection; inspector shows selected surface and corners.
- [x] Six new focused tests; headless and complete Debug regressions pass.
- [x] Complete Debug/Release runs: all 60 correctness tests passed (63 declarations including three skipped optional benchmarks).
- [x] Final actual-app selection/corners/portrait/output/reopen/New Project Cancel and Discard checks passed.
- [x] Signed Release app copied to builds/v1.05/ and app/ProjectionMapper.app; tested source preserved on GitHub without release/tag/bundle bump.

Evidence: [V1.05_VERIFICATION.md](V1.05_VERIFICATION.md). All seven steps are complete. Next: v1.06 Corner Nodes.


## v1.06 implementation and acceptance

- [x] Record [five-step plan](V1.06_PLAN.md), verify exact toolchain, branch from tested v1.05.
- [x] Editor-only outline/handles and active corner highlight.
- [x] Fitted coordinate conversion, clamped drag with grab offset, live shared renderer updates.
- [x] Native focus routing, arrows/Shift nudges, Escape and inspector/dirty/reset integration.
- [x] Eight focused new tests; 66 headless correctness tests passed.
- [x] Complete Debug/Release: 68 correctness tests passed; three optional benchmarks skipped (71 declarations total).
- [x] Actual-app landscape/portrait drag, normal/Shift nudge, Escape, field-focus isolation, clean output and geometry-only reset protection passed.
- [x] Signed app copies delivered and tested source saved to GitHub without release/tag/bundle bump.

All five steps complete; evidence: [V1.06_VERIFICATION.md](V1.06_VERIFICATION.md). Next: v1.07 Perspective Warp.


## v1.07 implementation and acceptance

- [x] Record five-step plan, verify pinned Xcode and branch from tested v1.06.
- [x] Diagnostic texture with mipmaps and corner orientation markers; solid fill option.
- [x] Validated projective transform, shared snapshots and seamless Metal texture mapping.
- [x] Invalid geometry clears safely; editor warning and overlapping-corner recovery.
- [x] Initial headless correctness/GPU checks pass.
- [x] Complete Debug/Release: 79 correctness tests passed; three optional benchmarks skipped (82 declarations).
- [x] Vital warp/clean-output/invalid/recovery/content/portrait/reset visual checks; fixed warning-induced canvas shift and added regression coverage.
- [x] Signed Release app copies and GitHub delivery; no release/tag/version bump.

All five steps complete; evidence: [V1.07_VERIFICATION.md](V1.07_VERIFICATION.md). Next active milestone: v1.08 Multiple Surfaces. Remaining milestones were reordered and renumbered; image/video import now follows core tools at v1.13/v1.14.


## Earlier roadmap scope update — October 5, 2026 (superseded below)

- Defer custom image import (v1.08) and custom video import (v1.09) at the user’s request.
- Preserve their milestone numbers and future scope. Next active milestone is v1.10 Built-In Animations.
- Planning update only: no app/source changes, new tests, build, version bump or release. v1.07 remains the latest accepted app.


## Remaining roadmap reordered — October 5, 2026

Approved sequence: v1.08 Multiple Surfaces → v1.09 Built-In Animations → v1.10 Save & Load → v1.11 Surface Controls → v1.12 Mapping Tools → v1.13 Images → v1.14 Video → v1.15 Polish & Release, including final upload. See [roadmap and old/new number mapping](V1_ROADMAP.md).

Completed milestones and historical acceptance records retain their original numbers. Saving will initially cover surfaces, generators and output settings, then gain later settings/media as those features arrive. Projector hardware work remains separately deferred. Planning-only update: no app rebuild, feature implementation, version bump or release. The existing v1.07 app’s historical saving-version label will be brought into line when next modifying the interface.


## Remaining milestone steps — October 5, 2026

Expanded all eight reordered milestones into [ordered implementation and verification steps](V1_REMAINING_PLAN.md), including collection/renderer migration, shared animation timing, early saving and later schema/media extensions, surface controls, calibration/blackout, image/video resources, and final undo/redo/packaging/upload. Planning only: no feature implementation, app changes, builds, tests or publication. Next implementation remains v1.08 Multiple Surfaces.

## Connected object faces planned — October 5, 2026

User approved adding object grouping and continuous content across faces to the whole plan. Updated development requirements, roadmap and every remaining milestone in [the detailed plan](V1_REMAINING_PLAN.md): v1.08 adds object membership/shared input maps/manual edge alignment; v1.09 adds shared generators and cross-face motion; v1.10 saves that structure; v1.11–v1.15 cover scoped controls, continuity diagnostics, shared image/video ownership, undo/redo, demo and final acceptance. Continuous and Repeat modes are explicit; standalone/detached faces remain supported. Manual flat layouts can contain deliberate seams; full 3D reconstruction is future scope.

Documentation-only update: reviewed scope/dependencies and checked the diff; no app code, build, screen use, feature implementation, version bump or release. v1.07 remains the latest accepted app.

## V1 foundations updated and V2 planned — October 5, 2026

User requested adjusting all V1 planning and planning V2 following research into mapping/sequencing/show-control software. Updated the remaining steps, roadmap, development requirements and source README future-scope links. V1 retains its approved order and adds layout/content separation and tags (1.08), deterministic time/seek and generator presets (1.09), migration contracts (1.10), reusable looks/palettes and master brightness/fades (1.11), basic polygon masks (1.12), editor-only house photo (1.13), explicit video-audio routing and requested-time playback (1.14), and readiness/full regression coverage (1.15).

Created [V2 roadmap](V2_ROADMAP.md) and [ordered implementation/acceptance plan](V2_IMPLEMENTATION_PLAN.md): 2.01 projector output/calibration, 2.02 music transport, 2.03 timeline/cues, 2.04 holiday choreography, 2.05 layers/regions/text, 2.06 reusable shows/layouts, 2.07 external synchronization/lighting integration, 2.08 Show Mode/readiness, 2.09 playlists/schedules, 2.10 local remote control, 2.11 export/portable delivery, 2.12 acceptance/release. Includes dependency gates, migration/seek/resource rules, research links and a prioritized later-feature backlog. Integration is conditional on a verified workflow and measured device versions, not assumed full xLights/FPP format support.

Physical hardware remains deferred; v2.01 now provides its future implementation/acceptance stage. V1 is accepted/published as Test Mode scope only until those capabilities are actually delivered. Planning changes only: reviewed document consistency, numbered stages and links; no feature implementation, app build, screen use, version bump, tag or release. v1.07 remains the latest accepted app.

## Git/GitHub delivery cadence changed — October 5, 2026

User requested Git/GitHub activity only when a new app version at the x.xx level is completed. Recorded this as no intermediate commits, pushes, tags or GitHub uploads for planning changes, small fixes or x.xx.x slices unless the user explicitly requests an exception. Read-only Git checks/local branch setup remain available; do not bump a version to create an upload boundary. Eligible milestone delivery does not automatically publish a release. Updated AGENTS.md, workflow and active plan delivery rules locally. These policy edits are intentionally uncommitted/unpushed until the next eligible milestone. Existing history remains intact.

## Known GitHub state preference — October 5, 2026

User states this agent is the sole GitHub writer and requests avoiding redundant remote inspection of known work. Updated local instructions/workflow to rely on local history and the last confirmed remote state, using remote checks only for unknown information, reported problems, evidence of outside changes or explicit requests. Successful delivery output is sufficient confirmation. Policy updates remain local under the x.xx-only delivery rule; no commit/push/upload or remote inspection performed.


## v1.08 implementation — local delivery

- [x] All twelve milestone steps implemented: ordered faces, stable layout/source/object IDs, tags, ownership, grouping, input maps/links, add/select/rename/duplicate/delete, visibility/order, dirty/reset behavior and shared collection rendering.
- [x] Seventeen new focused model/GPU tests; 96 correctness tests passed in both configurations (99 declarations including three skipped opt-in benchmarks).
- [x] Vital actual-app checks passed for independent warped faces, Continuous/Repeat, clean 4K output, face/object hiding, tags, object duplicate/delete, appearance-preserving ungrouping, empty black output and Cancel/Discard reset.
- [x] Version 1.08/build 5 universal Release copies installed locally and signatures verified; previous installed build preserved.
- [x] Local feature branch codex/v1.08-multiple-surfaces; source/documentation intentionally uncommitted and unpushed under this delivery's explicit exception.

## v1.08 local follow-up — canvas face selection

Clicking a rendered face in the editor selects its inspector/sidebar row, choosing the frontmost visible valid face when shapes overlap. Empty canvas deselects; selected corner handles keep drag priority. Picking works when no face or an object was previously selected, without dirtying the project. Required Xcode 27.0 beta 5 (27A5237l) reverified. Full Release suite passed 97 correctness tests (100 declarations including three skipped benchmarks), and focused native input/drag tests passed after adding native click/margin assertions. Logs: builds/v1.08/ClickSelection.log and ClickRouting.log. Refreshed signed Release copies in builds/v1.08/ and app/ProjectionMapper.app. No version bump, commit or GitHub upload. No additional manual screen session was needed for this follow-up.

## v1.09.1 implementation — local preview delivered

Shared elapsed-time transport, Play/Pause/Restart/speed, animated gradient/moving lines/checkers and two-color editing are implemented. Static/paused views retain on-demand rendering; eligible playing views use native display scheduling and resume at the shared phase. Full Debug and Release suites passed 102 correctness tests (105 declarations, three opt-in benchmarks skipped). Universal signed Release copies installed in builds/v1.09.1/ and app/ProjectionMapper.app; prior installed app preserved. Bundle remains 1.08/build 5 for this intermediate slice. Work is local with no GitHub delivery.

Vital screen playback acceptance is pending: the Mac was locked and automatic unlock failed. No manual motion/controls pass is claimed. See [verification](V1.09.1_VERIFICATION.md) and [three-slice plan](V1.09_PLAN.md). v1.08 remains the last milestone with complete local visual acceptance; the installed app now includes the automatically verified v1.09.1 preview. v1.09.2/.3 remain planned.

## Visual checks and v1.09.2 — current work

The user confirmed v1.09.1 visual playback checks worked. v1.09.1 is now accepted with user-reported visual evidence. They will perform routine visual checks until changing this preference; no screen control for routine acceptance. v1.09.2 effects/settings are implemented; automated correctness/performance verification and local delivery are in progress. v1.09.3 remains planned; no GitHub delivery for these slices.

## v1.09.2 — local delivery

- [x] Plasma, seeded animated value noise and analytic seeded particle field; existing gradient/lines/checkers gain effect settings.
- [x] Bounded owner settings and relevant-only controls; shared source edits preserve corners, input maps and global runtime transport.
- [x] 105 correctness tests pass in both configurations; new boundary/seed/limits/isolation tests plus expanded all-effect deterministic three-face GPU checks.
- [x] Separate opt-in Release mixed-effect matrix across all presets: six faces per view, two views, 20 measured pairs per preset; 4K GPU pair p95 1.6783 ms (workload timing, not visible FPS).
- [x] Universal ad-hoc signed app installed locally; previous installed app preserved. No source commit/upload or bundle bump.
- [ ] User visual check of new effects/settings; no routine screen control performed by the agent.

## v1.09.3 — local delivery

- [x] Bounded project-owned presets, save/apply/update/delete/reset, preserving mapping and runtime phase.
- [x] Global bounded seeking/scrubbing and elapsed readout; source-scoped pause/resume/restart with duplicate/detach/cleanup policies.
- [x] All 111 correctness tests passed in final Debug/Release runs, including backward loop replay, preset isolation, scope and reversed particle continuity.
- [x] Mixed/overlap profiling across all presets: 4K pair p95 2.1578 ms mixed; 44.5873 ms for eight overlapping particle faces per view. Heavy 4K overlap does not meet a 60 Hz two-view budget.
- [x] Universal signed app installed locally, previous app preserved. No screen control or GitHub delivery.
- [ ] User visual acceptance of v1.09.2/.3; full milestone version/history delivery pending.

## v1.09 GitHub delivery — authorized

The user explicitly requested saving v1.09 to GitHub before implementing v1.10 locally. The version is now 1.09/build 6. Final 111-test source and accumulated multiple-surface/animation work will be preserved on tested main; no release/tag/asset publication requested. v1.10 must remain off GitHub. Routine visuals continue to belong to the user.

## v1.10 local delivery

- [x] Versioned validated project packages and stable declarative data/IDs.
- [x] Atomic Save/Save As, asset-copy preservation, Open and bounded recents.
- [x] Saved baselines and Save/Discard/Cancel for New/Open/Close/Quit.
- [x] Debounced untitled/saved recovery, ten-copy retention and restore/later/delete.
- [x] Full Debug/Release suite: 128 correctness tests, four skipped opt-in benchmarks.
- [x] Universal ad-hoc signed 1.10/build 7 product in builds/v1.10/ and app/ProjectionMapper.app; prior installed app preserved.
- [ ] User native panel/lifecycle/recovery and visual round-trip acceptance.
- v1.10 source backup successfully pushed to main at 55d242c; no release/tag/assets. Next: v1.11.1 appearance/crop/flip.

## v1.11.1 local preview delivery

- [x] Bounded opacity, brightness, crop and flips, shared preview/output calculations.
- [x] Object inheritance and explicit face overrides; grouping/copy/detach policies and join diagnostics.
- [x] Schema 3, schema 1/2 default migration, saved baselines and recovery support.
- [x] 138 Debug/Release correctness tests; four optional benchmarks skipped.
- [x] Universal signed local app in builds/v1.11.1/ and app/; previous installed app preserved. Bundle stays 1.10/build 7.
- [ ] User appearance/override/save-reopen visual checks.
- Preview remains unstaged/uncommitted/off GitHub. Next: v1.11.2 locks, group movement and scoped resets.

## v1.11.2 local preview delivery

- [x] Persistent face/object output-geometry locks; preserved individual locks, protected manipulation/deletion and reachable unlock.
- [x] Bounded group translation through native center dragging, focused arrows and inspector controls; any member lock blocks the whole move.
- [x] Scoped face/object resets, explicit full-face/input-layout confirmations, identity/layout/link/clock preservation.
- [x] Schema 4 lock persistence with schema 1–3 migration; dirty baselines/save/recovery verification.
- [x] 150 Debug/Release correctness tests; four optional benchmarks skipped. Native event and GPU movement/reset regressions pass.
- [x] Universal signed local app in builds/v1.11.2/ and app/; previous preview preserved. Bundle stays 1.10/build 7.
- [ ] User visual locks/movement/reset/save-reopen checks.
- Intermediate slices remain unstaged/uncommitted/off GitHub. Next: v1.11.3 looks, palettes and master brightness/fade/blackout.

## v1.11.3 detailed planning — October 6, 2026

- [x] Defined the [seven-step implementation plan](V1.11.3_PLAN.md): schema/models, palettes, looks, runtime master controls, renderer/UI integration, full verification and milestone delivery.
- [x] Specified target compatibility, palette-reference materialization, mapping/lock preservation, independent fade timing and blackout/restore semantics.
- [ ] Implement and verify v1.11.3; user visual acceptance remains pending.
- Planning only: no app/source changes, builds, version bump, commits, pushes or GitHub uploads. Installed app remains the automatically verified v1.11.2 preview.

## v1.11.3 implementation in progress — October 6, 2026

- [x] Implemented looks, palettes, schema 5 migrations, saved master settings, playback-independent fades and immediate blackout/restore.
- [x] Initial integrated Debug run passed 178 correctness tests; four optional benchmarks skipped.
- [ ] Complete final v1.11/build 8 Debug/Release checks, deliver the tested app and perform eligible milestone source backup.
- Routine visuals remain user-performed and pending. No screen control or release publication. Current installed preview remains v1.11.2 until final delivery.

## v1.11 completed local milestone — October 6, 2026

- [x] Implemented all three Surface Controls slices, including reusable looks/palettes and persistent master output configuration with temporary fades/blackout.
- [x] Reverified Xcode 27.0 beta 5 (27A5237l); all 184 correctness tests passed in final Debug/Release runs. Four optional benchmarks skipped.
- [x] Delivered 1.11/build 8 universal locally signed app to app/ and builds/v1.11/; previous installed preview preserved; all tested-product file hashes match.
- [x] Updated schema 5 migration/save/recovery, documentation and [verification evidence](V1.11.3_VERIFICATION.md).
- [x] Completed eligible milestone Git source delivery: main fast-forwarded and successfully pushed from 55d242c to **87459a8**. No release/tag/assets requested or published.
- [ ] User visual acceptance: look recall, palettes, fade/blackout and prior appearance/locks/movement/reset checks. No new acceptance has been reported; no screen control used.
- Next: v1.12 calibration tools and basic face-local polygon masks, extending the existing global output controls.

Milestone source delivery confirmed October 6, 2026 by successful push output; no routine GitHub browse/fetch was needed. A documentation-only delivery record follows the tested source commit.

## v1.12.1 planning — October 7, 2026

- [x] Wrote the [three-slice v1.12 plan](V1.12_PLAN.md) and [detailed calibration contract](V1.12.1_PLAN.md).
- [x] Defined mapped-face scope, pattern coordinates, temporary appearance bypass, existing master/blackout priority, playback/idle behavior and acceptance checks.
- [ ] Implement/verify/deliver 1.12.1 locally; masks and editor/join tools remain later slices.
- Planning changes remain local. Installed app is still v1.11/build 8; no new visual acceptance has been reported.

## v1.12.1 implementation in progress — October 7, 2026

- [x] Implemented session-only calibration patterns/settings, shared shader/snapshot integration, controls and fade-aware idle scheduling.
- [x] Added eighteen correctness checks for calibration state, lifecycle/persistence isolation, GPU patterns/joins/appearance bypass/master priority and unshown native scheduling/output reopen.
- [ ] Finish final Debug/Release checks and deliver the verified local app; [verification draft](V1.12.1_VERIFICATION.md).
- No version bump, commit/push, release or screen control. Installed app remains v1.11 until tested replacement.

## v1.12.1 verified local delivery — October 7, 2026

- [x] Implemented calibration from the detailed plan; saved project schema remains 5 and runtime-only controls do not dirty/save/recover.
- [x] Exact Xcode 27.0 beta 5 (27A5237l) checked; final Debug/Release each passed 202 correctness tests, zero failures, four optional benchmarks skipped.
- [x] Delivered universal locally signed preview to app/ and builds/v1.12.1/; previous app preserved and all tested-product hashes match.
- [x] Recorded actual evidence in [verification](V1.12.1_VERIFICATION.md); updated plans/changelog/build instructions.
- [ ] User calibration visuals and prior v1.11 checks remain pending. No screen control or app launch used.
- Bundle stays 1.11/build 8; HEAD remains 03c9a45. No intermediate commits/pushes/tags/releases/assets.
- Next: 1.12.2 face-local polygon masks and cutout holes, including saved migrations and fail-closed clipping under calibration.

## v1.12.2 local masks and cutouts — October 7, 2026

- [x] Face-owned boundary and holes with bounded coordinates, concavity/winding support, intersection/containment validation and recoverable invalid-mask suppression.
- [x] Editor/inspector drawing, handle dragging, point insertion/deletion/numeric edits, enable/disable/remove and invalid-geometry local fallback.
- [x] Shared Metal clipping before every normal/calibration branch; cache bounded ring/point data and preserve output layering, sampling, fades and clocks.
- [x] Format 6 migration/save/recovery/dirty state; masks preserved by membership changes, duplicates, looks and scoped resets.
- [x] 217 correctness checks passed in each final Debug/Release run; four benchmarks skipped, two visible-window checks excluded. Exact Xcode 27A5237l; strict signing/universal slices and complete file hashes verified.
- [x] Tested app delivered locally, previous preview preserved, no intermediate commit/upload. Bundle 1.11/build 8.
- [ ] User mask/calibration visual acceptance; see [verification](V1.12.2_VERIFICATION.md).
- [ ] v1.12.3 editor visibility/labels, join inspection and full milestone verification/delivery.

## v1.12.3 and full v1.12 delivery — October 7, 2026

- [x] Session-only corner/object/mask handle and outline controls, optional names/edge labels, toolbar/menu access and shortcuts with safe reset defaults.
- [x] Cancel hidden-handle drag/key manipulation while preserving picking and typing focus; labels stay out of clean output and saved state.
- [x] Shared-canvas vertical/horizontal stripes and checker join inspection, projected traversal arrows and seam/mismatch status, preserving geometry/maps/content/clocks/masks.
- [x] 225 offscreen correctness checks passed in Debug/Release; four benchmarks skipped, two visible-window tests excluded. Exact Xcode 27A5237l, universal slices, strict signing and complete file hashes verified.
- [x] Bundle 1.12/build 9 delivered to app/ and builds/v1.12/; previous preview preserved.
- [x] Completed milestone source backup successfully pushed to main/GitHub at b786f55, preserving earlier history.
- [ ] User mapping-tools visual acceptance. See [verification](V1.12.3_VERIFICATION.md).

Next planned build: v1.13 Image Import. No release publication requested.


## Local v1.12 UI usability polish — October 7, 2026

- [x] Reviewed and used the running app via Computer Use at the user's explicit request; preserved the user's unsaved mapping before review.
- [x] Focused Edit/Show/Project tabs, content-first surface editing, collapsible advanced face/object controls, wider inspector, Project/Add/Guides/Calibrate/Show dropdowns and quick Play/Pause.
- [x] Selection returns to Edit; navigation remains temporary and does not dirty/save/render. Emergency Blackout stays directly reachable.
- [x] Final Debug/Release each passed 226 correctness tests; four benchmarks skipped and two legacy visible-window checks excluded. Pinned Xcode 27A5237l, universal slices, strict signing and full delivered file hashes verified.
- [x] Final Release installed locally and exercised for project reopening, grouping, blackout/restore and clean Test Output. Preview checks also exercised animated content and mask creation. Original user quad reopened clean at the end.
- [x] Previous installed app and original v1.12 milestone archive preserved. Bundle stays 1.12/build 9; see [UI polish verification](UI_USABILITY_POLISH.md).
- [ ] User-reported approval of the new UI. Minimum-width compact toolbar fallback is not visually verified; normal and enlarged window layouts reviewed.
- Local changes remain uncommitted on codex/ui-usability-polish. No GitHub upload; main/GitHub retain the completed v1.12 milestone. Next roadmap milestone remains v1.13 Image Import.


## v1.13 Image Import — October 9, 2026

- [x] Implemented in one complete pass: PNG/JPEG picker/drop, explicit shared-object/face-detach targets, Fit/Fill/Stretch, replace/remove/relink and bounded orientation/sRGB/alpha decoding.
- [x] Shared cached image textures across connected faces; preserve geometry, masks, crop/flips, clocks, calibration and output priorities. Collect unreferenced media while preserving duplicate/look references.
- [x] Portable format 7 saves/recovery with assets, migration, missing/damaged media recovery and atomic last-good-file preservation.
- [x] Editor-only reference photo with saved placement/position/scale/opacity/lock and temporary visibility, separate from clean output and mapping coordinates.
- [x] Previous local usability improvements included. Final Debug/Release each passed 239 correctness tests; four benchmarks skipped, two legacy visible-window checks excluded. Exact Xcode 27A5237l, universal slices, strict signatures and all delivered file hashes verified.
- [x] Version 1.13/build 10 installed in app/ and archived in builds/v1.13/; previous v1.12 UI-polish app preserved. See [verification](V1.13_VERIFICATION.md) and [image guide](IMAGE_IMPORT_GUIDE.md).
- [ ] User visual acceptance of picker/drop, image placement and reference compositing. No screen control/app launch used.
- Completed-milestone source backup successfully pushed to GitHub main at **6dfd076** (from 4e92123), including the prior UI polish. No release/tag/assets published. Next build: v1.14 Video Import.


## Local playback timeline — October 9, 2026

- [x] Resizable bottom lanes for objects/standalone faces, current-effect clips, seconds ruler, moving playhead, scrub/zoom/snap/follow and transport controls.
- [x] Timed captured effects/images with move/trim/edit/duplicate/delete; shared-owner evaluation, clip-local phase, dark gaps and live fallback on empty tracks.
- [x] Format 8 validation/migration, clip-image asset retention and object copy/detach/delete lifecycle.
- [x] Six new correctness tests; final Debug/Release each 245 passing, zero failures, four benchmarks skipped and two visible-window exclusions.
- [x] Signed universal Release app copied to app/ and builds/timeline/ with SHA256 equality; previous installed app preserved.
- [ ] User visual acceptance. No screen control/app launch used.
- No commit/push/upload/release for this local enhancement. See [verification](TIMELINE_VERIFICATION.md).

## Roadmap alignment — October 9, 2026

Planning updated to match the delivered format 8 timeline. v1.14 extends existing rows/transport/clips with videos, source in-points, shared frame/audio ownership and portable saves; v1.15 includes timeline undo/recovery/readiness, UI polish, demos and packaging. V2 extends this foundation for music/waveforms/advanced choreography. Corrected stale current-state summaries while preserving historical milestone records. Documentation only; no app/source changes, build, screen use or Git delivery.

## v1.14 detailed planning — October 9, 2026

Seven work stages planned: safe video import/model, existing timeline source-range edits, shared-clock decode/Metal frames, mapping/lifecycle, explicit embedded audio, portable format 8 migration/save/recovery and full verification/delivery. Source trim/move semantics, gaps/loops, shared audio/frame ownership, default mute and resource/cancellation policies are explicit. See [plan](V1.14_PLAN.md). Pinned Xcode 27A5237l reverified and installed AVFoundation headers inspected. Planning only: no video code, app build, version bump, screen use or Git delivery performed.

## v1.14 — Video Import and Timeline Integration — October 9, 2026

- [x] Seven approved implementation stages complete: bounded video import/model, timeline ranges, owner decode/Metal frames, mapping/lifecycle, explicit embedded audio, portable save/recovery, automated verification/local delivery.
- [x] 258 full-suite correctness tests in Debug and Release; final dedicated 13-test Release video run and sustained 1080p profiling. Four benchmarks skipped; two visible-window tests excluded.
- [x] Signed universal 1.14/build 11 app delivered to app/ and builds/v1.14/; previous installed app preserved; hashes/architecture/signatures verified.
- [x] Self-generated portable mixed video/effect/image demo, mask and editor reference saved under assets/demos/.
- [ ] User visual/listening acceptance and physical audio-device unplug/routing checks.
- Completed milestone source backup successfully pushed at **ccb5df2**; no release/tag/assets publication. Next v1.15.

## Full V1 release finalization — October 10, 2026

Published [Projection Mapper V1 — v1.15](https://github.com/Chosencode25/projection-mapper/releases/tag/v1.15) at 2026-10-10 22:29:38 UTC as the latest full release (not draft or prerelease). The private repository visibility is verified unchanged. Annotated tag **v1.15** points to **17a4647**, whose app sources match tested **60e838d**; 1.15/build 12 and format 9 are unchanged. Earlier tags/releases/assets are preserved.

Assets: ProjectionMapper-v1.15-macOS-universal.zip, SHA256SUMS.txt, V1_USER_GUIDE.md and Build-identity.json. All four were downloaded from GitHub before publication and matched their local bytes. Archive SHA-256: **f32cc9731ff0c3e93a3202c2c09dfb82be8ceb0560d23177b27fe67a22310a26**. Extracted app files matched every tested Release file and strict signature verification passed. Universal slices and bundle identity were checked. Local evidence is under builds/v1.15/V1-release/, including Published-release.json, Remote-tag.json and Repository-visibility.json. The verified app copy was restored to app/ProjectionMapper.app without launching it or using screen control. No code changed, so existing 269 passing tests per configuration and profile results remain applicable.

Developer ID/notarization, Intel/older-macOS runtime and user visual/listening acceptance remain unestablished. Physical fullscreen output and music/show features remain V2. The separate canonical demo has local deletions that are preserved unstaged; its tracked bytes match the intact bundled demo. Release documentation was committed separately without those deletions.

## Short V1 acceptance — October 10, 2026

Completed the authorized short Computer Use checks with a separate generated-media demo project, excluding the long session. Fixed missing Show readiness/audio controls locally and installed the verified universal app. Readiness, identification restoration, mapping/timeline undo/redo, clean output, calibration/blackout, compact layout and portable save/reopen/relink were observed. Speaker routing/volume/enablement and safe audio-off reopening were checked through UI; audible behavior/perceived sync and physical device-unplug remain unverified. Published release unchanged; details in V1.15_ACCEPTANCE.md.

## v1.15.1 release correction

The user explicitly authorized uploading the tested Show-controls correction. v1.15.1/build 13 is prepared as a full patch release; original v1.15 remains preserved. Corrected app code passed 269 tests in both Debug/Release, and version metadata was rebuilt with the pinned toolchain. See [patch verification](V1.15.1_VERIFICATION.md). Publication is confirmed below.

## Confirmed patch publication

Published [v1.15.1](https://github.com/Chosencode25/projection-mapper/releases/tag/v1.15.1) at 2026-10-10T22:50:58Z as the latest full release, not draft/prerelease. Annotated tag points to **a2fa5188a91fe92cafb29cabd4bf953b9f35ddf1**. Main source was successfully pushed; original v1.15 tag/release/assets are preserved. Four assets uploaded: universal app ZIP, SHA256SUMS.txt, guide and build identity. All four downloaded assets match local bytes; checksum, extracted app file hashes, strict signature and bundle 1.15.1/build 13 passed. ZIP SHA-256: **ee397193fc0c885c72414ade1c0e43c6ea66d493ab600f13be8bcc4751fc6cef**. Corrected app is installed at app/ProjectionMapper.app and archived under builds/v1.15.1/. Quit/reopen an older running copy. No new listening/device-unplug/long-session acceptance claim.

## V2 mobile editor planning — October 14, 2026

Added the approved mobile web editor to existing v2.10 without renumbering the roadmap: local Wi-Fi/QR pairing with face/object selection, corner/mask editing, effects, playback, undo and Mac-side saving; then mobile timeline and bounded preview; optional private-VPN internet access later. Recorded Mac-authoritative state/timing, session permissions, edit locks, revision/conflict/disconnect behavior and actual iPhone/Android acceptance gates. Native phone apps, Bluetooth and hosted relay remain later alternatives. Updated V2 roadmap, implementation steps and development requirements. Documentation only; no app changes, server enablement, builds, screen control, commits or GitHub uploads.


## v2.01 local implementation and delivery — October 14, 2026

Completed the authorized local implementation using Xcode 27.0 beta 5 (27A5237l). Fifteen added correctness tests cover routing/lifecycle/identity, shared GPU output, calibration profiles/fixtures and teardown; final Debug/Release each passed 284 correctness tests. Two sustained HD workloads and full-resolution effects matrix passed with documented limits. Universal 2.01/build 14 installed and archived with verified signature/file hashes/ZIP extraction; previous installed app preserved. No GitHub delivery, commits or routine screen use. Projector presentation/alignment/reconnect and optical measurements remain pending user/hardware acceptance. See V2.01_VERIFICATION.md.


## Cleanup and development improvements — October 19, 2026

- [x] Verify existing GitHub main/releases and the pinned Xcode 27A5237l.
- [x] Preserve eight saved mapping projects from build folders, with complete file-hash comparisons, under local-only assets/local-projects/; retain three scratch helpers and lightweight historical reports.
- [x] Remove 34 obsolete build folders (42.99 GiB logical file bytes), preserving source/history/tags and read-only references.
- [x] Add repeatable pinned-toolchain build/test commands, one cache and preview-first cache cleanup; simplify current instructions and keep the bundled demo as the single protected fixture.
- [x] Fix rejected projector opens getting stuck in opening; add resource-release/retry regression.
- [x] Final Debug and Release each passed 285 correctness tests, zero failures/recorded runtime warnings. Four optional benchmarks skipped, two visible-window tests excluded.
- [x] Install verified current universal app in app/ and Applications; remove obsolete external project-cache.
- [x] Current archive extracted/signature/file-hash verified in builds/current/; successful GitHub main source push at **0f8b517**, from **ecb57fe**. No release/tag/assets published.
- [x] Remove superseded local v2.01 copies and the new disposable build cache after delivery; builds/ is now about 38 MiB instead of about 45 GiB. Preserve all rescued projects, reports and current app/archive.
- No routine app launch or screen control. Hardware/listening/visual acceptance remains pending.


## GitHub presentation — October 19, 2026

- [x] Product-led README with branding, two real app screenshots and a short Test Mode GIF, stable v1.15.1 download versus v2.01 source, features, concise limits and navigation.
- [x] Getting-started guide, documentation hub, contribution guide and bug/feature issue forms.
- [x] Updated description and ten relevant topics; uploaded the custom 1280×640 social preview using the user-signed-in GitHub session.
- [x] Verified 63 local documentation/media links, SVG/media dimensions, YAML syntax/field IDs and diff hygiene. Exact pinned Xcode reverified; app source is unchanged, so no app rebuild/test repetition is required.
- [x] Successful main push **9107838 → 4d6d425**. Verified the live README assets and expanded GIF load, plus the chooser and both rendered issue forms; no issue submitted. Temporary raw captures removed after final media verification.
- App-window captures used only the bundled demo under the user's explicit screenshot/demo request. End state is paused at zero with Test Output closed. This is presentation media, not new routine user acceptance, audio/hardware or performance evidence.
- GitHub was already public when this work began; visibility is unchanged. See [presentation record](GITHUB_PRESENTATION.md).


## Local app polish delivery — October 19, 2026

- [x] Implement and integrate the local workspace, timeline, status and renderer improvements; internal build 15 distinguishes this local variant without a milestone/package-format bump.
- [x] Eight added regressions; final Debug/Release each 293 passing, zero failures/runtime warnings, four optional skips and two visible-window exclusions, exact Xcode 27A5237l.
- [x] Verified universal local app installed in app/ and Applications. Current ZIP extracted and all 11 app-file hashes/signatures verified; uncommitted source patch retained locally for recovery.
- [x] Update current build instructions, local guide, changelog and evidence; retain previous lightweight identity records and one shared cache, with no extra app staging directories.
- [ ] User visual acceptance of the new layout/navigation. No automated screen use or user acceptance inferred.
- No Git commits, push or GitHub delivery. Next independent roadmap milestone remains v2.02; this work refines the current app.


## Build 16 keyboard editing and source delivery — October 19, 2026

- [x] Install the verified keyboard editing update after the user saved and quit the running app; keep native text editing, mask/clip context and focused projector Escape intact.
- [x] Final Debug/Release each passed 312 correctness tests, including 19 shortcut regressions; zero failures/runtime warnings, four optional skips and two visible-window exclusions. Both installed universal app copies and extracted local ZIP match all 11 Release files and strict signatures.
- [x] Under the subsequent explicit upload request, publish all 40 app-action shortcuts plus file/history/panel/output/native keys in README and docs/KEYBOARD_SHORTCUTS.md; add navigation and distinguish build 16 source from the v1.15.1 download.
- [x] Validate the shortcut tables against the actual Swift catalog, 147 local documentation links and unchanged tested code/project/test source. No repeat app build was required for the final documentation edits.
- [x] Successful main source push **58a7574 → ed0e9f2**. Generated builds/caches, app archives, local projects and personal state remain excluded; historical releases/tags are preserved.
- User visual/listening, projector/optical, Intel/older-macOS and notarization acceptance remain pending. No new release/tag/asset upload or routine screen control. Next independent milestone remains v2.02.
