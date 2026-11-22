# Show Mode rehearsal

Use Projection Mapper v2.11/build 36 in Applications. Open a rehearsal copy of a show with projection, video, a soundtrack and simulated fixtures.

1. Enter **Show**. The show opens unarmed and pauses any editing preview at its current time. Confirm the project title, output, audio and clock. Choose Test Window for rehearsal. Open a selected projector before arming if using one.
2. Use **Check Readiness**. Repair blockers in Edit or Lighting, then return to Show. Review warnings before running. **Prepare & Arm** checks again, samples up to 12 video assets and starts warming nearby video clips. Arming leaves the show paused. For a show with more than 12 videos, rehearse beyond the opening to check the other clips.
3. Press **Play**. Test Pause, Stop, manual GO and Release to Timeline. Pause holds position. Stop returns to zero, blacks out projection and stops fixtures. The end of a nonlooping song or timed sequence holds the endpoint with projection blacked out and fixtures stopped. Use Stop, Restore Projection and Play to repeat from zero. An elapsed-time preview with no timed content runs until paused or stopped.
4. Check separate Projection Blackout, Fixture Blackout and audio mute. In **Projection Controls**, check live brightness and fade duration, then identify one object while paused. Finish Identification returns to the prior scene. Live controls are session settings.
5. Rehearse several shows back-to-back. Load each show, prepare it, run through the final cue and verify that operator controls remain available. Try a loop and check A/V playback and fixture cues across the wrap.
6. With a rehearsal running, close Test Window or disconnect the selected projector. Confirm Show reports an interruption and pauses. Restore the device, reopen output, prepare again, restore blackouts and press Play to resume. Repeat with external audio if available. Sleep and wake should require the same explicit rearm and resume.
7. In Lighting, use an injected simulated controller failure to check the readiness blocker, then clear it and prepare. For missing media, use a disposable copy and verify that preparation names the missing asset. Check the Show Log for recent preparation, fault and frame or decoder delay events.
8. Confirm phone Play and GO are disabled until the Mac is armed. Pause, Stop, blackout and mute remain operator controls. Close or quit during a running rehearsal to check the stop confirmation. Reopen to verify that Show Mode never starts itself.

Hardware timing, reconnect behavior, multi-show rehearsal and visual and listening acceptance are user checks. The log reports AVPlayer buffering and render submission symptoms. Use external measurement to establish optical latency or actual audio underruns.
