# Build and Run v1.02 Preview

Required Xcode: **27.0 beta 5 (27A5237l)** at /Applications/Xcode-beta.app.

## In Xcode

1. Open app/ProjectionMapper/ProjectionMapper.xcodeproj with Xcode-beta.
2. Select **ProjectionMapper** and **My Mac**.
3. Press **Command–R** to build and run.
4. Press **Command–U** to run the 21 state tests.

The project uses SwiftUI and programmatic AppKit. Its source is organized under App, Models, State, Views, and Resources. Minimum deployment target: macOS 15.0. Local ad-hoc signing needs no paid developer account.

If Xcode offers to update recommended project settings, review changes against the pinned toolchain rather than accepting migrations blindly.

## Standalone local build

Open builds/v1.02/ProjectionMapper.app. The earlier builds/v1.01/ProjectionMapper.app is preserved. This is a local Apple Silicon development build, not a notarized public installer.

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

Projects are held in memory. Name changes trigger discard protection; output selection does not. Choose Test Window or an eligible connected display through either output menu. Test Window is configured as 1280 × 720. Selecting it does not open a window yet: the separate test/projector window arrives in v1.03, and rendering in v1.04.

The preview has passed local builds, tests, and editor checks; physical external-display checks remain pending. Main stays at v1.01 until those checks are recorded.
