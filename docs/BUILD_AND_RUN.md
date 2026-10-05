# Build and Run

Required Xcode: **27.0 beta 5 (27A5237l)** at /Applications/Xcode-beta.app.

## In Xcode

1. Open app/ProjectionMapper/ProjectionMapper.xcodeproj with Xcode-beta.
2. Select **ProjectionMapper** and **My Mac**.
3. Press **Command–R** to build and run.
4. Press **Command–U** to run the 50 state/window/Metal tests (two require visible windows).

The project uses SwiftUI and programmatic AppKit. Its source is organized under App, Models, State, Views, and Resources. Minimum deployment target: macOS 15.0. Local ad-hoc signing needs no paid developer account.

If Xcode offers to update recommended project settings, review changes against the pinned toolchain rather than accepting migrations blindly.

## Standalone local build

Open app/ProjectionMapper.app or builds/v1.04.4/ProjectionMapper.app (the Debug build with automated lifecycle verification; bundle version remains 1.04.2/build 4). The published Release build is preserved in builds/v1.04.2/ProjectionMapper.app. The earlier builds/v1.01/ProjectionMapper.app is preserved. This is a local Apple Silicon development build, not a notarized public installer.

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
- Control–Command–O: Show Output (open, raise, or restore).
- Control–Command–E: Show Editor.
- Control–Command–S: Show/hide sidebar.
- Control–Command–I: Show/hide inspector.

Projects are held in memory. Name changes trigger discard protection; output actions do not. Select Test Window, then use Show Output in the toolbar, inspector, or Window menu. It opens one resizable window with an orange rectangle on black; repeated Open brings it forward. Close Output or its native close button leaves the editor intact.

Choose HD, Full HD, 4:3, Portrait, or 4K in the inspector. The saved simulated resolution controls the preview and aspect-fitted output surface independently of window size. The normal window size/position is remembered; inaccessible frames recover onto a current screen. Output starts closed on launch. Metal rectangle rendering and shared editor preview are implemented through v1.04.3. Projector output implementation and physical testing are deferred at the user's request.

## Metal shader compiler component

Starting with v1.04.2, building `.metal` sources requires Apple's Metal Toolchain component for the pinned Xcode. Component **27A5237l** was installed and verified during step 2. If missing, install it with the same developer directory:

```sh
DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer   xcodebuild -downloadComponent MetalToolchain
```

v1.04.3 has 44 passing Debug tests. v1.04.2 has 43 passing Debug and Release tests. The accepted Release app is `builds/v1.04.2/ProjectionMapper.app` and draws an orange rectangle on black.


## Automated checks without onscreen windows

v1.04.4 passed 48 automated tests without presenting windows. To run that subset from the project root, use:

```sh
DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer \
xcodebuild -project app/ProjectionMapper/ProjectionMapper.xcodeproj -scheme ProjectionMapper \
  -destination 'platform=macOS,arch=arm64' -derivedDataPath builds/v1.04.4/DerivedData \
  '-skip-testing:ProjectionMapperTests/TestOutputCoordinatorTests/normalFrameRestoresAcrossCloseAndNewCoordinator()' \
  '-skip-testing:ProjectionMapperTests/MetalRendererTests/nativeMetalOutputSurvivesPresetsResizeAndReopen()' test
```

The two excluded tests exercise visible minimize/zoom and drawable behavior. Interactive lifecycle acceptance remains pending; see V1.04.4_VERIFICATION.md. No production app launch is needed for this subset.
