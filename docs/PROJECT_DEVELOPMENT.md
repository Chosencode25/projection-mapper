# Projection Mapping — Development Requirements

## Required toolchain

Use **Xcode Version 27.0 beta 5 (27A5237l)** for the whole project, beginning with v1.01 and continuing through later milestones.

- Target this exact release for source code, Xcode projects, build settings, resources, tests, and build/run instructions.
- Validate API availability and Swift behavior against its bundled SDKs and compiler. Check Apple documentation and installed SDK interfaces when compatibility is uncertain.
- Build and run applicable checks with this toolchain before claiming compatibility. If unavailable, report verification as pending.
- Do not silently switch Xcode releases or migrate settings for another release.
- Choose and document the minimum macOS deployment target during implementation. It is separate from the Xcode version; do not infer it from “27.0.”
- Prefer a per-command DEVELOPER_DIR when the system developer directory points elsewhere. Do not change the machine-wide selection without authorization.

On October 5, 2026, `/Applications/Xcode-beta.app` was verified to report Xcode 27.0, build 27A5237l. The system selection was `/Library/Developer/CommandLineTools`.

Use this developer directory for build commands:

```text
/Applications/Xcode-beta.app/Contents/Developer
```

Recheck the build before implementation because the installed beta may be updated later.

## Interface implementation

Write the entire interface in code using SwiftUI and programmatic AppKit where needed. Do not use storyboards or XIBs or require drag-and-drop interface construction. Xcode previews are optional inspection aids.

Use Metal for rendering starting in v1.04. AVFoundation supplies v1.14 video inspection and shared-owner playback. The user reordered the remaining roadmap on October 5, 2026: multiple surfaces v1.08, animations v1.09, saving v1.10, surface controls v1.11, mapping tools v1.12, images v1.13, video v1.14, and final polish/release v1.15. No third-party dependency is needed for v1.01.

## Test Mode

Test Mode is a permanent feature. It will use a normal resizable output window on the Mac, while Projector Mode will use fullscreen output on the selected external display. Both modes must share the same renderer and mapping data.

Resizing the test window changes preview display size, not mapping coordinates or simulated output resolution. Output selection begins in v1.02, the output window in v1.03, and rendering in v1.04.

## Working location and references

Use `/Users/keith/Documents/Projection Mapping` for project work. Keep the original ChatGPT project mirror and synced source files unchanged.

## Test Mode first — October 5, 2026 scope update

The user explicitly deferred projector output implementation and physical testing. v1.03 is split into 1.03.1 basic Test Window, 1.03.2 resolution/scaling, and 1.03.3 window behavior/polish. Test-only milestones can be accepted and merged after local verification; missing projector hardware is no longer a release blocker for that scope. Preserve the shared-renderer direction for v1.04 and record external behavior as deferred/unverified.

## Connected object faces — October 5, 2026 requirement

The approved remaining V1 plan includes optional object groups whose faces share one content canvas and content owner. Each face retains independent output corners and a separate input mapping; manual edge alignment, orientation/scale validation and deliberate seams establish continuity. Continuous mode spans linked faces; Repeat uses shared timing with repeated whole content. Use one generator seed/time or video player/frame per linked object. Carry stable membership, shared maps/links and content ownership through saving, controls, calibration, imports, resource cleanup and undo/redo. Keep standalone surfaces and explicit detach supported. Static connected-object mapping is implemented and locally accepted in v1.08; animation ownership/time is implemented in v1.09 and persistence is implemented locally in v1.10; full 3D reconstruction and physical projector checks remain deferred. See [remaining milestone plan](V1_REMAINING_PLAN.md).

## Show foundations and next major version — October 5, 2026

The user requested integrating the appropriate show foundations into V1 and planning V2. Keep the approved V1 sequence; see [current remaining plan](V1_REMAINING_PLAN.md). Separate layout geometry/masks/input maps from content/presets and runtime playback. Use stable target/asset identities and explicit elapsed-time evaluation with deterministic seed/seek behavior. Reusable looks preserve mapping. Add palettes, master visual brightness/fade, face-local polygon cutouts, an editor-only house photo, explicit video-audio ownership/routing and bounded readiness checks in their assigned milestones. Extend versioned saves with migrations as features arrive; V2 show data refers to layout targets rather than duplicating geometry.

[V2 roadmap](V2_ROADMAP.md) and [implementation plan](V2_IMPLEMENTATION_PLAN.md) stage music transport, sequencing, holiday choreography, layers/regions/text, templates, verified external integration, operator controls, schedules, remote control and export. v2.01 schedules the deferred physical output work. Preserve Test Mode and the hardware deferral: independent development may proceed without equipment, but advertised real projector/synchronized-light capabilities require recorded hardware acceptance. Research products are references, not assumed dependencies or compatibility. The exact pinned Xcode requirement continues into V2 unless explicitly revised.

## Visual acceptance preference — October 5, 2026

The user confirmed v1.09.1 visual checks passed. Until they change this preference, they perform routine visual app checks. Use file changes and automated checks; do not operate their screen unless investigating a specific expected bug. Report automated evidence and leave new visual acceptance to the user without blocking local delivery.

## Timeline brought forward — October 9, 2026

The user's bottom video-editor timeline request is implemented as a local enhancement to 1.13/build 10: saved format 8 effect/image clips, shared content-owner lanes, clip-local shared-clock rendering and runtime scrub/zoom/snap/follow controls. See [verification](TIMELINE_VERIFICATION.md). v1.14 must extend this timeline with video asset references, source in-points and frame/audio timing rather than creating a separate transport. v1.15 must include timeline/media edit transactions in undo/recovery, readiness and final acceptance. Music/waveforms, layered overlaps and crossfades remain V2. Preserve existing clip timing/assets when evolving the package format. Routine user visual acceptance remains pending; this local enhancement and planning edits do not trigger Git delivery.

## Mobile web editor — October 14, 2026

The user approved adding the recommended phone browser editor to V2. Expand v2.10: Mac-hosted local Wi-Fi/QR pairing and mapping/effect/playback controls first, mobile timeline/optional preview second, optional private-VPN internet access later. Keep the native Mac UI in SwiftUI/programmatic AppKit; the separate hosted phone client uses web UI code. The Mac remains authoritative for validation, undo/recovery, files, rendering and show/audio timing. Enforce pairing/revocation, stale-edit/conflict handling and Show Mode locks. No cloud relay, native companion app or Bluetooth transport is required initially. Details and acceptance gates are in V2_IMPLEMENTATION_PLAN.md; this is planning, not authorization to enable a server or publish changes now.
