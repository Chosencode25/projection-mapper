# Repository media

- hero.svg: README banner, derived from the app's existing cube icon and palette.
- download-stable.svg / build-latest.svg: accessible README link graphics. Keep labels and destinations aligned when versions change.
- editor.png / test-output.png: actual v2.01/build 14 app-window captures using the bundled V1 demo.
- demo.gif: roughly 5.3 seconds of actual Test Output playback, encoded at 680 pixels wide / 10 fps. This is illustrative media, not a physical projector or performance measurement.
- social-preview.svg / social-preview.png: editable artwork and its 1280×640 GitHub social-image companion.

Regenerate branding with `python3 app/scripts/repository_artwork.py`. It uses Python's standard library for SVG files and optionally Pillow plus the Mac's Arial fonts for the PNG. These are development-artwork tools, not app runtime dependencies.

See [presentation record](../../docs/GITHUB_PRESENTATION.md) for provenance, validation and GitHub delivery status.
