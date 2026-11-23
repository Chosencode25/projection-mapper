import AVFoundation
import Darwin
import Foundation
import MetalKit
import Testing

@MainActor
enum EncoreRehearsal {
    static var fixture: URL {
        var checkout = URL(fileURLWithPath: #filePath)
        for _ in 0..<4 { checkout.deleteLastPathComponent() }
        return checkout.appendingPathComponent("assets/demos/Winter Lights Encore.projectionmap")
    }

    static func temporary() throws -> URL {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("Encore-" + UUID().uuidString)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: false)
        return folder
    }

    static func load(_ url: URL, into session: EditorSession) async throws {
        let document = try ProjectPackageStore().read(url)
        let videos = await VideoImportService.loadAssets(document.project.videoAssets, package: url)
        try session.load(document, from: url, loadedVideos: videos)
        try await until(10, "soundtrack load") { !session.songBusy }
    }

    static func until(_ timeout: Double, _ operation: String, _ ready: () -> Bool) async throws {
        let end = ProcessInfo.processInfo.systemUptime + timeout
        while !ready() {
            guard ProcessInfo.processInfo.systemUptime < end else { throw ProjectFileError.io("Timed out: \(operation).") }
            try await Task.sleep(for: .milliseconds(20))
        }
    }

    static func session() -> EditorSession {
        let defaults = UserDefaults(suiteName: "ProjectionMapper.encore." + UUID().uuidString)!
        return EditorSession(presentOutput: { _ in }, output: OutputSelectionState(preferences: OutputPreferences(defaults: defaults)))
    }

    static func show(_ session: EditorSession) async throws {
        session.songMuted = true
        session.videoPlayback.visualOverride = true
        session.switchWorkspace(to: .show)
        session.setTestResolution(.fullHD)
        session.openOutput()
        try #require(session.isOutputOpen)
        await session.prepareShow()
        try #require(session.showArmState == .armed, "\(session.showStatus ?? "No show status")")
        try #require(!session.playbackRequested)
    }
}

@MainActor
@Suite(.serialized)
struct EncoreSoakTests {
    @Test(.enabled(if: ProcessInfo.processInfo.environment["PROJECTION_ENCORE_SOAK_REPORT"] != nil))
    func loopTestModeWithLiveSoundtrackClock() async throws {
        let environment = ProcessInfo.processInfo.environment
        let report = URL(fileURLWithPath: try #require(environment["PROJECTION_ENCORE_SOAK_REPORT"]))
        let duration = Double(environment["PROJECTION_ENCORE_SOAK_SECONDS"] ?? "1800") ?? 1800
        try #require((1...1800).contains(duration))
        let folder = try EncoreRehearsal.temporary()
        let session = EncoreRehearsal.session()
        defer {
            session.releaseRuntimeResources()
            try? FileManager.default.removeItem(at: folder)
        }
        let show = folder.appendingPathComponent("Soak.projectionmap")
        try FileManager.default.copyItem(at: EncoreRehearsal.fixture, to: show)
        try await EncoreRehearsal.load(show, into: session)
        let length = try #require(session.project.song?.duration)
        try #require(length == 24)
        session.setSongLoop(SongLoop(start: 0, end: length))
        try await EncoreRehearsal.show(session)
        weak var outputWindow = session.testOutput.window
        let files = Array(session.videoFiles.values)
        var renderer: MetalRenderer? = try MetalRenderer(scene: session.scene)
        weak var rendererAfterClose = renderer
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: MetalRenderer.pixelFormat,
            width: 1920, height: 1080, mipmapped: false)
        descriptor.usage = .renderTarget
        descriptor.storageMode = .private
        let texture = try #require(renderer?.device.makeTexture(descriptor: descriptor))
        let pass = MTLRenderPassDescriptor()
        pass.colorAttachments[0].texture = texture
        try #require(session.setPlaying(true), "\(session.showStatus ?? session.songMessage ?? "No playback status")")
        let startup = ProcessInfo.processInfo.systemUptime
        try await EncoreRehearsal.until(5, "soundtrack clock advancement") { session.transport.position > 0.03 }
        let wallStart = ProcessInfo.processInfo.systemUptime
        let songStart = session.transport.position
        let cpuStart = cpuSeconds()
        let rssStart = residentBytes()
        var lastTime = songStart
        var previousSubmission = wallStart
        var wraps = 0
        var missingVideos = 0
        var requestedVideos = 0
        var skippedSlots = 0
        var wallMilliseconds: [Double] = []
        var gpuMilliseconds: [Double] = []
        var submissionIntervals: [Double] = []
        var rssSamples: [UInt64] = [rssStart]
        var next = wallStart
        var nextReport = wallStart + 60
        var teardown = false

        func percentile(_ values: [Double], _ fraction: Double) -> Double? {
            guard !values.isEmpty else { return nil }
            let sorted = values.sorted()
            return sorted[min(sorted.count - 1, Int(fraction * Double(sorted.count - 1)))]
        }

        func saveReport(_ status: String, rssAfter: UInt64? = nil) throws {
            let elapsed = ProcessInfo.processInfo.systemUptime - wallStart
            var summary: [String: Any] = [
                "status": status, "requestedSeconds": duration, "wallSeconds": elapsed, "showDurationSeconds": length,
                "resolution": "1920x1080", "targetCadence": 30, "renderedFrames": wallMilliseconds.count,
                "missedSubmissionSlots": skippedSlots, "songLoopWraps": wraps,
                "soundtrackClockStartSeconds": songStart, "soundtrackClockLastSeconds": lastTime,
                "clockMinusWallSeconds": Double(wraps) * length + lastTime - songStart - elapsed,
                "cpuSeconds": cpuSeconds() - cpuStart, "gpuTotalMilliseconds": gpuMilliseconds.reduce(0, +),
                "startingRSSBytes": rssStart, "rssSamplesBytes": rssSamples,
                "videoFramesRequested": requestedVideos, "videoFramesUnavailableAtSubmission": missingVideos,
                "runtimeTeardownVerified": teardown,
                "recentShowEvents": session.showLog.suffix(6).map(\.message)
            ]
            summary["submitWaitP95Milliseconds"] = percentile(wallMilliseconds, 0.95)
            summary["gpuP95Milliseconds"] = percentile(gpuMilliseconds, 0.95)
            summary["submissionIntervalP95Milliseconds"] = percentile(submissionIntervals, 0.95)
            summary["afterTeardownRSSBytes"] = rssAfter
            try JSONSerialization.data(withJSONObject: summary, options: [.prettyPrinted, .sortedKeys]).write(to: report, options: .atomic)
        }

        try saveReport("running")
        while ProcessInfo.processInfo.systemUptime - wallStart < duration {
            try Task.checkCancellation()
            let now = ProcessInfo.processInfo.systemUptime
            if next > now { try await Task.sleep(for: .seconds(next - now)) }
            let began = ProcessInfo.processInfo.systemUptime
            let late = max(0, Int((began - next) * 30))
            skippedSlots += late
            next += Double(late + 1) / 30
            if session.showArmState != .armed || !session.playbackRequested {
                try saveReport("interrupted")
                throw ProjectFileError.io(session.showLog.last?.message ?? session.showStatus ?? session.songMessage ?? "Show stopped during soak.")
            }
            let scene = session.scene
            let sample = scene.transport.position
            if sample < lastTime - length / 2 { wraps += 1 }
            lastTime = sample
            let videos = VideoPlaybackRequest.requests(scene: scene, assets: session.project.videoAssets, audioEnabled: false, at: began)
            requestedVideos += videos.count
            missingVideos += videos.filter { scene.videoFrames[$0.ownerID] == nil }.count
            renderer?.setScene(scene)
            let command = try #require(renderer?.encodeScene(to: pass, viewIdentifier: "Encore soak",
                evaluationTime: sample, evaluationUptime: began))
            let gpu = await withCheckedContinuation { (reply: CheckedContinuation<Double?, Never>) in
                command.addCompletedHandler {
                    reply.resume(returning: $0.status == .completed ? max(0, $0.gpuEndTime - $0.gpuStartTime) * 1000 : nil)
                }
                command.commit()
            }
            let gpuTime = try #require(gpu)
            gpuMilliseconds.append(gpuTime)
            wallMilliseconds.append((ProcessInfo.processInfo.systemUptime - began) * 1000)
            if wallMilliseconds.count > 1 { submissionIntervals.append((began - previousSubmission) * 1000) }
            previousSubmission = began
            if began >= nextReport {
                rssSamples.append(residentBytes())
                try saveReport("running")
                print("Encore soak: \(Int(began - startup)) s, \(wraps) song wraps, \(wallMilliseconds.count) rendered frames.")
                nextReport += 60
            }
        }

        #expect(wraps >= max(0, Int(duration / length) - 2))
        #expect(requestedVideos > 0 && missingVideos < requestedVideos)
        session.stopPlayback()
        #expect(session.showOutput.isBlackout && session.lightingSimulation.isStopped)
        session.releaseRuntimeResources()
        renderer = nil
        #expect(!session.isOutputOpen && session.videoPlayback.activeOwnerCount == 0)
        try await EncoreRehearsal.until(5, "output and renderer release") { outputWindow == nil && rendererAfterClose == nil }
        #expect(files.allSatisfy { !FileManager.default.fileExists(atPath: $0.path) })
        teardown = true
        try saveReport("completed", rssAfter: residentBytes())
    }

    private func cpuSeconds() -> Double {
        var value = rusage()
        getrusage(RUSAGE_SELF, &value)
        return Double(value.ru_utime.tv_sec + value.ru_stime.tv_sec) +
            Double(value.ru_utime.tv_usec + value.ru_stime.tv_usec) / 1_000_000
    }

    private func residentBytes() -> UInt64 {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size / MemoryLayout<natural_t>.size)
        let result = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
            }
        }
        return result == KERN_SUCCESS ? UInt64(info.resident_size) : 0
    }
}
