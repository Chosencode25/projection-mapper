import Foundation
import Observation

struct ReleaseVersion: Comparable, Sendable {
    let major: Int
    let minor: Int
    let patch: Int

    init?(_ value: String) {
        let number = value.hasPrefix("v") ? value.dropFirst() : value[...]
        let parts = number.split(separator: ".", omittingEmptySubsequences: false)
        guard (2...3).contains(parts.count),
              parts.allSatisfy({ !$0.isEmpty && $0.utf8.allSatisfy { (48...57).contains($0) } }) else { return nil }
        let values = parts.compactMap { Int($0) }
        guard values.count == parts.count else { return nil }
        major = values[0]
        minor = values[1]
        patch = values.count == 3 ? values[2] : 0
    }

    static func < (lhs: Self, rhs: Self) -> Bool {
        (lhs.major, lhs.minor, lhs.patch) < (rhs.major, rhs.minor, rhs.patch)
    }

    var preferenceKey: String { "\(major).\(minor).\(patch)" }
}

struct ReleaseUpdate: Equatable, Sendable {
    struct Archive: Equatable, Sendable {
        let zip: URL
        let signature: URL
        let size: Int
    }

    let version: ReleaseVersion
    let tag: String
    let page: URL
    var archive: Archive?
}

enum GitHubReleaseUpdates {
    static let endpoint = URL(string: "https://api.github.com/repos/Chosencode25/projection-mapper/releases/latest")!
    private static let releases = URL(string: "https://github.com/Chosencode25/projection-mapper/releases/tag")!
    private static let downloads = URL(string: "https://github.com/Chosencode25/projection-mapper/releases/download")!
    private static let session = URLSession(configuration: .ephemeral)

    private enum ReleaseError: Error { case unavailable, invalidRelease }

    private struct Payload: Decodable {
        struct Asset: Decodable {
            let name: String
            let state: String
            let size: Int
        }

        let tag_name: String
        let draft: Bool
        let prerelease: Bool
        let assets: [Asset]
    }

    static func check(installed: String) async throws -> ReleaseUpdate? {
        var request = URLRequest(url: endpoint, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 12)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue("ProjectionMapper", forHTTPHeaderField: "User-Agent")
        let (data, response) = try await session.data(for: request)
        guard let response = response as? HTTPURLResponse, response.statusCode == 200,
              response.url?.scheme == "https", response.url?.host == endpoint.host else {
            throw ReleaseError.unavailable
        }
        return try update(from: data, installed: installed)
    }

    static func update(from data: Data, installed: String) throws -> ReleaseUpdate? {
        guard data.count <= 512 * 1024, let current = ReleaseVersion(installed) else {
            throw ReleaseError.invalidRelease
        }
        let release = try JSONDecoder().decode(Payload.self, from: data)
        guard !release.draft, !release.prerelease else { return nil }
        guard release.tag_name.hasPrefix("v"), let version = ReleaseVersion(release.tag_name) else {
            throw ReleaseError.invalidRelease
        }
        guard version > current else { return nil }
        let appZIPs = release.assets.filter { asset in
            let name = asset.name.lowercased()
            return asset.state == "uploaded" && (1...ReleaseUpdateInstaller.maximumZIPSize).contains(asset.size) &&
                name.hasPrefix("projectionmapper-") && name.hasSuffix("-macos-universal.zip") &&
                name.utf8.allSatisfy { (48...57).contains($0) || (97...122).contains($0) || [45, 46, 95].contains($0) }
        }
        guard !appZIPs.isEmpty else { throw ReleaseError.invalidRelease }
        let signed = appZIPs.first { asset in
            release.assets.contains { $0.name == asset.name + ".sig" && $0.size == 64 && $0.state == "uploaded" }
        }
        let folder = downloads.appendingPathComponent(release.tag_name)
        let archive = signed.map {
            ReleaseUpdate.Archive(zip: folder.appendingPathComponent($0.name),
                                  signature: folder.appendingPathComponent($0.name + ".sig"), size: $0.size)
        }
        // Construct links from the repository, validated numeric tag, and bounded asset names.
        return ReleaseUpdate(version: version, tag: release.tag_name, page: releases.appendingPathComponent(release.tag_name), archive: archive)
    }
}

@MainActor
@Observable
final class ReleaseUpdateChecker {
    enum Notice: Equatable {
        case available(ReleaseUpdate)
        case upToDate
        case failed
        case installationFailed(String)
    }

    private(set) var notice: Notice?
    private(set) var isChecking = false
    private(set) var isPreparingInstall = false
    private(set) var readyToInstall: PreparedReleaseUpdate?
    private(set) var installError: String?
    private let defaults: UserDefaults
    private let request: @Sendable () async throws -> ReleaseUpdate?
    private var manualFeedback = false
    private static let interval: TimeInterval = 24 * 60 * 60
    private static let checkedKey = "ProjectionMapper.updateLastChecked"
    private static let laterKey = "ProjectionMapper.updateLater."

    init(defaults: UserDefaults = .standard, request: @escaping @Sendable () async throws -> ReleaseUpdate?) {
        self.defaults = defaults
        self.request = request
    }

    func check(manual: Bool = false, now: Date = .now) async {
        guard !isPreparingInstall, readyToInstall == nil else { return }
        if case .installationFailed = notice, !manual { return }
        if manual { manualFeedback = true }
        guard !isChecking else { return }
        guard manual || !isRecent(defaults.object(forKey: Self.checkedKey) as? Date, at: now) else { return }
        defaults.set(now, forKey: Self.checkedKey)
        isChecking = true
        if manual { notice = nil; installError = nil }
        defer {
            isChecking = false
            manualFeedback = false
        }
        do {
            guard let update = try await request() else {
                notice = manualFeedback ? .upToDate : nil
                return
            }
            let key = Self.laterKey + update.version.preferenceKey
            let postponed = isRecent(defaults.object(forKey: key) as? Date, at: now)
            notice = manualFeedback || !postponed ? .available(update) : nil
        } catch {
            if manualFeedback { notice = .failed }
        }
    }

    func loadLastInstallFailure() {
        if let error = defaults.string(forKey: ReleaseUpdateInstaller.failureKey) {
            defaults.removeObject(forKey: ReleaseUpdateInstaller.failureKey)
            notice = .installationFailed(error)
        }
    }

    func prepareInstall(_ update: ReleaseUpdate, for target: URL) async {
        guard notice == .available(update), !isChecking, !isPreparingInstall, readyToInstall == nil else { return }
        isPreparingInstall = true
        installError = nil
        defer { isPreparingInstall = false }
        do {
            readyToInstall = try await ReleaseUpdateInstaller.prepare(update, target: target)
        } catch {
            installError = error.localizedDescription
        }
    }

    func reportInstallError(_ error: Error) {
        installError = error.localizedDescription
    }

    func dismiss(now: Date = .now) {
        guard !isPreparingInstall else { return }
        readyToInstall?.discard()
        readyToInstall = nil
        installError = nil
        if case .available(let update) = notice {
            defaults.set(now, forKey: Self.laterKey + update.version.preferenceKey)
        }
        notice = nil
    }

    private func isRecent(_ date: Date?, at now: Date) -> Bool {
        guard let date else { return false }
        return (0..<Self.interval).contains(now.timeIntervalSince(date))
    }
}
