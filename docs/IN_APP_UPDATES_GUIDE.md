# Install Projection Mapper updates in the app

Install the first version with in-app installation manually. In Projection Mapper, choose **Check for Updates…** to check immediately. Automatic checks use the existing daily schedule.

When an available release supports in-app installation, choose **Install Update**. Projection Mapper downloads and verifies it, then offers **Restart to Install**. The app saves pending project work through its usual autosave flow, waits until it is idle, and reopens after replacement. Releases without a signed archive offer their download page. macOS can apply its normal permissions and approval prompts.

## Publish an in-app update

1. Build and test a newer full version. Use a higher bundle build number and an archive named `ProjectionMapper-…-macOS-universal.zip`.
2. On the publisher’s Mac, use the pinned Xcode Swift toolchain to run `xcrun swift app/tools/SignUpdate.swift sign /path/to/archive.zip`. This writes `archive.zip.sig` beside the verified archive. The signature covers the exact ZIP bytes.
3. Attach the ZIP and its matching `.sig` file to the same GitHub full release. Confirm the numeric tag matches the app’s version and verify the downloaded assets before publishing.

The app trusts the public key embedded in its bundle. The matching private key lives in the publisher’s local account at `~/Library/Application Support/ProjectionMapperReleaseSigning/ed25519.key` with owner-only permissions. Preserve it in a secure private backup. Existing app copies with the embedded public key require signatures made with that key.
