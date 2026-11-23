# Get Projection Mapper update notifications

Install the first updater-enabled build manually. On launch or when Projection Mapper becomes active, it checks GitHub at most once in 24 hours. **Projection Mapper → Check for Updates…** runs an immediate check.

When a newer full release is available, a card in the editor or Project Home shows the installed and available versions. **Download Update** opens the GitHub release page with the notes and Mac ZIP. **Later** defers that release for at least 24 hours, until an eligible automatic check. A manual check can show it sooner.

The card stays out of the projector window. Playback, active or armed shows, playlists, recording, exports, and project sheets defer it. Automatic checks stay quiet when the Mac is offline. A manual check reports a connection problem in the same card.

To send an update to users, build and test the next app version and publish it as a full release on the Projection Mapper GitHub repository. Use a numeric tag such as `v2.17` and attach the universal app ZIP using the `ProjectionMapper-…-macOS-universal.zip` filename pattern. The app uses GitHub’s latest full release and compares its version with the installed app. The update ZIP installs manually.
