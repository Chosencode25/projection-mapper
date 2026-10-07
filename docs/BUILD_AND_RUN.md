# Build and Run

Required Xcode: **27.0 beta 5 (27A5237l)** at `/Applications/Xcode-beta.app`.

## In Xcode

1. Open `app/ProjectionMapper/ProjectionMapper.xcodeproj` with Xcode-beta.
2. Select **ProjectionMapper** and **My Mac**.
3. Press **Command–R** to build and run.
4. Press **Command–U** for the full suite, including two legacy tests that present native windows. The current offscreen verification subset passes 225 correctness tests; four optional benchmark declarations are skipped unless explicitly enabled. Use the exclusions below for checks without visible windows.

The interface uses SwiftUI and programmatic AppKit, without storyboards/XIBs. Minimum deployment target: macOS 15.0. Local ad-hoc signing needs no paid developer account. Review proposed Xcode settings migrations against the pinned toolchain.

## Standalone local build

Open `app/ProjectionMapper.app` or `builds/v1.12/ProjectionMapper.app` for the completed Mapping Tools milestone. Bundle is 1.12/build 9. This is a universal arm64/x86_64, ad-hoc signed local development build; runtime verification was on Apple Silicon. Previous previews and published release products remain preserved. See [current verification](V1.12.2_VERIFICATION.md). Quit/reopen a running older instance to use the replacement binary.

## Build and test commands

Run from the project root:

```sh
DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer xcodebuild -version

DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer \
xcodebuild -project app/ProjectionMapper/ProjectionMapper.xcodeproj \
  -scheme ProjectionMapper -configuration Release \
  -destination 'platform=macOS,arch=arm64' \
  -derivedDataPath builds/v1.12.3/DerivedData \
  'ARCHS=arm64 x86_64' ONLY_ACTIVE_ARCH=NO build
```

Replace `build` with `test` to run checks; use `-configuration Debug` for Debug. Both final configurations passed 225 offscreen correctness tests, with the two exclusions below and four opt-in benchmarks skipped. The system-wide developer directory stays unchanged.

For the current 225-test correctness subset without presenting windows, append these before `test`:

```sh
'-skip-testing:ProjectionMapperTests/TestOutputCoordinatorTests/normalFrameRestoresAcrossCloseAndNewCoordinator()' \
'-skip-testing:ProjectionMapperTests/MetalRendererTests/nativeMetalOutputSurvivesPresetsResizeAndReopen()'
```

The excluded tests exercise minimize/zoom/frame persistence and native Metal drawable behavior. The optional benchmarks below remain disabled in normal runs. Current evidence: `builds/v1.12.3/Debug-third.xcresult` and `Release-final.xcresult` with their respective logs and JSON summaries. Historical sections below describe earlier deliveries.

## Opt-in benchmarks

Create the output directory first. Run each benchmark separately to avoid workload interference. The `TEST_RUNNER_` prefix forwards variables into Xcode's test runner; the Swift tests read the names without that prefix. Timed Release runs explicitly disable Metal validation; this is separate from ordinary correctness verification.

Exact-resolution matrix (9,000 samples plus warmup/pixel checks):

```sh
mkdir -p builds/v1.08/performance
TEST_RUNNER_PROJECTION_MAPPER_PERFORMANCE_OUTPUT="$PWD/builds/v1.08/performance" \
TEST_RUNNER_MTL_DEBUG_LAYER=0 TEST_RUNNER_MTL_SHADER_VALIDATION=0 \
DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer \
xcodebuild -project app/ProjectionMapper/ProjectionMapper.xcodeproj \
  -scheme ProjectionMapper -configuration Release \
  -destination 'platform=macOS,arch=arm64' \
  -derivedDataPath builds/v1.08/DerivedData \
  '-only-testing:ProjectionMapperTests/RenderPerformanceTests/offscreenPerformanceMatrix()' test
```

For native sizing, five ten-second idle states and three lifecycle stress batches, use `TEST_RUNNER_PROJECTION_MAPPER_NATIVE_OUTPUT` instead of `TEST_RUNNER_PROJECTION_MAPPER_PERFORMANCE_OUTPUT`, and select:

```sh
'-only-testing:ProjectionMapperTests/RenderPerformanceTests/nativeMatrixIdleAndLifecycle()'
```

This native benchmark may present windows; use it only during authorized onscreen checks. Record actual occlusion eligibility rather than assuming visible presentation.

For 100 synthetic invalidation-to-GPU-completion samples, use `TEST_RUNNER_PROJECTION_MAPPER_REDRAW_OUTPUT` and select:

```sh
'-only-testing:ProjectionMapperTests/RenderPerformanceTests/syntheticRedrawLatency()'
```

The synthetic harness does not present a window, deliberately overrides drawing eligibility, and does not measure OS restoration or display latency. The three optional benchmarks were not rerun for v1.08; prior measurements are preserved under builds/v1.04.5/. Raw JSON is written to the requested existing directory. Repeated runs overwrite those JSON files; use a separate output directory to preserve comparisons. Full methods, numbers, aggregation and limitations are in [V1.04.5_VERIFICATION.md](V1.04.5_VERIFICATION.md).

## Shortcuts and use

- Command–N: New Project.
- Command–W: Close editor.
- Command–Q: Quit.
- Control–Command–O: Show Output (open, raise, or restore).
- Control–Command–E: Show Editor.
- Control–Command–S: Show/hide sidebar.
- Control–Command–I: Show/hide inspector.

Projects stay in memory. Name changes trigger discard protection; output actions do not. Select Test Window, then Show Output in the toolbar, inspector or Window menu. Each fresh project owns one initially selected Surface 1. Select its sidebar row to inspect normalized corners; Deselect clears inspection without changing output. One resizable output window draws the same ordered project surfaces as the preview, on black with no editor UI. Close Output keeps the editor working.

Choose HD, Full HD, 4:3, Portrait or 4K in the inspector. The saved simulated resolution controls aspect ratio and metadata independently of native drawable pixels. Output normal size/position is remembered; inaccessible frames recover onto a current screen. Output starts closed on launch. Static scenes draw on demand. v1.04 is locally accepted for Test Mode; physical projector/backing-scale transition checks remain deferred. v1.05 First Surface is implemented. v1.06 corner editing is implemented; v1.07 perspective-correct texture mapping is implemented; multiple surfaces and connected objects (v1.08) are implemented, followed by planned animations (v1.09) and saving (v1.10). Image/video import is scheduled later at v1.13/v1.14; see the reordered roadmap.

## Metal shader compiler component

Building `.metal` sources requires Apple's Metal Toolchain component for the pinned Xcode. The installed component successfully compiles the project; compiler version is recorded in current verification. If missing, install it with the pinned developer directory:

```sh
DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer \
xcodebuild -downloadComponent MetalToolchain
```

## Editing corners

Select Surface 1 in the sidebar, then click one of its four preview handles. Drag to move that corner within the fitted canvas. Arrow keys move the active corner by 0.001 normalized units; Shift uses 0.01. Escape clears the active corner. Click the project-name field to type or move its caret without nudging geometry. Deselect Surface hides editing controls while leaving rendered content unchanged. Geometry edits activate New Project/Close/Quit protection. Both views update live; clean output excludes handles and outline. Save projects with Command-S; reopen with Command-O.

## Multiple surfaces and objects

Use Add Surface, select a face and edit its name, tags, corners, visibility and draw order. Sidebar order is front first. Check two or more faces and choose Group checked faces to give them one content owner and side-by-side input regions. Select the object to edit shared content or Continuous/Repeat mode; face input controls edit only the sampled canvas, preserving output geometry. Object edge controls link and align input boundaries or record a deliberate seam. Duplicate, detach and ungroup preserve the documented ownership policies. This milestone is local only: no source commit or GitHub upload.

## v1.09.1 animation preview

The installed app/ProjectionMapper.app now includes the automatically verified animation preview; its product/evidence are in builds/v1.09.1/. Both configurations passed 102 correctness tests. Use the inspector Content picker for Animated gradient, Moving lines or Moving checkers, then Play in the Playback section. Global speed/restart affect all animated faces without changing mapping. Visual acceptance is pending due to the locked Mac; the last fully accepted v1.08 product remains preserved. See [verification](V1.09.1_VERIFICATION.md). Existing build commands can target builds/v1.09.1/DerivedData for this slice. No bundle bump or GitHub delivery.

## v1.09.2 effects/settings preview

The installed app now includes plasma/noise/particles and effect settings. Product/tests are in builds/v1.09.2/; use that derived-data path for current builds. Both configurations pass 105 correctness tests; four optional benchmark declarations are skipped normally. Routine visual checks are user-performed. See [current verification](V1.09.2_VERIFICATION.md).

To reproduce the bounded mixed-effects workload, create builds/v1.09.2/performance, set TEST_RUNNER_PROJECTION_MAPPER_EFFECT_PERFORMANCE_OUTPUT to its absolute path, use Release with MTL_DEBUG_LAYER=0 and TEST_RUNNER_MTL_DEBUG_LAYER=0, and select only ProjectionMapperTests/MultipleSurfaceGPUTests/mixedEffectsPerformanceMatrix(). This writes mixed-effects.json; use a new directory to preserve a comparison. The six-effect scene has six non-overlapping faces per view and two serial offscreen submissions at each preset, four warmup pairs then 20 measured pairs. It measures GPU execution, not window/display FPS or worst-case overlapping faces.

## v1.09.3 final animation implementation

Installed app/product/evidence are under app/ProjectionMapper.app and builds/v1.09.3/. Use builds/v1.09.3/DerivedData for current commands. Final Debug/Release correctness runs pass 111 tests; four opt-in benchmarks are skipped normally. The effect matrix now includes six mixed faces and eight fully overlapping particle faces per view, with two serial views. Its opt-in command/environment remain the same using a fresh v1.09.3/performance directory. See [verification](V1.09.3_VERIFICATION.md) for bounds, runtime semantics and measured limits. User visual feedback is pending; no screen control or GitHub delivery performed.

## v1.10 Save & Load

Current local source/build is v1.10/build 7. Use builds/v1.10/DerivedData for build/test commands; products are copied to builds/v1.10/ProjectionMapper.app and app/ProjectionMapper.app after verification. File commands: Command-S Save, Shift-Command-S Save As, Command-O Open, Open Recent, Recover Unsaved Project. Projects use .projectionmap packages and reopen paused. Recovery is separate from manual save and updates after two seconds of editing inactivity. See [verification](V1.10_VERIFICATION.md) for automated evidence and user visual checks. v1.09 source is backed up on GitHub; v1.10 is explicitly local/uncommitted. Historical slice descriptions above describe their deliveries at the time.

## v1.11.1 appearance preview

Current preview source/products/evidence use builds/v1.11.1/DerivedData and builds/v1.11.1/ProjectionMapper.app, installed at app/ProjectionMapper.app after verification. Bundle stays 1.10/build 7 until the x.xx milestone boundary. Inspect a standalone face or object for opacity/brightness/crop/flips; member faces inherit object controls until "Override object appearance on this face" is enabled. Schema 3 saves include these controls; schema 1/2 load with defaults. See [verification](V1.11.1_VERIFICATION.md). v1.10 source is backed up at 55d242c; this slice is local/uncommitted. Quit/reopen an already running app to pick up the new binary.

## v1.11.2 editing protection preview

Current source/products/evidence use builds/v1.11.2/DerivedData and builds/v1.11.2/ProjectionMapper.app, installed to app/ProjectionMapper.app after verification. Bundle remains 1.10/build 7. Use sidebar/inspector locks to protect output geometry. Select an object and click/drag its center square, use arrows/Shift-arrows, or inspector steps/normalized offsets to move all members together. Any member lock blocks the whole move. Reset menus clearly separate face/shared controls and input layout; full-face and input-layout resets have confirmations. Schema 4 stores locks; schema 1–3 migrate. See [verification](V1.11.2_VERIFICATION.md). Quit/reopen a running older instance to use this preview. No intermediate commit/upload.

## v1.11 completed Surface Controls milestone

Current tested product is 1.11/build 8 at app/ProjectionMapper.app and builds/v1.11/ProjectionMapper.app, with Debug/Release logs/results in builds/v1.11.3/. Use builds/v1.11.3/DerivedData for current builds. Exact pinned Xcode 27A5237l; macOS 15.0 minimum; universal arm64/x86_64 build, tests run on Apple Silicon. All 184 correctness tests passed; four optional benchmarks skipped.

The project inspector offers Master Output, Looks and Palettes. Add palette slots, then choose a binding beside a selected owner's primary/secondary color. Save New Look captures current content/appearance; Apply preserves mapping/locks and reports missing targets. Palette removal keeps resolved colors. Fade duration accepts 0–30 seconds; fade/restore completes while generators are paused. Immediate Blackout is in the toolbar/Show menu (Command-Shift-B); Restore (Command-Shift-R) fades from black to saved master brightness. Runtime output actions do not dirty the project. Schema 5 libraries/settings save and recover; schemas 1–4 migrate. See [verification](V1.11.3_VERIFICATION.md). Quit/reopen a running older app to use the new binary. User visuals remain pending; no routine screen control is required.

## v1.12.1 local calibration preview

Current product/evidence: builds/v1.12.1/; tested app installed at app/ProjectionMapper.app. Use builds/v1.12.1/DerivedData for current builds. Bundle stays 1.11/build 8; exact Xcode 27A5237l; 202 Debug/Release correctness tests passed, four optional benchmarks skipped. Previous v1.11 app preserved at builds/v1.12.1/Previous-installed.app.

Open Calibration in the inspector or the grid icon in the toolbar. Choose Grid/Checkerboard/Crosshair/White Test/Black Test, or Normal Content to exit. Control-Command-C toggles Grid/Normal; blackout/restore shortcuts are unchanged. Patterns cover visible mapped faces, bypass saved content appearance, and retain master brightness/fades/blackout. Restore keeps the selected pattern; choose Normal Content to return to current project content. Counts are 2–64 and line width 1–4 drawable pixels. Calibration is not saved and resets on successful New/Open/recovery. See [verification](V1.12.1_VERIFICATION.md). Quit/reopen a running older app to use this preview. No intermediate Git delivery; routine visuals belong to the user.

## v1.12.2 local mask preview

Current product/evidence: builds/v1.12.2/; tested app installed at app/ProjectionMapper.app, previous preview at builds/v1.12.2/Previous-installed.app. Use builds/v1.12.2/DerivedData for current builds. Bundle stays 1.11/build 8; exact Xcode 27A5237l; final Debug/Release each passed 217 offscreen correctness tests, four benchmarks skipped and two visible-window tests excluded. Universal slices, strict signing and all delivered file hashes verified.

Select a face in the editor/sidebar, then Add Face Mask in its inspector. Draw Boundary or Draw Hole starts a temporary click-to-place draft in the preview or local square; Finish validates and saves the polygon, Cancel discards it. Drag a point, use Add Point to split the selected edge, delete points down to three, or edit X/Y. Enable Mask preserves a disabled draft; Remove Mask explicitly deletes its boundary/holes. Holes reveal lower faces. Masks stay in original face coordinates when input regions/crop/flips change, follow output corner movement, and remain active under calibration. Invalid enabled masks suppress the face with an inspector warning; repair or disable them. Geometry locks still allow mask edits. Saves/recovery use format 6; formats 1–5 migrate without masks, and older app copies cannot open newly saved format 6 packages. See [verification](V1.12.2_VERIFICATION.md) for limits and user checks. Next: 1.12.3 editor/join tools and milestone verification. No intermediate commit/upload.

## v1.12 completed Mapping Tools

Current tested app: app/ProjectionMapper.app and builds/v1.12/ProjectionMapper.app. Previous installed preview: builds/v1.12/Previous-installed.app. Bundle 1.12/build 9; format 6 projects; exact Xcode 27A5237l. Use builds/v1.12.3/DerivedData for builds/tests. Final Debug-third and Release-final result bundles/logs and summaries show 225 passing offscreen correctness tests each, four optional benchmarks skipped and two visible-window tests excluded. Signing, universal slices and file hashes match the tested Release product.

Use the toolbar eye menu/View > Editor Guides to control handles/outlines/names/edges. Control-Command-H toggles corner/object and mask handles together; Control-Command-L toggles names; Restore Editor Guides restores safe defaults. Picking remains available when handles are hidden; inspector mask editing remains available. Object inspector Vertical Stripes/Horizontal Stripes/Shared Checkerboard reveal names and projected edge labels without editing maps or membership. Patterns obey masks/master output; Return to Normal Content restores content and clocks. New/Open/recovery reset temporary guides/calibration. See [milestone verification](V1.12.3_VERIFICATION.md). User visual acceptance and physical output remain unverified. Source backup pending; no release publication requested.
