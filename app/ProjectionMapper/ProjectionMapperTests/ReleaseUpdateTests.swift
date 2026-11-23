import CryptoKit
import Foundation
import Testing

@MainActor
struct ReleaseUpdateTests {
    private func payload(_ tag: String, draft: Bool = false, preview: Bool = false, archive: Bool = true) throws -> Data {
        let assets: [[String: Any]] = archive ? [["name": "ProjectionMapper-v2.20-macOS-universal.zip", "state": "uploaded", "size": 100]] : []
        return try JSONSerialization.data(withJSONObject: [
            "tag_name": tag, "draft": draft, "prerelease": preview, "assets": assets,
            "html_url": "https://invalid.example/untrusted"
        ])
    }

    @Test func comparesNumericVersionsAndDerivesTheOfficialDownloadPage() throws {
        let next = try #require(try GitHubReleaseUpdates.update(from: payload("v2.16.1"), installed: "2.16"))
        #expect(next.tag == "v2.16.1")
        #expect(next.page.absoluteString == "https://github.com/Chosencode25/projection-mapper/releases/tag/v2.16.1")
        #expect(try GitHubReleaseUpdates.update(from: payload("v2.9"), installed: "2.16") == nil)
        #expect(try GitHubReleaseUpdates.update(from: payload("v2.16.0"), installed: "2.16") == nil)
        #expect(try GitHubReleaseUpdates.update(from: payload("v2.16"), installed: "2.9") != nil)
    }

    @Test func ignoresDraftsAndArchivesAndRejectsAnInvalidRelease() throws {
        #expect(try GitHubReleaseUpdates.update(from: payload("v2.21", draft: true), installed: "2.16") == nil)
        #expect(try GitHubReleaseUpdates.update(from: payload("archive/macos-builds", preview: true), installed: "2.16") == nil)
        #expect(try GitHubReleaseUpdates.update(from: payload("v2.21-preview.1", preview: true), installed: "2.16") == nil)
        #expect(throws: (any Error).self) {
            try GitHubReleaseUpdates.update(from: payload("v2.21", archive: false), installed: "2.16")
        }
        #expect(throws: (any Error).self) {
            try GitHubReleaseUpdates.update(from: payload("v2.21/extra"), installed: "2.16")
        }
    }

    @Test func throttlesAutomaticChecksAndHonorsLaterAcrossLaunches() async throws {
        let name = "update-tests." + UUID().uuidString
        let defaults = try #require(UserDefaults(suiteName: name))
        defer { defaults.removePersistentDomain(forName: name) }
        let update = try #require(try GitHubReleaseUpdates.update(from: payload("v2.17"), installed: "2.16"))
        let server = Response(update: update)
        let initial = Date(timeIntervalSince1970: 10_000)
        let checker = ReleaseUpdateChecker(defaults: defaults) { try await server.check() }
        await checker.check(now: initial)
        #expect(checker.notice == .available(update))
        await checker.check(now: initial.addingTimeInterval(100))
        #expect(await server.requests == 1)
        checker.dismiss(now: initial.addingTimeInterval(1_800))
        #expect(checker.notice == nil)

        let reopened = ReleaseUpdateChecker(defaults: defaults) { try await server.check() }
        let nextDay = initial.addingTimeInterval(86_400)
        await reopened.check(now: nextDay)
        #expect(await server.requests == 2 && reopened.notice == nil)
        await reopened.check(manual: true, now: nextDay)
        #expect(await server.requests == 3 && reopened.notice == .available(update))
    }

    @Test func aDifferentReleaseCanAppearDuringSnoozeAndOfflineErrorsStayQuiet() async throws {
        let name = "update-tests." + UUID().uuidString
        let defaults = try #require(UserDefaults(suiteName: name))
        defer { defaults.removePersistentDomain(forName: name) }
        let first = try #require(try GitHubReleaseUpdates.update(from: payload("v2.17"), installed: "2.16"))
        let newer = try #require(try GitHubReleaseUpdates.update(from: payload("v2.18"), installed: "2.16"))
        let server = Response(update: first)
        let initial = Date(timeIntervalSince1970: 10_000)
        let checker = ReleaseUpdateChecker(defaults: defaults) { try await server.check() }
        await checker.check(now: initial)
        checker.dismiss(now: initial.addingTimeInterval(1_800))
        await server.respond(with: newer)
        let nextDay = initial.addingTimeInterval(86_400)
        await checker.check(now: nextDay)
        #expect(checker.notice == .available(newer))
        checker.dismiss(now: nextDay)

        await server.respond(with: nil, offline: true)
        await checker.check(now: nextDay.addingTimeInterval(86_400))
        #expect(checker.notice == nil)
        await checker.check(manual: true, now: nextDay.addingTimeInterval(86_400))
        #expect(checker.notice == .failed)
        await server.respond(with: nil)
        await checker.check(manual: true, now: nextDay.addingTimeInterval(86_400))
        #expect(checker.notice == .upToDate)
    }

    @Test func presentationWaitsForPlaybackAndExport() {
        let session = EditorSession(presentOutput: { _ in })
        defer { session.releaseRuntimeResources() }
        #expect(session.canPresentReleaseUpdate)
        session.setPlaying(true, at: ProcessInfo.processInfo.systemUptime)
        #expect(!session.canPresentReleaseUpdate)
        session.setPlaying(false, at: ProcessInfo.processInfo.systemUptime)
        #expect(session.canPresentReleaseUpdate)
        session.deliveryRunning = true
        #expect(!session.canPresentReleaseUpdate)
        session.deliveryRunning = false
        #expect(session.canPresentReleaseUpdate)
    }

    @Test func signedReleasePairsOnlyTheExpectedZIPAndSignature() throws {
        let name = "ProjectionMapper-v2.17-macOS-universal.zip"
        let result = try JSONSerialization.data(withJSONObject: [
            "tag_name": "v2.17", "draft": false, "prerelease": false,
            "assets": [
                ["name": name, "state": "uploaded", "size": 100],
                ["name": name + ".sig", "state": "uploaded", "size": 64],
                ["name": "ProjectionMapper-wrong-macOS-universal.zip.sig", "state": "uploaded", "size": 64]
            ]
        ])
        let update = try #require(try GitHubReleaseUpdates.update(from: result, installed: "2.16"))
        let archive = try #require(update.archive)
        #expect(archive.zip.absoluteString == "https://github.com/Chosencode25/projection-mapper/releases/download/v2.17/" + name)
        #expect(archive.signature.absoluteString == archive.zip.absoluteString + ".sig")
        #expect(try GitHubReleaseUpdates.update(from: payload("v2.17"), installed: "2.16")?.archive == nil)
    }

    @Test func wrongSignaturesAndChangedArchiveBytesAreRejected() throws {
        let key = Curve25519.Signing.PrivateKey()
        let other = Curve25519.Signing.PrivateKey()
        let archive = Data("Test archive".utf8)
        let signature = try key.signature(for: archive)
        try ReleaseUpdateInstaller.verify(archive: archive, signature: signature, key: key.publicKey.rawRepresentation)
        #expect(throws: ReleaseUpdateInstaller.InstallError.authenticity) {
            try ReleaseUpdateInstaller.verify(archive: archive + Data([1]), signature: signature, key: key.publicKey.rawRepresentation)
        }
        #expect(throws: ReleaseUpdateInstaller.InstallError.authenticity) {
            try ReleaseUpdateInstaller.verify(archive: archive, signature: signature, key: other.publicKey.rawRepresentation)
        }
    }

    @Test func bundleValidationAndFailedLaunchLeaveTheOriginalInPlace() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: false)
        defer { try? FileManager.default.removeItem(at: directory) }
        let installed = try fixture(in: directory, name: "Installed.app", version: "2.16", build: "46")
        let candidate = try fixture(in: directory, name: "Candidate.app", version: "2.17", build: "47")
        let older = try fixture(in: directory, name: "Older.app", version: "2.17", build: "45")
        try ReleaseUpdateInstaller.validateCandidate(candidate, replacing: installed, tag: "v2.17")
        #expect(throws: ReleaseUpdateInstaller.InstallError.bundle) {
            try ReleaseUpdateInstaller.validateCandidate(older, replacing: installed, tag: "v2.17")
        }
        #expect(throws: ReleaseUpdateInstaller.InstallError.bundle) {
            try ReleaseUpdateInstaller.validateCandidate(candidate, replacing: installed, tag: "v2.18")
        }
        #expect(throws: ReleaseUpdateInstaller.InstallError.relaunch) {
            try ReleaseUpdateInstaller.replace(installed, with: candidate) { false }
        }
        #expect(Bundle(url: installed)?.object(forInfoDictionaryKey: "CFBundleVersion") as? String == "46")
        try ReleaseUpdateInstaller.replace(installed, with: candidate) { true }
        let bytes = try Data(contentsOf: installed.appendingPathComponent("Contents/Info.plist"))
        let next = try PropertyListSerialization.propertyList(from: bytes, format: nil) as? [String: String]
        #expect(next?["CFBundleVersion"] == "47")
    }

    private func fixture(in directory: URL, name: String, version: String, build: String) throws -> URL {
        let app = directory.appendingPathComponent(name)
        let contents = app.appendingPathComponent("Contents")
        let binaries = contents.appendingPathComponent("MacOS")
        try FileManager.default.createDirectory(at: binaries, withIntermediateDirectories: true)
        try FileManager.default.copyItem(at: URL(fileURLWithPath: "/bin/echo"),
                                         to: binaries.appendingPathComponent("ProjectionMapper"))
        let info = ["CFBundleVersion": build, "CFBundleShortVersionString": version,
                    "CFBundleIdentifier": "local.keith.ProjectionMapper", "CFBundleExecutable": "ProjectionMapper",
                    "CFBundlePackageType": "APPL", "LSMinimumSystemVersion": "15.0"]
        try PropertyListSerialization.data(fromPropertyList: info, format: .xml, options: 0)
            .write(to: contents.appendingPathComponent("Info.plist"))
        let codesign = Process()
        codesign.executableURL = URL(fileURLWithPath: "/usr/bin/codesign")
        codesign.arguments = ["--force", "--sign", "-", app.path]
        try codesign.run()
        codesign.waitUntilExit()
        try #require(codesign.terminationStatus == 0)
        return app
    }

    private actor Response {
        var requests = 0
        private var update: ReleaseUpdate?
        private var offline = false

        init(update: ReleaseUpdate?) { self.update = update }

        func respond(with update: ReleaseUpdate?, offline: Bool = false) {
            self.update = update
            self.offline = offline
        }

        func check() throws -> ReleaseUpdate? {
            requests += 1
            if offline { throw URLError(.notConnectedToInternet) }
            return update
        }
    }
}
