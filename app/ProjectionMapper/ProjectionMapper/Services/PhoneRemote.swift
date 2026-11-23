import Darwin
import Foundation
import Network
import Observation
import SystemConfiguration

enum PhoneRole: String, CaseIterable, Identifiable {
    case viewer = "Viewer", operatorRole = "Operator", editor = "Editor"
    var id: Self { self }
    var canOperate: Bool { self != .viewer }
}

/// Identity of the local endpoint, independent of default internet routes and VPN paths.
struct PhoneNetworkBinding: Equatable, Sendable, Identifiable {
    let interfaceName: String
    let address: String
    let netmask: String

    var id: String { interfaceName + ":" + address }
    var title: String { interfaceName + " · " + address }

    static func isPrivateIPv4(_ address: String) -> Bool {
        let octets = address.split(separator: ".", omittingEmptySubsequences: false).compactMap { UInt8($0) }
        return octets.count == 4 && (octets[0] == 10 || octets[0] == 127 ||
            (octets[0] == 192 && octets[1] == 168) || (octets[0] == 172 && (16...31).contains(octets[1])))
    }

    static func available() -> [Self] {
        var interfaces: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&interfaces) == 0, let first = interfaces else { return [] }
        defer { freeifaddrs(first) }
        let physical = SCNetworkInterfaceCopyAll() as? [SCNetworkInterface] ?? []
        var wifi = Set<String>()
        var lan = Set<String>()
        for interface in physical {
            guard let name = SCNetworkInterfaceGetBSDName(interface) as String?,
                  let type = SCNetworkInterfaceGetInterfaceType(interface) else { continue }
            if type == kSCNetworkInterfaceTypeIEEE80211 { wifi.insert(name); lan.insert(name) }
            if type == kSCNetworkInterfaceTypeEthernet { lan.insert(name) }
        }
        var bindings: [Self] = []
        var item: UnsafeMutablePointer<ifaddrs>? = first
        while let current = item {
            item = current.pointee.ifa_next
            let entry = current.pointee
            let name = String(cString: entry.ifa_name)
            guard lan.contains(name), let raw = entry.ifa_addr, raw.pointee.sa_family == UInt8(AF_INET) else { continue }
            var numeric = [CChar](repeating: 0, count: Int(NI_MAXHOST))
            guard getnameinfo(raw, socklen_t(raw.pointee.sa_len), &numeric, socklen_t(numeric.count), nil, 0, NI_NUMERICHOST) == 0 else { continue }
            let address = String(decoding: numeric.prefix { $0 != 0 }.map { UInt8(bitPattern: $0) }, as: UTF8.self)
            if isPrivateIPv4(address), let binding = Self.current(address: address), !bindings.contains(binding) {
                bindings.append(binding)
            }
        }
        return bindings.sorted {
            if wifi.contains($0.interfaceName) != wifi.contains($1.interfaceName) { return wifi.contains($0.interfaceName) }
            return $0.id < $1.id
        }
    }

    static func current(address: String) -> Self? {
        var interfaces: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&interfaces) == 0, let first = interfaces else { return nil }
        defer { freeifaddrs(first) }
        func numeric(_ raw: UnsafePointer<sockaddr>?) -> String? {
            guard let raw, raw.pointee.sa_family == UInt8(AF_INET) else { return nil }
            var buffer = [CChar](repeating: 0, count: Int(NI_MAXHOST))
            guard getnameinfo(raw, socklen_t(raw.pointee.sa_len), &buffer, socklen_t(buffer.count),
                              nil, 0, NI_NUMERICHOST) == 0 else { return nil }
            return String(decoding: buffer.prefix { $0 != 0 }.map { UInt8(bitPattern: $0) }, as: UTF8.self)
        }
        var item: UnsafeMutablePointer<ifaddrs>? = first
        while let current = item {
            item = current.pointee.ifa_next
            let entry = current.pointee
            guard entry.ifa_flags & UInt32(IFF_UP | IFF_RUNNING) == UInt32(IFF_UP | IFF_RUNNING),
                  numeric(entry.ifa_addr) == address, let mask = numeric(entry.ifa_netmask) else { continue }
            return Self(interfaceName: String(cString: entry.ifa_name), address: address, netmask: mask)
        }
        return nil
    }
}

@MainActor
@Observable
final class PhoneRemote {
    private let session: EditorSession
    private let listener = PhoneHTTPListener()
    private let port: UInt16
    private var host = ""
    private(set) var isEncrypted = true
    private var origin: String { (isEncrypted ? "https://" : "http://") + host }
    private var invite = ""
    private var inviteUntil = Date.distantPast
    private var pendingToken: String?
    private var pendingUntil = Date.distantPast
    private var activeToken: String?
    private var viewerTokens: [String: Date] = [:]
    private var viewerInvitation = false
    private var pendingViewer = false
    private(set) var additionalViewerCount = 0
    var allowsPreview = true {
        didSet { if !allowsPreview { preview.clear(); session.videoPlayback.endPhonePreview() } }
    }
    private let preview = PhonePreview()
    private var sessionUntil = Date.distantPast
    private var commandNumber = 0
    private var rateWindow = Date.distantPast
    private var requests = 0
    private var revision = UUID()
    private var revisionProject: MappingProject?
    private var networkMonitor: NWPathMonitor?
    private var networkIdentity: PhoneNetworkBinding?
    private let networkBinding: (String) -> PhoneNetworkBinding?
    private var networkLossTask: Task<Void, Never>?
    private var bindAddress = ""
    private var identificationID: UUID?
    var role = PhoneRole.viewer
    private(set) var status = "Off"
    private(set) var pairingURL: URL?
    private(set) var isRunning = false
    private(set) var hasPendingPhone = false
    private(set) var hasPhone = false
    private(set) var saveStatus = ""
    private var readinessStatus = ""
    var save: ((@escaping @MainActor @Sendable (Bool) -> Void) -> Void)?
    var canAcceptCommands: (() -> Bool)?

    init(session: EditorSession, port: UInt16 = 9443,
         networkBinding: @escaping (String) -> PhoneNetworkBinding? = { PhoneNetworkBinding.current(address: $0) }) {
        self.networkBinding = networkBinding
        self.session = session
        self.port = port
        listener.handle = { [weak self] request in
            self?.handle(request) ?? .json(["error": "Remote stopped."], status: "503 Service Unavailable")
        }
        listener.stateChanged = { [weak self] state in
            guard let self else { return }
            switch state {
            case .ready:
                self.status = "Ready on " + self.host
                self.newInvitation()
            case .failed(let error):
                self.stop()
                self.status = error.localizedDescription
            case .waiting:
                self.checkNetworkBinding()
            default: break
            }
        }
    }

    func start(hostname: String, address: String, identity: Data, password: String) throws {
        let name = hostname.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        let labels = name.split(separator: ".", omittingEmptySubsequences: false)
        guard name.utf8.count <= 253, labels.count >= 2,
              labels.allSatisfy({ !$0.isEmpty && $0.utf8.count <= 63 && !$0.hasPrefix("-") && !$0.hasSuffix("-") }),
              name.utf8.allSatisfy({ (97...122).contains($0) || (48...57).contains($0) || $0 == 45 || $0 == 46 }),
              PhoneNetworkBinding.isPrivateIPv4(address), let binding = networkBinding(address), identity.count <= 1_048_576 else {
            throw PhoneError("Enter a DNS hostname and a private IPv4 address assigned to this Mac.")
        }
        stop()
        host = name + ":" + String(port)
        isEncrypted = true
        try listener.start(address: address, port: port, identityData: identity, password: password)
        monitorNetwork(binding)
    }

    func startLocal(address: String? = nil) throws {
        let selected = address ?? PhoneNetworkBinding.available().first?.address
        guard let selected, PhoneNetworkBinding.isPrivateIPv4(selected), let binding = networkBinding(selected) else {
            throw PhoneError("Connect the Mac to your home Wi-Fi or Ethernet, then refresh the network list.")
        }
        stop()
        host = selected + ":" + String(port)
        isEncrypted = false
        try listener.startLocal(address: selected, port: port)
        monitorNetwork(binding)
    }

    private func monitorNetwork(_ binding: PhoneNetworkBinding) {
        bindAddress = binding.address
        networkIdentity = binding
        status = "Starting…"
        isRunning = true
        let monitor = NWPathMonitor()
        networkMonitor = monitor
        monitor.pathUpdateHandler = { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self, self.networkMonitor === monitor else { return }
                self.checkNetworkBinding()
            }
        }
        monitor.start(queue: .main)
    }

    /// Repeated path notifications preserve pairing while the bound endpoint is unchanged.
    func checkNetworkBinding() {
        guard isRunning else { return }
        if let current = networkBinding(bindAddress) {
            networkLossTask?.cancel()
            networkLossTask = nil
            if current != networkIdentity {
                stop()
                status = "Remote network address changed. Start Phone Remote again."
            }
            return
        }
        guard networkLossTask == nil else { return }
        networkLossTask = Task { @MainActor [weak self] in
            do { try await Task.sleep(for: .seconds(2)) }
            catch { return }
            guard let self, self.isRunning else { return }
            self.networkLossTask = nil
            if self.networkBinding(self.bindAddress) != nil {
                self.checkNetworkBinding()
            } else {
                self.stop()
                self.status = "Remote network address unavailable. Start Phone Remote again."
            }
        }
    }

    func stop() {
        listener.stop()
        networkMonitor?.cancel()
        networkMonitor = nil
        networkLossTask?.cancel()
        networkLossTask = nil
        networkIdentity = nil
        isRunning = false
        revoke()
        pairingURL = nil
        invite = ""
        status = "Off"
    }

    func newInvitation() { makeInvitation(viewer: false) }

    func newViewerInvitation() { makeInvitation(viewer: true) }

    private func pruneViewers(at now: Date) {
        viewerTokens = viewerTokens.filter { $0.value > now }
        additionalViewerCount = viewerTokens.count
    }

    private func makeInvitation(viewer: Bool) {
        pruneViewers(at: .now)
        guard isRunning, viewer ? (hasPhone && viewerTokens.count < 4) : !hasPhone else { return }
        pendingToken = nil
        hasPendingPhone = false
        viewerInvitation = viewer
        pendingViewer = false
        if !viewer { role = .viewer }
        invite = UUID().uuidString.lowercased() + UUID().uuidString.lowercased()
        inviteUntil = Date().addingTimeInterval(120)
        pairingURL = URL(string: "\(origin)/#\(invite)")
    }

    func approve() {
        let now = Date()
        guard let pendingToken, now < pendingUntil else {
            self.pendingToken = nil
            hasPendingPhone = false
            if !hasPhone { newInvitation() }
            return
        }
        if pendingViewer {
            pruneViewers(at: now)
            guard viewerTokens.count < 4 else { return }
            viewerTokens[pendingToken] = now.addingTimeInterval(4 * 3600)
            additionalViewerCount = viewerTokens.count
        } else {
            activeToken = pendingToken
            sessionUntil = now.addingTimeInterval(4 * 3600)
            commandNumber = 0
            hasPhone = true
        }
        self.pendingToken = nil
        pendingViewer = false
        hasPendingPhone = false
    }

    func revoke() {
        preview.clear()
        session.videoPlayback.endPhonePreview()
        viewerTokens.removeAll()
        additionalViewerCount = 0
        viewerInvitation = false
        pendingViewer = false
        invite = ""
        pairingURL = nil
        activeToken = nil
        pendingToken = nil
        hasPendingPhone = false
        hasPhone = false
        if let identificationID, session.identifyingSourceID == identificationID { session.finishIdentification() }
        identificationID = nil
        saveStatus = ""
        readinessStatus = ""
    }

    private func handle(_ request: PhoneRequest) -> PhoneResponse {
        guard request.headers["host"]?.lowercased() == host else {
            return .json(["error": "Unexpected host."], status: "403 Forbidden")
        }
        if request.method == "GET" {
            let assets = ["/": (PhonePage.html, "text/html; charset=utf-8"),
                          "/remote.js": (PhonePage.script, "text/javascript; charset=utf-8"),
                          "/remote.css": (PhonePage.css, "text/css; charset=utf-8")]
            if let (value, type) = assets[request.path] {
                return PhoneResponse(status: "200 OK", type: type, body: Data(value.utf8))
            }
        }
        guard request.method == "POST", request.headers["origin"] == origin,
              request.headers["content-type"] == "application/json" else {
            return .json(["error": "Unexpected request origin."], status: "403 Forbidden")
        }
        let now = Date()
        if now.timeIntervalSince(rateWindow) >= 1 { rateWindow = now; requests = 0 }
        requests += 1
        guard requests <= 24 else { return .json(["error": "Too many requests."], status: "429 Too Many Requests") }
        let data = (try? JSONSerialization.jsonObject(with: request.body)) as? [String: Any] ?? [:]
        if request.path == "/pair" {
            guard !invite.isEmpty, now < inviteUntil, data["code"] as? String == invite,
                  viewerInvitation ? (hasPhone && viewerTokens.count < 4) : !hasPhone else {
                return .json(["error": "Invitation expired or already used."], status: "403 Forbidden")
            }
            let token = UUID().uuidString + UUID().uuidString
            invite = ""
            pairingURL = nil
            pendingToken = token
            pendingViewer = viewerInvitation
            pendingUntil = now.addingTimeInterval(120)
            hasPendingPhone = true
            return .json(["token": token])
        }
        let auth = request.headers["authorization"]
        if let pendingToken, auth == "Bearer " + pendingToken, now < pendingUntil, request.path == "/state" {
            return .json(["pending": true])
        }
        let primary = activeToken.map { auth == "Bearer " + $0 && now < sessionUntil } ?? false
        pruneViewers(at: now)
        let readOnly = !primary && viewerTokens.keys.contains { auth == "Bearer " + $0 }
        guard primary || readOnly else {
            return .json(["error": "Pair this phone again on the Mac."], status: "401 Unauthorized")
        }
        if request.path == "/state" { return .json(snapshot(as: readOnly ? .viewer : role)) }
        if request.path == "/timeline" || request.path == "/preview" {
            refreshRevision()
            guard data["projectID"] as? String == session.project.id.uuidString else {
                return .json(["error": "The Mac opened another project."], status: "409 Conflict")
            }
            if request.path == "/timeline" {
                return .json(timelineSnapshot(start: data["start"] as? Double, span: data["span"] as? Double, page: data["page"] as? Int))
            }
            guard allowsPreview else { return .json(["error": "Preview is disabled on the Mac."], status: "403 Forbidden") }
            session.videoPlayback.requestPhonePreview()
            return preview.request(scene: session.scene, aspect: session.output.aspectRatio, key: revision)
        }
        guard primary else { return .json(["error": "This phone has viewer access."], status: "403 Forbidden") }
        guard request.path == "/command", let number = data["sequence"] as? Int, number > commandNumber else {
            return .json(["error": "Duplicate or invalid command."], status: "409 Conflict")
        }
        commandNumber = number
        do {
            try perform(data)
            return .json(snapshot())
        } catch {
            return .json(["error": error.localizedDescription, "state": snapshot()], status: "409 Conflict")
        }
    }

    private func refreshRevision() {
        if revisionProject != session.project { revisionProject = session.project; revision = UUID() }
    }

    func snapshot(as viewerRole: PhoneRole? = nil) -> [String: Any] {
        refreshRevision()
        let role = viewerRole ?? self.role
        let project = session.project
        let time = session.transport.elapsed(at: ProcessInfo.processInfo.systemUptime)
        let upcoming = ShowCuePreview.upcoming(session.manualCueList, at: time, loop: project.song?.loop,
                                               songEnd: project.song?.duration).first
        var state: [String: Any] = [
            "project": project.name, "projectID": project.id.uuidString, "revision": revision.uuidString,
            "showArmState": session.showArmState.rawValue, "showStatus": session.showStatus ?? "",
            "workspace": session.workspace.rawValue, "time": time, "playing": session.playbackRequested,
            "song": project.song?.name ?? "", "role": role.rawValue, "output": session.outputStatusText,
            "projectionBlackout": session.showOutput.isBlackout, "fixtureBlackout": session.lightingSimulation.blackout,
            "muted": project.song == nil ? !session.videoAudioEnabled : session.songMuted,
            "next": upcoming?.cue.name ?? "", "delay": upcoming?.delay ?? 0, "wrap": upcoming?.afterWrap ?? false,
            "fixtures": session.lightingSimulation.reports.values.flatMap(\.fixtures).map { value in
                ["name": project.lighting.fixtures.first(where: { $0.id == value.id })?.name ?? "",
                 "state": value.effective.label,
                 "status": session.project.lighting.fixtures.first(where: { $0.id == value.id })
                     .flatMap { session.lightingSimulation.reports[$0.controllerID]?.status.rawValue } ?? ""]
            },
            "saveStatus": saveStatus, "readiness": readinessStatus,
            "previewAvailable": allowsPreview, "timelineEnd": project.timelineContentEnd
        ]
        if role == .editor {
            state["brightness"] = project.masterOutput.brightness
            state["effects"] = SurfaceContent.allCases.filter { $0 != .image && $0 != .video }
                .map { ["id": $0.rawValue, "name": $0.title] }
            state["palettes"] = project.palettes.flatMap { palette in
                palette.slots.map { ["palette": palette.id.uuidString, "slot": $0.id.uuidString,
                                     "name": palette.name + " · " + $0.name] }
            }
            state["faces"] = project.surfaces.map { face -> [String: Any] in
                let source = project.resolvedSource(project.source(for: face))
                let corners = SurfaceCorner.allCases.map { corner in
                    let point = face.corners[corner]
                    return [point.x, point.y]
                }
                return ["id": face.id.uuidString, "name": face.name, "locked": project.isGeometryLocked(face),
                        "object": project.object(for: face)?.name ?? "", "corners": corners,
                        "mask": face.mask?.rings.map { $0.points.map { [$0.x, $0.y] } } ?? [],
                        "effect": source.content.rawValue, "rate": source.generator.rate,
                        "scale": source.generator.scale, "intensity": source.generator.intensity,
                        "color": [source.color.x, source.color.y, source.color.z]]
            }
        }
        return state
    }

    func timelineSnapshot(start rawStart: Double?, span rawSpan: Double?, page rawPage: Int?) -> [String: Any] {
        refreshRevision()
        let start = rawStart.flatMap { $0.isFinite ? min(3600, max(0, $0)) : nil } ?? 0
        let span = rawSpan.flatMap { $0.isFinite ? min(120, max(5, $0)) : nil } ?? 30
        let end = min(3600, start + span)
        let project = session.project
        let tracks = project.timelineTracks
        let pageSize = 12
        let pages = max(1, (tracks.count + pageSize - 1) / pageSize)
        let page = min(pages - 1, max(0, rawPage ?? 0))
        let visible = Array(tracks.dropFirst(page * pageSize).prefix(pageSize))
        let visibleIDs = Set(visible.map(\.id))
        let clips = project.timelineClips.filter { visibleIDs.contains($0.sourceID) && $0.start < end && $0.end > start }
            .sorted { $0.start < $1.start }
        let cues = project.lighting.cues.filter { !$0.isManual && $0.time >= start && $0.time <= end }
            .sorted { $0.time < $1.time }
        return ["projectID": project.id.uuidString, "revision": revision.uuidString, "page": page, "pages": pages,
                "start": start, "span": span, "limited": clips.count > 220 || cues.count > 160,
                "tracks": visible.map { ["id": $0.id.uuidString, "name": $0.name, "faces": $0.faceCount] },
                "clips": clips.prefix(220).map { clip -> [String: Any] in
                    var result: [String: Any] = ["id": clip.id.uuidString, "owner": clip.sourceID.uuidString,
                        "name": clip.source.content.title, "start": clip.start, "end": clip.end, "fade": clip.transition ?? 0]
                    if clip.source.content == .video, let video = clip.source.video {
                        result["in"] = video.inPoint
                        result["out"] = video.outPoint
                    }
                    return result
                },
                "cues": cues.prefix(160).map { ["id": $0.id.uuidString, "name": $0.name, "time": $0.time] }]
    }

    func perform(_ data: [String: Any]) throws {
        guard canAcceptCommands?() ?? true, data["projectID"] as? String == session.project.id.uuidString,
              let action = data["action"] as? String, role.canOperate else { throw PhoneError("Command unavailable.") }
        switch action {
        case "play":
            guard session.setPlaying(true) else { throw PhoneError(session.showStatus ?? session.songMessage ?? "Unable to start playback.") }
        case "pause": session.setPlaying(false)
        case "stop": session.stopPlayback()
        case "seek":
            guard let time = data["time"] as? Double, (0...3600).contains(time) else { throw PhoneError("Invalid time.") }
            session.setPlaying(false)
            session.seekPlayback(to: time)
        case "go":
            guard session.goManualCue() else { throw PhoneError("Arm the show and select an available cue.") }
        case "readiness":
            let report = session.playbackReadiness()
            readinessStatus = ([report.summary] + report.issues.prefix(4).map(\.message)).joined(separator: " · ")
        case "projectionOff": session.blackoutOutput()
        case "projectionOn": session.restoreOutput()
        case "fixturesOff", "fixturesOn":
            session.lightingSimulation.blackout = action == "fixturesOff"
            session.refreshLighting()
        case "mute", "unmute":
            if session.project.song == nil { session.enableVideoAudio(action == "unmute") }
            else { session.songMuted = action == "mute" }
        default: try edit(action, data: data)
        }
    }

    private func editTimelineClip(_ action: String, data: [String: Any]) throws {
        guard let id = (data["clip"] as? String).flatMap(UUID.init(uuidString:)),
              let owner = (data["owner"] as? String).flatMap(UUID.init(uuidString:)),
              let existing = session.project.timelineClips.first(where: { $0.id == id && $0.sourceID == owner }),
              let track = session.project.timelineTracks.first(where: { $0.id == owner }) else {
            throw PhoneError("Clip unavailable. Refresh the timeline.")
        }
        var candidate = existing
        switch action {
        case "clipMove":
            guard let start = data["start"] as? Double, (0...3600).contains(start) else { throw PhoneError("Invalid start time.") }
            candidate.start = start
        case "clipTrim":
            guard let start = data["start"] as? Double, let end = data["end"] as? Double,
                  (0...3600).contains(start), (0...3600).contains(end), end - start >= 0.1 - 0.000001 else {
                throw PhoneError("A clip needs at least 0.1 seconds within the timeline.")
            }
            candidate = existing.trimming(start: start, duration: max(0.1, end - start))
        case "clipSource":
            guard existing.source.content == .video, var video = existing.source.video,
                  let begin = data["in"] as? Double, let end = data["out"] as? Double,
                  (0...86400).contains(begin), (0...86400).contains(end), end - begin >= 0.1 else {
                throw PhoneError("Invalid video source range.")
            }
            video.inPoint = begin
            video.outPoint = end
            if (video.loopOffset ?? 0) >= video.rangeDuration { video.loopOffset = nil }
            candidate = existing.replacingVideo(video)
        default: return
        }
        guard session.updateTimelineClip(candidate) else {
            throw PhoneError(session.timelineMessage ?? "Clip timing could not be changed.")
        }
        session.selectedClipID = id
        session.selectTimelineTrack(track)
    }

    private func edit(_ action: String, data: [String: Any]) throws {
        refreshRevision()
        guard role == .editor, session.workspace == .edit else { throw PhoneError("Editing is locked. Switch to Edit on the Mac.") }
        guard data["revision"] as? String == revision.uuidString else { throw PhoneError("Project changed. Review the current state and try again.") }
        guard !session.isSavingMedia, !session.isImportingVideo, !session.isImportingImage, !session.isContinuousEditing else {
            throw PhoneError("The Mac is busy with media.")
        }
        switch action {
        case "clipMove", "clipTrim", "clipSource":
            try editTimelineClip(action, data: data)
            return
        case "cueTime", "selectCue":
            guard let id = (data["cue"] as? String).flatMap(UUID.init(uuidString:)),
                  let cue = session.project.lighting.cues.first(where: { $0.id == id }) else {
                throw PhoneError("Cue unavailable. Refresh the timeline.")
            }
            if action == "cueTime" {
                guard let time = data["time"] as? Double, (0...3600).contains(time) else { throw PhoneError("Invalid cue time.") }
                guard session.editLighting({ lighting in
                    if let index = lighting.cues.firstIndex(where: { $0.id == id }) {
                        lighting.cues[index].time = time
                    }
                }) else { throw PhoneError(session.lightingMessage ?? "Cue time could not be changed.") }
            }
            session.selectLightingCue(cue.id)
            return
        case "undo": session.undoProjectEdit(); return
        case "redo": session.redoProjectEdit(); return
        case "finish": session.finishIdentification(); identificationID = nil; return
        case "save":
            guard saveStatus != "Saving on Mac…", let save else { throw PhoneError("Save is unavailable.") }
            saveStatus = "Saving on Mac…"
            let token = activeToken
            save { [weak self] success in
                guard let self, self.activeToken == token else { return }
                self.saveStatus = success ? "Saved on Mac" : "Save cancelled or failed"
            }
            return
        case "brightness":
            guard let value = data["value"] as? Double, (0...1).contains(value) else { throw PhoneError("Invalid brightness.") }
            session.setMasterBrightness(Float(value))
            return
        default: break
        }
        guard let rawID = data["face"] as? String, let id = UUID(uuidString: rawID),
              let face = session.project.surfaces.first(where: { $0.id == id }) else { throw PhoneError("Surface unavailable.") }
        switch action {
        case "corner":
            let corners = SurfaceCorner.allCases
            guard !session.project.isGeometryLocked(face), let index = data["index"] as? Int, corners.indices.contains(index),
                  let point = Self.point(data["point"]) else { throw PhoneError("Corner is locked or outside the canvas.") }
            session.selectSurface(id)
            session.selectCorner(corners[index])
            session.moveSelectedCorner(to: point, surfaceID: id)
        case "mask":
            guard !session.project.isGeometryLocked(face), let rings = data["rings"] as? [[[Double]]],
                  !rings.isEmpty, rings.count <= FaceMask.maxHoles + 1 else { throw PhoneError("Invalid or locked mask.") }
            var polygons: [MaskPolygon] = []
            for ring in rings {
                let points = ring.compactMap { Self.point($0) }
                guard points.count == ring.count, points.count <= FaceMask.maxPoints else { throw PhoneError("Invalid mask points.") }
                let oldRings = face.mask?.rings ?? []
                let id = oldRings.indices.contains(polygons.count) ? oldRings[polygons.count].id : UUID()
                polygons.append(MaskPolygon(id: id, points: points))
            }
            let mask = FaceMask(isEnabled: face.mask?.isEnabled ?? true, boundary: polygons[0], holes: Array(polygons.dropFirst()))
            if let issue = mask.validationMessage { throw PhoneError(issue) }
            session.setMask(mask, faceID: id)
        case "identify":
            session.selectSurface(id); session.identifySelectedObject()
            identificationID = session.identifyingSourceID
        case "effect":
            guard let raw = data["value"] as? String, let content = SurfaceContent(rawValue: raw),
                  content != .image, content != .video else { throw PhoneError("Invalid effect.") }
            session.selectSurface(id); session.setSurfaceContent(content)
        case "rate", "scale", "intensity":
            guard let value = data["value"] as? Double else { throw PhoneError("Invalid effect setting.") }
            var settings = session.project.source(for: face).generator
            switch action {
            case "rate": settings.rate = Float(value)
            case "scale": settings.scale = Float(value)
            default: settings.intensity = Float(value)
            }
            guard settings.isValid else { throw PhoneError("Invalid effect setting.") }
            session.selectSurface(id); session.setGeneratorSettings(settings)
        case "color":
            guard let values = data["color"] as? [Double], values.count == 3,
                  values.allSatisfy({ (0...1).contains($0) }) else { throw PhoneError("Invalid color.") }
            session.selectSurface(id); session.setSourceColor(SIMD4(Float(values[0]), Float(values[1]), Float(values[2]), 1))
        case "palette":
            guard let palette = (data["palette"] as? String).flatMap(UUID.init(uuidString:)),
                  let slot = (data["slot"] as? String).flatMap(UUID.init(uuidString:)),
                  session.project.palettes.contains(where: { $0.id == palette && $0.slots.contains { $0.id == slot } }) else {
                throw PhoneError("Palette color is unavailable.")
            }
            session.bindColor(faceID: id, channel: .primary, binding: ColorBinding(paletteID: palette, slotID: slot))
        default: throw PhoneError("Unknown command.")
        }
    }

    private static func point(_ value: Any?) -> SIMD2<Float>? {
        guard let pair = value as? [Double], pair.count == 2, pair.allSatisfy({ (0...1).contains($0) }) else { return nil }
        return SIMD2(Float(pair[0]), Float(pair[1]))
    }
}
