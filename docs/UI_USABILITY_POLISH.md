# Local UI usability polish — v1.12

Requested October 7, 2026. This is local interface work on v1.12, not the v1.13 image-import milestone. Do not commit or upload it under the current milestone-only policy.

## Observed in the running app

The right inspector stacks project, playback, show output, calibration, surface appearance, content, input mapping, masks and output details into one long scroll. Choosing content requires scrolling past unrelated project/show controls. Frequent operations and advanced tools compete for space. The toolbar has unlabeled guide/calibration icons and lacks quick playback or project save/open controls.

The user's existing unsaved mapping was first saved through the app as `builds/ui-polish/Before UI Review.projectionmap`. It is preserved separately from the disposable review project.

## Implementation

1. Provide focused Edit, Show and Project tabs. Keep selection/content in Edit, playback/master/calibration/output in Show, and project name/libraries in Project.
2. Place content near the top of selection editing. Collapse masks, appearance, input mapping, geometry and organization into labeled sections. Keep lock/visibility and invalid output warnings immediately visible.
3. Add Project/Open/Save and Add/Group dropdowns, labeled Guides/Calibrate menus, quick Play/Pause and a Show menu. Keep emergency Blackout directly available.
4. Widen the inspector, route explicit surface/object selection back to Edit, and keep navigation outside saved documents.
5. Verify with pinned Xcode, install locally, then exercise the new workflows in the actual app. Preserve v1.12's original built snapshot and GitHub history.

## Verification

Implemented and verified locally. Exact Xcode 27.0 beta 5 (27A5237l) confirmed. Final Debug and Release each passed 226 correctness tests with zero failures; four opt-in benchmarks skipped and the same two legacy visible-window tests explicitly excluded. The added navigation check verifies that tab changes do not modify saved project data, dirty state or the render scene; valid face selection and new/open return to Edit while invalid selection is ignored.

Evidence: `builds/ui-polish/Debug-delivered.log/.xcresult`, `Debug-delivered-summary.json`, `Release-final.log/.xcresult`, `Release-summary.json`, and `Release-file-hashes.json`. An initial test compilation used the wrong dirty-state property in the new test; corrected before the passing runs. The results retain an existing offscreen Metal test layout-constraint warning; no failures.

The final universal arm64/x86_64 Release product was installed as `app/ProjectionMapper.app` and archived as `builds/ui-polish/ProjectionMapper.app`. Strict deep signing checks passed. Complete file hashes match the tested Release product, installed app and archive. Bundle remains 1.12/build 9, macOS 15 minimum and package format 6. Prior installed app preserved as `builds/ui-polish/Previous-installed.app`; the original v1.12 milestone build remains intact.

## Direct computer-use acceptance

Agent performed these checks under the user's explicit request; this does not count as user-reported visual approval:

- Reviewed the original running app, including the long inspector and content menu. Saved the user's unsaved perspective quad as Before UI Review before quitting the old running instance.
- Used a disposable preview to choose Animated gradient, start animation from the top bar, return from Show to Edit by selecting a face, expand Masks and add an enabled face mask. Saved through the new Project menu as UI Review.projectionmap.
- Used the final installed Release app to inspect the shorter Show panel and Project/library tabs. Opened the saved animation/mask fixture through Project > Open; its content and mask survived.
- Added Surface 2 through Add > Surface, checked both surfaces and grouped them through Add > Group checked surfaces. Object inspector exposes shared content and labeled advanced sections. Saved these fixture changes.
- Triggered toolbar Blackout and restored using Show > Restore brightness; the Show panel confirmed Normal, 100% brightness.
- Reopened Before UI Review, confirming the user's original perspective quad and clean state. Opened Test Output through the top bar and confirmed the mapped content without editor handles. Closed output and left the updated editor open on the user's preserved mapping.
- Reviewed at the normal 1200-point window and a larger zoomed window. Border-drag attempts did not change window size, so the minimum-width compact toolbar fallback is implemented but not claimed as visually verified.

All UI interactions used Computer Use. All code/build/file work used filesystem tools. No commit, push, tag, release or GitHub upload was performed. Local branch: codex/ui-usability-polish, based on 4e92123. The next roadmap milestone remains v1.13 Image Import.
