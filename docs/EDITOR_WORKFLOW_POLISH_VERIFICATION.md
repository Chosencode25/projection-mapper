# Editor workflow polish — build 31

November 17, 2026. Local v2.09 enhancement on `codex/phone-remote-network-stability`, extending the already-local phone stability and Local Remote changes. Portable project format remains 14. No commit, push, release or milestone-version bump is authorized by this intermediate slice.

## Implemented behavior

- One project title/save indicator; repeated inspector, canvas, timeline and mapping tutorials removed. Normal editing does not display the old bottom clip tutorial/editor.
- Objects expand to faces, regions and shared layers in the sidebar. Search includes child names. Layer controls appear when that layer is selected. Add Layer/Add Region stay next to the work.
- Clip selection opens timing, content/media, transition, capture, split, duplicate and delete in the inspector. Effect/color/media edits update that clip through undo, preserving its base content. Image/video completions verify the captured project, owner and clip selection.
- Cue selection opens timing/movement/fade controls; mouth-key selection opens time/shape controls. Duplicate/delete/hide/order keyboard actions follow their applicable active selection. Native text inputs retain their keyboard routing.
- Horizontal and vertical splitters resize the scene list, inspector and timeline. Runtime widths, timeline scale/scroll, group collapse, canvas zoom/pan and selection survive visiting Show. Tools → Reset workspace layout restores dimensions, visibility and canvas fit.
- Layers and region content have projected move/resize/rotation handles. Region shape drawing retains its separate point-edit mode. Coordinate conversion matches shared input maps, crop/flips, and region bounds.
- Per-owner timeline collapse hides its child lanes; the global child-lane toggle remains. Playback, stop, time, snap and zoom remain directly reachable. Fixture schematic selection reveals that fixture's manual controls; simulation labels and separate controller/monitor setup remain.
- Canvas media drops select the face under the pointer; empty canvas creates a new surface. Active drag feedback marks the canvas. Shared-face drops retain the explicit shared-object versus detach choice.

## Autosave design

- New work autosaves to `~/Library/Application Support/ProjectionMapper/Drafts/<project-id>.projectionmap`. Drafts are listed by saved project name in Project → Drafts; the last draft is reopened at launch when it is available. The bundled demo gets an independent project identity and draft destination.
- Named projects autosave to their existing package after roughly two idle seconds, with a ten-second scheduling bound while edits continue. File operation duration can extend durability beyond the scheduling bound. Command-S on a draft asks for a destination; Command-S on a named project flushes it. Save As writes a separate destination.
- Saves serialize on the existing transactional package writer, off the main actor. Each captures an immutable project and media-stamp snapshot. Successful completion advances the saved baseline only to that snapshot; newer edits remain dirty and schedule another write. Media generations prevent late results from changing a different open document's destination or status. Media leases protect staged files through the write.
- Unchanged staged videos reuse inspection results only when asset metadata, URL, size, modification time and inode match. Video copies try filesystem cloning and retain the cancellable streaming fallback. Cloning is copy-on-write, so later file replacement does not share mutable hard links.
- Up to five previous packages are retained in `ProjectionMapper/Checkpoints/<project-id>/`, at most one checkpoint per thirty seconds of saves. Project → Restore Checkpoint restores into the current destination after flushing pending changes.
- Open, draft switch, checkpoint restore, close and quit flush pending revisions. Save failures preserve dirty edits and the last valid destination, attempt a separate recovery copy, and expose Retry/Save a Copy beside save status. Launch compares the last draft against a newer differing recovery project's modification timestamp and offers recovery before loading the older draft. This is snapshot/timestamp coordination, not a new portable revision-number format.

## Snow and particle correction

Snowfall and Particles used screen derivatives of coordinates after wrapping. At a wrap boundary, a large derivative spread the antialiasing over an entire line. The shader now derives the pixel footprint from the continuous UV coordinates and applies the effect's scale. Other derivative-based effects were inspected; their antialiasing inputs are continuous waves/coordinates.

A GPU regression renders sparse white Snowfall and Particles against black at several times and rejects bright rows/columns across wrap boundaries. Existing composition, mapping and renderer checks remain in the full suite.

## Verification

Final full Release run: **355 tests passed in 37 suites**, zero failures, about 23 seconds of test execution. Four opt-in performance checks were skipped; two legacy visible-window checks were excluded. The pinned toolchain was rechecked: Xcode 27.0 beta 5, build 27A5237l. Evidence: `builds/v2.09/editor-polish/Release-verified.log` and `.xcresult`.

The full Debug run completed 355 tests with two curl timeouts in the HTTP/HTTPS phone tests during the 121-second concurrent workload. All five `PhoneRemoteTests` passed in isolation in 4.8 seconds with the final Debug interface build (`Debug-phone-isolated2.log`/`.xcresult`). The other Debug checks passed. Do not describe this as an entirely clean full Debug run.

Following the full suite, agent screen inspection found equal initial splitter allocation and inspector scroll position carrying over to a newly selected item. The final app-only correction sets initial AppKit divider positions once and resets inspector scrolling on selection changes. The final universal Release build passed (`Release-delivery.log`). Screen recheck confirmed a 244-point sidebar, a 634-point canvas column and a 320-point inspector at the 1200-point window width, with a 224-point timeline. AppKit divider indexing uses arranged panes; initial layout measurement does not overwrite the desired sizes. These sizes remained intact after Show → Edit. Tested model/rendering/network source is unchanged by these last UI corrections.

Focused added coverage includes direct clip edits/base isolation/undo; image import into a clip and stale completion rejection; draft/named autosave and undo; bounded checkpoint creation; last-good preservation and recovery after a failed destination; visual-coordinate round trips through rotated/mirrored input maps and crop; layer/mouth-key keyboard routing; and GPU seam rejection.

## Installed artifact

Installed `/Applications/ProjectionMapper.app`, v2.09/build 31, from the visually checked final Release product. All 11 files match the Release product, strict code-signature verification passed, and the executable includes arm64 and x86_64. Prior build 30 is preserved at `builds/v2.09/editor-polish/Previous-Applications.app`. Per-file hashes and installation paths are recorded in `builds/v2.09/editor-polish/installation.json`. No Git commit/push/release was performed.

## Acceptance and limits

Agent screen checks so far: snowfall playback, automatic Draft saved status, direct clip effect editing without changing the sidebar’s base effect, selected layer creation/handles, layer Delete keyboard routing, project-name commit, and draft autosave before Quit. A temporary local draft named Editor Check contains the snow inspection; temporary clips and layers were removed. Final checks also verified white snowfall against the dark preset background while playing, reset inspector scrolling when a clip is selected, intended panel sizes, Edit/Show layout retention, and draft relaunch paused at zero with output/remote off. The app was quit cleanly after inspection. Minimum-size visual coverage, full fixture-schematic interaction and full Encore rehearsal are not claimed by this focused check. User visual/listening acceptance of build 31 is pending and is separate from automated evidence. Full-disk injection, permission-denied mounted destinations, multi-gigabyte save latency, uninterrupted-edit ten-second durability timing, and repeated forced-crash/recovery scenarios have not been exhaustively exercised. Intel is cross-built; an Intel Mac is not used for runtime checks. Physical projector, adapter, moving-head and LED-strip acceptance remains deferred.

Follow-up refinement remains available for draft thumbnails, precise hover highlighting of the individual face during a canvas drag, and measured stress/performance acceptance. The implementation does not claim those planned acceptance details are already verified.
