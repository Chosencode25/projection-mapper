import Testing
import Foundation
import MetalKit

@Suite("Playback timeline") @MainActor
struct TimelineTests {
    @Test func timelineNavigationFitsShortAndHourLongSequences() {
        // Fit includes the final clip plus breathing room, even for the saved one-hour limit.
        for end in [0.0, 5, 75, 3599, 3600] {
            let scale = TimelinePresentation.fitScale(contentEnd: end, viewportWidth: 720)
            #expect((0.1...80).contains(scale))
            #expect((end + 1) * scale <= 720)
            #expect(Double(TimelinePresentation.tickStep(pixelsPerSecond: scale)) * scale >= 68)
        }
        #expect(TimelinePresentation.fitScale(contentEnd: 0, viewportWidth: 0) == 0.1)
        #expect(TimelinePresentation.horizon(contentEnd: 0, playhead: 0) == 60)
        #expect(TimelinePresentation.horizon(contentEnd: 74, playhead: 0) == 120)
        #expect(TimelinePresentation.horizon(contentEnd: 10, playhead: 121) == 180)
        #expect(TimelinePresentation.horizon(contentEnd: 0, playhead: 0, visibleDuration: 710) == 720)
        #expect(TimelinePresentation.horizon(contentEnd: 3600, playhead: 7200) == 3600)
        #expect(TimelinePresentation.timecode(-1) == "00:00.00")
        #expect(TimelinePresentation.timecode(61.25) == "01:01.25")
        #expect(TimelinePresentation.timecode(.infinity) == "00:00.00")
    }
    @Test func boundariesGapsAndLocalPhase() {
        let owner = SurfaceSource()
        let clip = EffectClip(sourceID: owner.id, start: 5, duration: 3, source: SourceLook(source: owner))
        let surface = RenderSurface(geometry: .diagnostic, color: owner.color, timelineClips: [clip])
        #expect(surface.evaluated(at: 4.99).appearance.opacity == 0)
        #expect(surface.evaluated(at: 5).appearance.opacity == 1)
        #expect(abs(surface.evaluated(at: 7.99).playback.elapsed(at: 7.99) - 2.99) < 0.000001)
        #expect(surface.evaluated(at: 8).appearance.opacity == 0)
        #expect(surface.evaluated(at: 8, calibrationActive: true).appearance.opacity == 1)
        #expect(RenderSurface(geometry: .diagnostic, color: owner.color).evaluated(at: 500).appearance.opacity == 1)
    }
    @Test func editingOverlapDirtyAndTransport() throws {
        let session = EditorSession(presentOutput: { _ in })
        let owner = session.project.timelineTracks[0].id
        let id = try #require(session.addTimelineClip(sourceID: owner, at: 0))
        #expect(session.hasUserChanges)
        #expect(session.addTimelineClip(sourceID: owner, at: 4) == nil)
        #expect(session.addTimelineClip(sourceID: owner, at: 5) != nil)
        var clip = try #require(session.project.timelineClips.first { $0.id == id })
        clip.start = 6
        #expect(!session.updateTimelineClip(clip))
        clip.start = 12; clip.duration = 2; clip.source.content = .plasma
        #expect(session.updateTimelineClip(clip))
        session.seekPlayback(to: 12, at: 100)
        #expect(session.scene.surfaces[0].evaluated(at: 12).content == .plasma)
        #expect(session.scene.surfaces[0].evaluated(at: 12).playback.elapsed(at: 12) == 0)
        session.duplicateTimelineClip(id)
        #expect(session.project.timelineClips.count == 3)
        session.deleteTimelineClip(id)
        #expect(session.project.timelineClips.count == 2)
        #expect(session.scene.surfaces[0].timelineClips.count == 2)
    }
    @Test func validationMigrationRoundTripAndDemand() throws {
        var project = MappingProject()
        var source = project.surfaces[0].source; source.content = .solid
        project.timelineClips = [EffectClip(sourceID: source.id, start: 10, duration: 4, source: SourceLook(source: source))]
        let document = ProjectDocument(project: project)
        #expect(try ProjectCodec.decode(ProjectCodec.encode(document)) == document)
        var json = try #require(JSONSerialization.jsonObject(with: ProjectCodec.encode(document)) as? [String:Any])
        json["formatVersion"] = 7
        var old = try #require(json["project"] as? [String:Any]); old.removeValue(forKey: "timelineClips"); json["project"] = old
        let migrated = try ProjectCodec.decode(JSONSerialization.data(withJSONObject: json))
        #expect(migrated.project.timelineClips.isEmpty)
        #expect(migrated.formatVersion == ProjectDocument.currentVersion)
        var scene = project.renderScene
        scene.transport.setPlaying(true, at: 0)
        #expect(scene.needsContinuousRendering(at: 1)) // future static clips must still advance
        scene.transport.setPlaying(false, at: 1)
        #expect(!scene.needsContinuousRendering(at: 1))
        var bad = project.timelineClips[0]; bad.duration = .infinity
        #expect(!EffectClip.validSequence([bad]))
        bad.duration = 0.01; #expect(!EffectClip.validSequence([bad]))
    }
    @Test func objectRowsCopyDetachAndDelete() throws {
        let session = EditorSession(presentOutput: { _ in })
        let original = session.project.surfaces[0].id
        session.addSurface()
        session.createObject(faceIDs: Set(session.project.surfaces.map(\.id)))
        let object = try #require(session.selectedObject)
        #expect(session.project.timelineTracks.count == 1)
        #expect(session.project.timelineTracks[0].faceCount == 2)
        let clipID = try #require(session.addTimelineClip(sourceID: object.source.id, at: 5))
        #expect(session.scene.surfaces.allSatisfy { $0.timelineClips.map(\.id) == [clipID] })
        session.duplicateObject(object.id)
        #expect(session.project.timelineTracks.count == 2)
        #expect(session.project.timelineClips.count == 2)
        session.detachSurface(original)
        #expect(session.project.timelineTracks.count == 3)
        #expect(session.project.timelineClips.count == 3)
        try ProjectCodec.validate(ProjectDocument(project: session.project))
        session.deleteSurface(original)
        #expect(session.project.timelineClips.count == 2)
        session.deleteObject(object.id)
        #expect(session.project.timelineClips.count == 1)
        try ProjectCodec.validate(ProjectDocument(project: session.project))
    }
    @Test func clipOnlyImageRetainedAndUnknownTargetRejected() throws {
        var project = MappingProject()
        let asset = ImageAsset(name: "fixture.png", width: 2, height: 2)
        project.imageAssets = [asset]
        var source = project.surfaces[0].source
        source.content = .image; source.image = ImageContent(assetID: asset.id)
        project.timelineClips = [EffectClip(sourceID: source.id, start: 0, duration: 5, source: SourceLook(source: source))]
        #expect(project.referencedImageIDs == [asset.id])
        let loaded = try ProjectCodec.decode(ProjectCodec.encode(ProjectDocument(project: project)))
        #expect(loaded.project.timelineClips == project.timelineClips)
        project.timelineClips[0].sourceID = UUID()
        #expect(throws: ProjectFileError.self) { try ProjectCodec.validate(ProjectDocument(project: project)) }
    }
    @Test func gpuClipBoundariesCalibrationAndSeekReconstruction() throws {
        let session = EditorSession(presentOutput: { _ in })
        session.setSurfaceContent(.solid)
        session.setSourceColor(SIMD4(1,0,0,1))
        let owner = session.project.timelineTracks[0].id
        _ = try #require(session.addTimelineClip(sourceID: owner, at: 5, duration: 5))
        session.selectedClipID = nil // Select base content before capturing another look.
        session.setSourceColor(SIMD4(0,0,1,1))
        _ = try #require(session.addTimelineClip(sourceID: owner, at: 10, duration: 5))
        let renderer = try MetalRenderer(scene: session.scene)
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .bgra8Unorm, width: 64, height: 64, mipmapped: false)
        descriptor.storageMode = .shared; descriptor.usage = .renderTarget
        let texture = try #require(renderer.device.makeTexture(descriptor: descriptor))
        func sample(_ time: Double) throws -> [UInt8] {
            let pass = MTLRenderPassDescriptor(); pass.colorAttachments[0].texture = texture
            let command = try #require(renderer.encodeScene(to: pass, evaluationTime: time, evaluationUptime: 100))
            command.commit(); command.waitUntilCompleted()
            #expect(command.status == .completed)
            var bytes = [UInt8](repeating: 0, count: 4)
            texture.getBytes(&bytes, bytesPerRow: 4, from: MTLRegionMake2D(32,32,1,1), mipmapLevel: 0)
            return Array(bytes.prefix(3))
        }
        #expect(try sample(4.99) == [0,0,0])
        #expect(try sample(5) == [0,0,255])
        #expect(try sample(10) == [255,0,0])
        #expect(try sample(15) == [0,0,0])
        #expect(try sample(6) == [0,0,255]) // backwards seek reconstructs without mutating saved content
        session.setCalibrationPattern(.white)
        renderer.setScene(session.scene)
        #expect(try sample(20) == [255,255,255])
    }

}


struct NavigationZoomTests {
    @Test func timelineZoomCentersPlayheadAndClampsAtEdges() {
        #expect(TimelinePresentation.centeredOffset(time: 10, pixelsPerSecond: 80, viewportWidth: 600, horizon: 60) == 500)
        #expect(TimelinePresentation.centeredOffset(time: 2, pixelsPerSecond: 80, viewportWidth: 600, horizon: 60) == 0)
        #expect(TimelinePresentation.centeredOffset(time: 60, pixelsPerSecond: 80, viewportWidth: 600, horizon: 60) == 4200)
    }

    @Test func diagonalTrackpadDeltasPanBothAxesAndRespectFit() {
        let viewport = CGSize(width: 600, height: 300)
        let fitted = CGSize(width: 560, height: 280)
        let start = CGPoint(x: 0.5, y: 0.5)
        let delta = CGSize(width: 56, height: -28)
        #expect(!CanvasNavigation.canPan(viewport: viewport, fitted: fitted, zoom: 1))
        #expect(CanvasNavigation.canPan(viewport: viewport, fitted: fitted, zoom: 2))
        let center = CanvasNavigation.center(start, translation: delta, viewport: viewport, fitted: fitted, zoom: 2)
        #expect(abs(center.x - 0.45) < 0.0001)
        #expect(abs(center.y - 0.55) < 0.0001)
    }

    @Test func canvasPanAndSelectionUseUnchangedOutputCoordinates() {
        let viewport = CGSize(width: 800, height: 480)
        let fitted = CGSize(width: 760, height: 420)
        let bounds = NormalizedRectangle(topLeft: SIMD2(0.5, 0.25), topRight: SIMD2(0.75, 0.25),
                                         bottomRight: SIMD2(0.75, 0.5), bottomLeft: SIMD2(0.5, 0.5))
        let target = CanvasNavigation.selection(bounds, viewport: viewport, fitted: fitted)
        #expect(target.center == CGPoint(x: 0.625, y: 0.375))
        #expect(target.zoom > 3)
        let panned = CanvasNavigation.center(target.center, translation: CGSize(width: 10000, height: -10000),
                                             viewport: viewport, fitted: fitted, zoom: target.zoom)
        #expect(panned.x > 0 && panned.x < 0.5 && panned.y > 0.5 && panned.y < 1)
        #expect(CanvasNavigation.center(target.center, translation: .zero, viewport: viewport, fitted: fitted, zoom: 1)
                == CGPoint(x: 0.5, y: 0.5))
    }
}

@MainActor
struct HolidayChoreographyTests {
    @Test func chaseOrderAndWaveUseStableTargetPositions() {
        let targets = [0.8, 0.1, 0.5].map { ChoreographyTarget(id: UUID(), position: .init(x: $0, y: 0.5)) }
        var clip = ChoreographyClip(pattern: .bounce, targets: targets, start: 3, interval: 0.5, repeats: 2)
        #expect(clip.isValid)
        #expect(clip.duration == 4)
        for (step, index) in [0, 1, 2, 1, 0, 1, 2, 1].enumerated() {
            #expect(clip.sample(at: 3 + Double(step) * 0.5, target: targets[index].id)?.active == true)
        }
        clip.pattern = .reverse
        #expect(clip.sample(at: 3, target: targets[2].id)?.active == true)
        clip.pattern = .wave
        #expect(clip.sample(at: 3, target: targets[1].id)?.active == true)
        #expect(clip.sample(at: 4, target: targets[0].id)?.active == true)
        var conflict = clip
        conflict.id = UUID()
        #expect(!ChoreographyClip.validSequence([clip, conflict]))
    }

    @Test func downbeatQueueFiresOnceAndSeekCancels() throws {
        let session = ProjectPersistenceTests().session()
        defer { session.releaseRuntimeResources() }
        let controller = LightingController(name: "Arduino", kind: .arduino)
        let fixture = PatchedFixture(name: "Plug", kind: .plug, controllerID: controller.id)
        let cue = LightingCue(name: "On", time: 0, manualOnly: true,
                              entries: [FixtureLookEntry(id: fixture.id, state: .plug(true))])
        session.editLighting {
            $0.controllers = [controller]; $0.fixtures = [fixture]; $0.cues = [cue]
        }
        let markers = [ShowMarker(time: 1, kind: .beat, name: "Beat"),
                       ShowMarker(time: 2, kind: .beat, downbeat: true, name: "Bar")]
        session.setShowMarkers(markers)
        let wrapped = BeatBoundary.bar.next(in: markers, after: 2.5, loop: SongLoop(start: 1, end: 3), end: 4)
        #expect(wrapped?.time == 2 && wrapped?.wraps == true)
        session.queueBeat(.bar, at: 10)
        #expect(session.queuedBeat?.time == 2)
        session.setPlaying(true, at: 10)
        session.refreshLighting(at: 11.9)
        #expect(session.lastManualCueID == nil)
        session.refreshLighting(at: 12)
        #expect(session.lastManualCueID == cue.id && session.queuedBeat == nil)
        session.seekPlayback(to: 0, at: 12)
        session.queueBeat(.beat, at: 12)
        session.seekPlayback(to: 0.5, at: 12)
        #expect(session.queuedBeat == nil)
    }
}

@MainActor
struct VisualCompositionTests {
    @Test func deletingFacePrunesRegionClipsAndUndoRestoresThem() throws {
        let session = EditorSession(presentOutput: { _ in })
        let face = try #require(session.selectedSurface)
        session.addRegion(faceID: face.id)
        let id = try #require(session.selectedVisualID)
        let clip = try #require(session.addTimelineClip(sourceID: id, at: 1))
        session.deleteSurface(face.id)
        #expect(session.project.regions.isEmpty && session.project.timelineClips.isEmpty)
        session.undoProjectEdit()
        #expect(session.project.regions.first?.id == id)
        #expect(session.project.timelineClips.first?.id == clip)
        try ProjectCodec.validate(session.document)
    }

    @Test func format13MigratesAndKeepsBaseTrack() throws {
        let project = MappingProject()
        let encoded = try ProjectCodec.encode(ProjectDocument(project: project))
        var object = try #require(JSONSerialization.jsonObject(with: encoded) as? [String: Any])
        object["formatVersion"] = 13
        let migrated = try ProjectCodec.decode(JSONSerialization.data(withJSONObject: object))
        #expect(migrated.formatVersion == ProjectDocument.currentVersion)
        #expect(migrated.project == project)
        #expect(migrated.project.timelineTracks.count == 1)
    }

    @Test func overlappingOverlayVideoUsesOneMutedOwnerAcrossLinkedFaces() throws {
        let base = MappingSurface()
        var project = MappingProject(surface: base)
        let object = MappingObject(name: "Two faces", source: base.source.independentCopy())
        project.objects = [object]
        project.surfaces.append(MappingSurface())
        for index in project.surfaces.indices { project.surfaces[index].layout.objectID = object.id }
        let url = demoPackage()
        let demo = try ProjectPackageStore().read(url).project
        let asset = try #require(demo.videoAssets.first)
        let video = VideoContent(assetID: asset.id, outPoint: asset.duration, loops: true, isMuted: false)
        project.videoAssets = [asset]
        let track = VisualTrack(source: SurfaceSource(content: .video, video: video), name: "Video overlay")
        project.visualLayers = [VisualLayer(ownerID: object.source.id, track: track)]
        project.timelineClips = [
            EffectClip(sourceID: track.id, start: 0, duration: 3, source: SourceLook(source: track.source)),
            EffectClip(sourceID: track.id, start: 2, duration: 2, source: SourceLook(source: track.source), transition: 1)
        ]
        try ProjectCodec.validate(ProjectDocument(project: project))
        var scene = project.renderScene
        scene.transport.sampleSong(2.5, playing: true)
        let requests = VideoPlaybackRequest.requests(scene: scene, assets: [asset], audioEnabled: true, at: 0)
        #expect(requests.count == 2 && Set(requests.map(\.ownerID)).count == 2)
        #expect(requests.allSatisfy { !$0.audible })
        project.objects[0].source.content = .video
        project.objects[0].source.video = video
        #expect(project.visualValidationIssue?.contains("two simultaneous videos") == true)
    }

    @Test func encorePackageLoadsMediaAndRoundTrips() async throws {
        let store = ProjectPackageStore()
        let url = demoPackage()
        let document = try store.read(url)
        let project = document.project
        #expect(project.layers.count == 5 && project.regions.count == 1 && project.regionShapes.count == 1)
        #expect(project.song?.duration == 24)
        let face = try #require(project.layers.first { $0.track.kind == .singingFace }?.track)
        #expect(face.mouth(at: 12.2) == .open && face.mouth(at: 12.22) == .closed)
        let count = try #require(project.layers.first { $0.track.text.mode == .countdown }?.track.text)
        #expect(count.displayedText(at: 18.9, songTitle: nil, markers: project.showMarkers) == "2")
        #expect(count.displayedText(at: 20, songTitle: nil, markers: project.showMarkers) == "0")
        let loaded = await VideoImportService.loadAssets(project.videoAssets, package: url)
        #expect(loaded.problems.isEmpty && loaded.posters.count == 1)
        let session = EditorSession(presentOutput: { _ in })
        try session.load(document, from: url, loadedVideos: loaded)
        #expect(session.imagePixels.count == 1)
        let temp = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: temp, withIntermediateDirectories: false)
        defer { try? FileManager.default.removeItem(at: temp) }
        let copy = temp.appendingPathComponent("Encore.projectionmap")
        try await session.saveMedia(to: copy)
        #expect(try store.read(copy).project == project)
    }

    private func demoPackage() -> URL {
        var root = URL(fileURLWithPath: #filePath)
        for _ in 0..<4 { root.deleteLastPathComponent() }
        return root.appendingPathComponent("assets/demos/Winter Lights Encore.projectionmap", isDirectory: true)
    }
}

@MainActor
struct EditorPolishTests {
    @Test func selectedClipEditsDoNotModifyBaseAndUndoRestoresClip() throws {
        let session = EditorSession(presentOutput: { _ in })
        let source = try #require(session.selectedSource)
        let id = try #require(session.addTimelineClip(sourceID: source.id, at: 0))
        session.setSurfaceContent(.snowfall)
        #expect(session.selectedClip?.source.content == .snowfall)
        #expect(session.project.surfaces[0].source == source)
        session.undoProjectEdit()
        #expect(session.project.timelineClips.first { $0.id == id }?.source.content == source.content)
    }

    @Test func draftsAutosaveUndoAndNamedProjectsPersist() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let session = EditorSession(presentOutput: { _ in })
        session.configureAutosave(directory: directory)
        session.renameProject("Draft rehearsal")
        try await session.flushAutosave()
        #expect(session.isManagedDraft && !session.hasUserChanges)
        let draft = try #require(session.documentURL)
        #expect(try ProjectPackageStore().read(draft).project.name == "Draft rehearsal")
        session.renameProject("Second name")
        try await session.flushAutosave()
        #expect(!session.availableCheckpoints.isEmpty)
        session.undoProjectEdit()
        try await session.flushAutosave()
        #expect(try ProjectPackageStore().read(draft).project.name == "Draft rehearsal")
        let named = directory.deletingLastPathComponent().appendingPathComponent(UUID().uuidString + ".projectionmap")
        defer { try? FileManager.default.removeItem(at: named) }
        try await session.saveMedia(to: named)
        #expect(!session.isManagedDraft)
        session.renameProject("Named project")
        try await session.flushAutosave()
        #expect(try ProjectPackageStore().read(named).project.name == "Named project")
        session.releaseRuntimeResources()
    }

    @Test func visualAndMouthKeyboardActionsFollowSelection() throws {
        let session = EditorSession(presentOutput: { _ in })
        let face = try #require(session.selectedSurface)
        session.addLayer(ownerID: face.source.id)
        let visual = try #require(session.selectedVisualID)
        session.performEditorAction(.visibility)
        #expect(session.project.visualTrack(visual)?.isVisible == false)
        #expect(session.selectedSurface?.layout.isVisible == true)
        #expect(!session.canPerformEditorAction(.lock))
        session.updateVisual(visual) { $0.kind = .singingFace; $0.mouthKeys = [MouthKey(time: 1, shape: .open)] }
        let key = try #require(session.project.visualTrack(visual)?.mouthKeys.first)
        let track = try #require(session.project.timelineTracks.first { $0.id == visual })
        session.selectMouthKey(key.id, on: track)
        session.performEditorAction(.duplicate)
        #expect(session.project.visualTrack(visual)?.mouthKeys.count == 2)
        session.performEditorAction(.delete)
        #expect(session.project.visualTrack(visual)?.mouthKeys.count == 1)
        #expect(session.project.layers.count == 1 && session.project.surfaces.count == 1)
        session.undoProjectEdit()
        #expect(session.project.visualTrack(visual)?.mouthKeys.count == 2)
    }

    @Test func visualHandlesRoundTripSharedCropAndRegionCoordinates() throws {
        var face = MappingSurface(color: SIMD4(1, 0, 0, 1), content: .solid)
        face.layout.inputMap = FaceInputMap(origin: SIMD2(0.2, 0.1), size: SIMD2(0.6, 0.8), quarterTurns: 1, mirrored: true)
        face.appearance.crop = ContentCrop(origin: SIMD2(0.1, 0.2), size: SIMD2(0.8, 0.6))
        var project = MappingProject(surface: face)
        let layer = VisualLayer(ownerID: face.source.id, track: VisualTrack(name: "Title"))
        let region = FaceRegion(faceID: face.id, track: VisualTrack(name: "Window"))
        project.visualLayers = [layer]; project.faceRegions = [region]
        for id in [layer.id, region.id] {
            let mapping = VisualCanvasCoordinates(project: project, face: face, visualID: id)
            for point in [SIMD2<Float>(0.5, 0.5), SIMD2(0.3, 0.7)] {
                let projected = try #require(mapping.project(point))
                let restored = try #require(mapping.unproject(projected))
                #expect(abs(restored.x - point.x) < 0.0001 && abs(restored.y - point.y) < 0.0001)
            }
        }
    }

    @Test func failedAutosaveKeepsEditsAndLastGoodPackage() async throws {
        let parent = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: parent, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: parent) }
        let session = EditorSession(presentOutput: { _ in })
        let recovery = ProjectRecoveryStore(directory: parent.appendingPathComponent("recovery"))
        session.configureRecovery(recovery)
        session.configureAutosave(directory: parent.appendingPathComponent("drafts"))
        let named = parent.appendingPathComponent("Good.projectionmap")
        try await session.saveMedia(to: named)
        let before = try ProjectPackageStore().read(named)
        try FileManager.default.moveItem(at: named, to: parent.appendingPathComponent("Moved.projectionmap"))
        try Data("unrelated file".utf8).write(to: named)
        session.renameProject("Keep my edits")
        do { try await session.flushAutosave(); Issue.record("Save should fail") } catch {}
        #expect(session.hasUserChanges)
        #expect(try ProjectPackageStore().read(parent.appendingPathComponent("Moved.projectionmap")).project == before.project)
        #expect(session.project.name == "Keep my edits")
        #expect(recovery.entries().first?.document.project.name == "Keep my edits")
        session.releaseRuntimeResources()
    }
}
