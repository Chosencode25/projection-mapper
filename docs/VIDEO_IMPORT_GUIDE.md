# Video import and timeline — v1.14

Quit/reopen the installed app to use 1.14/build 11. Choose a face or object, open its content inspector and choose **Import video…**, or drop an MP4/MOV on the editor. Shared object members use their object's video; **Detach and import video on this face…** creates independent ownership. Imports finish paused and muted. Existing geometry, input maps and masks stay in place.

## Put video on the timeline

Use **+** in the object's bottom timeline row to capture its current source. The new block contains its video and settings. Select the block to edit source In/Out, speed, loop, mute and placement. Changes in the source inspector affect the live source; existing blocks retain captured content until **Capture Current** or their own edit controls change them.

- Moving a block keeps the same footage. Leading/trailing edge trims change the source range for a non-looping clip. For a looping clip, trimming preserves the loop range and adjusts its phase.
- Source speed multiplies global transport speed. Non-looping duration cannot exceed the selected footage; invalid edits and overlaps are rejected.
- Use Play/Pause, Stop, one-second steps and the ruler to play or scrub. A sequenced row is dark between blocks; a row with no clips uses live content. A live non-looping video holds its final frame.
- Continuous canvas shares one frame across connected faces. Repeat shows the same complete frame on every face. Separate objects can use the same asset at different times. Preview and Test Output consume the same published frame.
- Fit/Fill/Stretch and canvas aspect work with the existing crop, flips, input maps, perspective, opacity/brightness and masks. Source orientation is honored.

## Audio

Audio has two gates: clear **Mute** on the relevant source/block and turn on **Enable Audio** under **Show → Video audio**. Select the output device and master volume there. New/Open/recovery always disable runtime audio; saved mute/volume/device preferences are retained. Scrubbing, Pause, Stop, gaps and non-video blocks silence outgoing audio.

One object owns one stream even with several faces and both views. Explicitly unmuted independent owners can mix. Effective audio speed is supported at 0.5×–2×; other speeds mute audio with a message. Visual blackout/fade does not mute deliberately enabled audio. Hiding every member or setting all face opacities to zero releases that owner's playback. Closing all visual views suspends visual decoding; explicitly enabled audible playback can continue. A lost selected device latches audio off; choose an available device and enable audio again. Automatic default-device fallback is not used for a missing explicitly selected device.

The tests verify actual player mute/rate/volume/device commands without sound. Listening, perceived synchronization, pitch quality and real unplug/reconnect behavior still need a user check with the intended equipment.

## Supported media and limits

SDR H.264/HEVC in MP4/MOV is supported after inspection and representative-frame decoding. Files must be regular local files, at least 0.1 s long, up to 4096 pixels on either edge, 8,847,360 pixels, 120 fps and 24 hours. Limits: 2 GiB/file, 64 video assets and 8 GiB/project video bytes. HDR transfer functions, unsupported codecs/containers and unreadable media are rejected. Compatibility is verified with generated H.264/HEVC fixtures; it is not a promise that every encoder's file will work.

Frame cache limit is 256 MiB for published app-owned pixel buffers; AVFoundation and GPU allocations use additional memory. Seek/loading discontinuities may briefly show darkness. Observed timing evidence is in [verification](V1.14_VERIFICATION.md); no universal frame-accuracy guarantee is made.

## Save, open and relink

Save/Save As copy referenced original videos into the portable `.projectionmap` package, including assets used only by timeline blocks or saved looks. Copying runs off the main thread with a status indicator and Cancel. A failed/cancelled save retains the last good destination and unsaved session. Recovery uses the same staged package writer. Keep the package's assets together; copying/moving the whole package preserves portability.

Missing/damaged videos keep their geometry and references. **Relink video…** re-inspects media and retains its identity/ranges. A replacement shorter than any referenced range is rejected until the ranges are corrected. Saving an incomplete portable project is rejected. Remove a video or its final references to allow asset collection.

## Rehearsal project

Open [Video timeline demo](../assets/demos/V1.14-VideoTimeline.projectionmap). It uses self-generated color-pattern footage: a connected three-face box plays video at 0–4 s, moving lines at 4–8 s and a checker image at 8–10 s. An independent video loops a 1–3 s source range on a 1–7 s block. There is a triangular mask cutout and an editor-only checker reference. Videos start muted and include a generated 440 Hz tone for a deliberate audio check. Use low volume, then check your own footage and intended output equipment.

For visual acceptance, check poster/block readability, scrubbing both directions, clip transitions/gaps, Continuous/Repeat, masks/crop/placement, Test Output agreement and Save/Open. User checks are recorded separately from automated tests. V1.15 adds undo/redo and final readiness/polish; music/waveforms and physical projector operation remain later work.
