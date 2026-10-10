import AppKit
import AVFoundation
import Observation
import CoreAudio

struct AudioOutputDevice: Identifiable, Equatable {
    let id: String
    let name: String
}
enum VideoAudioDevices {
    static func outputs() -> [AudioOutputDevice] {
        var address = AudioObjectPropertyAddress(mSelector: kAudioHardwarePropertyDevices,mScope: kAudioObjectPropertyScopeGlobal,mElement: kAudioObjectPropertyElementMain)
        var size: UInt32 = 0
        guard AudioObjectGetPropertyDataSize(AudioObjectID(kAudioObjectSystemObject),&address,0,nil,&size) == noErr else { return [] }
        var devices = [AudioDeviceID](repeating: 0,count: Int(size)/MemoryLayout<AudioDeviceID>.size)
        guard AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject),&address,0,nil,&size,&devices) == noErr else { return [] }
        return devices.compactMap { device in
            var streams = AudioObjectPropertyAddress(mSelector: kAudioDevicePropertyStreams,mScope: kAudioDevicePropertyScopeOutput,mElement: kAudioObjectPropertyElementMain)
            var streamBytes: UInt32 = 0
            guard AudioObjectGetPropertyDataSize(device,&streams,0,nil,&streamBytes) == noErr, streamBytes > 0 else { return nil }
            func string(_ selector: AudioObjectPropertySelector) -> String? {
                var property = AudioObjectPropertyAddress(mSelector: selector,mScope: kAudioObjectPropertyScopeGlobal,mElement: kAudioObjectPropertyElementMain)
                let pointer = UnsafeMutablePointer<Unmanaged<CFString>?>.allocate(capacity: 1)
                pointer.initialize(to: nil); defer { pointer.deinitialize(count: 1); pointer.deallocate() }
                var length = UInt32(MemoryLayout<Unmanaged<CFString>?>.size)
                guard AudioObjectGetPropertyData(device,&property,0,nil,&length,pointer) == noErr, let result = pointer.pointee else { return nil }
                return result.takeRetainedValue() as String
            }
            guard let uid = string(kAudioDevicePropertyDeviceUID), let name = string(kAudioObjectPropertyName) else { return nil }
            return AudioOutputDevice(id: uid,name: name)
        }
    }
}
@MainActor enum VideoRenderAvailability {
    static let views = NSHashTable<MetalSceneView>.weakObjects()
    static var isVisible: Bool { views.allObjects.contains { $0.isRenderingActive } }
}
struct VideoPlaybackRequest: Equatable {
    let ownerID: UUID
    let clipID: UUID?
    let content: VideoContent
    let asset: VideoAsset
    let sourceTime: Double
    let rate: Double
    let audible: Bool
    static func requests(scene: RenderScene, assets: [VideoAsset], audioEnabled: Bool, at uptime: TimeInterval) -> [Self] {
        let global = scene.transport.elapsed(at: uptime)
        var seen = Set<UUID>()
        return scene.surfaces.compactMap { surface in
            guard let owner = surface.sourceID, !seen.contains(owner) else { return nil }
            let evaluated = surface.evaluated(at: global)
            guard evaluated.appearance.opacity > 0, evaluated.content == .video, let content = evaluated.video,
                  let asset = assets.first(where: { $0.id == content.assetID }) else { return nil }
            seen.insert(owner)
            let clip = surface.timelineClips.first { $0.contains(global) }
            let elapsed = clip.map { global-$0.start } ?? surface.playback.elapsed(at: global)
            let running = scene.transport.isPlaying && (clip != nil || !surface.playback.isPaused)
            let exhausted = !content.loops && elapsed*content.rate >= content.rangeDuration
            let rate = running && !exhausted ? scene.transport.speed*content.rate : 0
            return Self(ownerID: owner,clipID: clip?.id,content: content,asset: asset,
                sourceTime: content.requestedTime(elapsed: elapsed),rate: rate,
                audible: audioEnabled && !content.isMuted && asset.hasAudio && rate > 0)
        }
    }
}
/// AVPlayer, output and seeks live once per content owner, never in render views.
@MainActor @Observable final class VideoPlaybackCoordinator {
    private(set) var frames: [UUID:VideoFrame] = [:]
    private(set) var problems: [UUID:String] = [:]
    @ObservationIgnored var changed: (() -> Void)?
    @ObservationIgnored var visualOverride: Bool?
    @ObservationIgnored var availableAudioDevices: () -> [AudioOutputDevice] = { VideoAudioDevices.outputs() }
    @ObservationIgnored private var scene = RenderScene.diagnostic
    @ObservationIgnored private var assets: [VideoAsset] = []
    @ObservationIgnored private var urls: [UUID:URL] = [:]
    @ObservationIgnored private var audio = VideoAudioSettings()
    @ObservationIgnored private var audioEnabled = false
    @ObservationIgnored private var revision = UUID()
    @ObservationIgnored private var preloaded: [UUID:Entry] = [:]
    @ObservationIgnored private var entries: [UUID:Entry] = [:]
    @ObservationIgnored private var timer: Timer?
    @ObservationIgnored private var deviceCheckAt: TimeInterval = -100
    @ObservationIgnored private var deviceAvailable = true
    @ObservationIgnored private var lostDevice = false
    static let maximumFrameBytes = 256*1024*1024
    @MainActor private final class Entry {
        let player: AVPlayer
        let output: AVPlayerItemVideoOutput
        let generator: AVAssetImageGenerator
        let assetID: UUID
        let clipID: UUID?
        var revision: UUID?
        var seeking = false
        var task: Task<Void,Never>?
        var token = UUID()
        var request: VideoPlaybackRequest
        init(url: URL,request: VideoPlaybackRequest) {
            self.request = request; assetID = request.asset.id; clipID = request.clipID
            let item = AVPlayerItem(url: url)
            generator = AVAssetImageGenerator(asset: AVURLAsset(url: url))
            generator.appliesPreferredTrackTransform = false
            generator.requestedTimeToleranceBefore = CMTime(seconds: 1/request.asset.frameRate,preferredTimescale: 60000)
            generator.requestedTimeToleranceAfter = .zero
            item.audioTimePitchAlgorithm = .timeDomain
            output = AVPlayerItemVideoOutput(pixelBufferAttributes: [kCVPixelBufferPixelFormatTypeKey as String:kCVPixelFormatType_32BGRA,
                kCVPixelBufferMetalCompatibilityKey as String:true])
            item.add(output); player = AVPlayer(playerItem: item)
            player.automaticallyWaitsToMinimizeStalling = false; player.isMuted = true
        }
        func stillImage(at time: CMTime) async throws -> (image: CGImage,actualTime: CMTime) {
            try await withCheckedThrowingContinuation { continuation in
                generator.generateCGImagesAsynchronously(forTimes: [NSValue(time: time)]) { _, image, actual, result, error in
                    if result == .succeeded, let image { continuation.resume(returning: (image,actual)) }
                    else { continuation.resume(throwing: error ?? ProjectFileError.io("Paused frame unavailable.")) }
                }
            }
        }
        func stop() { token = UUID(); task?.cancel(); task = nil; player.pause(); player.currentItem?.cancelPendingSeeks(); generator.cancelAllCGImageGeneration(); player.replaceCurrentItem(with: nil) }
    }
    func configure(scene: RenderScene,assets: [VideoAsset],urls: [UUID:URL],audio: VideoAudioSettings,enabled: Bool) {
        if self.scene.transport != scene.transport || self.scene.surfaces != scene.surfaces || self.urls != urls || self.audio != audio || audioEnabled != enabled { revision = UUID() }
        self.scene = scene; self.assets = assets; self.urls = urls; self.audio = audio; audioEnabled = enabled
        if assets.isEmpty { reset(); return }
        if timer == nil {
            timer = Timer.scheduledTimer(withTimeInterval: 1.0/60,repeats: true) { [weak self] _ in
                Task { @MainActor [weak self] in self?.tick() }
            }
        }
        tick()
    }
    func reset() {
        timer?.invalidate(); timer = nil
        entries.values.forEach { $0.stop() }; entries.removeAll()
        preloaded.values.forEach { $0.stop() }; preloaded.removeAll()
        frames.removeAll(); problems.removeAll(); revision = UUID(); lostDevice = false
    }
    func rearmAudio() { lostDevice = false; deviceCheckAt = -100 }
    func tick(at uptime: TimeInterval = ProcessInfo.processInfo.systemUptime) {
        let visual = (visualOverride ?? VideoRenderAvailability.isVisible) &&
            !scene.calibration.pattern.isActive && scene.effectiveGain(at: uptime) > 0
        if uptime-deviceCheckAt >= 1 {
            deviceCheckAt = uptime
            deviceAvailable = audio.deviceUID.map { uid in availableAudioDevices().contains { $0.id == uid } } ?? true
            if !deviceAvailable { lostDevice = true }
        }
        let requests = VideoPlaybackRequest.requests(scene: scene,assets: assets,audioEnabled: audioEnabled && !lostDevice,at: uptime)
        let needed = requests.filter { visual || $0.audible }
        let owners = Set(needed.map(\.ownerID))
        for id in Array(entries.keys) where !owners.contains(id) { entries.removeValue(forKey: id)?.stop(); frames.removeValue(forKey: id); problems.removeValue(forKey: id) }
        for request in needed {
            let id = request.ownerID
            guard let url = urls[request.asset.id] else { problems[id] = "Video missing or damaged; relink the asset."; frames.removeValue(forKey: id); continue }
            if let entry = entries[id], entry.assetID != request.asset.id || entry.clipID != request.clipID {
                entry.stop(); entries.removeValue(forKey: id); frames.removeValue(forKey: id)
            }
            let entry: Entry
            if let existing = entries[id] { entry = existing }
            else if let warm = preloaded.removeValue(forKey: id) {
                if warm.assetID == request.asset.id && warm.clipID == request.clipID { entry = warm; entry.revision = nil }
                else { warm.stop(); entry = Entry(url: url,request: request) }
                entries[id] = entry
            } else { entry = Entry(url: url,request: request); entries[id] = entry }
            entry.request = request
            let maximumFrameAge = max(0.12,1/request.asset.frameRate+0.005)
            if request.rate > 0, let previous = frames[id], abs(previous.sourceTime-request.sourceTime) > maximumFrameAge {
                frames.removeValue(forKey: id)
            }
            let audioRateSupported = request.rate == 0 || (0.5...2).contains(request.rate)
            entry.player.isMuted = !request.audible || !deviceAvailable || !audioRateSupported
            entry.player.volume = audio.volume
            if entry.player.audioOutputDeviceUniqueID != audio.deviceUID { entry.player.audioOutputDeviceUniqueID = audio.deviceUID }
            if lostDevice { problems[id] = "Audio device unavailable. Select a device and Enable Audio again." }
            else if request.audible && !audioRateSupported { problems[id] = "Audio is muted at this speed; audio supports 0.5×–2× effective rate." }
            else if entry.player.currentItem?.status == .failed { problems[id] = entry.player.currentItem?.error?.localizedDescription ?? "Video decoder failed." }
            else { problems.removeValue(forKey: id) }
            let drift = abs(entry.player.currentTime().seconds-request.sourceTime)
            if entry.revision != revision || (!entry.seeking && drift > 0.12) {
                seek(entry,owner: id,revision: revision)
            }
            if !entry.seeking, visual, request.rate > 0 {
                let time = CMTime(seconds: request.sourceTime,preferredTimescale: 60000)
                var display = CMTime.invalid
                if let buffer = entry.output.copyPixelBuffer(forItemTime: time,itemTimeForDisplay: &display) {
                    guard display.isNumeric, abs(display.seconds-request.sourceTime) <= 1/request.asset.frameRate+0.005 else { continue }
                    let frame = VideoFrame(buffer: buffer,asset: request.asset,clipID: request.clipID,sourceTime: display.isNumeric ? display.seconds : request.sourceTime)
                    // Decoding can block briefly: validate against the clock at publication, too.
                    let latest = VideoPlaybackRequest.requests(scene: scene,assets: assets,audioEnabled: false,at: ProcessInfo.processInfo.systemUptime).first { $0.ownerID == id }
                    guard let latest, latest.clipID == request.clipID, latest.asset.id == request.asset.id,
                          abs(frame.sourceTime-latest.sourceTime) <= maximumFrameAge else { frames.removeValue(forKey: id); continue }
                    let current = frames.filter { $0.key != id }.values.reduce(0) { $0+$1.byteCount }
                    if current+frame.byteCount <= Self.maximumFrameBytes { frames[id] = frame }
                    else { frames.removeValue(forKey: id); problems[id] = "Decoded frames exceed the 256 MiB cache budget." }
                }
            }
            if !visual { frames.removeValue(forKey: id) }
        }
        preload(visual: visual,at: uptime)
        changed?()
    }
    private func preload(visual: Bool,at uptime: TimeInterval) {
        guard visual, scene.transport.isPlaying else {
            preloaded.values.forEach { $0.stop() }; preloaded.removeAll(); return
        }
        let time = scene.transport.elapsed(at: uptime)
        var wanted: [UUID:EffectClip] = [:]
        for surface in scene.surfaces {
            guard wanted.count < 4, let owner = surface.sourceID else { continue }
            if let next = surface.timelineClips.filter({ $0.source.content == .video && $0.start > time && $0.start-time <= 1 }).min(by: { $0.start < $1.start }) { wanted[owner] = next }
        }
        for owner in Array(preloaded.keys) where preloaded[owner]?.clipID != wanted[owner]?.id { preloaded.removeValue(forKey: owner)?.stop() }
        for (owner,clip) in wanted where preloaded[owner] == nil {
            guard let content = clip.source.video, let asset = assets.first(where: { $0.id == content.assetID }), let url = urls[asset.id] else { continue }
            let request = VideoPlaybackRequest(ownerID: owner,clipID: clip.id,content: content,asset: asset,sourceTime: content.inPoint,rate: 0,audible: false)
            let entry = Entry(url: url,request: request); preloaded[owner] = entry
            let token = entry.token
            entry.task = Task { @MainActor [weak entry] in
                guard let entry else { return }
                for _ in 0..<300 {
                    guard !Task.isCancelled, entry.token == token else { return }
                    if entry.player.currentItem?.status != .unknown { break }
                    try? await Task.sleep(for: .milliseconds(10))
                }
                guard entry.player.currentItem?.status == .readyToPlay, !Task.isCancelled else { return }
                _ = await entry.player.seek(to: CMTime(seconds: content.inPoint,preferredTimescale: 60000),toleranceBefore: .zero,toleranceAfter: .zero)
            }
        }
    }
    private func seek(_ entry: Entry,owner: UUID,revision: UUID) {
        entry.player.pause(); entry.player.currentItem?.cancelPendingSeeks(); entry.generator.cancelAllCGImageGeneration(); entry.task?.cancel()
        let token = UUID(); entry.token = token; entry.revision = revision; entry.seeking = true
        frames.removeValue(forKey: owner)
        entry.task = Task { @MainActor [weak self,weak entry] in
            guard let self, let entry else { return }
            for _ in 0..<300 {
                guard !Task.isCancelled, entry.token == token else { return }
                if entry.player.currentItem?.status != .unknown { break }
                try? await Task.sleep(for: .milliseconds(10))
            }
            guard entry.player.currentItem?.status == .readyToPlay else { entry.seeking = false; return }
            let target = CMTime(seconds: entry.request.sourceTime,preferredTimescale: 60000)
            let success = await entry.player.seek(to: target,toleranceBefore: .zero,toleranceAfter: .zero)
            guard !Task.isCancelled, entry.token == token, self.entries[owner] === entry else { return }
            entry.seeking = false
            guard success else { self.problems[owner] = "Video seek failed."; return }
            let now = ProcessInfo.processInfo.systemUptime
            if let latest = VideoPlaybackRequest.requests(scene: self.scene,assets: self.assets,audioEnabled: self.audioEnabled && !self.lostDevice,at: now).first(where: { $0.ownerID == owner && $0.clipID == entry.clipID && $0.asset.id == entry.assetID }) {
                entry.request = latest
                entry.player.setRate(Float(latest.rate),time: CMTime(seconds: latest.sourceTime,preferredTimescale: 60000),atHostTime: CMClockGetTime(CMClockGetHostTimeClock()))
                if latest.rate == 0, self.visualOverride ?? VideoRenderAvailability.isVisible {
                    do {
                        let result = try await entry.stillImage(at: CMTime(seconds: latest.sourceTime,preferredTimescale: 60000))
                        guard !Task.isCancelled, entry.token == token, self.entries[owner] === entry else { return }
                        let buffer = try VideoImportService.pixelBuffer(result.image)
                        let frame = VideoFrame(buffer: buffer,asset: latest.asset,clipID: latest.clipID,sourceTime: result.actualTime.seconds)
                        let otherBytes = self.frames.filter { $0.key != owner }.values.reduce(0) { $0+$1.byteCount }
                        if otherBytes+frame.byteCount <= Self.maximumFrameBytes { self.frames[owner] = frame }
                        else { self.problems[owner] = "Decoded frames exceed the 256 MiB budget." }
                    } catch {
                        guard !Task.isCancelled, entry.token == token, self.entries[owner] === entry else { return }
                        self.problems[owner] = "Video frame unavailable: " + error.localizedDescription
                    }
                }
            }
            self.tick()
        }
    }
    struct AudioPlaybackState {
        let isMuted: Bool
        let volume: Float
        let rate: Float
        let deviceUID: String?
    }
    var audioPlaybackStates: [UUID:AudioPlaybackState] {
        entries.mapValues { AudioPlaybackState(isMuted: $0.player.isMuted,volume: $0.player.volume,rate: $0.player.rate,deviceUID: $0.player.audioOutputDeviceUniqueID) }
    }
    var activeOwnerCount: Int { entries.count }
    var audibleOwnerCount: Int { entries.values.filter { !$0.player.isMuted && $0.player.rate > 0 }.count }
}
