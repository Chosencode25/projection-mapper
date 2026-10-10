# Projection Mapper — v1.15 V1 Completion

Native SwiftUI/programmatic AppKit editor with shared Metal preview/Test Output and AVFoundation video. Required Xcode **27.0 beta 5 (27A5237l)**; minimum macOS **15.0**. Code-only interface.

Open ProjectionMapper.xcodeproj with Xcode-beta, select ProjectionMapper/My Mac, then Command–R. Command–U includes two legacy visible-window tests; use exclusions in [build instructions](../../docs/BUILD_AND_RUN.md) for offscreen verification.

Universal locally ad-hoc signed **1.15/build 12** is delivered at ../ProjectionMapper.app and ../../builds/v1.15/. Quit/reopen an older instance. V1 includes independent/connected faces, mapping/input joins, effects, looks/palettes, masks/calibration, images/reference photos, video/explicit muted audio, object timeline, portable saves/recovery, bounded undo/redo and readiness. Format 9 migrates formats 1–8; opens paused/audio-disabled. Help provides a protected unique-identity portable demo and guide.

269 correctness tests passed in Debug/Release with zero failures/runtime warnings; four optional benchmarks skipped and two visible-window tests excluded. Bounded mixed workload evidence is in [verification](../../docs/V1.15_VERIFICATION.md). User visual/listening acceptance, Intel/older macOS and physical projector runtime are unverified. The full V1 release packages the verified universal app, guide, installation notes and checksums. Developer ID/notarization remain unestablished; repository visibility stays private.

See [V1 guide](../../docs/V1_USER_GUIDE.md), [progress](../../docs/PROGRESS.md) and [V2 roadmap](../../docs/V2_ROADMAP.md). Next development is v2.01 physical output, preserving Test Mode. Generated builds/caches stay out of commits.
