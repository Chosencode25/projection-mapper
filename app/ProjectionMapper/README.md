# Projection Mapper — v1.14 Video Import and Timeline Integration

Native SwiftUI/programmatic AppKit editor with shared Metal preview/Test Output and AVFoundation video playback. Required Xcode **27.0 beta 5 (27A5237l)**; minimum macOS **15.0**. Source is entirely code-based.

Open ProjectionMapper.xcodeproj with Xcode-beta, select ProjectionMapper/My Mac, then Command–R. Command–U includes two legacy visible-window tests; use the exclusions in [build instructions](../../docs/BUILD_AND_RUN.md) for offscreen verification.

The signed universal 1.14/build 11 app is delivered at ../ProjectionMapper.app and archived in ../../builds/v1.14/. Quit/reopen an older running instance. Independent/connected surfaces, geometry/input maps, animations, looks/palettes, masks/calibration, images/reference photos and the object timeline are implemented. Video adds safe MP4/MOV import, source ranges/speed/looping, shared-owner frames, explicit mute/device controls and portable media saves/recovery. Project format 9 migrates formats 1–8; loading is paused with runtime audio disabled.

258 correctness tests passed in each Debug/Release configuration, plus the final 13-test Release video/profile run. Four optional benchmarks skipped and two visible-window tests excluded. User visual/listening acceptance remains pending; Intel/older-macOS runtime and physical projector operation remain unverified.

See [video usage/demo](../../docs/VIDEO_IMPORT_GUIDE.md), [verification](../../docs/V1.14_VERIFICATION.md) and [progress](../../docs/PROGRESS.md). Next: v1.15 undo/redo, readiness and polish. Generated apps/caches stay out of source commits; no release publication is included in this milestone.
