import AppKit
import Observation

@MainActor @Observable
final class ShowLibrary {
    private struct Settings: Codable {
        var version = 1
        var playlists: [ShowPlaylist] = []
        var schedules: [ShowSchedule] = []
        var seen: [String] = []
    }

    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private var task: Task<Void, Never>?
    @ObservationIgnored private var scheduler: Task<Void, Never>?
    @ObservationIgnored private var armedAt: Date?
    @ObservationIgnored private var gracefulStop = false
    @ObservationIgnored private var limit: Date?
    @ObservationIgnored private var graceStarted: TimeInterval?
    @ObservationIgnored private var scheduledRule: ShowSchedule?
    @ObservationIgnored private var runID = UUID()
    @ObservationIgnored private var settings = Settings()
    private(set) var playlists: [ShowPlaylist] = []
    private(set) var schedules: [ShowSchedule] = []
    private(set) var running = false
    private(set) var stoppingAfterCurrent = false
    private(set) var scheduled = false
    private(set) var status = ""
    private(set) var storageAvailable = true

    @ObservationIgnored var runEntry: ((ShowPlaylist.Entry, UUID) async throws -> Void)?
    @ObservationIgnored var stopOutput: (() -> Void)?
    // nil means the current item is still running or paused; an empty string means it finished.
    @ObservationIgnored var itemOutcome: (() -> String?)?
    @ObservationIgnored var canStart: (() -> Bool)?

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if let bytes = defaults.data(forKey: "ProjectionMapper.showLibrary") {
            guard let saved = try? JSONDecoder().decode(Settings.self, from: bytes), saved.version == 1 else {
                storageAvailable = false
                status = "The saved show library could not be read."
                return
            }
            settings = saved
            playlists = saved.playlists
            schedules = saved.schedules
        }
    }

    private func save(_ candidate: Settings) -> Bool {
        guard storageAvailable, let data = try? JSONEncoder().encode(candidate) else {
            status = "The show library could not be saved."
            return false
        }
        defaults.set(data, forKey: "ProjectionMapper.showLibrary")
        settings = candidate
        playlists = candidate.playlists
        schedules = candidate.schedules
        return true
    }

    func put(_ playlist: ShowPlaylist) {
        guard !running, !scheduled, playlist.isValid else { return }
        var copy = settings
        if let index = copy.playlists.firstIndex(where: { $0.id == playlist.id }) { copy.playlists[index] = playlist }
        else { copy.playlists.append(playlist) }
        if save(copy) { status = "Saved " + playlist.name }
    }

    func put(_ rule: ShowSchedule) {
        guard !running, !scheduled, rule.isValid, playlists.contains(where: { $0.id == rule.playlistID }) else { return }
        var copy = settings
        if let index = copy.schedules.firstIndex(where: { $0.id == rule.id }) { copy.schedules[index] = rule }
        else { copy.schedules.append(rule) }
        if save(copy) { status = "Saved " + rule.name }
    }

    func removePlaylist(_ id: UUID) {
        guard !running, !scheduled, !schedules.contains(where: { $0.playlistID == id }) else { return }
        var copy = settings
        copy.playlists.removeAll { $0.id == id }
        _ = save(copy)
    }

    func removeSchedule(_ id: UUID) {
        guard !running, !scheduled else { return }
        var copy = settings
        copy.schedules.removeAll { $0.id == id }
        _ = save(copy)
    }

    func dependenciesAvailable(_ playlist: ShowPlaylist) -> Bool {
        playlist.isValid && playlist.entries.allSatisfy { (try? ProjectPackageStore().read($0.url)) != nil }
    }

    func armSchedules() {
        guard !scheduled, storageAvailable, !running, (canStart?() ?? false) else { return }
        let enabled = schedules.filter(\.enabled)
        guard !enabled.isEmpty, enabled.allSatisfy({ rule in
            rule.isValid && playlists.contains { $0.id == rule.playlistID && dependenciesAvailable($0) }
        }) else {
            status = "Enable at least one valid schedule and locate all its show files."
            return
        }
        scheduled = true
        armedAt = .now
        status = "Schedules armed. Keep Projection Mapper open and the Mac awake."
        scheduler = Task { [weak self] in
            while !Task.isCancelled {
                guard let self else { return }
                self.checkSchedule(at: .now)
                do { try await Task.sleep(for: .seconds(1)) } catch { return }
            }
        }
    }

    func disarmSchedules() {
        scheduler?.cancel()
        scheduler = nil
        scheduled = false
        armedAt = nil
        if scheduledRule != nil { stopNow(message: "Schedule disarmed. Playback stopped.") }
        else if !running { status = "Schedules disarmed." }
    }

    func checkSchedule(at now: Date) {
        if let cutoff = graceStarted, ProcessInfo.processInfo.systemUptime - cutoff >= 3600 {
            stopNow(message: "Schedule ended. Grace period expired.")
        }
        if let end = limit, now >= end, let rule = scheduledRule {
            if !rule.finishCurrent { stopNow(message: "Schedule ended. Playback stopped.") }
            else {
                if graceStarted == nil { graceStarted = ProcessInfo.processInfo.systemUptime }
                if !gracefulStop { finishCurrent() }
                if now.timeIntervalSince(end) >= 3600 { stopNow(message: "Schedule ended. Grace period expired.") }
            }
        }
        guard scheduled, let armedAt else { return }
        let due = ShowSchedule.due(schedules, now: now, armedAt: armedAt, seen: Set(settings.seen))
        guard !due.isEmpty else { return }
        var copy = settings
        copy.seen.append(contentsOf: due.map { $0.1.id })
        copy.seen = Array(copy.seen.suffix(4096))
        guard save(copy) else { disarmSchedules(); return }
        guard !running, canStart?() == true else {
            status = "Skipped a scheduled start while another show or editor task was active."
            return
        }
        let (rule, occurrence) = due[0]
        guard let playlist = playlists.first(where: { $0.id == rule.playlistID }) else { return }
        start(playlist, until: occurrence.ends, rule: rule)
    }

    func start(_ playlist: ShowPlaylist, until end: Date? = nil, rule: ShowSchedule? = nil) {
        guard !running, canStart?() == true, dependenciesAvailable(playlist) else {
            status = "The playlist cannot start. Check its project files and stop other playback."
            return
        }
        guard let runEntry, let itemOutcome else { return }
        running = true
        gracefulStop = false
        stoppingAfterCurrent = false
        limit = end
        scheduledRule = rule
        let id = UUID()
        runID = id
        let entries = playlist.sequence()
        task = Task { [weak self] in
            do {
                for (index, entry) in entries.enumerated() {
                    guard let self, self.isCurrent(id), !self.gracefulStop else { break }
                    self.status = "\(playlist.name) · Preparing \(index + 1) of \(entries.count)"
                    try await runEntry(entry, id)
                    guard self.isCurrent(id) else { return }
                    if self.gracefulStop { break }
                    self.status = "\(playlist.name) · \(index + 1) of \(entries.count) · \(entry.role.rawValue)"
                    while self.isCurrent(id) {
                        if let outcome = itemOutcome() {
                            if !outcome.isEmpty { throw ProjectFileError.io(outcome) }
                            break
                        }
                        try await Task.sleep(for: .milliseconds(200))
                    }
                    guard self.isCurrent(id) else { return }
                }
                guard let self, self.isCurrent(id) else { return }
                self.stopNow(message: self.gracefulStop ? "Finished current item." : "Playlist finished.")
            } catch {
                guard let self, self.isCurrent(id) else { return }
                if error is CancellationError, self.gracefulStop || self.limit.map({ Date() >= $0 }) == true {
                    self.stopNow(message: self.gracefulStop ? "Finished current item." : "Playlist stopped at cutoff.")
                    return
                }
                self.stopNow(message: "Playlist stopped. " + error.localizedDescription)
                self.disarmAfterFault()
            }
        }
    }

    func isCurrent(_ id: UUID) -> Bool { running && runID == id }
    func mayBeginItem(_ id: UUID) -> Bool {
        isCurrent(id) && !gracefulStop && (limit.map { Date() < $0 } ?? true)
    }

    func finishCurrent() {
        guard running else { return }
        gracefulStop = true
        stoppingAfterCurrent = true
        status = "Finishing the current item."
    }

    func stopNow(message: String = "Playlist stopped.") {
        let wasRunning = running
        runID = UUID()
        running = false
        gracefulStop = false
        stoppingAfterCurrent = false
        limit = nil
        graceStarted = nil
        scheduledRule = nil
        task?.cancel()
        task = nil
        if wasRunning { stopOutput?() }
        status = message
    }

    func disarmAfterFault() {
        scheduler?.cancel()
        scheduler = nil
        scheduled = false
        armedAt = nil
    }
}
