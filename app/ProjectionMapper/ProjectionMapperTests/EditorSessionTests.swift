import Foundation
import Testing

@MainActor
struct EditorSessionTests {
    @Test func newProjectStartsClean() {
        let session = EditorSession()
        #expect(session.project.name == MappingProject.defaultName)
        #expect(!session.hasUserChanges)
        #expect(session.isSidebarVisible && session.isInspectorVisible)
    }

    @Test func renamePreservesIdentityAndCreationDate() {
        let created = Date(timeIntervalSince1970: 100)
        let changed = Date(timeIntervalSince1970: 200)
        let project = MappingProject(now: created)
        let session = EditorSession(project: project)
        session.renameProject("Halloween House", now: changed)
        #expect(session.project.id == project.id)
        #expect(session.project.createdAt == created)
        #expect(session.project.modifiedAt == changed)
        #expect(session.hasUserChanges)
    }

    @Test func editingTrimsWhitespaceAndRestoresEmptyName() {
        let session = EditorSession()
        session.renameProject("  House  ")
        session.finishNameEditing()
        #expect(session.project.name == "House")
        session.renameProject(" \n ")
        session.finishNameEditing()
        #expect(session.project.name == MappingProject.defaultName)
        #expect(!session.hasUserChanges)
    }

    @Test func resetReplacesProjectAndPreservesPanelPreferences() {
        let session = EditorSession()
        let previousID = session.project.id
        session.renameProject("House")
        session.isSidebarVisible = false
        let resetDate = Date(timeIntervalSince1970: 300)
        session.resetProject(now: resetDate)
        #expect(session.project.id != previousID)
        #expect(session.project.createdAt == resetDate)
        #expect(session.project.modifiedAt == resetDate)
        #expect(!session.hasUserChanges)
        #expect(!session.isSidebarVisible)
    }

    @Test func unchangedNameDoesNotChangeModificationDate() {
        let date = Date(timeIntervalSince1970: 100)
        let session = EditorSession(project: MappingProject(now: date))
        session.renameProject(MappingProject.defaultName, now: Date(timeIntervalSince1970: 200))
        #expect(session.project.modifiedAt == date)
        session.isInspectorVisible = false
        #expect(!session.hasUserChanges)
    }
}

@MainActor
@Suite(.serialized)
struct ProjectHistoryTests {
    private func session() -> EditorSession { EditorSession(presentOutput: { _ in }) }
    @Test func undoRedoSaveBranchAndRuntimeBoundaries() throws {
        let s = session(), initial = s.project
        s.renameProject("House"); #expect(s.canUndo && s.hasUserChanges)
        s.seekPlayback(to: 12,at: 100); s.setPlaying(true,at: 100)
        s.setCalibrationPattern(.checkerboard); s.blackoutOutput(); s.toggleEditorLabels()
        s.undoProjectEdit(); #expect(s.project == initial && !s.hasUserChanges && s.canRedo)
        #expect(s.transport.position == 12 && s.transport.isPlaying && s.calibration.pattern == .checkerboard && s.showOutput.isBlackout)
        s.redoProjectEdit(); #expect(s.project.name == "House")
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".projectionmap")
        defer { try? FileManager.default.removeItem(at: folder) }
        try s.save(to: folder); #expect(!s.hasUserChanges)
        s.undoProjectEdit(); #expect(s.hasUserChanges)
        s.redoProjectEdit(); #expect(!s.hasUserChanges)
        s.undoProjectEdit(); s.renameProject("New branch"); #expect(!s.canRedo)
        s.resetProject(); #expect(!s.canUndo && !s.canRedo && !s.hasUserChanges)
    }
    @Test func continuousChangesAreOneStepAndHistoryIsBounded() {
        let s = session(), before = s.project
        s.beginContinuousEdit("Brightness")
        for i in 1...40 { s.setMasterBrightness(Float(i)/100) }
        s.endContinuousEdit(); #expect(s.undoTitle == "Undo Brightness")
        s.undoProjectEdit(); #expect(s.project == before && !s.canUndo)
        s.redoProjectEdit(); #expect(s.project.masterOutput.brightness == 0.4)
        for i in 0..<120 { s.renameProject("Name \(i)") }
        var count = 0
        while s.canUndo { s.undoProjectEdit(); count += 1 }
        #expect(count == 100 && s.historyNotice != nil)
    }
    @Test func timelineSelectionAndIdentitySurviveUndo() throws {
        let s = session(), owner = s.project.timelineTracks[0].id
        let id = try #require(s.addTimelineClip(sourceID: owner,at: 0,duration: 5))
        let original = try #require(s.selectedClip)
        var moved = original; moved.start = 10
        #expect(s.updateTimelineClip(moved)); s.undoProjectEdit()
        #expect(s.project.timelineClips == [original])
        s.redoProjectEdit(); #expect(s.project.timelineClips == [moved])
        s.deleteTimelineClip(id); s.undoProjectEdit(); #expect(s.project.timelineClips == [moved])
        let before = s.project; s.selectSurface(s.project.surfaces[0].id); s.seekPlayback(to: 20)
        s.undoProjectEdit(); #expect(s.project.timelineClips == [original] && before.id == s.project.id)
    }
    @Test func groupingMapsMasksAndLibrariesAreRestoredTogether() throws {
        let s = session()
        s.addSurface(); s.addSurface()
        let original = s.project
        for face in s.project.surfaces { s.toggleGrouping(face.id) }
        s.createObject(); let grouped = s.project
        #expect(grouped.objects.count == 1)
        s.undoProjectEdit(); #expect(s.project == original)
        s.redoProjectEdit(); #expect(s.project == grouped)
        let face = try #require(s.project.surfaces.first)
        s.selectSurface(face.id); s.createMask(faceID: face.id); let masked = s.project
        s.undoProjectEdit(); #expect(s.project.surfaces.first?.mask == nil)
        s.redoProjectEdit(); #expect(s.project == masked)
        let palette = try #require(s.createPalette(name: "Christmas"))
        let withPalette = s.project; s.deletePalette(palette); s.undoProjectEdit(); #expect(s.project == withPalette)
        let look = try #require(s.saveLook(name: "Lights")); let withLook = s.project
        s.deleteLook(look); s.undoProjectEdit(); #expect(s.project == withLook)
    }
    @Test func readinessAndIdentificationNeverEditProjectOrTransport() {
        let s = session(), before = s.project
        s.seekPlayback(to: 8,at: 100); let clock = s.transport
        s.identifySelectedObject()
        #expect(s.scene.surfaces.count == 1 && s.scene.calibration.pattern == .white)
        let report = s.playbackReadiness()
        #expect(report.blockerCount == 0 && report.issues.contains { $0.id == "identify" })
        s.finishIdentification()
        #expect(s.project == before && s.transport == clock && !s.canUndo && s.calibration.pattern == .normal)
        #expect(!s.hasUserChanges)
    }
    @Test func demoRoundTripMixedWorkflowAndHistory() async throws {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let fixture = root.appendingPathComponent("app/ProjectionMapper/ProjectionMapper/Resources/V1-Demo.projectionmap")
        let template = try ProjectPackageStore().read(fixture)
        let document = try ProjectCodec.freshDemo(template)
        let another = try ProjectCodec.freshDemo(template)
        #expect(document.project.id != template.project.id && document.project.id != another.project.id)
        #expect(document.project.surfaces == template.project.surfaces && document.project.timelineClips == template.project.timelineClips)
        let images = ImageImportService.loadAssets(document.project,package: fixture)
        let videos = await VideoImportService.loadAssets(document.project.videoAssets,package: fixture)
        let s = session(); try s.load(document,from: fixture,recovering: true,loadedMedia: images,loadedVideos: videos)
        #expect(s.documentURL == nil && s.hasUserChanges && !s.canUndo)
        #expect(s.project.surfaces.count == 5 && s.project.objects.count == 1 && s.project.timelineClips.count == 5)
        #expect(s.playbackReadiness().blockerCount == 0)
        let object = try #require(s.project.objects.first), layout = s.project.surfaces.map(\.layout)
        s.selectObject(object.id); s.setSourceColor(SIMD4(0,1,0,1)); let colorEdit = s.project
        s.undoProjectEdit(); #expect(s.project.surfaces.map(\.layout) == layout)
        s.redoProjectEdit(); #expect(s.project == colorEdit)
        s.beginContinuousEdit("Move Object"); s.moveObject(object.id,by: SIMD2(-0.01,0.01)); s.moveObject(object.id,by: SIMD2(-0.01,0.01)); s.endContinuousEdit()
        s.undoProjectEdit(); #expect(s.project == colorEdit)
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".projectionmap")
        defer { try? FileManager.default.removeItem(at: folder) }
        try await s.saveMedia(to: folder); #expect(!s.hasUserChanges)
        for i in 0..<20 {
            s.seekPlayback(to: Double(i%10),at: 100 + Double(i)); s.blackoutOutput(); s.restoreOutput(at: 100+Double(i))
            s.setCalibrationPattern(.grid); s.setCalibrationPattern(.normal)
        }
        #expect(!s.hasUserChanges)
        let reopened = try ProjectPackageStore().read(folder)
        #expect(reopened.project == s.project && reopened.project.referencePhoto != nil)
        s.resetProject()
    }
    @Test func compoundGeometryAndContentEditsRestoreIdentitiesAndRecovery() throws {
        let s = session(); s.addSurface(); s.createObject(faceIDs: Set(s.project.surfaces.map(\.id)))
        let original = s.project, object = try #require(s.project.objects.first), face = s.project.surfaces[0]
        s.selectObject(object.id); s.setObjectMode(.repeatContent,id: object.id); s.undoProjectEdit(); #expect(s.project == original)
        s.setInputMap(FaceInputMap(origin: SIMD2(0.1,0),size: SIMD2(0.4,1)),faceID: face.id)
        s.undoProjectEdit(); #expect(s.project == original)
        s.ungroupObject(object.id); s.undoProjectEdit(); #expect(s.project == original)
        s.selectObject(object.id); s.setTags("house,christmas",objectID: object.id); let tagged = s.project
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: folder) }
        let recovery = ProjectRecoveryStore(directory: folder); s.configureRecovery(recovery)
        s.undoProjectEdit(); try s.flushRecovery(); #expect(recovery.entries().first?.document.project == original)
        s.redoProjectEdit(); #expect(s.project == tagged)
        s.setVideoAudio(VideoAudioSettings(volume: 0.25)); s.undoProjectEdit(); #expect(s.project == tagged)
        s.clearRecovery(); s.resetProject()
    }
    @Test func readinessChecksTimelineOnlyMissingMedia() {
        var p = MappingProject(); let owner = p.surfaces[0].source.id, missing = UUID()
        var source = SourceLook(source: p.surfaces[0].source)
        source.content = .image; source.image = ImageContent(assetID: missing)
        p.timelineClips = [EffectClip(sourceID: owner,start: 3,duration: 5,source: source)]
        let s = EditorSession(presentOutput: { _ in },project: p)
        let report = s.playbackReadiness()
        #expect(report.blockerCount >= 1 && report.issues.contains { $0.id == "image-\(missing)" })
        #expect(!s.transport.isPlaying && !s.videoAudioEnabled && !s.canUndo)
    }
}
