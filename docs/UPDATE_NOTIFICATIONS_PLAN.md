# GitHub release update notifications

Use the public Projection Mapper repository’s latest full release endpoint. Compare the release tag numerically with the installed version and require a universal Mac ZIP for a new release. Build the update link from the known repository and validated version tag.

Check automatically when the app launches or becomes active, at most once per 24 hours. Provide **Check for Updates** in the app menu for immediate checks. Background errors and current-version results are silent. Manual checks report whether a release is available, the app is current, or the request failed.

Present a dismissible notice in Project Home or the editor. Hold it while playback, recording, exports, Show Mode arming, or a playlist run is in progress. **Later** suppresses the automatic notice for that version for 24 hours. **Download Update** opens the release page for the notes and ZIP. Installation is manual.

Check current, older, newer, and invalid releases, the daily interval, per-version dismissal, manual override, errors, and presentation during protected show activities. Use Xcode 27.0 beta 5 (27A5237l). Deliver a local universal build for the first manual upgrade from build 44.
