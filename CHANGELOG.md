# Changelog

## Unreleased — v1.03.2 resolution/scaling — October 5, 2026

- Five saved Test Window resolution presets: HD, Full HD, 4:3, Portrait, and 4K.
- Editor preview/details and open output update immediately; centered aspect-preserving output surface keeps the simulated resolution independent of window size.
- Preferences stay separate from project changes. All 31 tests passed plus native live-update/relaunch checks with the pinned Xcode toolchain.
- Source update only; no new release, tag, or bundle version bump.

## v1.03.1 — Basic Test Window — October 5, 2026

- Open/Close Output controls in the toolbar, inspector, and Window menu.
- One normal movable/resizable/minimizable black output window, with duplicate prevention and shared status.
- Native close preserves the editor/project; New Project preserves output; successful editor close and quit clean up output.
- Test Window only; projector implementation and physical checks deferred at the user’s request.
- All 28 tests passed and an Apple Silicon Release build was locally verified with the pinned Xcode toolchain.

## v1.02-preview.1 — Output Selection Preview — October 5, 2026

- Shared toolbar/inspector selection of Test Window or an eligible connected display.
- Display discovery, UUID preferences, refresh, wake/reactivation updates, and safe disconnect/mirroring/editor-screen fallback.
- Render pixels, desktop points, scaling, reported refresh, connection messages, and aspect-aware preview.
- Output preferences stay separate from project changes; bundle-derived version 1.02/build 2.
- 21 tests passed, pinned-Xcode Release build and local runtime checks completed.
- Physical external-display acceptance pending; preview remains on the feature branch and main stays v1.01.

## v1.01 — App Skeleton — October 5, 2026

- Native Mac editor implemented entirely in SwiftUI and programmatic AppKit.
- Toolbar, surface sidebar, 16:9 empty preview canvas, project inspector, and status area.
- Project naming, timestamps, and in-memory session state.
- New Project, Close, and Quit with Cancel/Discard protection for changes.
- Panel toggles, keyboard shortcuts, editor reopening, and About information.
- Five focused state tests passed; editor layout and lifecycle checks completed.
- Xcode 27.0 beta 5 (27A5237l); macOS 15.0 deployment target.
- Local Apple Silicon development build. Rendering, media, output windows, and persistence are later milestones.
