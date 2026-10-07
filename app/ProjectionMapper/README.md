# Projection Mapper — v1.12 Mapping Tools

A native, entirely code-based Mac editor skeleton. Built for **Xcode 27.0 beta 5 (27A5237l)**. Minimum deployment target: **macOS 15.0**.

## Open and run

1. Open `ProjectionMapper.xcodeproj` in `/Applications/Xcode-beta.app`.
2. Select the **ProjectionMapper** scheme and **My Mac** destination.
3. Press **Command–R**.

Local builds use ad-hoc signing (“Sign to Run Locally”); an Apple Developer membership or team is not required for this development milestone. Public distribution signing is future work.

## Included

- One editor window with a toolbar, surface sidebar, aspect-aware Metal scene preview, project inspector, and status bar.
- Live project naming and title updates.
- New/Open/Close/Quit with Save/Discard/Cancel protection for changes.
- Close and Quit protection for changes; Show Editor and Dock reopening.
- Sidebar/inspector toggles, keyboard shortcuts, and About information.
- Test Window/display output menus, display information, safe recovery, and remembered preferences.
- Open/Close Output actions, one normal resizable test window with shared scene rendering, and shared status.
- Ordered project-owned surfaces, starting with selected Surface 1; add, rename, tag, duplicate, delete, hide and reorder from sidebar/inspector.
- Editor-only corner handles/outline, normalized dragging and focused arrow/Shift nudging; active-corner inspector and geometry discard protection.
- Projective diagnostic grid with mipmaps, Solid fill option, safe invalid geometry and overlapping-handle recovery.
- Named object grouping/ungrouping, shared content, Continuous/Repeat input maps, quarter-turn/mirror controls, manual edge alignment and join/seam diagnostics.
- Persistence, mapping and GPU correctness tests plus four opt-in benchmarks, runnable with Command–U; see ../../docs/BUILD_AND_RUN.md.

Projects save/open as .projectionmap packages through the File menu. Save As, recent files and debounced recovery are available. Loads start paused. Multiple surfaces, connected objects, six effects, presets and seeking are implemented. Opacity/brightness/crop/flips, explicit object/face appearance scope, output-geometry locks, bounded object movement and scoped resets are implemented. Reusable looks/palettes and master brightness/fade/blackout complete v1.11. Bundle 1.11/build 8; 184 Debug/Release correctness tests pass, user visuals pending. Local product is in builds/v1.11/ with evidence in builds/v1.11.3/. Milestone source backup successfully pushed to main at 87459a8; no release/tag/assets requested. See [verification](../../docs/V1.11.3_VERIFICATION.md). Image/video imports remain v1.13/v1.14.

## Planned direction

The [remaining V1 plan](../../docs/V1_REMAINING_PLAN.md) builds on implemented connected object faces and layout/content separation with deterministic effect time/seek, generator presets, reusable looks/palettes, master brightness/fades, polygon masks, editor-only house photos, explicit video-audio controls and readiness checks. Looks/palettes, master controls, calibration and masks are implemented; editor/join tools and media remain planned.

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

Projector output implementation and physical checks are deferred. See ../../docs/V1.03.1_VERIFICATION.md. Test Output draws an orange Metal rectangle on black with normalized geometry and aspect fitting in v1.04.2. See ../../docs/V1.04.2_VERIFICATION.md. Shared editor preview is implemented in v1.04.3; see ../../docs/V1.04.3_VERIFICATION.md. Bundle is 1.08/build 5. Lifecycle handling and local v1.04 acceptance are complete; see ../../docs/V1.04.5_VERIFICATION.md for Debug/Release tests, measured performance and remaining physical hardware limits. First Surface is implemented and locally accepted in v1.05; see ../../docs/V1.05_VERIFICATION.md. Corner Nodes are implemented and locally accepted in v1.06; see ../../docs/V1.06_VERIFICATION.md. Perspective Warp is implemented and locally accepted in v1.07; see ../../docs/V1.07_VERIFICATION.md. The local built app is ../ProjectionMapper.app.

Multiple Surfaces is locally accepted; see ../../docs/V1.08_VERIFICATION.md. This delivery is intentionally uncommitted/unpushed with no GitHub upload.

## Animation preview

Choose Animated gradient, Moving lines or Moving checkers in the face/object Content picker. The inspector Playback section controls all animated faces with Play/Pause, Restart and speed. Linked faces share settings; Continuous samples their input regions and Repeat shows the whole effect per face. Two-color controls edit the selected source. New/reset projects start paused; playback is runtime state and does not dirty the project. The preview and output use the same elapsed-time clock.

Debug/Release suites now pass 102 correctness tests. The user subsequently confirmed v1.09.1 visual playback checks worked. Installed copies: ../ProjectionMapper.app and ../../builds/v1.09.1/ProjectionMapper.app. Bundle remains 1.08/build 5. Full v1.09 and its other two slices remain incomplete; no GitHub delivery. See ../../docs/V1.09.1_VERIFICATION.md.

## More effects and settings

Choose Plasma, Animated noise or Particles in Content, alongside the first three effects. Each owner has Effect speed and two colors. Scale/spacing and direction apply to supported patterns; noise/plasma have Contrast; particles have Density (16–256) and Size; noise/particles have Seed. A shared object edits every linked face together. Controls preserve geometry and use the global playback clock.

Current Debug/Release evidence: 105 correctness tests pass; four opt-in benchmark declarations are disabled normally. Product is ../../builds/v1.09.2/ProjectionMapper.app and ../ProjectionMapper.app. User confirmed v1.09.1 visuals; v1.09.2 visual feedback is pending under the user's routine-check preference. No agent screen control used. See ../../docs/V1.09.2_VERIFICATION.md. Presets/seek remain v1.09.3.

## Presets and seeking

The inspector Effect Presets section saves/applies/updates/deletes named effect settings and resets current effect parameters/colors. It preserves mapping and phase. Presets remain in memory with the project until v1.10 saving. Playback offers numeric seek (0–3600 seconds), first-minute scrubbing and elapsed readout. Owner pause/restart controls affect the selected standalone face or every linked face in its object. Global Restart resets all phases; seek updates frozen times too.

Current product: ../../builds/v1.09.3/ProjectionMapper.app and ../ProjectionMapper.app. All 111 correctness tests pass in Debug/Release; profiling is recorded in ../../docs/V1.09.3_VERIFICATION.md. Visual acceptance belongs to the user. Bundle remains 1.08/build 5 pending full v1.09 acceptance; no GitHub delivery.

Local calibration preview: Grid/Checkerboard/Crosshair/White/Black patterns cover visible mapped faces temporarily. Inspector/toolbar/Show menu controls; Control-Command-C toggles Grid/Normal. Master brightness/fades/blackout retain priority, saved content/layout remains intact, and generators retain logical phase. 202 Debug/Release correctness tests passed; product/evidence in builds/v1.12.1/ and app installed at app/ProjectionMapper.app. Bundle stays 1.11/build 8; schema stays 5; source remains local/uncommitted. User visuals pending. See [calibration verification](../../docs/V1.12.1_VERIFICATION.md).

## Current local preview: masks and cutouts

1.12.2 adds face-local polygon boundaries and up to seven holes. Choose Add Face Mask in the face inspector; click Draw Boundary/Draw Hole, place points in the preview or local square, and Finish. Drag/select points, split an edge with Add Point, delete points or use X/Y fields. Mask clipping precedes all content and calibration. Invalid enabled masks suppress their face with a repair warning; disabled masks retain the draft. Grouping, content/looks, input sampling, geometry locks and resets preserve masks.

Final Debug/Release builds passed 217 offscreen correctness tests each, with four opt-in benchmarks skipped and two visible-window tests excluded. Product/evidence: builds/v1.12.2/; installed app: app/ProjectionMapper.app; previous preview preserved. Bundle remains 1.11/build 8; saves use format 6 and migrate formats 1–5. Older app copies cannot open new format 6 packages. User visuals pending. Source remains local/uncommitted. See [current verification](../../docs/V1.12.2_VERIFICATION.md). Next: 1.12.3 editor visibility/join tools and full milestone verification.

## Completed v1.12 Mapping Tools

Bundle 1.12/build 9 is installed at app/ProjectionMapper.app and archived at builds/v1.12/ProjectionMapper.app, with evidence under builds/v1.12.3/. All 225 offscreen correctness checks passed in both Debug/Release; four benchmarks skipped and two visible-window tests excluded. Exact Xcode 27A5237l, universal slices and strict signing verified. Previous preview preserved; user visuals pending. Completed source successfully backed up on GitHub main at b786f55; no release/tag/assets authorized.

The toolbar eye menu and View > Editor Guides show/hide corner/object handles, mask handles, outlines, names and selected edges. Control-Command-H toggles both handle sets; Control-Command-L toggles names; Restore Editor Guides restores defaults. Object inspector stripe/checker actions reveal names/edges for checking Continuous/Repeat mapping. Edge traversal arrows follow output geometry; green joined, cyan deliberate seam, orange mismatch. Temporary guides/patterns are excluded from projects and labels stay out of Test Window output. New/Open/recovery restore runtime defaults. See [milestone verification](../../docs/V1.12.3_VERIFICATION.md). Next: v1.13 Image Import.
