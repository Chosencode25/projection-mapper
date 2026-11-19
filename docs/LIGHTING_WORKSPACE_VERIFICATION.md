# Lighting workspace first section — verification

November 17, 2026. User invoked **Build** after the first Lighting section was identified. Local feature branch `codex/lighting-workspace`, based on the backed-up build 32 source. Active source remains `builds/worktrees/v2.09/app/ProjectionMapper/`; the directory name is historical. No commit, push, installation, release, tag or upload was performed for this Build command.

## Implemented scope

- Lighting joins Edit and Show in the workspace switch, using the same project, transport, undo/autosave and simulated fixture evaluator. A running Show requires a pause transition before either authoring workspace. Switching authoring views does not seek or reset the clock.
- Resizable fixture/group/look list, large existing 2D schematic, contextual inspector and shared bottom timeline. The right inspector retains Output/Project panels and their existing shortcuts; selecting a lighting target returns it to Selection. The list and schematic share fixture selection; named groups target their existing fixture membership. Schematic visibility is runtime-only and does not change saved patches or output. Placement edits keep the existing undoable patch update.
- Existing controller/fixture/monitor setup remains in a separate panel. Contextual fixture creation finds a free compatible patch. Supported head controls, plugs and discrete RGB controls target selected types without implying continuous dimming for relays or addressed pixels.
- Manual audition, selected-look audition, clearing overrides and capturing saved looks. Fixture/group changes leave other fixtures unchanged. Looks and cues use existing persistence and validation; no package migration or schema bump.
- Reused cue inspector for time, moving-head lead/curve/fade, manual-only flag, GO, duplicate and delete. Lighting timeline has an overview cue row and per-fixture rows, with shared song waveform/markers/loop/snapping/zoom/follow. Optional projection references are read-only; the existing choreography editor is restricted to fixtures when opened in Lighting.
- Keyboard routing prevents projection editing through stale Edit selections. Undo/redo is available in both authoring workspaces and locked in Show. Remote projection editing retains its existing requirement that the Mac be in Edit. Transport/operator commands remain shared.
- Playground new-show chooser offers Edit or Lighting; the direct current-setup shortcut preserves Lighting when used there. Show is never the initial armed workspace for a new draft.

## Automated checks

Exact Xcode verified before work: **27.0 beta 5, build 27A5237l**, at `/Applications/Xcode-beta.app/Contents/Developer`. Minimum macOS remains 15.0. SwiftUI/programmatic AppKit only. Test Mode/shared renderer preserved.

Six new `LightingEditingTests` passed in the initial focused Release run. They cover workspace/project/clock identity and Show pause gating; type-safe mixed-group audition and undoable capture; cue target filtering/snapping and seek reconstruction; safe keyboard routing with stale projection selection; stale group/fixture/look selection cleanup and valid nonoverlapping patch creation; and autosave/reopen plus independent Playground creation directly into Lighting.

Final full **Release** suite succeeded: **368 tests reported across 39 suites**, zero failures, approximately **23.1 seconds**. Four optional performance tests were skipped and the two established legacy visible-window tests excluded. Evidence: `builds/lighting-workspace/Release-final.log` and `Release-final.xcresult`. The earlier complete Release run also passed.

Focused **Debug** run succeeded: **48 tests across four suites** (`LightingEditingTests`, `PlaygroundTests`, `EditorShortcutTests`, `ProjectPersistenceTests`), approximately **4.6 seconds**, zero failures. Evidence: `Debug-focused.log` and `Debug-focused.xcresult` in the same directory. This focused Debug run preceded the final inspector integration; the final full Release run passed afterward. This is not a full Debug-suite claim. Full Release includes the existing phone checks; prior full-Debug phone curl timing sensitivity remains recorded in build 32 history.

Logs contain existing Apple media/service diagnostics and the pinned SDK's optional x86_64 testing-framework warning. No visual result or physical timing is inferred from model/regression checks.

## Local artifact

- App: `builds/lighting-workspace/ProjectionMapper.app`, **2.09/build 33**.
- ZIP: `builds/lighting-workspace/ProjectionMapper-Lighting-build33-macOS-universal.zip`.
- Archive SHA-256: `856c7b7c70413eaa4fe263c57b0e78d437531084af45551a3e2b798eb7e05144`.
- Identity/checksums: `Build-identity.json`, `SHA256SUMS.txt` in that directory.

All 11 app files match the Release product and extracted archive. Strict/deep ad-hoc signatures passed for product, local app and extracted archive; executable contains arm64 and x86_64. Intel is cross-built, not runtime-tested. Applications retains build 32. The milestone version stays 2.09 because this is an intermediate preview and no Lighting milestone version has been assigned.

## Pending acceptance and later scope

User visual/listening rehearsal remains pending; use [the guide](LIGHTING_WORKSPACE_GUIDE.md). No app launch or screen control was performed. Panel sizing, clicks/dragging, inspector presentation and full song/Test Mode rehearsal still require the user's check. Physical moving-head, Arduino and projector/timing acceptance remain deferred. Movement-path/position-keyframe editing is next; new reusable lighting effects/preview expansion follow. Broader v2.10 reuse roles/templates/recording and later Show Mode completion remain planned.
