# Project cleanup — October 19, 2026

User requested removing old local versions already recoverable from GitHub,
backing up newer local work correctly and improving the project while preserving
its usability and development environment. This explicitly supersedes the earlier
local-only delivery restriction for this cleanup/source backup. No new release,
tag or published app download is requested.

## Findings and retained structure

GitHub main was verified at `ecb57fe9986fbb69743a25d7feb0f5f8a0694425`.
Existing releases include v1.01, v1.02-preview.1, v1.03.1, v1.04.2, v1.15 and
v1.15.1; release metadata and V1 archive SHA-256 digests match existing local
records. The working tree contained the newer, uncommitted v2.01 implementation
and mobile-editor planning. Those are retained for source backup with this work.

Old `builds/v1.*`, `builds/timeline` and `builds/ui-polish` directories held about
42.99 GiB of logical file data in generated output. Source, tests, media, guides, milestone plans, Git
history/tags, pinned Xcode and the read-only ChatGPT mirror remain available.
Lightweight old JSON/text/log evidence was copied into `builds/evidence/history/`
before removing raw result bundles, derived data, ZIPs and application copies.
Historical verification documents retain original dates and test limits; paths
to removed raw artifacts are historical references, not current files.

Eight `.projectionmap` projects found inside old build folders were copied to
`assets/local-projects/` with complete per-file SHA-256 comparisons before deletion.
Three old scratch helpers were preserved there under `development-samples/`.
These local working files are excluded from Git and from build cache cleanup.
The local audit `builds/evidence/rescued-projects.json` records their exact paths.
The separate demo previously deleted from `assets/demos/` is consolidated into
the intact bundled resource; tests and Help use that same protected fixture.
The distinct older video/timeline demo remains as a useful source fixture.

## Improvements

- Add `app/scripts/project.py` with doctor/build/test and preview-first cache cleanup.
  Builds/tests reject any toolchain other than Xcode 27.0 (27A5237l), use one
  disposable cache, build universal slices and retain dated evidence. Cleaning
  targets only that cache and refuses redirected output directories.
- Replace accumulated obsolete current-build instructions with one current guide
  and simplify the root/source READMEs. Keep historical milestone records.
- Fix a display-change race during projector-window creation: a rejected window
  releases its renderer and transitions out of opening to a useful recovery state.
  A regression checks no presentation, resource release and successful explicit retry.
- Keep one current runnable workspace app, one current local archive and a current
  Applications copy; remove obsolete application versions and version-specific caches.

## Verification and delivery

Exact pinned Xcode verified. Final Debug and Release each passed **285 correctness
tests**, zero failures/recorded runtime warnings, four benchmarks skipped and two
legacy visible-window tests excluded. Compact summaries are tracked under
`docs/verification/2026-10-19/`. Universal Release build, strict signature and all
11 file hashes passed; matching app copies are installed in app/ and Applications.
The old Applications v1.15 copy and obsolete project-specific Library cache have
been removed. App packaging and GitHub delivery are being completed. No routine app
launch or screen control is used. Physical projector, optical timing, listening,
Intel/older-macOS runtime and Developer ID/notarization remain pending/unestablished.
The October 14 workload profiling remains applicable except for the narrowly
changed opening-failure path; no new performance or physical acceptance claim.

## Scope limits

Cleanup covers the working project, matching files found in accessible home-folder
locations, `/Applications/ProjectionMapper.app` and the identified project-specific
Xcode DerivedData folder. Protected/unreadable locations, system backups and the
read-only project mirror are not erased. Git history is deliberately retained for
ongoing development. Published releases/assets and private repository visibility
are preserved.
