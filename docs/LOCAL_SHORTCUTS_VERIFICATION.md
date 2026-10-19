# Local keyboard editing verification — October 19, 2026

Status: implemented, automatically verified and installed locally. The user subsequently
authorized GitHub source delivery, confirmed at **ed0e9f2** on main; details are
recorded in PROGRESS.md and GITHUB_WORKFLOW.md.
Baseline local app: v2.01/build 15. New local variant: v2.01/build 16, format 9.
Plan: [local keyboard editing](LOCAL_SHORTCUTS_PLAN.md). Full bindings and behavior:
[local app guide](LOCAL_APP_GUIDE.md). Pinned toolchain verified: Xcode 27.0 beta 5,
build 27A5237l, at /Applications/Xcode-beta.app.

## Implementation

Shared action definitions drive File/Edit/Show/Timeline/View/Window commands and a
searchable Help → Keyboard Shortcuts reference (Command-/). Space toggles the shared
transport in the editor, Test Output and focused projector output. Native routing is
limited to those windows, respects key-window/event identity, field editor/text input,
modal/sheet state and ongoing mouse drags. Held Space/Delete are consumed without
repeating. Text undo uses the active window's field editor, including reference search.
Focus changes invalidate command availability; native Cut/Copy/Paste remain intact.

Contextual Duplicate/Delete use the selected clip or face/object. Sidebar/canvas
selection clears stale clip context; selecting a timeline track exits mask editing.
Mask Delete changes only the selected point or last draft point. Escape cancels a
mask draft, grouping, mask edit, clip/corner selection or face selection in stages;
physical projector Escape still closes output. Geometry locks and standard undo,
clip overlap/range limits, media ownership and save behavior are reused.

New actions cover surface creation, grouping/ungrouping, lock/visibility/order and
surface navigation; image/video imports; capture/apply clip content; source-preserving
video split and clip nudging; bounded paused seeking, timeline zoom/fit/reveal/snap/
follow, inspectors, output close and explicit audio mute. No shortcut opens output,
enables audio or writes a file without the corresponding deliberate command. Playback
never arms output. New viewport requests stay outside the document/save/history and
are cleared on reset/open. Marketing version and schema are unchanged.

## Automated evidence

The first integrated Debug run passed 307 correctness tests (14 new shortcut tests),
zero failures/recorded runtime warnings, four benchmarks skipped and two legacy
visible-window checks excluded. Log/result/summary stem:
`builds/checks/20261019T182231.559121Z-Debug-test`.

A non-elevated initial build could not access the already installed Metal component
inside the filesystem sandbox. Checks then used the same pinned toolchain with the
required host access; no component download, toolchain migration or system developer
selection change was performed. Known SDK Intel test-framework linker/AppIntents and
platform AVFoundation/linkd diagnostics are separate from recorded test runtime warnings.

Final Debug passed **312 correctness tests**, zero failures/recorded runtime
warnings; four optional benchmarks skipped and two legacy visible-window tests
excluded. This includes **19 shortcut regressions** covering native/non-text focus,
key/modifier routing, hidden windows/foreign events/held keys, real Test Output shared
transport, menu-binding uniqueness, contextual duplicate/delete and undo, stale clip
selection, masks and mask-to-clip transitions, geometry lock/visibility, grouping,
bounded seeking, runtime-only viewport/inspector navigation, clip nudge overlap/range
checks, wrapped surface navigation, video split phase/rate/undo and invalid ranges.
Evidence stem: `builds/checks/20261019T182641.080824Z-Debug-test`.

Final Release also passed **312 correctness tests**, zero failures/recorded runtime
warnings, four optional benchmarks skipped and two legacy visible-window tests
excluded. Evidence stem: `builds/checks/20261019T182829.495054Z-Release-test`.
The final universal Release build succeeded. Evidence:
`builds/checks/20261019T183002.163884Z-Release-build.log`.
Both arm64/x86_64 slices and strict ad-hoc signatures passed; all 11 app-file hashes
match the tested Release product and extracted current ZIP. Source patch reverse
validation passed, including new files. Compact evidence: builds/keyboard-shortcuts/.

Archive: `builds/current/ProjectionMapper-v2.01-build16-local-macOS-universal.zip`,
SHA-256 **c9eec8c5ca6a956679c27607496ecbf549d01029e9ca5183315042793443b579**.
Build identity/checksums/app-file hashes and binary-safe app/source/test/project patch
are beside it. Prior build 15 identity/source-patch evidence is retained under
builds/evidence/pre-keyboard-build16/. Temporary packaging copies are removed; one
shared development cache remains.

Installation initially waited because the app was running. After the user reported
saving and closing it, verified build 16 replaced app/ProjectionMapper.app and
/Applications/ProjectionMapper.app. Both copies pass strict signature checks and all
11 file hashes match the tested Release and extracted archive. No app was launched
or force-quit and no screen control was used. The archive was repacked once to correct
the guide's About build number, then extracted and reverified; the final hash is above.
No Git commits, pushes, tags, releases, uploads or remote checks were performed during
the original local implementation. The subsequent explicit source-delivery request
also adds the full README/standalone shortcut reference. App code has not changed
since the passing runs, so documentation checks reuse that automated evidence.

## Acceptance limits

No routine screen control or app launch is used. The user performs visual review:
try Space outside and inside a name field; Duplicate/Delete on clips versus faces;
mask Delete/Escape; Option-arrow stepping, Command-B video split; timeline Fit/zoom;
and Help reference search. This is not user acceptance yet. Physical projector,
listening/optical timing, Intel/older-macOS runtime and Developer ID/notarization remain
unverified. Steps are nominal 1/30 second, not decoded-frame guarantees. Effect clips
have no phase-offset field, so split is video-only. Clipboard surface cut/paste,
ripple editing, crossfades and music waveforms remain outside this enhancement.
