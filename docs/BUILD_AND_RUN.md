# Build and Run v1.01

Required Xcode: **27.0 beta 5 (27A5237l)** at /Applications/Xcode-beta.app.

## In Xcode

1. Open app/ProjectionMapper/ProjectionMapper.xcodeproj with Xcode-beta.
2. Select **ProjectionMapper** and **My Mac**.
3. Press **Command–R** to build and run.
4. Press **Command–U** to run the five state tests.

The project uses SwiftUI and programmatic AppKit. Its source is organized under App, Models, State, Views, and Resources. Minimum deployment target: macOS 15.0. Local ad-hoc signing needs no paid developer account.

If Xcode offers to update recommended project settings, review changes against the pinned toolchain rather than accepting migrations blindly.

## Standalone local build

Open builds/v1.01/ProjectionMapper.app. This is a local Apple Silicon development build, not a notarized public installer.

## Commands

From app/ProjectionMapper/:

```sh
DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer \
xcodebuild -project ProjectionMapper.xcodeproj -scheme ProjectionMapper \
  -destination 'platform=macOS' -derivedDataPath DerivedData build
```

Replace build with test to run the tests. The system-wide developer directory remains unchanged.

## Shortcuts

- Command–N: New Project.
- Command–W: Close editor.
- Command–Q: Quit.
- Control–Command–S: Show/hide sidebar.
- Control–Command–I: Show/hide inspector.

Projects are held in memory for v1.01. Name changes trigger discard protection. Output selection begins in v1.02, the separate test/projector window in v1.03, and rendering in v1.04.
