# Build and Run

Required Xcode: **27.0 beta 5 (27A5237l)** at `/Applications/Xcode-beta.app`.

## In Xcode

1. Open `app/ProjectionMapper/ProjectionMapper.xcodeproj` with Xcode-beta.
2. Select **ProjectionMapper** and **My Mac**.
3. Press **Command–R** to build and run.
4. Press **Command–U** for 60 correctness tests (two require visible native windows). Three optional benchmark declarations are skipped unless explicitly enabled.

The interface uses SwiftUI and programmatic AppKit, without storyboards/XIBs. Minimum deployment target: macOS 15.0. Local ad-hoc signing needs no paid developer account. Review proposed Xcode settings migrations against the pinned toolchain.

## Standalone local build

Open `app/ProjectionMapper.app` or `builds/v1.05/ProjectionMapper.app`: the accepted Apple Silicon Release build with a project-owned Surface 1, sidebar selection and corner inspector. Bundle remains 1.04.2/build 4; the published v1.04.2 and earlier local products remain preserved. This is a local development build, not a notarized public installer. See [current verification](V1.05_VERIFICATION.md).

## Build and test commands

Run from the project root:

```sh
DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer xcodebuild -version

DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer \
xcodebuild -project app/ProjectionMapper/ProjectionMapper.xcodeproj \
  -scheme ProjectionMapper -configuration Release \
  -destination 'platform=macOS,arch=arm64' \
  -derivedDataPath builds/v1.05/DerivedData build
```

Replace `build` with `test` to run all correctness tests; use `-configuration Debug` for Debug. Both configurations passed all 60 correctness tests. The system-wide developer directory stays unchanged.

For the 58-test subset without presenting windows, append these before `test`:

```sh
'-skip-testing:ProjectionMapperTests/TestOutputCoordinatorTests/normalFrameRestoresAcrossCloseAndNewCoordinator()' \
'-skip-testing:ProjectionMapperTests/MetalRendererTests/nativeMetalOutputSurvivesPresetsResizeAndReopen()'
```

The excluded tests exercise minimize/zoom/frame persistence and native Metal drawable behavior. The optional benchmarks below remain disabled in normal runs. Current complete evidence: `builds/v1.05/Debug-Acceptance.xcresult` and `Release-Acceptance.xcresult` with their respective logs.

## Opt-in benchmarks

Create the output directory first. Run each benchmark separately to avoid workload interference. The `TEST_RUNNER_` prefix forwards variables into Xcode's test runner; the Swift tests read the names without that prefix. Timed Release runs explicitly disable Metal validation; this is separate from ordinary correctness verification.

Exact-resolution matrix (9,000 samples plus warmup/pixel checks):

```sh
mkdir -p builds/v1.05/performance
TEST_RUNNER_PROJECTION_MAPPER_PERFORMANCE_OUTPUT="$PWD/builds/v1.05/performance" \
TEST_RUNNER_MTL_DEBUG_LAYER=0 TEST_RUNNER_MTL_SHADER_VALIDATION=0 \
DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer \
xcodebuild -project app/ProjectionMapper/ProjectionMapper.xcodeproj \
  -scheme ProjectionMapper -configuration Release \
  -destination 'platform=macOS,arch=arm64' \
  -derivedDataPath builds/v1.05/DerivedData \
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

The synthetic harness does not present a window, deliberately overrides drawing eligibility, and does not measure OS restoration or display latency. The three optional benchmarks were not rerun for v1.05; prior measurements are preserved under builds/v1.04.5/. Raw JSON is written to the requested existing directory. Repeated runs overwrite those JSON files; use a separate output directory to preserve comparisons. Full methods, numbers, aggregation and limitations are in [V1.04.5_VERIFICATION.md](V1.04.5_VERIFICATION.md).

## Shortcuts and use

- Command–N: New Project.
- Command–W: Close editor.
- Command–Q: Quit.
- Control–Command–O: Show Output (open, raise, or restore).
- Control–Command–E: Show Editor.
- Control–Command–S: Show/hide sidebar.
- Control–Command–I: Show/hide inspector.

Projects stay in memory. Name changes trigger discard protection; output actions do not. Select Test Window, then Show Output in the toolbar, inspector or Window menu. Each fresh project owns one initially selected Surface 1. Select its sidebar row to inspect normalized corners; Deselect Surface clears inspection without changing output. One resizable output window draws the same project surface as the preview, on black with no editor UI. Close Output keeps the editor working.

Choose HD, Full HD, 4:3, Portrait or 4K in the inspector. The saved simulated resolution controls aspect ratio and metadata independently of native drawable pixels. Output normal size/position is remembered; inaccessible frames recover onto a current screen. Output starts closed on launch. Static scenes draw on demand. v1.04 is locally accepted for Test Mode; physical projector/backing-scale transition checks remain deferred. v1.05 First Surface is implemented. v1.06 introduces draggable corner nodes and keyboard nudging.

## Metal shader compiler component

Building `.metal` sources requires Apple's Metal Toolchain component for the pinned Xcode. The installed component successfully compiles the project; compiler version is recorded in current verification. If missing, install it with the pinned developer directory:

```sh
DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer \
xcodebuild -downloadComponent MetalToolchain
```
