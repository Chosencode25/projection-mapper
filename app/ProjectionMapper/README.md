# Projection Mapper — v1.07 source

A native, entirely code-based Mac editor skeleton. Built for **Xcode 27.0 beta 5 (27A5237l)**. Minimum deployment target: **macOS 15.0**.

## Open and run

1. Open `ProjectionMapper.xcodeproj` in `/Applications/Xcode-beta.app`.
2. Select the **ProjectionMapper** scheme and **My Mac** destination.
3. Press **Command–R**.

Local builds use ad-hoc signing (“Sign to Run Locally”); an Apple Developer membership or team is not required for this development milestone. Public distribution signing is future work.

## Included

- One editor window with a toolbar, surface sidebar, aspect-aware Metal scene preview, project inspector, and status bar.
- Live project naming and title updates.
- New Project with safe Cancel/Discard behavior for changes.
- Close and Quit protection for changes; Show Editor and Dock reopening.
- Sidebar/inspector toggles, keyboard shortcuts, and About information.
- Test Window/display output menus, display information, safe recovery, and remembered preferences.
- Open/Close Output actions, one normal resizable test window with shared scene rendering, and shared status.
- One project-owned Surface 1, selected initially, with sidebar selection/deselection and read-only normalized corner inspector.
- Editor-only corner handles/outline, normalized dragging and focused arrow/Shift nudging; active-corner inspector and geometry discard protection.
- Projective diagnostic grid with mipmaps, Solid fill option, safe invalid geometry and overlapping-handle recovery.
- 79 correctness tests (77 run without presenting windows) plus three opt-in benchmarks, runnable with Command–U; see ../../docs/BUILD_AND_RUN.md.

Projects remain in memory. Basic test output is available. Shared editor/Test Output rendering is implemented. Four-corner surface storage is implemented; corner editing is implemented; perspective mapping is implemented; multiple surfaces (v1.08) are next, followed by built-in animations (v1.09) and saving (v1.10). Image/video import now follows core tools at v1.13/v1.14.

## Planned direction

The [remaining V1 plan](../../docs/V1_REMAINING_PLAN.md) adds connected object faces, layout/content separation, deterministic effect time/seek, generator presets, reusable looks/palettes, master brightness/fades, polygon masks, editor-only house photos, explicit video-audio controls and readiness checks. These features are planned, not included in the v1.07 source/app.

The [V2 roadmap](../../docs/V2_ROADMAP.md) and [detailed steps](../../docs/V2_IMPLEMENTATION_PLAN.md) cover music timelines, holiday choreography and show operation. Fullscreen projector implementation/physical checks are scheduled for v2.01 with the hardware deferral preserved.

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

Projector output implementation and physical checks are deferred. See ../../docs/V1.03.1_VERIFICATION.md. Test Output draws an orange Metal rectangle on black with normalized geometry and aspect fitting in v1.04.2. See ../../docs/V1.04.2_VERIFICATION.md. Shared editor preview is implemented in v1.04.3; see ../../docs/V1.04.3_VERIFICATION.md. Bundle remains 1.04.2/build 4. Lifecycle handling and local v1.04 acceptance are complete; see ../../docs/V1.04.5_VERIFICATION.md for Debug/Release tests, measured performance and remaining physical hardware limits. First Surface is implemented and locally accepted in v1.05; see ../../docs/V1.05_VERIFICATION.md. Corner Nodes are implemented and locally accepted in v1.06; see ../../docs/V1.06_VERIFICATION.md. Perspective Warp is implemented and locally accepted in v1.07; see ../../docs/V1.07_VERIFICATION.md. The local built app is ../ProjectionMapper.app.
