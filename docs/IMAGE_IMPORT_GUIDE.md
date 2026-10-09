# Using images in v1.13

## Add an image

1. Select a surface in the canvas or sidebar, or select an object.
2. In **Edit → Content**, choose **Import image…** and pick one PNG or JPEG.
3. Choose **Fit**, **Fill** or **Stretch**. Fit displays the whole image with transparent unused space; Fill crops the center to cover; Stretch fills the canvas without preserving image proportions.

For an object, import replaces its shared content across all linked faces. Continuous mode samples one canvas across the faces; Repeat uses the whole image on each face. To replace only one grouped face, select that face and choose **Detach and import on this face…**.

Canvas aspect is the shared content canvas's width divided by height; it starts with the selected output aspect ratio. Changing it adjusts Fit/Fill proportions without moving any output corners. Crop, flips, masks and surface appearance still apply.

## Drop, replace and remove

Drop one PNG/JPEG on a canvas face to target it. A grouped face offers a choice between replacing the object's shared image and detaching the face. A drop outside faces uses the existing selected content target; with no selection it creates an image surface. Use **Deselect** before dropping if you want a new face.

Import again to replace the selected owner's image. **Remove image** returns it to Diagnostic grid while preserving geometry and masks. **Relink image…** repairs the asset while keeping its identity, updating every face/look/reference photo using that same asset.

## Use a house or display photo

Open **Project → Reference photo**, then import a photo. This photo is behind the editor preview and never enters Test Output.

Unlock photo alignment to change Fit/Fill/Stretch, center and scale. Center X/Y use canvas coordinates: 0.5, 0.5 is the middle. Photo opacity remains adjustable while alignment is locked. **Show reference photo** is temporary; the photo asset, alignment, opacity and lock settings are saved. None of these settings moves mapped surfaces.

## Save and reopen

Save through **Project → Save project** or Command-S. Imported images and the reference photo are included in the .projectionmap package; copied/moved packages do not depend on the original imported files. Unsaved image data participates in the normal recovery copy.

Missing/damaged images retain their mapping and asset identity. Select their owner and relink/replace the image, or repair/remove the reference photo. A save with unresolved assets fails without replacing the last good package.

Image limits: one PNG/JPEG per import, input up to 128 MB and 100 megapixels, normalized to at most 4096 pixels on its longest edge. Projects allow up to 64 image assets, with 256 MB limits for decoded pixels and normalized PNG data. Images normalize orientation and convert to sRGB; transparency is preserved. Project format is now 7; older app versions cannot open these new saves.

## Your visual checks

Try an image on a warped surface, Fit/Fill/Stretch and a transparent PNG; then group two faces and check Continuous versus Repeat. Add a reference photo, adjust it, and confirm it stays out of Test Output. Save, copy the project package elsewhere and reopen it. Try dropping an image onto a grouped face and onto empty space after Deselect.
