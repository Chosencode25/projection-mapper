# Changelog

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
