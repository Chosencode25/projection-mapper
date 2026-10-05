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

Use Metal for rendering starting in v1.04 and AVFoundation for video starting in v1.09. No third-party dependency is needed for v1.01.

## Test Mode

Test Mode is a permanent feature. It will use a normal resizable output window on the Mac, while Projector Mode will use fullscreen output on the selected external display. Both modes must share the same renderer and mapping data.

Resizing the test window changes preview display size, not mapping coordinates or simulated output resolution. Output selection begins in v1.02, the output window in v1.03, and rendering in v1.04.

## Working location and references

Use `/Users/keith/Documents/Projection Mapping` for project work. Keep the original ChatGPT project mirror and synced source files unchanged.
