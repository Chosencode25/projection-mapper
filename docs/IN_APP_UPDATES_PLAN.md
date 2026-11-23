# In-app updates

Keep GitHub Releases as the delivery source and use the existing idle update notice. Add an in-app download and verification step, then ask the user to restart. Save or discard pending changes through the ordinary project prompt before quitting. Defer restart while a show, recording, playlist, export, or project operation is active.

Authenticate each archive with a separate Ed25519 signature and a public key embedded in the app. Keep the private key in the publisher's local account. Check the expected repository asset, signature, bundle identity, build and version before the installed app is touched. Use native tools so the free ad-hoc build does not need a loaded third-party framework.

Run the replacement as a separate process after the app exits. Stage beside the application so replacement is atomic, preserve the old app until launch is requested successfully, and restore it if relaunch fails. Keep normal macOS authorization and permission checks. Older unsigned releases retain the manual download route.

Exercise current, unsigned and signed release discovery, corrupt archive rejection, same or older build rejection, and replacement of a disposable signed app. Keep the active Applications copy and GitHub release unchanged until separate delivery authorization.
