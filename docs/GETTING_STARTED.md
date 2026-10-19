# Get started with Projection Mapper

Start with the included demo, rehearse in Test Mode, then create your own layout.

## Choose an app

**Ready-to-download app:** [v1.15.1 for macOS](https://github.com/Chosencode25/projection-mapper/releases/download/v1.15.1/ProjectionMapper-v1.15.1-macOS-universal.zip), universal Apple Silicon/Intel, macOS 15 or later. Extract the archive and move ProjectionMapper.app to Applications. Read the included installation notes; this is a locally ad-hoc signed development app, without Developer ID signing/notarization.

**Latest source:** v2.01/build 16 adds explicit external fullscreen output and local device calibration, a cleaner workspace, timeline tools and keyboard editing. Use [Build and Run](BUILD_AND_RUN.md) with the exact pinned Xcode 27.0 beta 5 (27A5237l). This source update has no published v2.01 app download. In an existing development workspace, its verified app may already be installed under app/ProjectionMapper.app.

## Explore the demo

1. Open **Help → Open V1 Demo**. It opens an unsaved template and protects any project already being edited with Save / Discard / Cancel.
2. Select the house face to inspect corner mapping, polygon masks and window cutouts. The house reference is visible only in the editor.
3. Select the connected box to explore one content owner shared by several faces. Continuous mode samples one canvas; Repeat uses repeated whole content.
4. Open **Test Output**. The resizable window shows clean content without editor guides or the reference image.
5. Press **Play** and scrub the bottom timeline. Clips show captured effects, images or videos; gaps in populated tracks are dark. Audio starts disabled.
6. Stop playback and save a separate copy if you want to keep edits. The bundled original stays protected.

![Editor and timeline in the bundled demo](../assets/github/editor.png)

## Keyboard editing in the latest source

Press **Space** to play/pause, **Command-D** to duplicate, and **Delete** to remove the selected clip, face, object or mask point. Open **Help → Keyboard Shortcuts…** with **Command-/**. Normal typing retains spaces and native text editing. See [all keyboard shortcuts](KEYBOARD_SHORTCUTS.md); this expanded set requires build 16 rather than the older downloadable release.

## Create a layout

Start a new project, add a surface, and drag its four corner handles onto the shape you want to map. Choose an effect or import an image/video, add masks for cutouts, and capture content into timeline clips when timing matters. Group checked faces when they should share content. Save with Command-S; the portable .projectionmap package retains referenced media.

Use the [authoring guide](V1_USER_GUIDE.md) for editing, undo, media, timing and saving. The [output guide](V2.01_USER_GUIDE.md) explains the newer source's explicit projector open/close and calibration controls.

## Before using physical output

Test Mode remains available without projector hardware. Physical fullscreen output is implemented in v2.01 source, with conservative close/reopen behavior on display changes; actual projector presentation, optical delay and device behavior remain pending acceptance. Automated checks and a Test Window recording do not establish physical projector performance. See [current verification](V2.01_VERIFICATION.md).

## Next steps

- [All documentation](README.md)
- [Build and test](BUILD_AND_RUN.md)
- [Current limits and hardware checklist](V2.01_VERIFICATION.md)
- [Report a bug or suggest a feature](https://github.com/Chosencode25/projection-mapper/issues/new/choose)
