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
