import CryptoKit
import Darwin
import Foundation

struct PreparedReleaseUpdate: Sendable {
    let id: UUID
    let target: URL
    let tag: String

    var directory: URL {
        target.deletingLastPathComponent().appendingPathComponent(".ProjectionMapper-Update-" + id.uuidString, isDirectory: true)
    }

    func discard() {
        if ReleaseUpdateInstaller.isPrivateDirectory(directory) { try? FileManager.default.removeItem(at: directory) }
    }
}

enum ReleaseUpdateInstaller {
    static let argument = "--projection-mapper-install-update"
    static let failureKey = "ProjectionMapper.updateInstallFailure"
    static let maximumZIPSize = 256 * 1024 * 1024
    private static let keyName = "ProjectionMapperUpdatePublicKey"
    private static let bundleID = "local.keith.ProjectionMapper"

    enum InstallError: LocalizedError {
        case unsigned, location, download, authenticity, bundle, replacement, relaunch, rollback

        var errorDescription: String? {
            switch self {
            case .unsigned: "This release needs a manual installation."
            case .location: "Move Projection Mapper to a writable Applications folder before installing an update."
            case .download: "The update download couldn’t finish. Try again."
            case .authenticity: "The update signature couldn’t be verified."
            case .bundle: "The downloaded app doesn’t match the expected Projection Mapper update."
            case .replacement: "The update couldn’t replace the installed app."
            case .relaunch: "macOS couldn’t reopen Projection Mapper after the update."
            case .rollback: "The update couldn’t restore the previous app. Its copy is still in the private update folder."
            }
        }
    }

    static func prepare(_ update: ReleaseUpdate, target: URL) async throws -> PreparedReleaseUpdate {
        guard let archive = update.archive, let publicKey = publicKey(in: target) else { throw InstallError.unsigned }
        let target = target.resolvingSymlinksInPath()
        guard isEligibleTarget(target) else { throw InstallError.location }
        let prepared = PreparedReleaseUpdate(id: UUID(), target: target, tag: update.tag)
        do {
            try FileManager.default.createDirectory(at: prepared.directory, withIntermediateDirectories: false,
                                                    attributes: [.posixPermissions: 0o700])
        } catch { throw InstallError.location }
        guard isPrivateDirectory(prepared.directory) else { throw InstallError.location }

        do {
            let session = URLSession(configuration: .ephemeral)
            defer { session.finishTasksAndInvalidate() }
            try await download(archive.signature, bytes: 64, using: session, to: prepared.directory.appendingPathComponent("update.sig"))
            try await download(archive.zip, bytes: archive.size, using: session, to: prepared.directory.appendingPathComponent("update.zip"))
            try Task.checkCancellation()
            let validation = Task.detached(priority: .userInitiated) { try extract(prepared, key: publicKey) }
            let extracted = try await validation.value
            try FileManager.default.removeItem(at: extracted.deletingLastPathComponent())
            return prepared
        } catch {
            prepared.discard()
            throw error
        }
    }

    private static func download(_ url: URL, bytes: Int, using session: URLSession, to destination: URL) async throws {
        guard (1...maximumZIPSize).contains(bytes) else { throw InstallError.download }
        let request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 30)
        let (temporary, response) = try await session.download(for: request)
        defer { try? FileManager.default.removeItem(at: temporary) }
        guard let response = response as? HTTPURLResponse, response.statusCode == 200,
              response.url?.scheme == "https",
              let host = response.url?.host, ["github.com", "release-assets.githubusercontent.com", "objects.githubusercontent.com"].contains(host),
              isRegularFile(temporary, bytes: bytes) else { throw InstallError.download }
        try FileManager.default.moveItem(at: temporary, to: destination)
    }

    static func verify(archive: Data, signature: Data, key: Data) throws {
        guard !archive.isEmpty, archive.count <= maximumZIPSize, signature.count == 64,
              let publicKey = try? Curve25519.Signing.PublicKey(rawRepresentation: key),
              publicKey.isValidSignature(signature, for: archive) else { throw InstallError.authenticity }
    }

    static func validateCandidate(_ candidate: URL, replacing target: URL, tag: String) throws {
        let current = info(in: target)
        let replacement = info(in: candidate)
        guard let currentVersion = current?["CFBundleShortVersionString"] as? String,
              let currentBuild = (current?["CFBundleVersion"] as? String).flatMap(Int.init),
              let nextVersion = replacement?["CFBundleShortVersionString"] as? String,
              let nextBuild = (replacement?["CFBundleVersion"] as? String).flatMap(Int.init),
              let installed = ReleaseVersion(currentVersion), let available = ReleaseVersion(tag),
              available == ReleaseVersion(nextVersion), available > installed, nextBuild > currentBuild,
              current?["CFBundleIdentifier"] as? String == bundleID,
              replacement?["CFBundleIdentifier"] as? String == bundleID,
              replacement?["CFBundlePackageType"] as? String == "APPL",
              replacement?["CFBundleExecutable"] as? String == "ProjectionMapper",
              let minimum = (replacement?["LSMinimumSystemVersion"] as? String).flatMap(ReleaseVersion.init),
              let os = ReleaseVersion(ProcessInfo.processInfo.operatingSystemVersion) else { throw InstallError.bundle }
        guard os >= minimum, run("/usr/bin/codesign", ["--verify", "--deep", "--strict", candidate.path]) else {
            throw InstallError.bundle
        }
    }

    static func startHelper(for update: PreparedReleaseUpdate, executable: URL) throws {
        guard isPrivateDirectory(update.directory), isEligibleTarget(update.target) else { throw InstallError.location }
        let process = Process()
        process.executableURL = executable
        process.arguments = [argument, update.id.uuidString, update.tag, String(getpid())]
        process.standardInput = FileHandle.nullDevice
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        try process.run()
    }

    /// The current app executable also handles the short, UI-free replacement after its original process exits.
    static func runHelper(_ arguments: [String], bundle: URL) -> Int32? {
        guard arguments.first == argument else { return nil }
        let target = bundle.resolvingSymlinksInPath()
        guard arguments.count == 4, let id = UUID(uuidString: arguments[1]),
              let parent = Int32(arguments[3]), parent > 1,
              isEligibleTarget(target), let key = publicKey(in: target) else { return 1 }
        let prepared = PreparedReleaseUpdate(id: id, target: target, tag: arguments[2])
        guard isPrivateDirectory(prepared.directory) else { return 1 }
        // A very fast parent exit may reparent the helper before it reaches this line.
        guard getppid() == parent || (getppid() == 1 && kill(parent, 0) == -1 && errno == ESRCH) else { return 1 }
        let end = ProcessInfo.processInfo.systemUptime + 30
        while getppid() == parent && ProcessInfo.processInfo.systemUptime < end { usleep(50_000) }
        guard getppid() != parent else { return 1 }

        var shouldDiscard = true
        defer { if shouldDiscard { prepared.discard() } }
        do {
            let next = try extract(prepared, key: key)
            try replace(target, with: next) {
                run("/usr/bin/open", ["-n", target.path])
            }
            return 0
        } catch {
            // A failed atomic rollback leaves the previous bundle in the private staging folder.
            if case InstallError.rollback = error { shouldDiscard = false }
            UserDefaults.standard.set(error.localizedDescription, forKey: failureKey)
            UserDefaults.standard.synchronize()
            _ = run("/usr/bin/open", ["-n", target.path])
            return 1
        }
    }

    /// Both bundle paths are on the same volume and the replacement is already verified.
    static func replace(_ target: URL, with candidate: URL, launch: () -> Bool) throws {
        guard swap(target, candidate) else { throw InstallError.replacement }
        guard launch() else {
            guard swap(target, candidate) else { throw InstallError.rollback }
            throw InstallError.relaunch
        }
    }

    private static func swap(_ first: URL, _ second: URL) -> Bool {
        first.path.withCString { a in
            second.path.withCString { b in
                renameatx_np(AT_FDCWD, a, AT_FDCWD, b, UInt32(RENAME_SWAP)) == 0
            }
        }
    }

    private static func extract(_ update: PreparedReleaseUpdate, key: Data) throws -> URL {
        guard isPrivateDirectory(update.directory) else { throw InstallError.location }
        let zip = update.directory.appendingPathComponent("update.zip")
        let signature = update.directory.appendingPathComponent("update.sig")
        guard isRegularFile(signature, bytes: 64), let size = regularFileSize(zip),
              (1...maximumZIPSize).contains(size) else { throw InstallError.authenticity }
        try verify(archive: Data(contentsOf: zip, options: .mappedIfSafe), signature: Data(contentsOf: signature), key: key)
        let destination = update.directory.appendingPathComponent("Extracted", isDirectory: true)
        try FileManager.default.createDirectory(at: destination, withIntermediateDirectories: false)
        guard run("/usr/bin/ditto", ["-x", "-k", zip.path, destination.path]) else { throw InstallError.bundle }
        let app = destination.appendingPathComponent("ProjectionMapper.app", isDirectory: true)
        let entries = try FileManager.default.contentsOfDirectory(atPath: destination.path)
        let values = try app.resourceValues(forKeys: [.isDirectoryKey, .isSymbolicLinkKey])
        guard entries == [app.lastPathComponent], values.isDirectory == true, values.isSymbolicLink == false else { throw InstallError.bundle }
        try validateCandidate(app, replacing: update.target, tag: update.tag)
        return app
    }

    static func publicKey(in target: URL) -> Data? {
        (info(in: target)?[keyName] as? String).flatMap { Data(base64Encoded: $0) }
    }

    private static func info(in bundle: URL) -> [String: Any]? {
        guard let data = try? Data(contentsOf: bundle.appendingPathComponent("Contents/Info.plist")) else { return nil }
        return (try? PropertyListSerialization.propertyList(from: data, format: nil)) as? [String: Any]
    }

    static func isPrivateDirectory(_ url: URL) -> Bool {
        var value = stat()
        return lstat(url.path, &value) == 0 && (value.st_mode & S_IFMT) == S_IFDIR &&
            value.st_uid == getuid() && value.st_mode & 0o077 == 0
    }

    private static func isEligibleTarget(_ url: URL) -> Bool {
        url.isFileURL && url.pathExtension == "app" && !url.pathComponents.contains("AppTranslocation") &&
            info(in: url)?["CFBundleIdentifier"] as? String == bundleID
    }

    private static func regularFileSize(_ url: URL) -> Int? {
        var value = stat()
        guard lstat(url.path, &value) == 0, (value.st_mode & S_IFMT) == S_IFREG else { return nil }
        return Int(exactly: value.st_size)
    }

    private static func isRegularFile(_ url: URL, bytes: Int) -> Bool { regularFileSize(url) == bytes }

    @discardableResult
    private static func run(_ executable: String, _ arguments: [String]) -> Bool {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments
        process.standardInput = FileHandle.nullDevice
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        do { try process.run() } catch { return false }
        process.waitUntilExit()
        return process.terminationReason == .exit && process.terminationStatus == 0
    }
}

private extension ReleaseVersion {
    init?(_ value: OperatingSystemVersion) {
        self.init("\(value.majorVersion).\(value.minorVersion).\(value.patchVersion)")
    }
}
