# Automatic local Phone Remote setup

Implementation record updated November 17, 2026 following the user's requirement that the Mac host the entire remote and use the home network. The proposed simple mode uses a local HTTP page in Safari. The user explicitly accepted unencrypted local transport on November 17, 2026. Build 30 implements this mode. The existing HTTPS option remains available for encrypted use.

The intended experience is **Phone Remote → Start Local Remote → Scan QR → Approve Phone**.

## Build sequence

1. Add an explicit Local HTTP mode to the existing Mac listener. Serve the phone page, scripts, styles, and commands directly from the Mac. Show that this mode is unencrypted and intended for a trusted network before enabling it.
2. Discover active private IPv4 interfaces automatically. Prefer the active Wi-Fi interface, expose an interface picker when needed, and bind to the chosen address. Generate the QR using that numeric address, which avoids a hostname or local DNS setup.
3. Replace the normal certificate form with Start Local Remote, status, QR, permissions, approval, revoke, and stop controls. Keep HTTPS identity controls under Advanced.
4. Parameterize the request origin and pairing URL by the selected HTTP or HTTPS mode. Preserve exact Host and Origin checks, invitation expiry, Mac approval, session expiry, roles, request limits, command deduplication, project revision checks, and Show locks.
5. Verify the current phone scripts against HTTP. Use same-origin requests for all browser communication, including state polling. The first browser opening uses the Camera QR scan. Check Safari's behavior and any HTTP warnings on the actual iPhone.
6. Reuse build 29's endpoint-specific network monitoring. Keep approval through brief interruptions while the endpoint is unchanged. If its address changes, show a new QR after the user restarts local remote. Show disconnected state on the phone and require current Mac state before resuming commands.
7. Test HTTP and HTTPS pairing, approval, revocation, expired invitations, rejected origins, stale edits, interrupted requests, and duplicate commands. Rehearse on iPhone Safari and Android Chrome on a private network, including a network with no internet service. Verify that playback continues through disconnects and that the service stops when requested.
8. Run the required Mac checks with Xcode 27.0 beta 5 (27A5237l), package the tested universal app, and update the local setup guide. Record which browsers and networks were actually verified.

## Tradeoff and acceptance

HTTP provides an unencrypted connection. Pairing tokens, commands, and displayed project information can be observed or modified by someone able to intercept local traffic. Pairing and Mac approval enforce app permissions but do not provide transport encryption. Safari may label the page Not Secure. The user accepted this tradeoff for the home network before implementation.

A certificate-trusted encrypted browser connection still requires trust provisioning. Fully local encrypted alternatives include the existing certificate setup or a future native phone app with an authenticated pairing design.

The earlier hosted relay proposal is superseded by the user's local-only requirement. Build 30 is installed in Applications and passed five focused Release checks for HTTP and HTTPS. Actual phone-browser and offline-network rehearsal remain pending.

HTTP transport reference. [RFC 9110](https://www.rfc-editor.org/rfc/rfc9110.html#section-4.2).
