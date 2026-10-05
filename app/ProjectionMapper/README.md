# Projection Mapper — v1.03.1

A native, entirely code-based Mac editor skeleton. Built for **Xcode 27.0 beta 5 (27A5237l)**. Minimum deployment target: **macOS 15.0**.

## Open and run

1. Open `ProjectionMapper.xcodeproj` in `/Applications/Xcode-beta.app`.
2. Select the **ProjectionMapper** scheme and **My Mac** destination.
3. Press **Command–R**.

Local builds use ad-hoc signing (“Sign to Run Locally”); an Apple Developer membership or team is not required for this development milestone. Public distribution signing is future work.

## Included

- One editor window with a toolbar, surface sidebar, aspect-aware empty canvas, project inspector, and status bar.
- Live project naming and title updates.
- New Project with safe Cancel/Discard behavior for changes.
- Close and Quit protection for changes; Show Editor and Dock reopening.
- Sidebar/inspector toggles, keyboard shortcuts, and About information.
- Test Window/display output menus, display information, safe recovery, and remembered preferences.
- Open/Close Output actions, one normal resizable black test window, and shared status.
- 28 focused model/session/output/window tests, runnable with Command–U.

Projects remain in memory. Basic test output is available. Rendering, media import, mapping, and saving are later milestones.

## Source organization

`ProjectionMapper/App/` contains app entry, commands, and window lifecycle. `Models/` contains project and display models. `Services/` contains display discovery and output preferences. `State/` contains observable editor state. `Views/` contains SwiftUI panels. `Resources/` contains the asset catalog. `ProjectionMapperTests/` contains unhosted state tests; those compile the same model/session/output source files and do not launch the editor.

Files are explicitly included in the Xcode project. When adding a new file outside Xcode, add it to the appropriate target in the Project navigator; merely putting it anywhere in the folder does not include it automatically.

## Command-line build

Run from this directory:

```sh
DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer \
xcodebuild -project ProjectionMapper.xcodeproj -scheme ProjectionMapper \
  -destination 'platform=macOS' -derivedDataPath DerivedData build
```

For tests, replace `build` with `test`. Before building, verify the toolchain using `DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer xcodebuild -version`.

The minimum deployment target is a build setting; runtime verification on the development Mac does not establish testing on every supported macOS release.

Projector output implementation and physical checks are deferred. See ../../docs/V1.03.1_VERIFICATION.md. Test Output now draws a blue Metal diagnostic color with black margins in v1.04.1. See ../../docs/V1.04.1_VERIFICATION.md. Rectangle and shared editor preview remain planned.
