# Local app usability and performance polish — October 19, 2026

Historical build 15 implementation/verification record. The user subsequently
explicitly authorized GitHub delivery of the combined build 16 polish/shortcuts update.
See [current progress](PROGRESS.md) for delivery state; earlier local-only statements
below describe the original implementation, not the later delivery authorization.

User requested improving the current app's appearance, responsiveness and usability,
with **no GitHub delivery until explicitly requested**. This is local refinement of
v2.01, with internal build 15 for this local variant, not a new roadmap milestone or format migration. Current source
baseline is 58a7574; app-code baseline remains the verified 0f8b517 source.

## Plan

1. Give the workspace a calmer grouped toolbar, direct Save, discoverable output
   controls and one-action restoration after blackout. Preserve explicit projector
   opening, Test Mode, keyboard access and unsaved-project protection.
2. Make surface names and selection easier to read; put grouping controls into an
   intentional grouping mode and keep search/selection temporary. Clarify shared
   content and timeline ownership in the inspector.
3. Give more default space to the canvas, bound timeline height and allow hiding it
   while mapping. Improve timeline transport, fitting, clip labels and empty rows.
4. Reduce repeated timeline view/ruler construction and unchanged renderer surface
   preparation. Preserve actual output pixels, masks, clips and media ownership.
5. Make edit/import/media errors visible even when the inspector is hidden. Keep
   disabled/progress states clear without projecting editor diagnostics.
6. Run focused and full offscreen Debug/Release regressions with pinned **Xcode
   27.0 beta 5 (27A5237l)**, verify universal app/signatures and install locally.
   Keep compact evidence and one cache; no commits, pushes, releases or uploads.

## Acceptance boundaries

Toolchain reverified before implementation. Routine visual checks remain
user-performed: use no screen control or routine app launch for this work. Any
automated checks and measured limits will be recorded separately from user visual
acceptance. Physical projector, optical timing, audible synchronization, older
macOS/Intel runtime and notarization remain outside this local polish acceptance.

## Status

Implemented, automatically verified and installed locally as **v2.01/build 15**.
User visual acceptance remains pending. Changes stay uncommitted on
codex/local-app-polish; no GitHub delivery. The plan above now describes the
implemented scope; the final verification/delivery record is below.

## Implemented workflows — verification in progress

- **Save** is directly available in the toolbar. **Tools** groups editor guides,
  calibration patterns, timeline visibility and show controls. Output selection is
  separate from **Open Output**; output still opens only deliberately.
- **Blackout** changes to **Restore** while blacked out or fading to black. The
  status bar also keeps Restore reachable and displays edit errors even with the
  inspector hidden, plus active import/save progress.
- Surface search matches names, object names and face tags. **Group faces…** opens
  checkboxes intentionally; Create Object applies grouping, Cancel clears it. The
  sidebar retains full-name help, visibility/locks and Deselect.
- Shared faces show which object owns their content. Sequenced content explains
  that **Apply Edited Content** copies edited source settings into a selected clip.
- The canvas gets a larger default share of the split. **Control-Command-T** toggles
  the timeline; **Command-Return** plays/pauses without replacing text-field Space.
- The timeline keeps static tracks/ruler outside clock animation, uses one grid
  path, fits complete sequences (including up to one hour), scrolls to the playhead
  and opens a bounded time-jump editor from the time display. Narrow clips show
  adaptive labels/icons; the clip editor scrolls to retain video controls.
- Picking uses the perspective inverse and original-UV mask boundary/holes, so a
  transparent cutout selects the visible face behind it. Invalid enabled masks
  do not intercept picks; disabled masks permit the whole quad.
- Renderer payloads cache vertices, inverse/input matrices and mask arrays. Frame,
  transport and master-output snapshots reuse them when surface definitions and
  calibration mode are unchanged; explicit invalidation retains edits/owner identity.

No portable format or roadmap sequence changed. Earlier GitHub screenshots and
published downloads remain historical to build 14/v1.15.1; this local variant is
not uploaded. The first Debug run was interrupted before its result bundle finished,
so it is not counted as a pass; final verification is being rerun.


## Automated verification so far

Pinned **Xcode 27.0 beta 5 (27A5237l)**. Final Debug on the integrated source passed
**293 correctness tests**, zero failures and zero recorded runtime warnings. Four
optional benchmarks skipped and the two legacy visible-window tests remain excluded.
Evidence: builds/checks/20261019T180716.961174Z-Debug-test.log/.xcresult and
-summary.json; compact copy under builds/local-polish/Debug-summary.json.

Eight added regressions cover mask-aware perspective picking (three), renderer
payload reuse/invalidation/owner swaps with offscreen GPU pixel comparisons (three),
sequence fit/ruler/time-navigation bounds (one), and UI/grouping state remaining
outside saved project/render/history data (one).

The renderer regression observed **one preparation pass across 120 runtime
updates**, versus a preparation on every setScene previously. This is an allocation/
CPU-work reduction, not a measured FPS increase or optical projector result.
The grid and static timeline hierarchy are no longer rebuilt by the outer 30 Hz
playback timer. Existing media lifecycle/save/undo/Test Mode regressions also passed.
Release verification and local binary/archive delivery remain in progress.


## Final verification and local delivery

Final Release also passed **293 correctness tests**, zero failures/recorded runtime
warnings, four optional benchmarks skipped and two legacy visible-window tests
excluded. Evidence: builds/checks/20261019T180853.676770Z-Release-test.log/.xcresult
and -summary.json; compact Debug/Release copies under builds/local-polish/.
The final universal Release build also passed. Existing platform linkd/AVFoundation
messages in logs are distinct from recorded runtime warnings/test failures.

Bundle **2.01/build 15**, format **9**, was installed at app/ProjectionMapper.app and
/Applications/ProjectionMapper.app. Both architectures and strict signatures passed.
All **11 app-file hashes** match the tested Release and the extracted current ZIP.
No running copy was detected; no app was launched or force-quit. Current package:
`builds/current/ProjectionMapper-v2.01-build15-local-macOS-universal.zip`, SHA-256
**f9b8ca44067680b618bfe08512a8a806fbcac77ff3b292b71647699559e06f30**.

Build identity explicitly records the local uncommitted state and source baseline
**58a75748412231fbd33f932c69c47414534c911a**. A binary-safe Local-source-changes.patch
in builds/current/ and the archive captures the app/test/project delta for recovery;
this is not a Git commit. Lightweight prior identity reports are retained under
builds/evidence/pre-local-polish/. The superseded current archive was replaced only
after the new archive was extracted and checked. Packaging staging copies are removed;
one shared Xcode cache remains for ongoing development.

No GitHub calls, commits, pushes, tags, releases or uploads were performed for this
work. Main remains the prior delivered baseline. Routine user visual review of the
new toolbar, sidebar, canvas/timeline split and clip controls is still pending.
Hardware/listening/optical/Intel/older-macOS and notarization limits are unchanged.


Build 15 is superseded locally by build 16 keyboard editing. Its app improvements
remain included. See [current shortcut verification](LOCAL_SHORTCUTS_VERIFICATION.md)
for the 312-test Debug/Release evidence, installed app and current archive.
