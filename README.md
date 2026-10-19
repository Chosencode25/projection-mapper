![Projection Mapper — Make every surface a canvas](assets/github/hero.svg)

**A native Mac editor for projection mapping, connected surfaces, and timed visual effects.**
Shape your canvas, bring it to life with effects and media, and rehearse in a separate Test Window.

<p>
  <a href="https://github.com/Chosencode25/projection-mapper/releases/download/v1.15.1/ProjectionMapper-v1.15.1-macOS-universal.zip"><img src="assets/github/download-stable.svg" alt="Download stable v1.15.1 for macOS" height="46"></a>
  <a href="docs/BUILD_AND_RUN.md"><img src="assets/github/build-latest.svg" alt="Build latest v2.01 from source" height="46"></a>
</p>

macOS **15+** · Apple Silicon + Intel builds · SwiftUI, AppKit & Metal

[Getting started](docs/GETTING_STARTED.md) · [User guide](docs/V1_USER_GUIDE.md) · [Documentation](docs/README.md) · [Roadmap](docs/V2_ROADMAP.md) · [Report a bug](https://github.com/Chosencode25/projection-mapper/issues/new/choose)

## Your workspace, your output

<table>
  <tr>
    <td width="70%"><a href="assets/github/editor.png"><img src="assets/github/editor.png" alt="Actual v2.01 editor showing mapped house cutouts, connected faces, content controls, and timeline clips"></a></td>
    <td width="30%"><a href="assets/github/test-output.png"><img src="assets/github/test-output.png" alt="Actual clean Test Output window showing the bundled demo without editing handles or its reference image"></a></td>
  </tr>
  <tr><td><b>Edit and sequence.</b> Keep surfaces, content, and timing in one workspace.</td><td><b>Rehearse separately.</b> Inspect clean output while keeping the editor available.</td></tr>
</table>

<details>
<summary><b>Watch the demo</b> — a short capture of Test Mode playback</summary>

<p align="center"><img src="assets/github/demo.gif" alt="A five-second recording of the actual v2.01 Test Output playing the bundled demo's animated gradient, moving lines, and generated video fixtures" width="440"></p>

Captured from the actual v2.01 app using project-owned demo media. This shows Test Mode playback, not a physical projection or a frame-rate benchmark.

</details>

## What you can make

| Feature | In your workflow |
|---|---|
| **Surface mapping** | Position corners, shape polygon masks, and cut out windows or other details. |
| **Connected objects** | Give multiple faces one content canvas, with Continuous and Repeat modes. |
| **Effects and media** | Mix built-in animations, images, and video; reuse looks and palettes. |
| **Visual timeline** | Capture content into clips, trim and move them, then scrub and rehearse. |
| **Portable projects** | Save referenced media with your layout, with undo/redo and recovery. |
| **Test Mode** | Use a resizable output window that shares the editor's renderer and timing. |

## Choose your version

| | Downloadable release | Latest source |
|---|---|---|
| **Version** | [v1.15.1 / build 13](https://github.com/Chosencode25/projection-mapper/releases/tag/v1.15.1) | [v2.01 / build 14](docs/BUILD_AND_RUN.md) |
| **Output** | Resizable Test Window | Test Window + explicit external fullscreen output |
| **Use it** | [Download the universal app](https://github.com/Chosencode25/projection-mapper/releases/download/v1.15.1/ProjectionMapper-v1.15.1-macOS-universal.zip) | Build with **Xcode 27.0 beta 5 (27A5237l)** |

The latest source passed **285 correctness checks in both Debug and Release** on the recorded Apple Silicon test host. These are local automated checks, not hosted CI. [Verification and exclusions →](docs/V2.01_VERIFICATION.md)

**Current limits:** physical projector and optical timing acceptance remain pending. Listening/device-loss and Intel/older-macOS runtime acceptance are also pending. Builds are locally ad-hoc signed; Developer ID signing and notarization are not established. Music sequencing, advanced choreography, and the phone editor are on the [V2 roadmap](docs/V2_ROADMAP.md).

## Get started

1. Download the release, extract it, and move **ProjectionMapper.app** to Applications.
2. Open **Help → Open V1 Demo** to explore an unsaved copy of the included project.
3. Select a face, inspect its mapping and content, then open **Test Output** and press Play.

[Full getting-started guide →](docs/GETTING_STARTED.md)

## Build and contribute

```sh
git clone https://github.com/Chosencode25/projection-mapper.git
cd projection-mapper
python3 app/scripts/project.py doctor
python3 app/scripts/project.py build
```

Use the exact pinned Xcode build. The helper keeps generated files in one disposable cache; the native interface is entirely SwiftUI and programmatic AppKit.

[Build & test](docs/BUILD_AND_RUN.md) · [Contributing](CONTRIBUTING.md) · [Feature requests](https://github.com/Chosencode25/projection-mapper/issues/new/choose) · [Changelog](CHANGELOG.md)

<details>
<summary>Project history and maintenance</summary>

[Development requirements](docs/PROJECT_DEVELOPMENT.md), [progress](docs/PROGRESS.md), [GitHub workflow](docs/GITHUB_WORKFLOW.md), and [cleanup records](docs/PROJECT_CLEANUP_2026-10-19.md) retain detailed milestone evidence. Published releases and tags are preserved. [Documentation index →](docs/README.md)

</details>
