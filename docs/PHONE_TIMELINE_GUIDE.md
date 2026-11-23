# Phone timeline and Mac preview

Use Projection Mapper v2.14 build 38. Open a rehearsal copy of a show. Start Phone Remote on the Mac, pair the phone and approve the primary phone as **Editor**. Keep the Mac in **Edit** when changing the show.

1. Open **Timeline & Lighting Cues** on the phone. Use **Playhead** to center the view near the current show time. Change the 10–120 second range, move earlier or later, or page through tracks. Orange marks the shared Mac playhead.
2. Drag a clip to move it within its existing track. Select it first to expose trim edges, then drag an edge. The selection fields below the diagram also let you move or trim by exact times. Snap applies to drag gestures. Use the numerical fields for values between snap points.
3. For video, edit **Source in** and **Source out** and apply the range. The Mac uses its existing edit and validation rules for source bounds, clip length and crossfades. An edit that would break a transition is rejected. Each accepted edit is one Mac undo step.
4. Tap a lighting cue diamond or use the chooser. **Select on Mac** focuses it in the editor. Drag the cue or enter a new time. It retains its current fixture states. Cue diamonds represent timed cues.
5. Open **Mac Preview** and tap **Start Preview**. The image is generated on the Mac, with a time and approximate age. Turn it off on the phone or disable **Allow Phone Preview** on the Mac. The preview stops requesting frames when the browser is in the background or the panel is closed. It uses the normal Mac video decoder, which may need a moment to produce a frame.
6. To show the preview on more devices, use **Invite Read-Only Viewer** on the Mac and approve each device. Up to four additional viewers can see preview and timeline. The primary phone retains its selected permission. **Revoke All Phones** removes all sessions.
7. Compare phone edits against the desktop, then undo, redo, save and reopen. Try a clip with a fade, a connected object and a lighting cue. Cancel a drag by backgrounding the browser. Disconnect Wi-Fi during a drag, make a Mac edit and reconnect. Verify that the old gesture is discarded or rejected. Switch to Show and verify the timeline is read-only.

The preview is a capped JPEG snapshot of the Mac editor scene, refreshed at about one frame per second. It can lag the current playback and does not measure projection timing. Real iPhone Safari and Android Chrome rehearsal remains pending.
