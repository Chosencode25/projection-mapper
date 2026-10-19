# GitHub presentation — October 19, 2026

User explicitly requested the proposed GitHub presentation improvements, including screenshots, a demo, clearer download/version choices, navigation, repository metadata, social artwork and issue templates. This authorizes delivery of these documentation/media changes as an exception to the milestone-only cadence. No app version bump or release publication is part of this work.

## Content

- Product-led README with app-icon-derived SVG branding, real editor/Test Output screenshots and a short expandable playback GIF.
- Separate download links for published v1.15.1/build 13 and build instructions for v2.01/build 14 source. Test Mode and physical-output acceptance are distinguished; no hosted CI badge or unverified projector-performance claim.
- Getting-started guide, documentation hub, contribution guide, and bug/feature issue forms.
- Repository description/topics and a custom 1280×640 social preview. Artwork source and its regeneration helper live in assets/github/ and app/scripts/repository_artwork.py.

## Media provenance

Screenshots and animation were captured from the installed, verified v2.01/build 14 app through Computer Use under the user's explicit request for those media assets. The app started on the default Untitled Project. Help → Open V1 Demo supplied only project-owned media; no personal project or original reference mirror was opened or changed. The screenshot timeline was zoomed to the demo's short clips. No content, geometry or playback settings were saved into the bundled demo.

editor.png and test-output.png are actual app-window captures. demo.gif encodes about 5.3 seconds of actual Test Output captures, reduced to 680 pixels wide / 10 fps for repository size. It is an illustrative recording, not a source/display FPS, optical latency or physical projector benchmark. Audio remained disabled. At the end the demo was paused at zero and Test Output closed. Routine user visual/listening/hardware acceptance remains separate.

The banner/social artwork uses the existing app icon's orange/magenta/cyan palette and connected cube motif. It is branding, not an app screenshot. SVG sources are editable; the PNG companion is rendered locally with Pillow, with no app dependency added. Social image dimensions/file limits follow [GitHub's social preview documentation](https://docs.github.com/en/repositories/managing-your-repositorys-settings-and-features/customizing-your-repository/customizing-your-repositorys-social-media-preview).

## Verification and delivery

Exact pinned Xcode reverified using the development helper. No app source or Xcode configuration changed, so the existing 285 Debug/Release correctness results remain the applicable app evidence. 63 local documentation/media links, SVG/media dimensions, issue-form syntax/field IDs and diff hygiene passed. Live GitHub rendering also passed: all README images/buttons and the expanded GIF loaded with nonzero native dimensions, and GitHub rendered the chooser and both issue forms with their intended fields. No issue was submitted. The description and ten topics were successfully applied through the GitHub API. The user signed into GitHub in the browser, and the social image upload completed with the artwork visible in repository settings. Repository files were successfully pushed on main at **4d6d42542b5cd13051b0a646689415afa0a93c33**, from **9107838**. Live README/media and both issue forms were verified after that push. Compact evidence is in docs/verification/2026-10-19/GitHub-presentation.json. The documentation-only verification record follows the presentation commit; app sources and published releases/tags remain unchanged.

## Visibility observation

GitHub's API and signed-in repository settings reported this repository as **public** at the start of this presentation work, despite the earlier local private-visibility records. Main still matched the last confirmed 9107838 delivery. Visibility was not changed by this work; no date or cause for the prior visibility change is inferred. Screenshots include only the bundled demo. Earlier private-visibility statements are historical records, not a current access guarantee.


Temporary raw captures and the intermediate image render were removed after the final
media were verified. Retained project media total about 1.9 MiB. The repository page
is left open on the redesigned README. No browser viewport override was applied.
