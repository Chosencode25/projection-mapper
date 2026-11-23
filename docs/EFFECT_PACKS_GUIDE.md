# Reuse effects and palettes

Use **File → Export Effect & Palette Pack** in Edit or Lighting while playback is paused. Name the pack and select the saved palettes, projection effect presets, and lighting chase or wave presets you want. The portable .projectionpack file contains these definitions and their colors, timing settings, and effect parameters.

Open another show and choose **File → Import Effect & Palette Pack**. Open the file, select the items to import, and review any matching names before clicking **Import Selected**.

- **Keep Both** is the default. It adds the incoming item under an available name such as Christmas (2).
- **Replace** updates the selected existing item in place. Matching is case-insensitive within each item type. For palettes, a color slot whose name matches uniquely stays linked and adopts the imported color. Links to removed or ambiguous slots keep their pre-import colors.
- Uncheck any item you want to skip.

The imported items appear in the existing palette, projection preset, and lighting preset controls. Apply them from those controls as usual. Existing timeline clips and fixture assignments stay in place. Use Undo once to reverse the import.

Packs contain the selected definitions. The song, media, mapping, and fixture patch stay in their projects.
