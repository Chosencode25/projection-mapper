# Projection Mapper — v2.01

SwiftUI/programmatic AppKit editor with shared Metal preview/Test/Projector Output
and AVFoundation video. Required **Xcode 27.0 beta 5 (27A5237l)**; macOS **15.0+**.

Open `ProjectionMapper.xcodeproj` in Xcode-beta, select ProjectionMapper / My Mac,
then Command-R. From the repository root:

```sh
python3 app/scripts/project.py doctor
python3 app/scripts/project.py build
python3 app/scripts/project.py test --configuration Debug
python3 app/scripts/project.py test --configuration Release
python3 app/scripts/project.py clean
```

The helper verifies the exact toolchain, builds universal binaries, excludes the
two legacy visible-window tests, saves check evidence and shares one disposable cache.
`clean` previews; `clean --apply` removes only that cache.
See [build instructions](../../docs/BUILD_AND_RUN.md) for details.

Current source: **2.01/build 16 — workspace polish and keyboard editing**, format **9**.
After building, open the Release app path printed by the helper. In the maintained
local workspace, the verified app is also installed at `../ProjectionMapper.app`;
local archives stay under `../../builds/current/` and are excluded from Git.

Space plays/pauses; Command-D duplicates; Delete follows the selection;
Command-/ opens the searchable reference. See [all shortcuts](../../docs/KEYBOARD_SHORTCUTS.md)
and the [current app guide](../../docs/LOCAL_APP_GUIDE.md).

Debug and Release each passed **312 correctness tests**, zero failures/recorded
runtime warnings; four optional benchmarks skipped and two visible-window tests
excluded. See [shortcut verification](../../docs/LOCAL_SHORTCUTS_VERIFICATION.md),
[earlier polish evidence](../../docs/LOCAL_APP_POLISH_2026-10-19.md),
[output guide](../../docs/V2.01_USER_GUIDE.md) and [authoring guide](../../docs/V1_USER_GUIDE.md).

The user explicitly authorized GitHub source delivery of this update on October 19.
The published app download remains v1.15.1; no new release/tag is part of this delivery.
Test Window remains resizable; projector output requires explicit Open and closes
on display/sleep changes. Physical projector/optical timing, user visual/listening
and Intel/older-macOS runtime acceptance remain pending. Signing is local ad-hoc;
Developer ID/notarization remain unestablished. Next independent milestone: v2.02.
