# Project Progress

Last updated: October 6, 2026.

## Current state

v1.11 Surface Controls is implemented and automatically verified: all **184 correctness tests passed in Debug and Release**, with four optional benchmarks skipped. Bundle **1.11/build 8** is installed at app/ProjectionMapper.app; tested universal product is under builds/v1.11/, evidence under builds/v1.11.3/. The previous preview is preserved. Looks, palettes and master brightness/fade/blackout complete all three slices. Source backup is ready for milestone Git delivery; last confirmed remote main remains v1.10 at 55d242c until successful push. Routine visuals belong to the user and remain pending; no screen control was used. Latest published release remains v1.04.2. Next development milestone: v1.12 Mapping Tools.

## Completed

- [x] Recover V1 roadmap and v1.01 scope from earlier project chats.
- [x] Record code-based interface, Test Mode, and exact Xcode requirements.
- [x] Verify /Applications/Xcode-beta.app matches the required build.
- [x] Create Xcode project and shared ProjectionMapper scheme.
- [x] Set and document macOS 15.0 minimum deployment target.
- [x] Implement project model, naming, timestamps, and session state.
- [x] Build toolbar, sidebar, 16:9 empty canvas, inspector, and status area.
- [x] Connect New Project, panel toggles, menus, shortcuts, and About.
- [x] Implement Cancel/Discard protection for reset, close, and quit.
- [x] Verify editor reopening and default, minimum, and larger layouts.
- [x] Pass five focused model/session tests.
- [x] Produce an ad-hoc signed local development build.
- [x] Add build/run instructions and acceptance record.

## Current acceptance and next milestone

v1.11.2 adds output-geometry locks, bounded whole-object translation and explicit reset scopes while preserving content/layout identities and clocks. See [slice verification](V1.11.2_VERIFICATION.md) and [three-slice plan](V1.11_PLAN.md). User save/recovery/appearance and locking/movement/reset visuals remain pending. v1.11.3 is now implemented; see [final slice verification](V1.11.3_VERIFICATION.md). Next: v1.12 Mapping Tools.

## Scope and limitations

Projects can be saved/opened as portable .projectionmap packages. Output selection/preferences, a separate resizable Test Window, editable perspective surfaces and static connected-object mapping are implemented. Six built-in effects and shared playback are implemented; generator presets/seeking and scoped runtime playback are implemented; saving/recovery are implemented; appearance/crop/flip are implemented; locks/group movement/scoped resets are implemented; looks/palettes, master controls, masks and imports remain later work. Physical projector output remains deferred. Runtime verification used Apple Silicon on the development Mac running macOS 27.0; Intel and older macOS runtime compatibility are unverified. Release includes arm64 and x86_64 slices.

See [V1.11.2_VERIFICATION.md](V1.11.2_VERIFICATION.md) for current evidence and [BUILD_AND_RUN.md](BUILD_AND_RUN.md) for instructions.

## GitHub version history

Private repository: https://github.com/Chosencode25/projection-mapper. The initial source snapshot is v1.01; its release notes are in releases/v1.01.md. Follow GITHUB_WORKFLOW.md for future milestone history.

## v1.02 implementation

- [x] Shared toolbar/inspector destination selection and Test Window default.
- [x] AppKit/Core Graphics display snapshots, names, UUIDs, metadata, mirroring and editor-screen eligibility.
- [x] App-owned coalesced discovery with screen changes, activation, wake, and manual refresh.
- [x] Explicit preference persistence, startup restoration, safe fallback, and reconnect without automatic switching.
- [x] Aspect-aware empty canvas, output details/status, scrollable inspector, version 1.02/build 2.
- [x] Sixteen focused output tests plus the existing five session tests passed.
- [x] No-external-display runtime, project reset protections, packaged app, About, panel shortcut, and synthetic minimum-size portrait/long-name layout checks.
- [x] Build and signature verification; preview ZIP and checksum published in the private v1.02-preview.1 prerelease.
- [ ] Deferred: physical extended-display metadata, unplug/reconnect, saved external preference relaunch, mirroring, editor movement, scaling/rotation.
- [ ] Final v1.02 hardware acceptance remains deferred. Its preview tag/assets are preserved while Test Mode development proceeds.

The plan is [V1.02_PLAN.md](V1.02_PLAN.md). Current verification is [V1.02_VERIFICATION.md](V1.02_VERIFICATION.md). Preview notes are [releases/v1.02-preview.1.md](releases/v1.02-preview.1.md).

## v1.03.1 implementation

- [x] One app-owned observable Test Output window; normal native controls and plain black content.
- [x] Toolbar/inspector/Window menu open/close actions and shared open/closed status.
- [x] Duplicate prevention, minimize restoration, native close/reopen, external destination guard.
- [x] Project reset independent of output; successful editor close/quit cleanup, Cancel preserving both windows.
- [x] Seven focused AppKit window tests plus all 21 regressions passed.
- [x] Local runtime checks and pinned-Xcode Release build/signature verification.
- [x] Published v1.03.1 app/checksum and advanced main to the accepted Test Mode milestone.

Plan: [V1.03.1_PLAN.md](V1.03.1_PLAN.md). Verification: [V1.03.1_VERIFICATION.md](V1.03.1_VERIFICATION.md).

## Version-history preference — October 5, 2026

Small changes are preserved by commits pushed to the private repository. Full releases, version bumps, tags, and downloadable archives are reserved for substantial milestones or explicit requests. Existing published versions remain preserved. This workflow-only update requires no app build.

## v1.03.2 implementation

- [x] HD, Full HD, 4:3, Portrait, and 4K presets in the Test Window inspector.
- [x] Resolution preference saved separately from project data; HD default and invalid-value fallback.
- [x] Editor preview/details and existing output window update immediately without changing the window size or project state.
- [x] Centered aspect-preserving black output surface and black margins; native window resizing preserves simulated resolution.
- [x] All 31 tests passed with the pinned Xcode toolchain, including preset persistence, fitted geometry, live window updates, resizing, reset, and session restoration.
- [x] Native runtime checks: Portrait/Full HD selection, minimized output restoration, live window title/canvas metadata, and relaunch restoring Full HD with output closed.
- [x] Tested Debug app copied to builds/v1.03.2/ProjectionMapper.app and its signature verified.

Plan: [V1.03.2_PLAN.md](V1.03.2_PLAN.md). Test evidence: builds/v1.03.2/test.log and Tests.xcresult (local, excluded from Git). This is a source-history update; no version bump, tag, archive, or release. Bundle version remains the last published v1.03.1/build 3. Rendering remains scheduled for v1.04; window geometry persistence/navigation for v1.03.3.

## v1.03.3 implementation

- [x] Normal Test Output frame saved on move/resize/close, separately from project state and simulated resolution.
- [x] Reopen and new-coordinator restoration; launch remains closed.
- [x] Invalid stored values fall back to the default window; offscreen and oversized frames fit a current screen's visible area. Multi-screen selection, removed-screen recovery, and minimum dimensions verified with synthetic screen frames.
- [x] Show Output naming throughout toolbar/inspector/menu; Control–Command–O shows/restores output and Control–Command–E raises the editor.
- [x] Minimize and zoom preserve the normal saved frame. Zoom transition event ordering is guarded; fullscreen transitions use the same guard.
- [x] All 35 tests passed with Xcode 27.0 beta 5 (27A5237l), including native AppKit move/resize callbacks, close/reopen, new-coordinator restoration, minimize/show, zoom/close restoration, preference validation, and existing regressions.
- [x] Native running-app checks confirmed both new shortcuts, minimized-output restoration, consistent controls, panel shortcuts, and closed startup with the existing 4K preference preserved.
- [x] Refreshed builds/v1.03.3/ProjectionMapper.app from the tested Debug build and verified its signature.

Plan: [V1.03.3_PLAN.md](V1.03.3_PLAN.md). Final evidence: builds/v1.03.3/test.log and Tests-zoom-fix.xcresult (local, excluded from Git). Native pointer-driven move/resize checks were inconclusive in the automation surface; actual NSWindow frame changes and restoration passed the AppKit tests. Fullscreen animation and physical display removal have not been runtime-tested. Earlier minimum-layout checks remain applicable; no editor layout structure changed. The fitted output surface needs no further restructuring before v1.04. No version bump, tag, archive, or release; the bundle remains v1.03.1/build 3.

## v1.04 planning — October 5, 2026

The five-slice renderer breakdown and completion criteria are saved in [V1.04_PLAN.md](V1.04_PLAN.md), individual slice plans, and the roadmap. Relative milestone difficulty estimates are recorded in the roadmap as subjective estimates. This documentation update changes no app behavior; the latest verified app remains v1.03.3 with 35 passing tests.

- [x] v1.04.1 — Metal Foundation (implemented and locally verified).
- [x] v1.04.2 — First Rectangle (implemented and locally accepted).
- [ ] v1.04.3 — Shared Editor Preview.
- [ ] v1.04.4 — Rendering Lifecycle.
- [ ] v1.04.5 — Performance and Acceptance.

v1.04.1 is implemented and locally verified; the other four remain planned. Test and push each completed slice; no automatic release/tag/version bump. Physical projector implementation/reconnect checks remain deferred.

## v1.04.1 implementation

- [x] Independent Metal renderer initializes the device/command queue and clears the fitted Test Output surface to a fixed blue diagnostic color.
- [x] On-demand MTKView drawing; simulated resolution remains independent of native drawable size. Existing black margins, preferences, window ownership, and navigation are preserved.
- [x] App-visible initialization error text with injected device/queue failure verification.
- [x] All 38 tests pass with the exact pinned toolchain, including actual GPU texture readback and native Metal window preset/resize/close/reopen checks.
- [x] Running-app checks confirmed visible output and margins at 4K and Portrait, live resolution changes, close/reopen, minimize/restore, and both navigation shortcuts. Original 4K preference restored.
- [x] Tested Debug app copied to builds/v1.04.1/ProjectionMapper.app; ad-hoc signature verified.

Plan: [V1.04.1_PLAN.md](V1.04.1_PLAN.md). Verification: [V1.04.1_VERIFICATION.md](V1.04.1_VERIFICATION.md). No frame-rate/4K-performance claim; actual performance measurement is v1.04.5. The rectangle and shared editor preview remain planned. No bundle version bump, tag, archive, or release.

## v1.04.2 development — steps 1–2

On `codex/v1.04.2-first-rectangle`, based on tested v1.04.1 commit `ba34723`. Exact Xcode build reverified. Apple Metal Toolchain component **27A5237l** installed for shader compilation.

- [x] Step 1: verify toolchain and create feature branch from tested main.
- [x] Step 2: compiled vertex/fragment shaders and initialized BGRA8 render pipeline, with visible library/function/pipeline errors. All **40 tests pass**, including actual shader GPU pixel readback and injected failure handling.
- [ ] Steps 3–7: rectangle drawing, normalized scene geometry, sizing integration, full acceptance, and advancement of tested main.

The running output remains the v1.04.1 blue diagnostic clear; shader/pipeline creation is ready for step 3. `main` remains the completed v1.04.1 milestone. Interim tested app: `builds/v1.04.2/step2/ProjectionMapper.app`. Evidence: [V1.04.2_VERIFICATION.md](V1.04.2_VERIFICATION.md). This is partial feature-branch work, not completed v1.04.2 acceptance. No release/tag/version bump.

## v1.04.2 development — step 3

- [x] Draw a temporary orange rectangle on black using the compiled Metal pipeline and two triangles. Temporary clip-space vertices precede normalized scene storage in step 4.
- [x] All 40 tests pass with the exact pinned Xcode, including every-pixel GPU rectangle/background verification and existing native window/preset regressions.
- [x] Running step-3 app visibly draws the rectangle at Full HD and after native close/reopen. Signature verified; local app is `builds/v1.04.2/step3/ProjectionMapper.app`.
- [ ] Steps 4–7 and full v1.04.2 acceptance remain pending; main remains v1.04.1. Work preserved on the feature branch without release/tag/bundle bump.

Latest feature-branch output is now the rectangle rather than the step-2 diagnostic clear. See [V1.04.2_VERIFICATION.md](V1.04.2_VERIFICATION.md).

## v1.04.2 development — step 4

- [x] Four immutable normalized scene corners with top-left origin, converted to Metal clip positions and two triangles at render time.
- [x] All 42 tests pass with pinned Xcode, including off-center GPU pixel checks, coordinate extents/center, and stored geometry unchanged through preset/window changes.
- [x] Running app confirms the centered rectangle retains its appearance. Local signed/tested app: `builds/v1.04.2/step4/ProjectionMapper.app`.
- [ ] Steps 5–7 remain pending; full v1.04.2 acceptance and advancement of main have not occurred.

Latest feature-branch geometry now uses normalized corners; the step-3 appearance is preserved. See [V1.04.2_VERIFICATION.md](V1.04.2_VERIFICATION.md). Intermediate work is saved on the feature branch without release/tag/version bump.

## v1.04.2 development — step 5

- [x] Record step-5 plan before implementation; explicitly enable automatic native drawable resizing. Existing aspect fitting required no fix.
- [x] All 43 tests pass: live five-preset switching in wide/tall/square native windows, actual backing drawable dimensions, window/geometry preservation, and GPU coverage across landscape/4:3/portrait shapes.
- [x] Running app checked 4K, Portrait, and 4:3 fitting; original 4K preference restored and output closed. Signed/tested local app: `builds/v1.04.2/step5/ProjectionMapper.app`.
- [ ] Steps 6–7 remain pending; full v1.04.2 acceptance and advancement of main have not occurred.

Simulated target resolution remains independent of drawable pixel dimensions. See [V1.04.2_VERIFICATION.md](V1.04.2_VERIFICATION.md). This feature-branch checkpoint has no release/tag/version bump.

## v1.04.2 development — step 6

- [x] Local rectangle acceptance passed: all five presets visually checked; running minimize/restore and native close/reopen redraw confirmed.
- [x] Reviewed unchanged implementation and its complete 43-test passing run for GPU geometry/pixels, failure handling, native wide/tall/square windows, and existing regressions. Required Xcode build rechecked; strict app signature verified.
- [ ] Step 7 delivery/main advancement remains pending. Main still contains completed v1.04.1; accepted feature implementation remains at `0ddacc1` with documentation checkpoints on the feature branch.

No app change or repeated test run was needed in this acceptance-only step. Tested app remains `builds/v1.04.2/step5/ProjectionMapper.app`. See [acceptance record](V1.04.2_VERIFICATION.md). Original 4K preference restored and output closed; no release/tag/version bump.

## v1.04.2 delivery — step 7

All seven steps are complete. The user explicitly requested a release during delivery, superseding the earlier source-only checkpoint plan. Bundle advanced to v1.04.2/build 4; all 43 Release tests passed with pinned Xcode. Signed Apple Silicon Release app copied to `builds/v1.04.2/ProjectionMapper.app`, runtime rendering/version checked, and ZIP/checksum prepared. Feature source is finalized for main and the v1.04.2 development prerelease; see [release notes](releases/v1.04.2.md). Earlier step entries are historical checkpoints.

Publication verified: non-draft development prerelease at [v1.04.2](https://github.com/Chosencode25/projection-mapper/releases/tag/v1.04.2), tag fixed at tested source `afd2440`. Both app ZIP and checksum assets report uploaded; GitHub archive digest matches the local SHA-256. Main advanced to tested source, with this subsequent documentation confirmation. Next: v1.04.3 Shared Editor Preview. Performance measurements and projector implementation remain deferred.


## v1.04.3 implementation

- [x] Session-owned immutable RenderScene contains normalized geometry and color; both views receive it.
- [x] Reusable MetalSceneView supports editor preview and Test Output with separate renderers/drawables, the same pipeline implementation, and aspect fitting.
- [x] Replaced the empty canvas with rendered content; editor caption/border stay outside clean output.
- [x] All 44 Debug tests pass, including hosted SwiftUI/AppKit preview and GPU pixel checks from both renderers with an injected green scene across all five presets.
- [x] Running app checked matching 4K/Portrait content, panel toggles, New Project, and preview with output closed. Restored 4K and both panels.
- [x] Tested Debug app copied to builds/v1.04.3/ProjectionMapper.app and strict signature verified.

Source delivery through codex/v1.04.3-shared-preview into main; no new release/tag/archive or bundle bump. Evidence: [V1.04.3_VERIFICATION.md](V1.04.3_VERIFICATION.md). Next: v1.04.4 Rendering Lifecycle; lifecycle stress and performance acceptance remain planned.


## v1.04.4 implementation

- [x] Gate on-demand drawing by attachment, visibility/occlusion, minimization, hiding, and valid surface size; re-invalidate when eligible.
- [x] Stop/release output drawables and detach content/delegate on close; clear editor hosting content on close/termination.
- [x] Add injectable presentation so automated window checks do not appear on the user's desktop.
- [x] Six new lifecycle/GPU/resource tests; 48 automated Debug tests passed, with two visible-window checks excluded.
- [x] Preserve separate editor/output rendering and verify weak view/renderer deallocation over 20 output cycles.
- [x] Deliver signed local Debug app in builds/v1.04.4/ and, as requested, app/ProjectionMapper.app; commit/push tested source into main without release/tag/version bump.
- [ ] Interactive minimize/restore, occlusion wakeup, navigation, backing transitions, and quit acceptance: not performed because the user prohibited onscreen app use.

Evidence and exclusions: [V1.04.4_VERIFICATION.md](V1.04.4_VERIFICATION.md). v1.04.5 performance/final acceptance remains planned.


## v1.04.4 onscreen follow-up

- [x] User authorized the two previously deferred onscreen tests; both passed with the pinned Xcode.
- [x] Verified native minimize/restore/zoom/frame persistence and native drawable dimensions across five presets, window shapes, and close/reopen.
- [x] Updated the drawable test’s obsolete always-enabled assumption to honor actual occlusion eligibility; narrowed observer cleanup to lifecycle notification names.
- [x] Remaining 48 headless regressions passed again; all 50 tests passed across the two runs. Refreshed signed app copies and saved changes to GitHub.
- [ ] Broader visible-frame occlusion wakeup, backing-scale transitions, editor navigation, and quit acceptance remain pending.

Evidence: [V1.04.4_VERIFICATION.md](V1.04.4_VERIFICATION.md). Previous exclusions above describe the original file-only delivery.


## v1.04.5 detailed planning

Expanded [V1.04.5_PLAN.md](V1.04.5_PLAN.md) into seven implementation/delivery steps with exact texture sizes, sampling counts, lifecycle stress workloads, measurement limits, and acceptance criteria. Plan only: no renderer changes, new build, or performance results. Preserve the user's file-only workflow; broader visual checks require user participation or specific authorization.


## v1.04.5 implementation and acceptance

- [x] Add optional bounded diagnostics, default off, without continuous production drawing.
- [x] Four new regular correctness tests; all 54 regular tests passed in Debug and Release. Three benchmarks are opt-in (57 declarations total).
- [x] Measure all five exact texture resolutions, one/two-view queues: 9,000 samples with GPU status and representative pixels verified.
- [x] Verify 30 native drawable records and zero submissions in five settled occluded idle states. Actual Release app idle samples supplement counters.
- [x] 150 window/view cycles and 15,000 preset changes release weak ownership; peak RSS stable across three batches.
- [x] 100 synthetic request-to-GPU completions passed; distinguish synthetic timing from OS restoration and display presentation.
- [x] Complete authorized actual-app restore/occlusion, shortcuts/panels, compact/larger portrait layouts, reset/close/quit protection and final process cleanup.
- [x] Deliver signed Release app copies and preserve source on GitHub; no bundle bump, tag, archive or release.
- [ ] Deferred: backing-scale transitions, projector/external-display physical acceptance, Intel and older macOS runtime checks.

All seven planned steps are complete for local Test Mode. Earlier entries describe historical checkpoints. Evidence: [V1.04.5_VERIFICATION.md](V1.04.5_VERIFICATION.md). Next: v1.05 First Surface.


## v1.05 implementation and acceptance

- [x] Read requirements and record [V1.05_PLAN.md](V1.05_PLAN.md); verify pinned Xcode and create feature branch from tested main.
- [x] Add project-owned MappingSurface with identity/name/four normalized corners/fill.
- [x] Derive and refresh shared render snapshots, including reset of existing preview/output.
- [x] One sidebar row with selection/deselection; inspector shows selected surface and corners.
- [x] Six new focused tests; headless and complete Debug regressions pass.
- [x] Complete Debug/Release runs: all 60 correctness tests passed (63 declarations including three skipped optional benchmarks).
- [x] Final actual-app selection/corners/portrait/output/reopen/New Project Cancel and Discard checks passed.
- [x] Signed Release app copied to builds/v1.05/ and app/ProjectionMapper.app; tested source preserved on GitHub without release/tag/bundle bump.

Evidence: [V1.05_VERIFICATION.md](V1.05_VERIFICATION.md). All seven steps are complete. Next: v1.06 Corner Nodes.


## v1.06 implementation and acceptance

- [x] Record [five-step plan](V1.06_PLAN.md), verify exact toolchain, branch from tested v1.05.
- [x] Editor-only outline/handles and active corner highlight.
- [x] Fitted coordinate conversion, clamped drag with grab offset, live shared renderer updates.
- [x] Native focus routing, arrows/Shift nudges, Escape and inspector/dirty/reset integration.
- [x] Eight focused new tests; 66 headless correctness tests passed.
- [x] Complete Debug/Release: 68 correctness tests passed; three optional benchmarks skipped (71 declarations total).
- [x] Actual-app landscape/portrait drag, normal/Shift nudge, Escape, field-focus isolation, clean output and geometry-only reset protection passed.
- [x] Signed app copies delivered and tested source saved to GitHub without release/tag/bundle bump.

All five steps complete; evidence: [V1.06_VERIFICATION.md](V1.06_VERIFICATION.md). Next: v1.07 Perspective Warp.


## v1.07 implementation and acceptance

- [x] Record five-step plan, verify pinned Xcode and branch from tested v1.06.
- [x] Diagnostic texture with mipmaps and corner orientation markers; solid fill option.
- [x] Validated projective transform, shared snapshots and seamless Metal texture mapping.
- [x] Invalid geometry clears safely; editor warning and overlapping-corner recovery.
- [x] Initial headless correctness/GPU checks pass.
- [x] Complete Debug/Release: 79 correctness tests passed; three optional benchmarks skipped (82 declarations).
- [x] Vital warp/clean-output/invalid/recovery/content/portrait/reset visual checks; fixed warning-induced canvas shift and added regression coverage.
- [x] Signed Release app copies and GitHub delivery; no release/tag/version bump.

All five steps complete; evidence: [V1.07_VERIFICATION.md](V1.07_VERIFICATION.md). Next active milestone: v1.08 Multiple Surfaces. Remaining milestones were reordered and renumbered; image/video import now follows core tools at v1.13/v1.14.


## Earlier roadmap scope update — October 5, 2026 (superseded below)

- Defer custom image import (v1.08) and custom video import (v1.09) at the user’s request.
- Preserve their milestone numbers and future scope. Next active milestone is v1.10 Built-In Animations.
- Planning update only: no app/source changes, new tests, build, version bump or release. v1.07 remains the latest accepted app.


## Remaining roadmap reordered — October 5, 2026

Approved sequence: v1.08 Multiple Surfaces → v1.09 Built-In Animations → v1.10 Save & Load → v1.11 Surface Controls → v1.12 Mapping Tools → v1.13 Images → v1.14 Video → v1.15 Polish & Release, including final upload. See [roadmap and old/new number mapping](V1_ROADMAP.md).

Completed milestones and historical acceptance records retain their original numbers. Saving will initially cover surfaces, generators and output settings, then gain later settings/media as those features arrive. Projector hardware work remains separately deferred. Planning-only update: no app rebuild, feature implementation, version bump or release. The existing v1.07 app’s historical saving-version label will be brought into line when next modifying the interface.


## Remaining milestone steps — October 5, 2026

Expanded all eight reordered milestones into [ordered implementation and verification steps](V1_REMAINING_PLAN.md), including collection/renderer migration, shared animation timing, early saving and later schema/media extensions, surface controls, calibration/blackout, image/video resources, and final undo/redo/packaging/upload. Planning only: no feature implementation, app changes, builds, tests or publication. Next implementation remains v1.08 Multiple Surfaces.

## Connected object faces planned — October 5, 2026

User approved adding object grouping and continuous content across faces to the whole plan. Updated development requirements, roadmap and every remaining milestone in [the detailed plan](V1_REMAINING_PLAN.md): v1.08 adds object membership/shared input maps/manual edge alignment; v1.09 adds shared generators and cross-face motion; v1.10 saves that structure; v1.11–v1.15 cover scoped controls, continuity diagnostics, shared image/video ownership, undo/redo, demo and final acceptance. Continuous and Repeat modes are explicit; standalone/detached faces remain supported. Manual flat layouts can contain deliberate seams; full 3D reconstruction is future scope.

Documentation-only update: reviewed scope/dependencies and checked the diff; no app code, build, screen use, feature implementation, version bump or release. v1.07 remains the latest accepted app.

## V1 foundations updated and V2 planned — October 5, 2026

User requested adjusting all V1 planning and planning V2 following research into mapping/sequencing/show-control software. Updated the remaining steps, roadmap, development requirements and source README future-scope links. V1 retains its approved order and adds layout/content separation and tags (1.08), deterministic time/seek and generator presets (1.09), migration contracts (1.10), reusable looks/palettes and master brightness/fades (1.11), basic polygon masks (1.12), editor-only house photo (1.13), explicit video-audio routing and requested-time playback (1.14), and readiness/full regression coverage (1.15).

Created [V2 roadmap](V2_ROADMAP.md) and [ordered implementation/acceptance plan](V2_IMPLEMENTATION_PLAN.md): 2.01 projector output/calibration, 2.02 music transport, 2.03 timeline/cues, 2.04 holiday choreography, 2.05 layers/regions/text, 2.06 reusable shows/layouts, 2.07 external synchronization/lighting integration, 2.08 Show Mode/readiness, 2.09 playlists/schedules, 2.10 local remote control, 2.11 export/portable delivery, 2.12 acceptance/release. Includes dependency gates, migration/seek/resource rules, research links and a prioritized later-feature backlog. Integration is conditional on a verified workflow and measured device versions, not assumed full xLights/FPP format support.

Physical hardware remains deferred; v2.01 now provides its future implementation/acceptance stage. V1 is accepted/published as Test Mode scope only until those capabilities are actually delivered. Planning changes only: reviewed document consistency, numbered stages and links; no feature implementation, app build, screen use, version bump, tag or release. v1.07 remains the latest accepted app.

## Git/GitHub delivery cadence changed — October 5, 2026

User requested Git/GitHub activity only when a new app version at the x.xx level is completed. Recorded this as no intermediate commits, pushes, tags or GitHub uploads for planning changes, small fixes or x.xx.x slices unless the user explicitly requests an exception. Read-only Git checks/local branch setup remain available; do not bump a version to create an upload boundary. Eligible milestone delivery does not automatically publish a release. Updated AGENTS.md, workflow and active plan delivery rules locally. These policy edits are intentionally uncommitted/unpushed until the next eligible milestone. Existing history remains intact.

## Known GitHub state preference — October 5, 2026

User states this agent is the sole GitHub writer and requests avoiding redundant remote inspection of known work. Updated local instructions/workflow to rely on local history and the last confirmed remote state, using remote checks only for unknown information, reported problems, evidence of outside changes or explicit requests. Successful delivery output is sufficient confirmation. Policy updates remain local under the x.xx-only delivery rule; no commit/push/upload or remote inspection performed.


## v1.08 implementation — local delivery

- [x] All twelve milestone steps implemented: ordered faces, stable layout/source/object IDs, tags, ownership, grouping, input maps/links, add/select/rename/duplicate/delete, visibility/order, dirty/reset behavior and shared collection rendering.
- [x] Seventeen new focused model/GPU tests; 96 correctness tests passed in both configurations (99 declarations including three skipped opt-in benchmarks).
- [x] Vital actual-app checks passed for independent warped faces, Continuous/Repeat, clean 4K output, face/object hiding, tags, object duplicate/delete, appearance-preserving ungrouping, empty black output and Cancel/Discard reset.
- [x] Version 1.08/build 5 universal Release copies installed locally and signatures verified; previous installed build preserved.
- [x] Local feature branch codex/v1.08-multiple-surfaces; source/documentation intentionally uncommitted and unpushed under this delivery's explicit exception.

## v1.08 local follow-up — canvas face selection

Clicking a rendered face in the editor selects its inspector/sidebar row, choosing the frontmost visible valid face when shapes overlap. Empty canvas deselects; selected corner handles keep drag priority. Picking works when no face or an object was previously selected, without dirtying the project. Required Xcode 27.0 beta 5 (27A5237l) reverified. Full Release suite passed 97 correctness tests (100 declarations including three skipped benchmarks), and focused native input/drag tests passed after adding native click/margin assertions. Logs: builds/v1.08/ClickSelection.log and ClickRouting.log. Refreshed signed Release copies in builds/v1.08/ and app/ProjectionMapper.app. No version bump, commit or GitHub upload. No additional manual screen session was needed for this follow-up.

## v1.09.1 implementation — local preview delivered

Shared elapsed-time transport, Play/Pause/Restart/speed, animated gradient/moving lines/checkers and two-color editing are implemented. Static/paused views retain on-demand rendering; eligible playing views use native display scheduling and resume at the shared phase. Full Debug and Release suites passed 102 correctness tests (105 declarations, three opt-in benchmarks skipped). Universal signed Release copies installed in builds/v1.09.1/ and app/ProjectionMapper.app; prior installed app preserved. Bundle remains 1.08/build 5 for this intermediate slice. Work is local with no GitHub delivery.

Vital screen playback acceptance is pending: the Mac was locked and automatic unlock failed. No manual motion/controls pass is claimed. See [verification](V1.09.1_VERIFICATION.md) and [three-slice plan](V1.09_PLAN.md). v1.08 remains the last milestone with complete local visual acceptance; the installed app now includes the automatically verified v1.09.1 preview. v1.09.2/.3 remain planned.

## Visual checks and v1.09.2 — current work

The user confirmed v1.09.1 visual playback checks worked. v1.09.1 is now accepted with user-reported visual evidence. They will perform routine visual checks until changing this preference; no screen control for routine acceptance. v1.09.2 effects/settings are implemented; automated correctness/performance verification and local delivery are in progress. v1.09.3 remains planned; no GitHub delivery for these slices.

## v1.09.2 — local delivery

- [x] Plasma, seeded animated value noise and analytic seeded particle field; existing gradient/lines/checkers gain effect settings.
- [x] Bounded owner settings and relevant-only controls; shared source edits preserve corners, input maps and global runtime transport.
- [x] 105 correctness tests pass in both configurations; new boundary/seed/limits/isolation tests plus expanded all-effect deterministic three-face GPU checks.
- [x] Separate opt-in Release mixed-effect matrix across all presets: six faces per view, two views, 20 measured pairs per preset; 4K GPU pair p95 1.6783 ms (workload timing, not visible FPS).
- [x] Universal ad-hoc signed app installed locally; previous installed app preserved. No source commit/upload or bundle bump.
- [ ] User visual check of new effects/settings; no routine screen control performed by the agent.

## v1.09.3 — local delivery

- [x] Bounded project-owned presets, save/apply/update/delete/reset, preserving mapping and runtime phase.
- [x] Global bounded seeking/scrubbing and elapsed readout; source-scoped pause/resume/restart with duplicate/detach/cleanup policies.
- [x] All 111 correctness tests passed in final Debug/Release runs, including backward loop replay, preset isolation, scope and reversed particle continuity.
- [x] Mixed/overlap profiling across all presets: 4K pair p95 2.1578 ms mixed; 44.5873 ms for eight overlapping particle faces per view. Heavy 4K overlap does not meet a 60 Hz two-view budget.
- [x] Universal signed app installed locally, previous app preserved. No screen control or GitHub delivery.
- [ ] User visual acceptance of v1.09.2/.3; full milestone version/history delivery pending.

## v1.09 GitHub delivery — authorized

The user explicitly requested saving v1.09 to GitHub before implementing v1.10 locally. The version is now 1.09/build 6. Final 111-test source and accumulated multiple-surface/animation work will be preserved on tested main; no release/tag/asset publication requested. v1.10 must remain off GitHub. Routine visuals continue to belong to the user.

## v1.10 local delivery

- [x] Versioned validated project packages and stable declarative data/IDs.
- [x] Atomic Save/Save As, asset-copy preservation, Open and bounded recents.
- [x] Saved baselines and Save/Discard/Cancel for New/Open/Close/Quit.
- [x] Debounced untitled/saved recovery, ten-copy retention and restore/later/delete.
- [x] Full Debug/Release suite: 128 correctness tests, four skipped opt-in benchmarks.
- [x] Universal ad-hoc signed 1.10/build 7 product in builds/v1.10/ and app/ProjectionMapper.app; prior installed app preserved.
- [ ] User native panel/lifecycle/recovery and visual round-trip acceptance.
- v1.10 source backup successfully pushed to main at 55d242c; no release/tag/assets. Next: v1.11.1 appearance/crop/flip.

## v1.11.1 local preview delivery

- [x] Bounded opacity, brightness, crop and flips, shared preview/output calculations.
- [x] Object inheritance and explicit face overrides; grouping/copy/detach policies and join diagnostics.
- [x] Schema 3, schema 1/2 default migration, saved baselines and recovery support.
- [x] 138 Debug/Release correctness tests; four optional benchmarks skipped.
- [x] Universal signed local app in builds/v1.11.1/ and app/; previous installed app preserved. Bundle stays 1.10/build 7.
- [ ] User appearance/override/save-reopen visual checks.
- Preview remains unstaged/uncommitted/off GitHub. Next: v1.11.2 locks, group movement and scoped resets.

## v1.11.2 local preview delivery

- [x] Persistent face/object output-geometry locks; preserved individual locks, protected manipulation/deletion and reachable unlock.
- [x] Bounded group translation through native center dragging, focused arrows and inspector controls; any member lock blocks the whole move.
- [x] Scoped face/object resets, explicit full-face/input-layout confirmations, identity/layout/link/clock preservation.
- [x] Schema 4 lock persistence with schema 1–3 migration; dirty baselines/save/recovery verification.
- [x] 150 Debug/Release correctness tests; four optional benchmarks skipped. Native event and GPU movement/reset regressions pass.
- [x] Universal signed local app in builds/v1.11.2/ and app/; previous preview preserved. Bundle stays 1.10/build 7.
- [ ] User visual locks/movement/reset/save-reopen checks.
- Intermediate slices remain unstaged/uncommitted/off GitHub. Next: v1.11.3 looks, palettes and master brightness/fade/blackout.

## v1.11.3 detailed planning — October 6, 2026

- [x] Defined the [seven-step implementation plan](V1.11.3_PLAN.md): schema/models, palettes, looks, runtime master controls, renderer/UI integration, full verification and milestone delivery.
- [x] Specified target compatibility, palette-reference materialization, mapping/lock preservation, independent fade timing and blackout/restore semantics.
- [ ] Implement and verify v1.11.3; user visual acceptance remains pending.
- Planning only: no app/source changes, builds, version bump, commits, pushes or GitHub uploads. Installed app remains the automatically verified v1.11.2 preview.

## v1.11.3 implementation in progress — October 6, 2026

- [x] Implemented looks, palettes, schema 5 migrations, saved master settings, playback-independent fades and immediate blackout/restore.
- [x] Initial integrated Debug run passed 178 correctness tests; four optional benchmarks skipped.
- [ ] Complete final v1.11/build 8 Debug/Release checks, deliver the tested app and perform eligible milestone source backup.
- Routine visuals remain user-performed and pending. No screen control or release publication. Current installed preview remains v1.11.2 until final delivery.

## v1.11 completed local milestone — October 6, 2026

- [x] Implemented all three Surface Controls slices, including reusable looks/palettes and persistent master output configuration with temporary fades/blackout.
- [x] Reverified Xcode 27.0 beta 5 (27A5237l); all 184 correctness tests passed in final Debug/Release runs. Four optional benchmarks skipped.
- [x] Delivered 1.11/build 8 universal locally signed app to app/ and builds/v1.11/; previous installed preview preserved; all tested-product file hashes match.
- [x] Updated schema 5 migration/save/recovery, documentation and [verification evidence](V1.11.3_VERIFICATION.md).
- [ ] Complete eligible milestone Git source delivery (remote confirmation follows push). No release/tag/assets requested.
- [ ] User visual acceptance: look recall, palettes, fade/blackout and prior appearance/locks/movement/reset checks. No new acceptance has been reported; no screen control used.
- Next: v1.12 calibration tools and basic face-local polygon masks, extending the existing global output controls.
