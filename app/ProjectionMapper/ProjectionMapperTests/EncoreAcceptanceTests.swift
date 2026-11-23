import AppKit
import AVFoundation
import Foundation
import Testing

@MainActor
@Suite(.serialized)
struct EncoreAcceptanceTests {
    @Test func reusableSectionMovesClipsCuesAndMediaToAnotherLayout() async throws {
        let folder = try EncoreRehearsal.temporary()
        let session = EncoreRehearsal.session()
        defer {
            session.releaseRuntimeResources()
            try? FileManager.default.removeItem(at: folder)
        }
        let fixture = try ProjectPackageStore().read(EncoreRehearsal.fixture).project
        let image = try #require(fixture.imageAssets.first)
        let video = try #require(fixture.videoAssets.first)
        let media = EncoreRehearsal.fixture.appendingPathComponent("assets")
        let imageBytes = try Data(contentsOf: media.appendingPathComponent(image.fileName))
        let videoURL = media.appendingPathComponent(video.fileName)

        var origin = MappingProject(name: "First house")
        origin.surfaces[0].name = "Roof"
        origin.videoAssets = [video]
        origin.imageAssets = [image]
        let roof = origin.surfaces[0].source.id
        let lights = LightingController(name: "Simulated relay", kind: .arduino)
        let fixtureA = PatchedFixture(name: "Roof lights", kind: .rgb, controllerID: lights.id)
        origin.lighting.controllers = [lights]
        origin.lighting.fixtures = [fixtureA]
        let imageLook = SourceLook(source: SurfaceSource(content: .image, image: ImageContent(assetID: image.id)))
        let movieLook = SourceLook(source: SurfaceSource(content: .video, video: VideoContent(assetID: video.id, outPoint: video.duration)))
        origin.timelineClips = [
            EffectClip(sourceID: roof, start: 2, duration: 2, source: movieLook),
            EffectClip(sourceID: roof, start: 4, duration: 1, source: imageLook)
        ]
        origin.lighting.cues = [
            LightingCue(name: "Go green", time: 3, lead: 1, entries: [.init(id: fixtureA.id, state: .rgb(.green))]),
            LightingCue(name: "Manual cue", time: 4, manualOnly: true, entries: [.init(id: fixtureA.id, state: .rgb(.red))]),
            LightingCue(name: "After the section", time: 5, entries: [.init(id: fixtureA.id, state: .rgb(.blue))])
        ]
        let section = try ShowSection.capture(origin, name: "Finale", start: 2.5, end: 5)
        #expect(section.clips.map(\.start) == [0, 1.5] && section.clips.first?.source.video?.inPoint == 0.5)
        #expect(section.cues.map(\.time) == [0.5] && section.cues.first?.lead == 0.5)
        let portable = folder.appendingPathComponent("Finale.projectionsection")
        let bytes = try JSONEncoder().encode(section)
        try ShowSectionStore.write(bytes, to: portable, images: [image.id: imageBytes], videos: [video.id: videoURL])
        #expect(throws: DeliveryError.self) {
            try ShowSectionStore.write(bytes, to: portable, images: [image.id: imageBytes], videos: [video.id: videoURL])
        }
        let reopened = try ShowSectionStore.read(portable)

        var receiving = MappingProject(name: "Second house")
        receiving.surfaces[0].name = "Upper windows"
        receiving.surfaces[0].mask = FaceMask(holes: [MaskPolygon(points: [SIMD2(0.2, 0.2), SIMD2(0.4, 0.2), SIMD2(0.3, 0.4)])])
        let target = receiving.surfaces[0].source.id
        let fixtureB = PatchedFixture(name: "Window strip", kind: .rgb, controllerID: lights.id)
        receiving.lighting.controllers = [lights]
        receiving.lighting.fixtures = [fixtureB]
        let targetPath = folder.appendingPathComponent("Second House.projectionmap")
        let document = ProjectDocument(project: receiving)
        try ProjectPackageStore().write(document, to: targetPath)
        try session.load(document, from: targetPath)

        let matching = [roof: target, fixtureA.id: fixtureB.id]
        #expect(throws: DeliveryError.self) {
            try reopened.insertion(into: receiving, matching: [roof: fixtureB.id, fixtureA.id: target], at: 10)
        }
        try await session.insertShowSection(reopened, from: portable, matching: matching, at: 10)
        #expect(session.project.surfaces == receiving.surfaces && session.project.lighting.fixtures == receiving.lighting.fixtures)
        #expect(session.project.timelineClips.map(\.start) == [10, 11.5])
        #expect(session.project.timelineClips.allSatisfy { $0.sourceID == target })
        #expect(Set(session.project.timelineClips.map(\.id)).isDisjoint(with: origin.timelineClips.map(\.id)))
        #expect(session.project.lighting.cues.first?.time == 10.5 && session.project.lighting.cues.first?.entries.first?.id == fixtureB.id)
        #expect(session.project.imageAssets.first?.id != image.id && session.project.videoAssets.first?.id != video.id)
        #expect(throws: DeliveryError.self) {
            try reopened.insertion(into: session.project, matching: matching, at: 10)
        }
        session.undoProjectEdit()
        #expect(session.project == receiving)
        session.redoProjectEdit()
        try FileManager.default.removeItem(at: portable)
        try await session.saveMedia(to: targetPath)
        let saved = try ProjectPackageStore().read(targetPath).project
        #expect(saved.timelineClips == session.project.timelineClips && saved.lighting.cues == session.project.lighting.cues)
        let savedVideo = try #require(saved.videoAssets.first)
        #expect(try Data(contentsOf: targetPath.appendingPathComponent("assets/" + savedVideo.fileName)) == Data(contentsOf: videoURL))
        let images = ImageImportService.loadAssets(saved, package: targetPath)
        #expect(images.problems.isEmpty && images.pixels.count == 1)
    }

    @Test func reusableSectionProtectsFadeBoundariesAndEmptySelections() throws {
        let origin = try ProjectPackageStore().read(EncoreRehearsal.fixture).project
        #expect(throws: DeliveryError.self) { try ShowSection.capture(origin, name: "Interrupted fade", start: 4, end: 10) }
        #expect(throws: DeliveryError.self) { try ShowSection.capture(origin, name: "Empty", start: 50, end: 55) }
        let section = try ShowSection.capture(origin, name: "Encore", start: 3.75, end: 14.5)
        #expect(section.clips.contains { ($0.transition ?? 0) > 0 })
        #expect(section.roles.contains { $0.kind == .fixture(.movingHead) })
        #expect(section.roles.contains { $0.kind == .visual(.text, region: false) })
        #expect(!section.videos.isEmpty)
    }

    @Test func phoneEditsAndShowFaultsOnDisposableEncoreCopy() async throws {
        let folder = try EncoreRehearsal.temporary()
        let session = EncoreRehearsal.session()
        let port: UInt16 = 19449
        let phone = PhoneRemote(session: session, port: port)
        defer {
            phone.stop()
            session.releaseRuntimeResources()
            try? FileManager.default.removeItem(at: folder)
        }
        let copy = folder.appendingPathComponent("Encore rehearsal.projectionmap")
        try FileManager.default.copyItem(at: EncoreRehearsal.fixture, to: copy)
        try await EncoreRehearsal.load(copy, into: session)
        let project = session.project
        let greeting = try #require(project.visualTracks.first { $0.name == "Snowfall Greeting" })
        let clip = try #require(project.timelineClips.first { $0.sourceID == greeting.id })
        let lightingCue = try #require(project.lighting.cues.first { $0.name == "Finale Gold" })
        let controller = try #require(project.lighting.controllers.first)
        let address = "http://127.0.0.1:\(port)"
        try phone.startLocal(address: "127.0.0.1")

        func request(_ path: String, _ payload: [String: Any], token: String = "") async throws -> [String: Any] {
            var request = URLRequest(url: URL(string: address + path)!, timeoutInterval: 4)
            request.httpMethod = "POST"
            request.setValue(address, forHTTPHeaderField: "Origin")
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            if !token.isEmpty { request.setValue("Bearer " + token, forHTTPHeaderField: "Authorization") }
            request.httpBody = try JSONSerialization.data(withJSONObject: payload)
            let (data, _) = try await URLSession.shared.data(for: request)
            return try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
        }

        try await EncoreRehearsal.until(3, "loopback pairing invitation") { phone.pairingURL != nil }
        let code = try #require(phone.pairingURL?.fragment)
        let pair = try await request("/pair", ["code": code])
        let token = try #require(pair["token"] as? String)
        let pending = try await request("/state", [:], token: token)
        #expect(pending["pending"] as? Bool == true)
        phone.approve()
        phone.role = .editor
        let state = try await request("/state", [:], token: token)
        let revision = try #require(state["revision"] as? String)
        var move: [String: Any] = ["sequence":1, "action":"clipMove", "projectID":project.id.uuidString,
                                   "revision":revision, "owner":clip.sourceID.uuidString, "clip":clip.id.uuidString, "start":5.0]
        let updated = try await request("/command", move, token: token)
        #expect(updated["error"] == nil && session.selectedClip?.start == 5)
        var cue: [String: Any] = ["sequence":2, "action":"cueTime", "projectID":project.id.uuidString,
                                  "revision":try #require(updated["revision"] as? String), "cue":lightingCue.id.uuidString, "time":20.25]
        let retimed = try await request("/command", cue, token: token)
        #expect(retimed["error"] == nil && session.selectedLightingCue?.time == 20.25)
        session.undoProjectEdit()
        #expect(session.project.lighting.cues.first { $0.id == lightingCue.id }?.time == lightingCue.time)
        session.undoProjectEdit()
        #expect(session.project.timelineClips.first { $0.id == clip.id }?.start == clip.start)
        session.redoProjectEdit()
        session.redoProjectEdit()
        try await session.saveMedia(to: copy)
        try await EncoreRehearsal.load(copy, into: session)
        #expect(session.project.timelineClips.first { $0.id == clip.id }?.start == 5)
        #expect(session.project.lighting.cues.first { $0.id == lightingCue.id }?.time == 20.25)
        #expect(session.project.surfaces == project.surfaces && session.project.objects == project.objects)

        try await EncoreRehearsal.show(session)
        let refreshed = try await request("/state", [:], token: token)
        move["sequence"] = 3
        move["revision"] = refreshed["revision"]
        cue["sequence"] = 4
        cue["revision"] = refreshed["revision"]
        #expect(try await request("/command", move, token: token)["error"] != nil)
        #expect(try await request("/command", cue, token: token)["error"] != nil)
        phone.revoke()
        #expect(!phone.hasPhone)
        #expect(try await request("/state", [:], token: token)["error"] != nil)

        try #require(session.setPlaying(true))
        try await EncoreRehearsal.until(5, "Encore clock starts") { session.transport.position > 0.05 }
        session.closeOutput()
        session.inspectArmedShow()
        #expect(session.showArmState == .interrupted && !session.playbackRequested)
        #expect(session.showOutput.isBlackout && session.lightingSimulation.isStopped && session.lightingSimulation.blackout)
        #expect(!session.setPlaying(true))
        session.openOutput()
        await session.prepareShow()
        try #require(session.showArmState == .armed && !session.playbackRequested)
        session.restoreOutput()
        try #require(session.setPlaying(true))
        session.lightingSimulation.setFailure(true, for: controller.id)
        session.inspectArmedShow()
        #expect(session.showArmState == .interrupted && session.showOutput.isBlackout)
        #expect(session.showStatus?.localizedCaseInsensitiveContains("fixture") == true)
        session.lightingSimulation.setFailure(false, for: controller.id)
        await session.prepareShow()
        #expect(session.showArmState == .armed && !session.playbackRequested)

        let asset = try #require(session.project.videoAssets.first)
        let stagedVideo = try #require(session.videoFiles[asset.id])
        try FileManager.default.removeItem(at: stagedVideo)
        session.inspectArmedShow()
        #expect(session.showArmState == .interrupted && session.showStatus?.contains(asset.name) == true)
        await session.prepareShow()
        #expect(session.showArmState != .armed)
        #expect(session.showChecks?.issues.contains { $0.severity == .blocker && $0.message.contains(asset.name) } == true)
        #expect(FileManager.default.fileExists(atPath: copy.appendingPathComponent("assets/\(asset.fileName)").path))
    }

    @Test func failedSaveAndDamagedOpenKeepEncoreRecoverable() async throws {
        let folder = try EncoreRehearsal.temporary()
        let session = EncoreRehearsal.session()
        defer {
            session.releaseRuntimeResources()
            try? FileManager.default.removeItem(at: folder)
        }
        let copy = folder.appendingPathComponent("Encore saved.projectionmap")
        try FileManager.default.copyItem(at: EncoreRehearsal.fixture, to: copy)
        try await EncoreRehearsal.load(copy, into: session)
        let saved = try ProjectPackageStore().read(copy)
        let prior = try Data(contentsOf: copy.appendingPathComponent("manifest.json"))
        let recovery = ProjectRecoveryStore(directory: folder.appendingPathComponent("Recovery"))
        session.configureRecovery(recovery)
        session.renameProject("Encore with recovered edits")
        let interrupted = ProjectPackageStore()
        interrupted.beforeCommit = { _ in throw CancellationError() }
        #expect(throws: CancellationError.self) {
            try interrupted.write(session.document, to: copy, assetsFrom: copy, videoFiles: session.videoFiles)
        }
        #expect(try Data(contentsOf: copy.appendingPathComponent("manifest.json")) == prior)
        try session.flushRecovery()
        let entry = try #require(recovery.entries().first)
        #expect(entry.document.project.name == "Encore with recovered edits")
        #expect(entry.document.project.referencedVideoIDs == saved.project.referencedVideoIDs)
        var malformed = entry.document
        malformed.project.surfaces[0].name = ""
        let active = session.project
        #expect(throws: ProjectFileError.self) { try session.load(malformed, from: copy) }
        #expect(session.project == active)
        #expect(throws: ProjectFileError.self) { try ProjectCodec.decode(Data("{broken".utf8)) }
        try session.load(entry.document, from: entry.url, recovering: true)
        #expect(session.project.name == "Encore with recovered edits" && session.hasUserChanges)
        #expect(session.workspace == .edit && !session.playbackRequested)
        #expect(try ProjectPackageStore().read(copy) == saved)
    }

    @Test func requestedLoopWrapsWhenPlayerStopsJustShortOfFullSongEnd() {
        let loop = SongLoop(start: 0, end: 24)
        #expect(loop.shouldWrap(at: 23.979, stopped: true))
        #expect(!loop.shouldWrap(at: 23.979, stopped: false))
        #expect(!loop.shouldWrap(at: 23.9, stopped: true))
        #expect(loop.shouldWrap(at: 23.996, stopped: false))
        #expect(loop.shouldWrap(at: 24, stopped: false))
    }

    @Test func documentedSchemaVersionsRetainCoreMappingAndSafeDefaults() throws {
        var project = MappingProject(name: "Migration fixture")
        let face = project.surfaces[0]
        project.surfaces[0].source.content = .solid
        project.surfaces[0].source.color = SIMD4(0.3, 0.7, 0.2, 1)
        let encoded = try ProjectCodec.encode(ProjectDocument(project: project))
        let base = try #require(JSONSerialization.jsonObject(with: encoded) as? [String: Any])
        for version in 1...ProjectDocument.currentVersion {
            var document = base
            var model = try #require(document["project"] as? [String: Any])
            var surfaces = try #require(model["surfaces"] as? [[String: Any]])
            document["formatVersion"] = version
            if version == 1 {
                document.removeValue(forKey: "output")
                model.removeValue(forKey: "generatorPresets")
            }
            if version <= 2 { surfaces[0].removeValue(forKey: "appearance") }
            if version <= 3 {
                var layout = try #require(surfaces[0]["layout"] as? [String: Any])
                layout.removeValue(forKey: "isGeometryLocked")
                surfaces[0]["layout"] = layout
            }
            model["surfaces"] = surfaces
            if version <= 4 { for key in ["palettes","looks","masterOutput"] { model.removeValue(forKey: key) } }
            if version <= 6 { model.removeValue(forKey: "imageAssets") }
            if version <= 7 { model.removeValue(forKey: "timelineClips") }
            if version <= 8 { for key in ["videoAssets","videoAudio"] { model.removeValue(forKey: key) } }
            if version <= 9 { model.removeValue(forKey: "lighting") }
            if version <= 15, var lighting = model["lighting"] as? [String: Any] {
                lighting.removeValue(forKey: "effects")
                if version <= 14 { lighting.removeValue(forKey: "positionKeys") }
                model["lighting"] = lighting
            }
            document["project"] = model
            let reopened = try ProjectCodec.decode(JSONSerialization.data(withJSONObject: document))
            #expect(reopened.formatVersion == ProjectDocument.currentVersion, "from \(version)")
            #expect(reopened.project.surfaces[0].id == face.id && reopened.project.surfaces[0].corners == face.corners, "from \(version)")
            #expect(reopened.project.surfaces[0].source == project.surfaces[0].source, "from \(version)")
            #expect(reopened.project.videoAudio == VideoAudioSettings() && reopened.project.song == nil, "from \(version)")
            #expect(reopened.output.destination == .testWindow, "from \(version)")
            #expect(try ProjectCodec.decode(ProjectCodec.encode(reopened)) == reopened, "from \(version)")
        }
    }

    @Test(.enabled(if: ProcessInfo.processInfo.environment["PROJECTION_ENCORE_ACCEPTANCE"] != nil))
    func completeEncoreExportAndPortableDelivery() async throws {
        let folder = URL(fileURLWithPath: try #require(ProcessInfo.processInfo.environment["PROJECTION_ENCORE_ACCEPTANCE"]))
        let session = EncoreRehearsal.session()
        defer { session.releaseRuntimeResources() }
        let copy = folder.appendingPathComponent("Working Copy.projectionmap")
        try FileManager.default.copyItem(at: EncoreRehearsal.fixture, to: copy)
        try await EncoreRehearsal.load(copy, into: session)
        let project = session.project
        let owner = try #require(project.objects.first?.source.id)
        let exporter = folder.appendingPathComponent("Winter Lights Encore - mapped.mp4")
        let canvas = folder.appendingPathComponent("Winter Lights Encore - panorama.mp4")
        let portable = folder.appendingPathComponent("Collected Encore.projectionmap")
        try await session.withDeliverySnapshot { snapshot in
            let settings = VideoExportOptions(width: 1920, height: 1080, framesPerSecond: 30, start: 0, end: 24, includeSong: true)
            try await ShowVideoExport.write(snapshot: snapshot, options: settings, to: exporter) { _, _ in }
            var options = settings
            options.mode = .canvas
            options.owner = owner
            options.includeSong = false
            try await ShowVideoExport.write(snapshot: snapshot, options: options, to: canvas) { _, _ in }
            try await snapshot.collect(to: portable) { _, _ in }
        }
        #expect(session.documentURL == copy)
        for (url, hasSong) in [(exporter, true), (canvas, false)] {
            let asset = AVURLAsset(url: url)
            let track = try #require(try await asset.loadTracks(withMediaType: .video).first)
            #expect(try await track.load(.naturalSize) == CGSize(width: 1920, height: 1080))
            #expect(abs(try await asset.load(.duration).seconds - 24) < 0.002)
            let reader = try AVAssetReader(asset: asset)
            let video = AVAssetReaderTrackOutput(track: track, outputSettings: nil)
            reader.add(video)
            #expect(reader.startReading())
            var index = 0
            var greatestError = 0.0
            while let frame = video.copyNextSampleBuffer() {
                guard frame.numSamples > 0 else { continue }
                greatestError = max(greatestError, abs(frame.presentationTimeStamp.seconds - Double(index) / 30))
                index += 1
            }
            #expect(reader.status == .completed)
            #expect(index == 720 && greatestError < 0.0001)
            let tracks = try await asset.loadTracks(withMediaType: .audio)
            #expect(tracks.count == (hasSong ? 1 : 0))
            if let soundtrack = tracks.first {
                let range = try await soundtrack.load(.timeRange)
                #expect(abs(range.start.seconds) < 0.005 && abs(range.duration.seconds - 24) < 0.005)
            }
            let generator = AVAssetImageGenerator(asset: asset)
            generator.maximumSize = CGSize(width: 320, height: 180)
            for seconds in [0.0, 4.75, 8.0, 12.0, 14.0, 16.75, 20.0, 23.9] {
                let image = try await generator.image(at: CMTime(seconds: seconds, preferredTimescale: 600)).image
                #expect(image.width == 320 && image.height == 180)
            }
        }

        let moved = folder.appendingPathComponent("Portable")
        try FileManager.default.createDirectory(at: moved, withIntermediateDirectories: false)
        let reopened = moved.appendingPathComponent(portable.lastPathComponent)
        try FileManager.default.moveItem(at: portable, to: reopened)
        session.releaseRuntimeResources()
        try FileManager.default.removeItem(at: copy)
        try await EncoreRehearsal.load(reopened, into: session)
        #expect(session.project == project && session.imageProblems.isEmpty && session.videoProblems.isEmpty)
        #expect(!session.songPeaks.isEmpty && !session.playbackRequested)
    }

    @Test(.enabled(if: ProcessInfo.processInfo.environment["PROJECTION_ENCORE_ACCEPTANCE"] != nil))
    func completeEncoreThenRunTwoSavedPlaylistItems() async throws {
        let folder = try EncoreRehearsal.temporary()
        let session = EncoreRehearsal.session()
        let defaults = UserDefaults(suiteName: "ProjectionMapper.encore.playlist." + UUID().uuidString)!
        let library = ShowLibrary(defaults: defaults)
        defer {
            library.stopNow()
            session.releaseRuntimeResources()
            try? FileManager.default.removeItem(at: folder)
        }
        let first = folder.appendingPathComponent("Encore first.projectionmap")
        let second = folder.appendingPathComponent("Encore second.projectionmap")
        try FileManager.default.copyItem(at: EncoreRehearsal.fixture, to: first)
        try FileManager.default.copyItem(at: EncoreRehearsal.fixture, to: second)
        try await EncoreRehearsal.load(first, into: session)
        try await EncoreRehearsal.show(session)
        try #require(session.setPlaying(true))
        try await EncoreRehearsal.until(32, "full 24-second show") { !session.playbackRequested }
        #expect(session.transport.position == 24)
        #expect(session.showOutput.isBlackout && session.lightingSimulation.isStopped)
        #expect(session.showLog.contains { $0.message.contains("Song ended") })
        session.disarmShow()

        let list = ShowPlaylist(name: "Encore handoff", entries: [
            .init(path: first.path, seconds: 24), .init(path: second.path, seconds: 24)
        ])
        var opened: [String] = []
        library.canStart = { !session.playbackRequested }
        library.stopOutput = { session.disarmShow() }
        library.itemOutcome = {
            if session.showArmState != .armed { return session.showStatus ?? "Show interrupted." }
            return session.playlistItemCompleted ? "" : nil
        }
        library.runEntry = { entry, id in
            guard library.mayBeginItem(id) else { throw CancellationError() }
            try await EncoreRehearsal.load(entry.url, into: session)
            try await EncoreRehearsal.show(session)
            session.configurePlaylistItem(end: Double(entry.seconds)) { library.stopNow() }
            opened.append(entry.url.lastPathComponent)
            try #require(session.setPlaying(true))
        }
        library.start(list)
        try #require(library.running, "\(library.status)")
        try await EncoreRehearsal.until(64, "two complete playlist items") { !library.running }
        #expect(opened == [first.lastPathComponent, second.lastPathComponent])
        #expect(library.status == "Playlist finished.")
        #expect(session.showOutput.isBlackout && session.lightingSimulation.isStopped && !session.playbackRequested)
    }
}
