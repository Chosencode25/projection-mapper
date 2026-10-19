# Contributing

Start with [Getting started](docs/GETTING_STARTED.md) and the [documentation index](docs/README.md).

## Report a problem or propose a feature

Use the [issue forms](https://github.com/Chosencode25/projection-mapper/issues/new/choose). For a bug, include the app version/build, macOS version, steps, and what you expected versus what happened. Use the bundled demo when possible; avoid uploading personal media or unneeded personal file paths.

For output problems, include Test Mode versus an external display and any relevant display/mode/cable details. Distinguish observed behavior from untested hardware assumptions. A feature request is most useful when it explains the workflow and desired result.

## Develop locally

Read [project instructions](AGENTS.md), [development requirements](docs/PROJECT_DEVELOPMENT.md), the applicable milestone plan, and [GitHub workflow](docs/GITHUB_WORKFLOW.md) before changing source or delivering work.

- Use **Xcode 27.0 beta 5 (27A5237l)**. The [build helper](docs/BUILD_AND_RUN.md) checks it before building or testing.
- Keep native UI in SwiftUI/programmatic AppKit; preserve Test Mode and shared rendering/media ownership.
- Keep source in app/, plans/progress in docs/, project media in assets/, and generated output in builds/.
- Use a codex/ feature branch for the next milestone. Follow the project owner's delivery cadence; intermediate work stays local unless an exception is requested.
- Add focused regressions for behavioral fixes. Routine visual acceptance remains user-performed; record automated and visual evidence separately.
- Keep builds, caches, personal Xcode state and local projects out of commits. Preserve existing releases and tags.

```sh
python3 app/scripts/project.py doctor
python3 app/scripts/project.py build
python3 app/scripts/project.py test --configuration Debug
python3 app/scripts/project.py test --configuration Release
```

Explain the problem, resulting behavior, relevant checks and remaining limits in a proposed change. A documentation-only change does not require rebuilding the app. The repository does not currently declare an open-source license; no license grant is added by this guide.
