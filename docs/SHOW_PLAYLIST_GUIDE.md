# Project Home, playlists and schedules

Open the build 37 preview. Project Home lists recently opened shows and managed drafts. Each card shows the layout as a small schematic, plus its song or a surface and fixture count. Double-click a card to open it, or select it and choose **Open Project**. **Open File** locates another show. **New Project**, **From Playground**, **Open Demo** and **Recover** are also available. Use the house button in the editor or **Window → Project Home** to return.

## Playlists

1. Save the shows you want to run. Go to **Project Home → Playlists → New Playlist** and add the saved project files. Reorder entries with the arrows.
2. Choose **Intro**, **Show**, **Intermission** or **Outro** for each entry. Intros run once before the repeated body. Intermissions stay in their slots during shuffle. Outros run once after the last pass. With two or more distinct main show files, shuffle avoids repeating the same file at consecutive pass boundaries when there is an alternative.
3. Enter a duration to limit an item. A value of zero follows the soundtrack length or timed programming. A still intermission defaults to ten seconds. Give an untimed show, intro or outro an explicit duration. Playlist playback runs saved songs once while preserving the loop saved in the show.
4. Select the desired output in the editor first. For a separate Test Window, open it before starting the playlist. Select **Play** in Playlists. The app checks each show, loads it and prepares it in Show Mode. Between items, output goes dark while the next show is prepared. The playlist keeps the output route selected when it starts.
5. Return to Project Home to see the playlist status and use **Finish Current** or **Stop Now**. Show Mode's **Stop** also ends the run. Pause in Show Mode holds the current item. Playback stops on a fault or if the show is disarmed. Address the fault before starting the playlist again.

## Schedules

Create a schedule for a saved playlist and set its timezone, start/end, weekdays and optional first/last date. Use **Skip dates** for holiday exceptions, for example `2026-12-25, 2026-12-31`. Enable the schedule and click **Arm Schedules**. Set the desired output before arming. An end time earlier than the start time falls on the following day.

The list flags intersecting windows in the next week. When multiple occurrences become due together, the highest priority goes first, with a stable tie-break. An active run keeps its slot. The app records starts and skips, so revisiting a start minute after a clock change cannot run it again. A lost spring daylight saving time is skipped. On a repeated fall hour, the first occurrence is used.

At cutoff, the rule can stop immediately or let the current item finish. The latter has a one-hour upper bound and starts no new items after cutoff. Keep the app open and the Mac awake, and arm before the start. The scheduler skips starts missed by more than a minute and opens disarmed after relaunch. Sleep stops a running playlist and disarms scheduling.

## Rehearsal

Use disposable copies of two saved shows, an intro, a still intermission and an outro. Verify normal order, repeat, shuffle, finish-current, immediate stop and a deleted or relocated show file. Schedule a near-future rehearsal with a short cutoff. Verify show order and output handoffs in Test Window, then test a real display if available. Reopen the app to verify it returns to Project Home disarmed. Visual, listening and hardware rehearsal remain pending.
