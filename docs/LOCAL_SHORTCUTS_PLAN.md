# Local keyboard editing — October 19, 2026

User initially authorized app-wide playback/editing shortcuts as local work. On
October 19 they explicitly requested GitHub delivery and the full shortcut reference.
This overrides local-only delivery for this update without a milestone bump or new release.
Read with PROJECT_DEVELOPMENT.md, V2.01_PLAN.md and LOCAL_APP_GUIDE.md.

- Add Space play/pause, stop, bounded paused time stepping and sequence navigation.
- Add contextual duplicate/delete, surface creation/grouping/lock/visibility/order,
  media import, clip capture and video split, timeline zoom/fit/snap/follow, inspector
  navigation, output actions and a searchable in-app keyboard reference.
- Keep native typing, text undo/cut/copy/paste, menus, sheets and output Escape intact.
  Scope bare keys to app-owned windows; never install a global keyboard monitor.
- Make canvas/sidebar selection clear stale clip selection. Mask Delete edits the
  point/draft instead of deleting a face; locked geometry retains its existing guard.
- Preserve saved format 9, shared transport/rendering, Test Mode and explicit output
  opening. Time steps are nominal 1/30 second or one second, not media-frame promises.
  Split is video-only: existing video trimming preserves source phase; procedural
  clips have no saved phase offset and must not acquire a misleading split command.
- Verify routing/focus/repeat safeguards, context/undo, video splits and runtime-only
  state with automated tests under Xcode 27.0 beta 5 (27A5237l), Debug and Release.
  Install/archive only the verified local build; user performs routine visual review.

Status: implemented and installed locally as build 16; Debug/Release each passed 312 correctness tests. Visual acceptance remains user-performed and pending. See PROGRESS.md and LOCAL_SHORTCUTS_VERIFICATION.md.
