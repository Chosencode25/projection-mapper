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

Use Metal for rendering starting in v1.04. AVFoundation remains the planned tool for future v1.14 video work. The user reordered the remaining roadmap on October 5, 2026: multiple surfaces v1.08, animations v1.09, saving v1.10, surface controls v1.11, mapping tools v1.12, images v1.13, video v1.14, and final polish/release v1.15. No third-party dependency is needed for v1.01.

## Test Mode

Test Mode is a permanent feature. It will use a normal resizable output window on the Mac, while Projector Mode will use fullscreen output on the selected external display. Both modes must share the same renderer and mapping data.

Resizing the test window changes preview display size, not mapping coordinates or simulated output resolution. Output selection begins in v1.02, the output window in v1.03, and rendering in v1.04.

## Working location and references

Use `/Users/keith/Documents/Projection Mapping` for project work. Keep the original ChatGPT project mirror and synced source files unchanged.

## Test Mode first — October 5, 2026 scope update

The user explicitly deferred projector output implementation and physical testing. v1.03 is split into 1.03.1 basic Test Window, 1.03.2 resolution/scaling, and 1.03.3 window behavior/polish. Test-only milestones can be accepted and merged after local verification; missing projector hardware is no longer a release blocker for that scope. Preserve the shared-renderer direction for v1.04 and record external behavior as deferred/unverified.

## Connected object faces — October 5, 2026 requirement

The approved remaining V1 plan includes optional object groups whose faces share one content canvas and content owner. Each face retains independent output corners and a separate input mapping; manual edge alignment, orientation/scale validation and deliberate seams establish continuity. Continuous mode spans linked faces; Repeat uses shared timing with repeated whole content. Use one generator seed/time or video player/frame per linked object. Carry stable membership, shared maps/links and content ownership through saving, controls, calibration, imports, resource cleanup and undo/redo. Keep standalone surfaces and explicit detach supported. This is planned work beginning in v1.08, with animations in v1.09; full 3D reconstruction and physical projector checks remain deferred. See [remaining milestone plan](V1_REMAINING_PLAN.md).
