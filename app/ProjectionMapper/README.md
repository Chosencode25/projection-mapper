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

Current runnable app: `../ProjectionMapper.app`, **2.01/build 14**, format **9**,
local ad-hoc signing. Current archive: `../../builds/current/`.
V1 authoring remains available. Test Window remains resizable; projector output
requires explicit Open and closes on display/sleep changes. Physical projector,
optical timing, user visual/listening and Intel/older-macOS runtime acceptance
remain pending; Developer ID/notarization remain unestablished.

See [verification](../../docs/V2.01_VERIFICATION.md),
[output guide](../../docs/V2.01_USER_GUIDE.md),
[authoring guide](../../docs/V1_USER_GUIDE.md) and
[cleanup record](../../docs/PROJECT_CLEANUP_2026-10-19.md).
GitHub source backup is authorized by the October 19 request; latest published
download remains v1.15.1. Next independent milestone: v2.02 music/song transport.
