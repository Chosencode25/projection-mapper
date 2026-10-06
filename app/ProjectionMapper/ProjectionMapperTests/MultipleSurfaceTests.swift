import AppKit
import MetalKit
import simd
import Testing

@MainActor
struct MultipleSurfaceTests {
    @Test func presetLibraryCopiesOnlyContentAndBoundsNamesWhilePreservingClockAndLayout() throws {
        let session = EditorSession(); session.addSurface()
        session.createObject(faceIDs: Set(session.project.surfaces.map(\.id)))
        session.setSurfaceContent(.particles)
        var settings = GeneratorSettings.defaults; settings.seed = 98; settings.rate = 2
        session.setGeneratorSettings(settings); session.setSourceColor(SIMD4(0,1,0,1))
        let layouts = session.project.surfaces.map(\.layout), ownerID = session.selectedSource!.id
        session.seekPlayback(to: 4,at: 10); session.setSelectedPaused(true,at: 10)
        let clock = session.selectedPlayback
        let id = try #require(session.saveGeneratorPreset(name: "  Snow  "))
        #expect(session.project.generatorPresets[0].name == "Snow")
        session.setSurfaceContent(.noise); session.resetGeneratorSettings(); session.applyGeneratorPreset(id)
        #expect(session.selectedSource?.content == .particles && session.selectedSource?.generator == settings)
        #expect(session.selectedSource?.color == SIMD4(0,1,0,1))
        #expect(session.selectedSource?.id == ownerID && session.project.surfaces.map(\.layout) == layouts)
        #expect(session.selectedPlayback == clock)
        let before = session.project; session.applyGeneratorPreset(id); session.updateGeneratorPreset(id)
        #expect(session.project == before)
        let second = try #require(session.saveGeneratorPreset(name: "Snow"))
        #expect(second != id && session.project.generatorPresets[1].name == "Snow 2")
        session.setSurfaceContent(.plasma); session.updateGeneratorPreset(id)
        #expect(session.project.generatorPresets[0].content == .plasma)
        session.deleteGeneratorPreset(second); #expect(session.project.generatorPresets.count == 1)
        session.resetGeneratorSettings(); #expect(session.selectedSource?.content == .plasma && session.selectedPlayback == clock)
        session.saveGeneratorPreset(name: String(repeating: "x",count: 100))
        session.saveGeneratorPreset(name: String(repeating: "x",count: 100))
        #expect(session.project.generatorPresets.allSatisfy { $0.name.count <= 80 })
        session.resetProject(); #expect(session.project.generatorPresets.isEmpty && !session.hasUserChanges)
    }
    @Test func seekRejectsInvalidTimesAndKeepsRuntimeOutOfProjectDirtyState() {
        let session = EditorSession(), before = session.project
        session.setPlaying(true,at: 10); session.seekPlayback(to: 12,at: 20)
        #expect(session.transport.elapsed(at: 21) == 13 && session.transport.isPlaying)
        session.seekPlayback(to: 0,at: 21); #expect(session.transport.elapsed(at: 21) == 0)
        let clock = session.transport
        for invalid in [Double.nan, Double.infinity, -1, 3601] { session.seekPlayback(to: invalid,at: 21) }
        #expect(session.transport == clock && session.project == before && !session.hasUserChanges)
        session.setPlaying(false,at: 21); session.seekPlayback(to: 3600,at: 21)
        #expect(session.transport.elapsed(at: 500) == 3600 && !session.transport.isPlaying)
    }
    @Test func scopedPlaybackDuplicatesDetachAndCleanupPreserveOwnerPhases() throws {
        let session = EditorSession(); session.setSurfaceContent(.particles); session.addSurface()
        session.setSurfaceContent(.gradient)
        let front = session.selectedSurfaceID!, back = session.project.surfaces[1].id
        session.setPlaying(true,at: 100); session.setSelectedPaused(true,at: 102)
        #expect(session.selectedPlayback.elapsed(at: 4) == 2)
        #expect(session.scene.needsContinuousRendering)
        session.selectSurface(back); session.setSelectedPaused(true,at: 103)
        #expect(!session.scene.needsContinuousRendering)
        session.selectSurface(front); session.duplicateSurface(front)
        let copy = try #require(session.selectedSurface)
        #expect(session.selectedPlayback.isPaused && session.selectedPlayback.elapsed(at: 50) == 2)
        session.deleteSurface(copy.id); #expect(session.sourcePlayback[copy.source.id] == nil)
        session.createObject(faceIDs: [front,back]); let object = try #require(session.selectedObject)
        #expect(session.selectedPlayback.isPaused && session.selectedPlayback.elapsed(at: 50) == 2)
        session.duplicateObject(object.id); let copyObject = try #require(session.selectedObject)
        #expect(session.selectedPlayback.isPaused)
        let member = session.project.surfaces.first { $0.layout.objectID == copyObject.id }!
        session.detachSurface(member.id); session.selectSurface(member.id)
        #expect(session.selectedPlayback.isPaused && session.selectedPlayback.elapsed(at: 50) == 2)
        session.setSelectedPaused(false,at: 104)
        #expect(session.selectedPlayback.elapsed(at: 5) == 3)
        session.restartSelectedPlayback(at: 104); #expect(session.selectedPlayback.elapsed(at: 4) == 0)
        let before = session.project
        session.seekPlayback(to: 6,at: 104); session.restartPlayback(at: 104)
        #expect(session.project == before)
        #expect(session.sourcePlayback.values.allSatisfy { $0.elapsed(at: 0) == 0 })
        session.resetProject(); #expect(session.sourcePlayback.isEmpty)
    }
    @Test func presetLibraryLimitAndStaleActionsAreSafe() {
        let session = EditorSession(); session.setSurfaceContent(.noise)
        for _ in 0..<100 { session.saveGeneratorPreset(name: "Look") }
        let before = session.project
        #expect(session.saveGeneratorPreset(name: "Overflow") == nil && session.project == before)
        session.applyGeneratorPreset(UUID()); session.updateGeneratorPreset(UUID()); session.deleteGeneratorPreset(UUID())
        #expect(session.project == before && Set(session.project.generatorPresets.map(\.id)).count == 100)
    }

    @Test func generatorParametersValidateBoundsAndOnlyRealOwnerEditsDirtyProject() throws {
        let session = EditorSession(); let before = session.project
        var settings = GeneratorSettings.defaults
        session.setGeneratorSettings(settings); #expect(session.project == before)
        for invalid in [Float.nan, -1, 5] {
            settings = .defaults; settings.scale = invalid; session.setGeneratorSettings(settings)
            #expect(session.project == before)
        }
        settings = .defaults; settings.density = 17; session.setGeneratorSettings(settings)
        settings = .defaults; settings.seed = 1000000; session.setGeneratorSettings(settings)
        settings = .defaults; settings.secondaryColor.x = .nan; session.setGeneratorSettings(settings)
        #expect(session.project == before)
        settings = .defaults; settings.rate = 4; settings.scale = 0.5; settings.density = 16
        settings.particleSize = 0.35; settings.direction = 7; settings.seed = 999999
        #expect(settings.isValid); session.setGeneratorSettings(settings)
        #expect(session.hasUserChanges && session.selectedSource?.generator == settings)
        #expect(session.project.surfaces[0].layout == before.surfaces[0].layout)
    }
    @Test func effectParametersShareWithObjectAndRemainIndependentAfterDetach() throws {
        let session = EditorSession(); session.addSurface()
        session.createObject(faceIDs: Set(session.project.surfaces.map(\.id)))
        let object = try #require(session.selectedObject)
        session.setSurfaceContent(.particles)
        var settings = object.source.generator; settings.seed = 98; settings.density = 16; settings.rate = 2
        session.setGeneratorSettings(settings)
        #expect(session.scene.surfaces.allSatisfy { $0.generator == settings })
        let face = session.project.surfaces[0]; session.detachSurface(face.id); session.selectSurface(face.id)
        settings.seed = 99; session.setGeneratorSettings(settings)
        #expect(session.project.objects.first { $0.id == object.id }?.source.generator.seed == 98)
        #expect(session.selectedSource?.generator.seed == 99)
    }

    @Test func transportKeepsElapsedPhaseAcrossPauseSpeedAndRestartWithoutProjectEdits() {
        let session = EditorSession(); let before = session.project
        session.setPlaying(true, at: 100)
        #expect(session.transport.elapsed(at: 102) == 2)
        session.setPlaybackSpeed(2, at: 102)
        #expect(session.transport.elapsed(at: 103) == 4)
        session.setPlaying(false, at: 103)
        #expect(session.transport.elapsed(at: 1000) == 4)
        session.setPlaybackSpeed(0.5, at: 1000)
        session.setPlaying(true, at: 1000)
        #expect(session.transport.elapsed(at: 1002) == 5)
        session.restartPlayback(at: 1002)
        #expect(session.transport.elapsed(at: 1002) == 0 && session.transport.isPlaying)
        session.setPlaybackSpeed(.nan, at: 1002); session.setPlaybackSpeed(50, at: 1002)
        #expect(session.transport.speed == 0.5)
        #expect(session.project == before && !session.hasUserChanges && session.testOutput.scene == session.scene)
        session.resetProject(); #expect(!session.transport.isPlaying && session.transport.elapsed(at: 1003) == 0)
    }
    @Test func generatorOwnersPreserveLayoutAndDuplicateDetachSettingsAtSharedPhase() throws {
        let session = EditorSession(); session.addSurface()
        session.createObject(faceIDs: Set(session.project.surfaces.map(\.id)))
        let object = try #require(session.selectedObject), geometry = session.project.surfaces.map(\.layout)
        session.setSurfaceContent(.movingLines); session.setSecondaryColor(SIMD4(0,1,0,1))
        #expect(session.project.surfaces.map(\.layout) == geometry)
        #expect(session.scene.surfaces.allSatisfy { $0.content == .movingLines && $0.generator.secondaryColor == SIMD4(0,1,0,1) })
        session.setPlaying(true, at: 100); let clock = session.transport
        session.duplicateObject(object.id)
        let copy = try #require(session.selectedObject)
        #expect(copy.source.id != object.source.id && copy.source.generator.secondaryColor == SIMD4(0,1,0,1))
        session.setSecondaryColor(SIMD4(0,0,1,1))
        #expect(session.project.objects.first { $0.id == object.id }?.source.generator.secondaryColor == SIMD4(0,1,0,1))
        let member = try #require(session.project.surfaces.first { $0.layout.objectID == copy.id })
        session.detachSurface(member.id); session.selectSurface(member.id); session.setSurfaceContent(.gradient)
        #expect(session.project.objects.first { $0.id == copy.id }?.source.content == .movingLines)
        #expect(session.transport == clock)
    }
    @Test func animationSchedulingRequiresVisibleValidAnimatedContentAndPlayingClock() {
        let session = EditorSession(); session.setPlaying(true, at: 10)
        #expect(!session.scene.needsContinuousRendering)
        session.setSurfaceContent(.gradient); #expect(session.scene.needsContinuousRendering)
        let id = session.selectedSurfaceID!
        session.setVisible(false, faceID: id); #expect(!session.scene.needsContinuousRendering)
        session.setVisible(true, faceID: id); session.setPlaying(false, at: 12)
        #expect(!session.scene.needsContinuousRendering && session.scene.hasAnimation)
        session.setPlaying(true, at: 12); session.selectCorner(.topLeft)
        session.moveSelectedCorner(to: SIMD2(0.8,0.8), surfaceID: id)
        #expect(!session.scene.needsContinuousRendering)
    }

    @Test func canvasPickingUsesFrontmostVisibleGeometryAndKeepsProjectUnchanged() throws {
        let session = EditorSession(); session.addSurface()
        let front = session.project.surfaces[0].id, back = session.project.surfaces[1].id
        session.selectSurface(nil)
        var before = session.project
        session.selectSurface(at: SIMD2(0.5,0.5))
        #expect(session.selectedSurfaceID == front && session.project == before)
        session.setVisible(false, faceID: front); before = session.project
        session.selectSurface(at: SIMD2(0.5,0.5))
        #expect(session.selectedSurfaceID == back && session.project == before)
        session.selectSurface(at: SIMD2(0.1,0.1)); #expect(session.selectedSurfaceID == nil)
        session.selectSurface(at: nil); #expect(session.selectedSurfaceID == nil)
        session.setVisible(true, faceID: front)
        session.createObject(faceIDs: [front,back]); let object = try #require(session.selectedObject)
        session.selectSurface(at: SIMD2(0.5,0.5)); #expect(session.selectedSurfaceID == front && session.selectedObjectID == nil)
        session.setVisible(false, objectID: object.id)
        session.selectSurface(at: SIMD2(0.5,0.5)); #expect(session.selectedSurfaceID == nil)
        session.setVisible(true, objectID: object.id); session.selectSurface(front); session.selectCorner(.topLeft)
        session.moveSelectedCorner(to: SIMD2(0.6,0.6), surfaceID: front)
        session.selectSurface(at: SIMD2(0.5,0.5)); #expect(session.selectedSurfaceID == back)
    }

    @Test func addingEditingRenamingAndTagsKeepFacesIndependent() {
        let session = EditorSession(); let first = session.project.surfaces[0]
        session.addSurface(); let second = session.project.surfaces[0]
        #expect(first.id != second.id && first.source.id != second.source.id)
        session.renameSurface(second.id, "Left window")
        session.setTags(" windows, left, windows ", faceID: second.id)
        session.selectCorner(.topLeft); session.moveSelectedCorner(to: SIMD2(0.1,0.1), surfaceID: second.id)
        session.setSurfaceContent(.solid)
        #expect(session.project.surfaces[1] == first)
        #expect(session.project.surfaces[0].name == "Left window")
        #expect(session.project.surfaces[0].tags == ["windows","left"])
        let before = session.project
        session.selectTag("windows")
        #expect(session.groupingSelection == [second.id] && session.project == before)
        session.selectSurface(first.id)
        session.moveSelectedCorner(to: SIMD2(0,0), surfaceID: second.id)
        #expect(session.project == before && session.hasUserChanges)
    }
    @Test func deleteStaleEventsAndEmptyResetAreSafe() {
        let session = EditorSession(); session.addSurface()
        let deleted = session.selectedSurfaceID!
        session.selectCorner(.topRight); session.toggleGrouping(deleted); session.deleteSurface(deleted)
        #expect(session.selectedCorner == nil && session.selectedSurface != nil && !session.groupingSelection.contains(deleted))
        let before = session.project
        session.moveSelectedCorner(to: .zero, surfaceID: deleted)
        session.renameSurface(deleted, "Stale"); session.selectSurface(deleted)
        #expect(session.project == before)
        session.deleteSurface(session.selectedSurfaceID!)
        #expect(session.project.surfaces.isEmpty && session.scene.surfaces.isEmpty && session.selectedSurface == nil)
        #expect(session.hasUserChanges)
        session.resetProject()
        #expect(session.project.surfaces.count == 1 && session.selectedSurface != nil && !session.hasUserChanges)
    }
    @Test func surfaceOrderAndVisibilityArePersistentButSelectionIsNot() {
        let session = EditorSession(); session.addSurface()
        let a = session.project.surfaces[0].id, b = session.project.surfaces[1].id
        let before = session.project
        session.selectSurface(b); session.selectCorner(.bottomLeft); session.toggleGrouping(a)
        #expect(session.project == before)
        session.moveSurface(a, offset: 1)
        #expect(session.project.surfaces.map(\.id) == [b,a])
        session.setVisible(false, faceID: b)
        #expect(session.scene.surfaces.count == 1 && !session.project.surfaces[0].layout.isVisible)
        session.selectSurface(b); session.setVisible(true, faceID: b)
        #expect(session.scene.surfaces.count == 2)
    }
    @Test func groupedSourcesMapsAndTagsRemainSeparateFromOutputGeometry() throws {
        let session = EditorSession(); session.addSurface(); session.addSurface()
        let originals = session.project.surfaces
        session.createObject(faceIDs: Set(originals.map(\.id)))
        let object = try #require(session.selectedObject)
        #expect(session.project.surfaces.map(\.corners) == originals.map(\.corners))
        #expect(session.project.surfaces.allSatisfy { $0.layout.objectID == object.id })
        #expect(object.links.count == 2 && session.project.joinWarnings.isEmpty)
        session.setSurfaceContent(.solid); session.setSourceColor(SIMD4(0,1,0,1))
        #expect(session.scene.surfaces.allSatisfy { $0.content == .solid && $0.color == SIMD4(0,1,0,1) })
        #expect(session.project.surfaces.map(\.source) == originals.map(\.source))
        session.setTags("windows", objectID: object.id); session.selectTag("windows")
        #expect(session.groupingSelection == Set(originals.map(\.id)))
        session.setObjectMode(.repeatContent, id: object.id)
        #expect(session.scene.surfaces.allSatisfy { $0.inputMap == .full })
        session.setObjectMode(.continuous, id: object.id)
        #expect(session.scene.surfaces.allSatisfy { $0.inputMap.size.x < 1 })
    }
    @Test func objectVisibilityDoesNotEraseFaceVisibilityAndDetachPreservesAppearance() throws {
        let session = EditorSession(); session.addSurface()
        session.createObject(faceIDs: Set(session.project.surfaces.map(\.id)))
        let object = try #require(session.selectedObject), a = session.project.surfaces[0].id, b = session.project.surfaces[1].id
        session.setVisible(false, faceID: a); session.setVisible(false, objectID: object.id)
        #expect(session.scene.surfaces.isEmpty)
        session.setVisible(true, objectID: object.id)
        #expect(session.scene.surfaces.count == 1 && !session.project.surfaces[0].layout.isVisible)
        let originalMap = session.project.surfaces[1].layout.inputMap
        session.detachSurface(b)
        let detached = try #require(session.project.surfaces.first { $0.id == b })
        #expect(detached.layout.objectID == nil && detached.layout.inputMap == originalMap)
        #expect(detached.source.id != object.source.id)
        #expect(session.scene.surfaces.first?.inputMap == originalMap)
        session.selectSurface(b); session.setSurfaceContent(.solid)
        #expect(session.project.objects[0].source.content == .diagnosticGrid)
    }
    @Test func repeatDetachUsesWholeCanvasAndUngroupCleansReferences() throws {
        let session = EditorSession(); session.addSurface()
        session.createObject(faceIDs: Set(session.project.surfaces.map(\.id)))
        let id = try #require(session.selectedObjectID)
        session.setObjectMode(.repeatContent, id: id); session.ungroupObject(id)
        #expect(session.project.objects.isEmpty)
        #expect(session.project.surfaces.allSatisfy { $0.layout.objectID == nil && $0.layout.inputMap == .full })
        #expect(Set(session.project.surfaces.map { $0.source.id }).count == 2)
    }
    @Test func memberAndObjectDuplicationRewriteOnlyRequiredReferences() throws {
        let session = EditorSession(); session.addSurface()
        session.createObject(faceIDs: Set(session.project.surfaces.map(\.id)))
        let original = try #require(session.selectedObject)
        let member = session.project.surfaces[0]
        session.duplicateSurface(member.id)
        let duplicate = try #require(session.selectedSurface)
        #expect(duplicate.id != member.id && duplicate.layout == member.layout)
        #expect(session.project.source(for: duplicate).id == original.source.id)
        session.deleteSurface(duplicate.id)
        session.duplicateObject(original.id)
        let copy = try #require(session.selectedObject)
        let copyMembers = session.project.surfaces.filter { $0.layout.objectID == copy.id }
        #expect(copy.id != original.id && copy.source.id != original.source.id && copyMembers.count == 2)
        #expect(copy.links.allSatisfy { link in copyMembers.contains { $0.id == link.firstFace } && copyMembers.contains { $0.id == link.secondFace } })
        #expect(session.project.joinWarnings.isEmpty)
        session.setSurfaceContent(.solid)
        #expect(session.project.objects.first { $0.id == original.id }?.source.content == .diagnosticGrid)
        session.deleteObject(copy.id)
        #expect(session.project.objects.count == 1 && session.project.surfaces.count == 2)
    }
    @Test func deletingMembersAndReattachingRemoveStaleLinksAndEmptyObjects() throws {
        let session = EditorSession(); session.addSurface(); session.addSurface()
        let ids = session.project.surfaces.map(\.id)
        session.createObject(faceIDs: Set(ids.prefix(2))); let first = try #require(session.selectedObjectID)
        session.createObject(faceIDs: [ids[2]]); let second = try #require(session.selectedObjectID)
        session.attachSurface(ids[0], to: second)
        #expect(session.project.objects.first { $0.id == first }?.links.isEmpty == true)
        session.deleteSurface(ids[1])
        #expect(!session.project.objects.contains { $0.id == first })
        session.deleteSurface(ids[0]); session.deleteSurface(ids[2])
        #expect(session.project.objects.isEmpty && session.project.surfaces.isEmpty)
    }
    @Test func inputMapsRejectInvalidValuesAndDoNotMutateOutputCorners() {
        let session = EditorSession(); let face = session.project.surfaces[0]
        for map in [FaceInputMap(origin: SIMD2(.nan,0)),FaceInputMap(size: SIMD2(0,1)),FaceInputMap(origin: SIMD2(0.8,0),size: SIMD2(0.5,1)),FaceInputMap(quarterTurns: 4)] {
            session.setInputMap(map, faceID: face.id)
            #expect(session.project.surfaces[0] == face)
        }
        let map = FaceInputMap(origin: SIMD2(0.1,0.2),size: SIMD2(0.4,0.5),quarterTurns: 1,mirrored: true)
        session.setInputMap(map, faceID: face.id)
        #expect(session.project.surfaces[0].corners == face.corners && session.scene.surfaces[0].inputMap == map)
        let projected = map.matrix * SIMD3<Float>(0.3,0.7,1)
        #expect(simd_length(map.sample(SIMD2(0.3,0.7)) - SIMD2(projected.x,projected.y)) < 0.00001)
    }
    @Test func edgeAlignmentHandlesReversalRotationAndScaleWithoutMovingOutput() throws {
        let session = EditorSession(); session.addSurface()
        session.createObject(faceIDs: Set(session.project.surfaces.map(\.id)))
        let object = try #require(session.selectedObject), faces = session.project.surfaces
        session.removeLink(object.links[0].id, objectID: object.id)
        var map = faces[1].layout.inputMap; map.size.y = 0.5; map.quarterTurns = 2
        session.setInputMap(map, faceID: faces[1].id)
        let link = FaceEdgeLink(firstFace: faces[0].id,firstEdge: .right,secondFace: faces[1].id,secondEdge: .left)
        session.addLink(link,objectID: object.id)
        #expect(!session.project.joinWarnings.isEmpty)
        session.removeLink(link.id,objectID: object.id)
        session.addLink(link,objectID: object.id,align: true)
        #expect(session.project.joinWarnings.isEmpty && session.project.objects[0].links.count == 1)
        #expect(session.project.surfaces.map(\.corners) == faces.map(\.corners))
        let aligned = session.project
        session.addLink(link,objectID: object.id,align: true)
        #expect(session.project == aligned && session.editMessage != nil)
        session.removeLink(link.id,objectID: object.id)
        var seam = link; seam.id = UUID(); seam.isSeam = true
        session.addLink(seam,objectID: object.id)
        #expect(session.project.joinWarnings.isEmpty && session.project.joinMessage(seam,objectID: object.id) == "Deliberate seam")
    }
    @Test func impossibleAlignmentAndInvalidLinksLeaveProjectUnchanged() throws {
        let session = EditorSession(); session.addSurface()
        session.createObject(faceIDs: Set(session.project.surfaces.map(\.id)))
        let object = try #require(session.selectedObject), a = session.project.surfaces[0], b = session.project.surfaces[1]
        session.removeLink(object.links[0].id,objectID: object.id)
        session.setInputMap(.full,faceID: a.id); session.setInputMap(.full,faceID: b.id)
        let before = session.project
        session.addLink(FaceEdgeLink(firstFace: a.id,firstEdge: .right,secondFace: b.id,secondEdge: .left),objectID: object.id,align: true)
        #expect(session.project == before && session.editMessage != nil)
        session.addLink(FaceEdgeLink(firstFace: UUID(),firstEdge: .right,secondFace: b.id,secondEdge: .left),objectID: object.id)
        #expect(session.project == before)
    }
    @Test func standaloneDuplicatesHaveIndependentContentAndUniqueNames() throws {
        let session = EditorSession(); let first = session.project.surfaces[0]
        session.duplicateSurface(first.id); let duplicate = try #require(session.selectedSurface)
        #expect(duplicate.source.id != first.source.id && duplicate.id != first.id)
        session.setSurfaceContent(.solid); session.setSourceColor(SIMD4(0,0,1,1))
        #expect(session.project.surfaces[1] == first)
        session.duplicateSurface(first.id)
        #expect(Set(session.project.surfaces.map(\.name)).count == 3)
        session.renameSurface(first.id, "   ")
        #expect(session.project.surfaces.first { $0.id == first.id }?.name == first.name)
    }
    @Test func everyEdgeDirectionCanAlignAndInputMatricesMatchAllOrientations() throws {
        let object = MappingObject(name: "Box", source: SurfaceSource())
        var a = MappingSurface(), b = MappingSurface()
        a.layout.objectID = object.id; b.layout.objectID = object.id
        a.layout.inputMap = FaceInputMap(size: SIMD2(0.5,1))
        b.layout.inputMap = FaceInputMap(origin: SIMD2(0.5,0),size: SIMD2(0.5,1))
        for edge in FaceEdge.allCases {
            for reversed in [false,true] {
                let link = FaceEdgeLink(firstFace: a.id,firstEdge: .right,secondFace: b.id,secondEdge: edge,reversed: reversed)
                let aligned = try #require(EditorSession.alignedMap(first: a.layout.inputMap,second: b.layout.inputMap,link: link))
                b.layout.inputMap = aligned
                var project = MappingProject(surface: a); project.surfaces = [a,b]; project.objects = [object]
                #expect(project.joinMessage(link,objectID: object.id) == nil)
            }
        }
        for turn in 0..<4 {
            for mirror in [false,true] {
                let map = FaceInputMap(origin: SIMD2(0.1,0.2),size: SIMD2(0.4,0.5),quarterTurns: turn,mirrored: mirror)
                for point in [SIMD2<Float>(0,0),SIMD2(1,1),SIMD2(0.25,0.75)] {
                    let value = map.matrix * SIMD3(point.x,point.y,1)
                    #expect(simd_length(map.sample(point) - SIMD2(value.x,value.y)) < 0.00001)
                }
            }
        }
    }
    @Test func presetsReopenAndResetPreserveFullCollection() throws {
        let session = EditorSession(presentOutput: { _ in }); session.addSurface()
        session.createObject(faceIDs: Set(session.project.surfaces.map(\.id)))
        let before = session.project
        defer { session.testOutput.close() }
        for resolution in TestResolution.allCases {
            session.setTestResolution(resolution); session.testOutput.open(for: .testWindow,resolution: resolution)
            let renderer = try #require((session.testOutput.window?.contentView as? TestOutputView)?.metalView?.delegate as? MetalRenderer)
            #expect(renderer.scene == session.scene && session.project == before)
            session.testOutput.close()
        }
        session.resetProject()
        #expect(session.project.objects.isEmpty && session.project.surfaces.count == 1 && !session.hasUserChanges)
    }
}

@MainActor
struct AppearanceControlsTests {
    func session() -> EditorSession {
        let defaults = UserDefaults(suiteName: "v111.tests." + UUID().uuidString)!
        return EditorSession(output: OutputSelectionState(preferences: OutputPreferences(defaults: defaults)))
    }
    func altered() -> SurfaceAppearance {
        SurfaceAppearance(opacity: 0.4,brightness: 1.5,crop: ContentCrop(origin: SIMD2(0.1,0.2),size: SIMD2(0.7,0.6)),flipHorizontal: true,flipVertical: true)
    }
    @Test func controlsValidateBoundsAndLeaveGeometryContentAndClocksUntouched() throws {
        let s = session(), id = s.project.surfaces[0].id, before = s.project
        s.setPlaying(true,at: 10); s.seekPlayback(to: 4,at: 10); let clock = s.transport
        let value = altered(); s.setAppearance(value,faceID: id)
        #expect(s.hasUserChanges && s.project.surfaces[0].appearance == value)
        #expect(s.project.surfaces[0].layout == before.surfaces[0].layout && s.selectedSource == before.surfaces[0].source && s.transport == clock)
        let changed = s.project
        for invalid in [Float.nan,Float.infinity,-0.1,1.1] { var bad = value; bad.opacity = invalid; s.setAppearance(bad,faceID: id); #expect(s.project == changed) }
        for invalid in [Float.nan,-0.1,2.1] { var bad = value; bad.brightness = invalid; s.setAppearance(bad,faceID: id); #expect(s.project == changed) }
        for invalid in [Float.nan,0,-1,2] { var bad = value; bad.crop.size.x = invalid; s.setAppearance(bad,faceID: id); #expect(s.project == changed) }
        s.setAppearance(.defaults,faceID: id); #expect(!s.hasUserChanges)
    }
    @Test func objectInheritanceOverridesAndReturningToInheritanceAreExplicit() throws {
        let s = session(); s.addSurface(); s.createObject(faceIDs: Set(s.project.surfaces.map(\.id)))
        let object = try #require(s.selectedObject), face = s.project.surfaces[0], value = altered()
        s.setAppearance(value,objectID: object.id)
        #expect(s.scene.surfaces.allSatisfy { $0.appearance == value })
        let original = s.project
        s.setAppearance(.defaults,faceID: face.id); #expect(s.project == original)
        s.setAppearanceOverride(true,faceID: face.id)
        #expect(s.project.surfaces[0].appearanceOverride == value && s.scene == original.renderScene)
        var override = value; override.brightness = 0.2; s.setAppearance(override,faceID: face.id)
        var shared = value; shared.opacity = 0.8; s.setAppearance(shared,objectID: object.id)
        #expect(s.project.appearance(for: s.project.surfaces[0]) == override)
        #expect(s.project.appearance(for: s.project.surfaces[1]) == shared)
        #expect(!s.project.joinWarnings.isEmpty)
        s.setAppearanceOverride(false,faceID: face.id)
        #expect(s.scene.surfaces.allSatisfy { $0.appearance == shared } && s.project.joinWarnings.isEmpty)
    }
    @Test func detachDuplicateUngroupAndAttachPreserveDefinedAppearanceScope() throws {
        let s = session(); s.addSurface(); let value = altered()
        s.setAppearance(value,faceID: s.selectedSurfaceID); s.createObject(faceIDs: Set(s.project.surfaces.map(\.id)))
        let object = try #require(s.selectedObject)
        #expect(object.appearance == value && s.project.surfaces.allSatisfy { $0.appearanceOverride == nil })
        let face = s.project.surfaces[0]; s.setAppearanceOverride(true,faceID: face.id)
        var custom = value; custom.flipHorizontal = false; s.setAppearance(custom,faceID: face.id)
        s.duplicateObject(object.id); let duplicate = try #require(s.selectedObject)
        #expect(duplicate.appearance == value)
        #expect(s.project.surfaces.contains { $0.layout.objectID == duplicate.id && $0.appearanceOverride == custom })
        s.detachSurface(face.id); let detached = try #require(s.project.surfaces.first { $0.id == face.id })
        #expect(detached.appearance == custom && detached.appearanceOverride == nil && detached.layout.inputMap == face.layout.inputMap)
        s.attachSurface(face.id,to: duplicate.id)
        #expect(s.project.appearance(for: s.project.surfaces.first { $0.id == face.id }!) == value)
        s.ungroupObject(duplicate.id)
        #expect(s.project.surfaces.filter { $0.layout.objectID == nil }.allSatisfy { $0.appearanceOverride == nil })
    }
    @Test func cropFlipMatrixSamplesSelectedRegionAndPreservesSharedBoundaries() {
        let value = altered(), p0 = value.matrix * SIMD3<Float>(0,0,1), p1 = value.matrix * SIMD3<Float>(1,1,1)
        #expect(abs(p0.x - 0.8) < 0.00001 && abs(p0.y - 0.8) < 0.00001)
        #expect(abs(p1.x - 0.1) < 0.00001 && abs(p1.y - 0.2) < 0.00001)
        let left = FaceInputMap(size: SIMD2(0.5,1)), right = FaceInputMap(origin: SIMD2(0.5,0),size: SIMD2(0.5,1))
        let a = value.matrix * left.matrix * SIMD3<Float>(1,0.3,1), b = value.matrix * right.matrix * SIMD3<Float>(0,0.3,1)
        #expect(simd_length(a-b) < 0.00001)
    }
    @Test func legacySchemaTwoMigratesDefaultsAndSchemaThreeRejectsBadAppearance() throws {
        let s = session(); s.addSurface(); s.createObject(faceIDs: Set(s.project.surfaces.map(\.id)))
        let original = s.document
        var json = try #require(JSONSerialization.jsonObject(with: ProjectCodec.encode(original)) as? [String:Any])
        json["formatVersion"] = 2
        var project = try #require(json["project"] as? [String:Any])
        for key in ["surfaces","objects"] {
            project[key] = (project[key] as! [[String:Any]]).map { item in var item = item; item.removeValue(forKey: "appearance"); item.removeValue(forKey: "appearanceOverride"); return item }
        }
        json["project"] = project
        let restored = try ProjectCodec.decode(JSONSerialization.data(withJSONObject: json))
        #expect(restored.project == original.project && restored.formatVersion == ProjectDocument.currentVersion)
        var bad = original; bad.project.objects[0].appearance.brightness = 3
        #expect(throws: ProjectFileError.self) { try ProjectCodec.encode(bad) }
        bad = original; bad.project.surfaces[0].appearance.crop.size.y = 0
        #expect(throws: ProjectFileError.self) { try ProjectCodec.encode(bad) }
    }
    @Test func appearanceRoundTripsThroughSaveBaselineAndRecoveryWithoutLosingPresets() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: dir,withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        let s = session(); s.addSurface(); s.createObject(faceIDs: Set(s.project.surfaces.map(\.id))); s.setSurfaceContent(.particles)
        _ = s.saveGeneratorPreset(name: "Snow"); s.setAppearance(altered(),objectID: s.selectedObjectID)
        s.setAppearanceOverride(true,faceID: s.project.surfaces[0].id)
        let url = dir.appendingPathComponent("House.projectionmap"); try s.save(to: url)
        #expect(!s.hasUserChanges)
        let loaded = session(); try loaded.load(ProjectPackageStore().read(url),from: url)
        #expect(loaded.project == s.project && !loaded.hasUserChanges && !loaded.transport.isPlaying)
        let recovery = ProjectRecoveryStore(directory: dir.appendingPathComponent("recovery")); s.configureRecovery(recovery)
        var edited = altered(); edited.opacity = 0.9; s.setAppearance(edited,objectID: s.project.objects[0].id); try s.flushRecovery()
        let entry = try #require(recovery.entries().first)
        #expect(entry.document.project.objects[0].appearance == edited && entry.document.project.generatorPresets == loaded.project.generatorPresets)
        s.clearRecovery()
    }
}

@MainActor
struct EditingProtectionTests {
    func session() -> EditorSession {
        EditorSession(presentOutput: { _ in },output: OutputSelectionState(preferences: OutputPreferences(defaults: UserDefaults(suiteName: "v1112.tests." + UUID().uuidString)!)))
    }
    func grouped() -> EditorSession {
        let s = session(); let first = s.project.surfaces[0].id
        s.selectCorner(.topLeft); s.moveSelectedCorner(to: SIMD2(0.1,0.15),surfaceID: first)
        s.addSurface(); s.createObject(faceIDs: Set(s.project.surfaces.map(\.id)))
        s.setSurfaceContent(.particles); var generator = GeneratorSettings.defaults; generator.seed = 97; s.setGeneratorSettings(generator)
        s.setPlaying(true,at: 10); s.seekPlayback(to: 3,at: 10); s.setSelectedPaused(true,at: 10)
        return s
    }
    @Test func locksBlockGeometryResetAndDeletionButAllowSelectionAndContent() {
        let s = session(), id = s.project.surfaces[0].id
        s.selectCorner(.topLeft); s.moveSelectedCorner(to: SIMD2(0.1,0.1),surfaceID: id)
        s.setGeometryLocked(true,faceID: id); let locked = s.project
        s.moveSelectedCorner(to: SIMD2(0.4,0.4),surfaceID: id); s.nudgeSelectedCorner(direction: SIMD2(1,0),larger: true)
        s.resetFace(id,scope: .outputGeometry); s.resetFace(id,scope: .fullFace); s.deleteSurface(id)
        #expect(s.project == locked)
        s.selectSurface(at: SIMD2(0.5,0.5)); #expect(s.selectedSurfaceID == id)
        s.setSurfaceContent(.noise); var appearance = SurfaceAppearance.defaults; appearance.brightness = 0.5
        s.setAppearance(appearance,faceID: id)
        #expect(s.project.surfaces[0].corners == locked.surfaces[0].corners && s.selectedSource?.content == .noise)
        s.setGeometryLocked(false,faceID: id); s.resetFace(id,scope: .outputGeometry)
        #expect(s.project.surfaces[0].corners == .diagnostic)
    }
    @Test func objectLocksPreserveIndividualLocksAndBlockWholeTransactions() throws {
        let s = grouped(), id = try #require(s.selectedObjectID), face = s.project.surfaces[0].id
        s.setGeometryLocked(true,faceID: face); s.setGeometryLocked(true,objectID: id)
        let locked = s.project; s.moveObject(id,by: SIMD2(0.05,0.05)); s.deleteObject(id)
        #expect(s.project == locked && !s.project.canMoveObject(id))
        s.setGeometryLocked(false,objectID: id)
        #expect(s.project.surfaces[0].layout.isGeometryLocked && !s.project.surfaces[1].layout.isGeometryLocked)
        let stillLocked = s.project; s.moveObject(id,by: SIMD2(0.05,0)); #expect(s.project == stillLocked)
        s.setGeometryLocked(false,faceID: face); #expect(s.project.canMoveObject(id))
        s.moveObject(id,by: SIMD2(0.05,0)); #expect(s.project != stillLocked)
    }
    @Test func boundedMovementAppliesOneOffsetAndPreservesOwnershipInputAndPlayback() throws {
        let s = grouped(), id = try #require(s.selectedObjectID), before = s.project, clock = s.transport, phases = s.sourcePlayback
        let changed = Date(timeIntervalSince1970: 700)
        s.moveObject(id,by: SIMD2(100,-100),now: changed)
        let bounds = try #require(s.project.outputBounds(forObject: id))
        #expect(abs(bounds.bottomRight.x-1) < 0.000001 && abs(bounds.topLeft.y) < 0.000001)
        let delta = s.project.surfaces[0].corners.topLeft - before.surfaces[0].corners.topLeft
        for (old,new) in zip(before.surfaces,s.project.surfaces) {
            for corner in SurfaceCorner.allCases { #expect(simd_length((new.corners[corner]-old.corners[corner])-delta) < 0.000001) }
            #expect(new.layout.inputMap == old.layout.inputMap && new.layout.objectID == old.layout.objectID && new.source == old.source)
        }
        #expect(s.project.objects == before.objects && s.project.modifiedAt == changed && s.transport == clock && s.sourcePlayback == phases)
        #expect(s.testOutput.scene == s.scene)
        let stopped = s.project; s.moveObject(id,by: SIMD2(100,-100),now: .distantFuture); s.moveObject(id,by: SIMD2(.nan,0)); s.moveObject(UUID(),by: SIMD2(0.1,0.1))
        #expect(s.project == stopped)
    }
    @Test func resetScopesPreserveUnrelatedFaceValuesAndClocks() {
        let s = session(), id = s.project.surfaces[0].id
        s.setSurfaceContent(.particles); var generator = GeneratorSettings.defaults; generator.seed = 77; s.setGeneratorSettings(generator)
        s.setSelectedPaused(true,at: 10); let clock = s.selectedPlayback
        var appearance = SurfaceAppearance.defaults; appearance.opacity = 0.4; appearance.brightness = 1.5; appearance.crop.size = SIMD2(0.5,0.5); appearance.flipHorizontal = true
        s.setAppearance(appearance,faceID: id); s.selectCorner(.topLeft); s.moveSelectedCorner(to: SIMD2(0.1,0.1),surfaceID: id)
        let layout = s.project.surfaces[0].layout, owner = s.selectedSource!.id
        s.resetFace(id,scope: .appearance)
        #expect(s.project.surfaces[0].appearance.opacity == 1 && s.project.surfaces[0].appearance.crop == appearance.crop)
        #expect(s.selectedSource?.generator == generator && s.project.surfaces[0].layout == layout)
        s.resetFace(id,scope: .cropAndFlip); #expect(s.project.surfaces[0].appearance == .defaults)
        s.resetFace(id,scope: .generatorParameters)
        #expect(s.selectedSource?.content == .particles && s.selectedSource?.id == owner && s.selectedPlayback == clock)
        s.resetFace(id,scope: .content)
        #expect(s.selectedSource?.content == .diagnosticGrid && s.selectedSource?.id == owner && s.project.surfaces[0].layout == layout && s.selectedPlayback == clock)
    }
    @Test func groupedFaceFullResetPreservesSharedContentMapsLinksAndOtherFaces() throws {
        let s = grouped(), id = s.project.surfaces[0].id
        s.setAppearanceOverride(true,faceID: id); var custom = SurfaceAppearance.defaults; custom.opacity = 0.5; s.setAppearance(custom,faceID: id)
        s.setVisible(false,faceID: id); s.selectSurface(id); s.selectCorner(.topLeft); s.moveSelectedCorner(to: SIMD2(0.2,0.3),surfaceID: id)
        let before = s.project, phases = s.sourcePlayback
        s.resetFace(id,scope: .content); #expect(s.project == before)
        s.resetFace(id,scope: .fullFace)
        let face = try #require(s.project.surfaces.first { $0.id == id }), original = before.surfaces[0]
        #expect(face.corners == .diagnostic && face.layout.isVisible && face.appearanceOverride == nil)
        #expect(face.id == original.id && face.name == original.name && face.tags == original.tags && face.source == original.source)
        #expect(face.layout.inputMap == original.layout.inputMap && face.layout.objectID == original.layout.objectID)
        #expect(s.project.objects == before.objects && s.project.surfaces[1] == before.surfaces[1] && s.sourcePlayback == phases)
    }
    @Test func sharedResetsKeepOverridesAndOnlyExplicitInputLayoutResetChangesMaps() throws {
        let s = grouped(), id = try #require(s.selectedObjectID), member = s.project.surfaces[0].id
        var shared = SurfaceAppearance.defaults; shared.brightness = 0.4; shared.crop.size = SIMD2(0.5,0.5); s.setAppearance(shared,objectID: id)
        s.setAppearanceOverride(true,faceID: member)
        var map = s.project.surfaces[0].layout.inputMap; map.quarterTurns = 2; s.setInputMap(map,faceID: member)
        let before = s.project, phases = s.sourcePlayback
        s.resetObject(id,scope: .appearance); s.resetObject(id,scope: .generatorParameters)
        #expect(s.project.surfaces == before.surfaces && s.project.objects[0].links == before.objects[0].links)
        #expect(s.project.objects[0].appearance.crop == shared.crop && s.project.objects[0].source.content == .particles)
        s.resetObject(id,scope: .inputLayout)
        #expect(s.project.surfaces[0].layout.inputMap.quarterTurns == 0 && s.project.objects[0].links == before.objects[0].links)
        #expect(s.project.surfaces.map(\.corners) == before.surfaces.map(\.corners) && s.sourcePlayback == phases)
        let sourceID = s.project.objects[0].source.id; s.resetObject(id,scope: .content)
        #expect(s.project.objects[0].source.id == sourceID && s.project.objects[0].source.content == .diagnosticGrid)
    }
    @Test func duplicatesAndDetachRetainEffectiveLocks() throws {
        let s = grouped(), id = try #require(s.selectedObjectID)
        s.setGeometryLocked(true,objectID: id); s.duplicateObject(id)
        let copy = try #require(s.selectedObject); #expect(copy.isGeometryLocked)
        let member = try #require(s.project.surfaces.first { $0.layout.objectID == id })
        s.detachSurface(member.id)
        let detached = try #require(s.project.surfaces.first { $0.id == member.id })
        #expect(detached.layout.isGeometryLocked && detached.layout.objectID == nil)
        s.duplicateSurface(detached.id); #expect(s.selectedSurface?.layout.isGeometryLocked == true)
    }
    @Test func standaloneFullResetPreservesIdentityTagsInputMapsOtherFacesAndPhase() {
        let s = session(), id = s.project.surfaces[0].id
        s.renameSurface(id,"Roof"); s.setTags("house, upper",faceID: id)
        s.setSurfaceContent(.noise); s.setSelectedPaused(true,at: 10)
        s.setInputMap(FaceInputMap(origin: SIMD2(0.1,0.2),size: SIMD2(0.7,0.6),quarterTurns: 2),faceID: id)
        var appearance = SurfaceAppearance.defaults; appearance.opacity = 0.3; appearance.flipVertical = true; s.setAppearance(appearance,faceID: id)
        s.selectCorner(.topLeft); s.moveSelectedCorner(to: SIMD2(0.1,0.1),surfaceID: id); s.setVisible(false,faceID: id)
        let original = s.project.surfaces[0], phase = s.sourcePlayback
        s.addSurface(); let other = s.project.surfaces[0]
        s.resetFace(id,scope: .fullFace)
        let reset = s.project.surfaces[1]
        #expect(reset.id == id && reset.name == original.name && reset.tags == original.tags && reset.source.id == original.source.id)
        #expect(reset.corners == .diagnostic && reset.content == .diagnosticGrid && reset.appearance == .defaults && reset.layout.isVisible)
        #expect(reset.layout.inputMap == original.layout.inputMap && reset.layout.objectID == original.layout.objectID && s.project.surfaces[0] == other)
        #expect(s.sourcePlayback == phase)
        let cleanReset = s.project; s.resetFace(id,scope: .fullFace); s.resetFace(UUID(),scope: .content); s.resetObject(UUID(),scope: .content)
        #expect(s.project == cleanReset)
    }
    @Test func legacyLocksMigrationSaveRecoveryAndBaselineAreConsistent() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: dir,withIntermediateDirectories: true); defer { try? FileManager.default.removeItem(at: dir) }
        let s = grouped(), id = try #require(s.selectedObjectID)
        var json = try #require(JSONSerialization.jsonObject(with: ProjectCodec.encode(s.document)) as? [String:Any]); json["formatVersion"] = 3
        var project = json["project"] as! [String:Any]
        project["objects"] = (project["objects"] as! [[String:Any]]).map { item in var item = item; item.removeValue(forKey: "isGeometryLocked"); return item }
        project["surfaces"] = (project["surfaces"] as! [[String:Any]]).map { item in var item = item; var layout = item["layout"] as! [String:Any]; layout.removeValue(forKey: "isGeometryLocked"); item["layout"] = layout; return item }; json["project"] = project
        #expect(try ProjectCodec.decode(JSONSerialization.data(withJSONObject: json)).project == s.project)
        let url = dir.appendingPathComponent("House.projectionmap"); try s.save(to: url)
        s.setGeometryLocked(true,objectID: id); #expect(s.hasUserChanges)
        let recovery = ProjectRecoveryStore(directory: dir.appendingPathComponent("recovery")); s.configureRecovery(recovery); try s.flushRecovery()
        #expect(recovery.entries().first?.document.project.objects[0].isGeometryLocked == true)
        s.setGeometryLocked(false,objectID: id); #expect(!s.hasUserChanges)
        s.setGeometryLocked(true,objectID: id); try s.save(to: url)
        let loaded = session(); try loaded.load(ProjectPackageStore().read(url),from: url)
        #expect(!loaded.hasUserChanges && !loaded.project.canMoveObject(id) && recovery.entries().isEmpty)
    }
}

@MainActor
struct MultipleSurfaceGPUTests {
    private func rect(_ x: Float, _ width: Float) -> NormalizedRectangle {
        NormalizedRectangle(topLeft: SIMD2(x,0),topRight: SIMD2(x+width,0),bottomRight: SIMD2(x+width,1),bottomLeft: SIMD2(x,1))
    }
    @Test func savedJoinedAnimationsReproduceGPUFramesAfterPausedReload() throws {
        let defaults = UserDefaults(suiteName: "v110.gpu." + UUID().uuidString)!
        let session = EditorSession(presentOutput: { _ in },output: OutputSelectionState(preferences: OutputPreferences(defaults: defaults)))
        session.addSurface(); session.createObject(faceIDs: Set(session.project.surfaces.map(\.id)))
        let faces = session.project.surfaces
        session.selectSurface(faces[0].id); for corner in SurfaceCorner.allCases { session.selectCorner(corner); session.moveSelectedCorner(to: rect(0,0.5)[corner],surfaceID: faces[0].id) }
        session.selectSurface(faces[1].id); for corner in SurfaceCorner.allCases { session.selectCorner(corner); session.moveSelectedCorner(to: rect(0.5,1)[corner],surfaceID: faces[1].id) }
        for content in [SurfaceContent.particles,.movingLines,.noise] {
            session.setSurfaceContent(content); session.seekPlayback(to: 0.37,at: 100)
            let before = try pixels(MetalRenderer(scene: session.scene))
            let doc = try ProjectCodec.decode(ProjectCodec.encode(session.document))
            try session.load(doc,from: URL(fileURLWithPath: "/tmp/replay.projectionmap"))
            #expect(!session.transport.isPlaying)
            session.seekPlayback(to: 0.37,at: 100)
            #expect(try pixels(MetalRenderer(scene: session.scene)) == before)
            #expect(try pixels(MetalRenderer(scene: session.testOutput.scene)) == before)
        }
    }
    @Test func opacityCompositesLayersAndZeroOpacityHasNoPixelsOrAnimationDemand() throws {
        let back = RenderSurface(geometry: rect(0,1),color: SIMD4(0,0,1,1))
        var front = RenderSurface(geometry: rect(0,1),color: SIMD4(1,0,0,0.5))
        front.appearance.opacity = 0.5
        let renderer = try MetalRenderer(scene: RenderScene(surfaces: [back,front]))
        var data = try pixels(renderer); let center = (64*128+64)*4
        #expect(abs(Int(data[center])-191) <= 1 && data[center+1] == 0 && abs(Int(data[center+2])-64) <= 1 && data[center+3] == 255)
        front.appearance.opacity = 0; renderer.setScene(RenderScene(surfaces: [back,front]))
        #expect(try pixels(renderer) == pixels(MetalRenderer(scene: RenderScene(surfaces: [back]))))
        var transport = AnimationTransport(); transport.setPlaying(true,at: 10); front.content = .particles
        #expect(!RenderScene(surfaces: [front],transport: transport).needsContinuousRendering)
        front.appearance.opacity = 0.5; front.content = .solid
        renderer.setScene(RenderScene(surfaces: [front,back])); data = try pixels(renderer)
        #expect(data[center] == 255 && data[center+2] == 0)
    }
    @Test func brightnessMultipliesEvaluatedContentAndClipsWithoutChangingAlpha() throws {
        var face = RenderSurface(geometry: rect(0,1),color: SIMD4(0.8,0.4,0.1,1))
        face.appearance.brightness = 2
        let renderer = try MetalRenderer(scene: RenderScene(surfaces: [face]))
        var data = try pixels(renderer); let center = (64*128+64)*4
        #expect(abs(Int(data[center])-51) <= 1 && abs(Int(data[center+1])-204) <= 1 && data[center+2] == 255 && data[center+3] == 255)
        face.appearance.brightness = 0; renderer.setScene(RenderScene(surfaces: [face])); data = try pixels(renderer)
        #expect(data[center] == 0 && data[center+1] == 0 && data[center+2] == 0 && data[center+3] == 255)
        for content in SurfaceContent.allCases {
            face.content = content; face.appearance.brightness = 1; renderer.setScene(RenderScene(surfaces: [face]))
            let original = try pixels(renderer,time: 0.37)
            face.appearance.brightness = 0.5; renderer.setScene(RenderScene(surfaces: [face])); let dimmed = try pixels(renderer,time: 0.37)
            #expect(original.indices.allSatisfy { i in i % 4 == 3 || abs(Int(dimmed[i])*2-Int(original[i])) <= 2 })
            #expect(stride(from: 3,to: original.count,by: 4).allSatisfy { dimmed[$0] == original[$0] })
        }
    }
    @Test func croppedFlippedGridAndGeneratorsMatchIndependentInputMapReference() throws {
        let crop = ContentCrop(origin: SIMD2(0.1,0.2),size: SIMD2(0.6,0.7))
        for content in [SurfaceContent.diagnosticGrid,.gradient,.particles] {
            for horizontal in [false,true] { for vertical in [false,true] {
                var face = RenderSurface(geometry: rect(0,1),color: SIMD4(1,0.2,0,1),content: content)
                face.appearance = SurfaceAppearance(crop: crop,flipHorizontal: horizontal,flipVertical: vertical)
                let actual = try pixels(MetalRenderer(scene: RenderScene(surfaces: [face])),time: 0.37)
                face.appearance = .defaults
                face.inputMap = FaceInputMap(origin: crop.origin,size: crop.size,quarterTurns: vertical ? 2 : 0,mirrored: horizontal != vertical)
                let reference = try pixels(MetalRenderer(scene: RenderScene(surfaces: [face])),time: 0.37)
                #expect(zip(actual,reference).allSatisfy { abs(Int($0)-Int($1)) <= 2 })
            } }
        }
    }
    @Test func sharedAppearancePreservesJoinedFramesAndPreviewOutputParity() throws {
        let appearance = SurfaceAppearance(opacity: 0.6,brightness: 1.3,crop: ContentCrop(origin: SIMD2(0.1,0.15),size: SIMD2(0.7,0.8)),flipHorizontal: true,flipVertical: true)
        for content in SurfaceContent.allCases {
            let full = RenderSurface(geometry: rect(0,1),color: SIMD4(1,0.2,0,1),content: content,appearance: appearance)
            let whole = try pixels(MetalRenderer(scene: RenderScene(surfaces: [full])),time: 0.37)
            let pieces = (0..<3).map { i in RenderSurface(geometry: rect(Float(i)/3,1.0/3),color: full.color,content: content,inputMap: FaceInputMap(origin: SIMD2(Float(i)/3,0),size: SIMD2(1.0/3,1)),appearance: appearance) }
            let preview = try pixels(MetalRenderer(scene: RenderScene(surfaces: pieces)),time: 0.37)
            #expect(zip(whole,preview).allSatisfy { abs(Int($0)-Int($1)) <= 2 })
            #expect(try pixels(MetalRenderer(scene: RenderScene(surfaces: pieces)),time: 0.37) == preview)
        }
    }
    @Test func objectMovementAndGeometryResetReachMatchingLiveGPUViews() throws {
        let defaults = UserDefaults(suiteName: "v1112.gpu." + UUID().uuidString)!
        let s = EditorSession(presentOutput: { _ in },output: OutputSelectionState(preferences: OutputPreferences(defaults: defaults)))
        s.addSurface(); s.createObject(faceIDs: Set(s.project.surfaces.map(\.id))); s.setSurfaceContent(.particles); s.seekPlayback(to: 0.37,at: 100)
        let id = try #require(s.selectedObjectID), preview = try MetalRenderer(scene: s.scene), output = try MetalRenderer(scene: s.testOutput.scene)
        let original = try pixels(preview), texture = preview.diagnosticTexture
        s.moveObject(id,by: SIMD2(0.1,0.05)); preview.setScene(s.scene); output.setScene(s.testOutput.scene)
        let moved = try pixels(preview)
        let outputPixels = try pixels(output)
        #expect(moved != original && moved == outputPixels && preview.diagnosticTexture === texture)
        s.setGeometryLocked(true,objectID: id); let locked = s.project
        s.resetFace(s.project.surfaces[0].id,scope: .outputGeometry); s.moveObject(id,by: SIMD2(0.1,0))
        #expect(s.project == locked)
        s.setGeometryLocked(false,objectID: id); s.resetFace(s.project.surfaces[0].id,scope: .outputGeometry)
        preview.setScene(s.scene); output.setScene(s.testOutput.scene)
        #expect(try pixels(preview) == pixels(output) && preview.diagnosticTexture === texture)
    }
    private func pixels(_ renderer: MetalRenderer, size: Int = 128, time: Double? = nil) throws -> [UInt8] {
        let desc = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: MetalRenderer.pixelFormat,width: size,height: size,mipmapped: false)
        desc.storageMode = .shared; desc.usage = .renderTarget
        let texture = try #require(renderer.device.makeTexture(descriptor: desc))
        let pass = MTLRenderPassDescriptor(); pass.colorAttachments[0].texture = texture
        let command = try #require(renderer.encodeScene(to: pass, evaluationTime: time)); command.commit(); command.waitUntilCompleted()
        #expect(command.status == .completed && command.error == nil)
        var data = [UInt8](repeating: 0,count: size*size*4)
        data.withUnsafeMutableBytes { texture.getBytes($0.baseAddress!,bytesPerRow: size*4,from: MTLRegionMake2D(0,0,size,size),mipmapLevel: 0) }
        return data
    }
    @Test func simpleEffectsAreDeterministicAnimatedAndContinuousAcrossThreeFaces() throws {
        for content in [SurfaceContent.gradient, .movingLines, .movingCheckers, .plasma, .noise, .particles] {
            let whole = try MetalRenderer(scene: RenderScene(geometry: rect(0,1),color: SIMD4(1,0,0,1),content: content))
            let texture = whole.diagnosticTexture
            let zero = try pixels(whole,time: 0), moved = try pixels(whole,time: 0.37)
            #expect(zero != moved)
            #expect(try pixels(whole,time: 0) == zero)
            #expect(try pixels(whole,time: 8) == zero)
            #expect(try pixels(whole,time: 8.37) == moved)
            let slices = (0..<3).map { i in
                RenderSurface(geometry: rect(Float(i)/3,1.0/3), color: SIMD4(1,0,0,1),content: content,
                              inputMap: FaceInputMap(origin: SIMD2(Float(i)/3,0),size: SIMD2(1.0/3,1)))
            }
            let preview = try MetalRenderer(scene: RenderScene(surfaces: slices))
            let output = try MetalRenderer(scene: RenderScene(surfaces: slices))
            let joined = try pixels(preview,time: 0.37)
            #expect(zip(joined,moved).allSatisfy { abs(Int($0)-Int($1)) <= 2 })
            #expect(try pixels(output,time: 0.37) == joined)
            output.setScene(RenderScene(surfaces: slices.map { var face = $0; face.inputMap = .full; return face }))
            #expect(try pixels(output,time: 0.37) != joined)
            #expect(whole.diagnosticTexture === texture)
        }
    }
    @Test func actualSeekingReplaysEveryEffectAcrossLoopBoundariesAndPresets() throws {
        let session = EditorSession(presentOutput: { _ in })
        for content in [SurfaceContent.gradient,.movingLines,.movingCheckers,.plasma,.noise,.particles] {
            session.setSurfaceContent(content)
            var settings = GeneratorSettings.defaults; settings.rate = 1.5; settings.seed = 47; settings.density = 12
            session.setGeneratorSettings(settings)
            session.seekPlayback(to: 0.37,at: 100)
            let renderer = try MetalRenderer(scene: session.scene), reference = try pixels(renderer)
            let preset = try #require(session.saveGeneratorPreset(name: content.title))
            for time in [32.0, 5.32, 0.01, 16.0, 0.37] {
                session.seekPlayback(to: time,at: 100); renderer.setScene(session.scene); _ = try pixels(renderer)
            }
            #expect(try pixels(renderer) == reference)
            session.resetGeneratorSettings(); session.applyGeneratorPreset(preset); renderer.setScene(session.scene)
            #expect(try pixels(renderer) == reference)
            let output = try MetalRenderer(scene: session.testOutput.scene)
            #expect(try pixels(output) == reference)
        }
    }
    @Test func reversedFaceMapsKeepParticleContinuityAndScopedPauseFreezesOnlyOneOwner() throws {
        let source = SurfaceSource(content: .particles)
        let full = RenderSurface(geometry: rect(0,1),color: source.color,content: .particles)
        let whole = try MetalRenderer(scene: RenderScene(surfaces: [full]))
        let upsideDown = NormalizedRectangle(topLeft: SIMD2<Float>(0.5,1),topRight: SIMD2(1,1),bottomRight: SIMD2(1,0),bottomLeft: SIMD2(0.5,0))
        let pieces = [RenderSurface(geometry: rect(0,0.5),color: source.color,content: .particles,inputMap: FaceInputMap(size: SIMD2(0.5,1))),
                      RenderSurface(geometry: upsideDown,color: source.color,content: .particles,inputMap: FaceInputMap(origin: SIMD2(0.5,0),size: SIMD2(0.5,1),quarterTurns: 2,mirrored: true))]
        let joined = try MetalRenderer(scene: RenderScene(surfaces: pieces))
        let a = try pixels(whole,time: 0.37), b = try pixels(joined,time: 0.37)
        #expect(zip(a,b).allSatisfy { abs(Int($0)-Int($1)) <= 2 })
        var frozen = full; frozen.playback = SourcePlayback(frozenTime: 0.37)
        joined.setScene(RenderScene(surfaces: [frozen]))
        #expect(try pixels(joined,time: 999) == a)
        let texture = joined.diagnosticTexture
        for time in 0..<32 { _ = try pixels(joined,time: Double(time)); joined.setScene(RenderScene(surfaces: [frozen])) }
        #expect(joined.diagnosticTexture === texture)
        var left = RenderSurface(geometry: rect(0,0.5),color: source.color,content: .particles)
        left.playback = SourcePlayback(frozenTime: 0.37)
        let right = RenderSurface(geometry: rect(0.5,0.5),color: source.color,content: .plasma)
        let owners = RenderScene(surfaces: [left,right])
        joined.setScene(owners)
        let first = try pixels(joined,time: 0.37), later = try pixels(joined,time: 1.37)
        var rightChanged = false
        for y in 0..<128 { for x in 0..<128 {
            let i = (y*128+x)*4
            if x < 64 { #expect(Array(first[i..<i+4]) == Array(later[i..<i+4])) }
            else if Array(first[i..<i+4]) != Array(later[i..<i+4]) { rightChanged = true }
        } }
        #expect(rightChanged)
        let output = try MetalRenderer(scene: owners)
        #expect(try pixels(output,time: 1.37) == later)
    }
    @Test func seededEffectsSettingsAndExtremeParametersProduceRepeatableFrames() throws {
        for content in [SurfaceContent.noise, .particles] {
            var item = RenderSurface(geometry: rect(0,1),color: SIMD4(1,1,1,1),content: content)
            let renderer = try MetalRenderer(scene: RenderScene(surfaces: [item]))
            let first = try pixels(renderer,time: 0.7)
            item.generator.seed = 999999; renderer.setScene(RenderScene(surfaces: [item]))
            let other = try pixels(renderer,time: 0.7)
            #expect(first != other)
            #expect(try pixels(renderer,time: 0.7) == other)
            for direction in 0..<8 {
                item.generator.direction = direction; item.generator.density = 16; item.generator.particleSize = 0.35
                item.generator.rate = 4; item.generator.scale = 4
                renderer.setScene(RenderScene(surfaces: [item]))
                #expect(try pixels(renderer,time: 0.25) == pixels(renderer,time: 2.25))
            }
        }
        var item = RenderSurface(geometry: rect(0,1),color: SIMD4(1,0,0,1),content: .movingLines)
        let renderer = try MetalRenderer(scene: RenderScene(surfaces: [item]))
        let first = try pixels(renderer,time: 0.37)
        item.generator.scale = 2; item.generator.direction = 2; item.generator.rate = 2
        renderer.setScene(RenderScene(surfaces: [item]))
        #expect(try pixels(renderer,time: 0.37) != first)
        #expect(try pixels(renderer,time: 0.37) == pixels(renderer,time: 4.37))
    }
    @Test(.enabled(if: ProcessInfo.processInfo.environment["PROJECTION_MAPPER_EFFECT_PERFORMANCE_OUTPUT"] != nil))
    func mixedEffectsPerformanceMatrix() throws {
        let path = try #require(ProcessInfo.processInfo.environment["PROJECTION_MAPPER_EFFECT_PERFORMANCE_OUTPUT"])
        var rows: [[String:Any]] = []
        let effects: [SurfaceContent] = [.gradient,.movingLines,.movingCheckers,.plasma,.noise,.particles]
        let items = (0..<6).map { i in RenderSurface(geometry: rect(Float(i)/6,1.0/6),color: SIMD4(1,0.4,0.1,1),content: effects[i]) }
        let overlapping = (0..<8).map { index in
            var face = RenderSurface(geometry: rect(0,1),color: SIMD4(1,0.4,0.1,0.5),content: .particles)
            face.generator.density = 16; face.generator.seed = UInt32(index+1); return face
        }
        for (workload,faces) in [("sixMixedFaces",items),("eightOverlappingParticleFaces",overlapping)] {
        let scene = RenderScene(surfaces: faces)
        let preview = try MetalRenderer(scene: scene), output = try MetalRenderer(scene: scene)
        for resolution in TestResolution.allCases {
            let descriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: MetalRenderer.pixelFormat,
                width: Int(resolution.size.width),height: Int(resolution.size.height),mipmapped: false)
            descriptor.storageMode = .private; descriptor.usage = .renderTarget
            let texture = try #require(output.device.makeTexture(descriptor: descriptor))
            let pass = MTLRenderPassDescriptor(); pass.colorAttachments[0].texture = texture
            var times: [Double] = []
            for i in 0..<24 {
                var total: Double = 0
                for renderer in [preview,output] {
                    let command = try #require(renderer.encodeScene(to: pass,evaluationTime: Double(i)/60))
                    command.commit(); command.waitUntilCompleted()
                    #expect(command.status == .completed && command.error == nil)
                    if command.gpuEndTime > command.gpuStartTime { total += (command.gpuEndTime-command.gpuStartTime)*1000 }
                }
                if i >= 4 { times.append(total) }
            }
            times.sort()
            rows.append(["workload":workload,"resolution":resolution.dimensions,"surfacesPerView":faces.count,"views":2,"samples":times.count,
                         "gpuPairMedianMs":times[times.count/2],"gpuPairP95Ms":times[Int(Double(times.count-1)*0.95)]])
        }
        }
        try JSONSerialization.data(withJSONObject: rows,options:[.prettyPrinted,.sortedKeys]).write(to: URL(fileURLWithPath:path).appendingPathComponent("mixed-effects.json"))
    }
    @Test func pausedClockUsesOneExplicitPhaseForBothRenderersAndReopen() throws {
        let session = EditorSession(presentOutput: { _ in })
        session.setSurfaceContent(.movingCheckers); session.setPlaying(true,at: 100)
        session.setPlaying(false,at: 100.37)
        let preview = try MetalRenderer(scene: session.scene)
        session.testOutput.open(for: .testWindow)
        defer { session.testOutput.close() }
        var output = try #require((session.testOutput.window?.contentView as? TestOutputView)?.metalView?.delegate as? MetalRenderer)
        let paused = try pixels(preview)
        #expect(try pixels(output) == paused)
        session.testOutput.close(); session.testOutput.open(for: .testWindow)
        output = try #require((session.testOutput.window?.contentView as? TestOutputView)?.metalView?.delegate as? MetalRenderer)
        #expect(try pixels(output) == paused && output.scene.transport == session.transport)
        let view = try #require(session.testOutput.window?.contentView as? TestOutputView)
        #expect(view.metalView?.isPaused == true) // Unpresented view suspends even when playing.
        session.setPlaying(true,at: ProcessInfo.processInfo.systemUptime)
        #expect(view.metalView?.isPaused == true)
        session.setSurfaceContent(.solid); #expect(view.metalView?.isPaused == true)
    }
    @Test func collectionOrderAlphaInvalidIsolationAndEmptyClear() throws {
        let back = RenderSurface(geometry: rect(0,1),color: SIMD4(0,0,1,1))
        let front = RenderSurface(geometry: rect(0.25,0.5),color: SIMD4(1,0,0,0.5))
        let renderer = try MetalRenderer(scene: RenderScene(surfaces: [back,front]))
        var data = try pixels(renderer); let center = (64*128+64)*4
        #expect(abs(Int(data[center])-128)<=1 && abs(Int(data[center+2])-128)<=1 && data[center+3] == 255)
        let texture = renderer.diagnosticTexture
        renderer.setScene(RenderScene(surfaces: [front,back])); data = try pixels(renderer)
        #expect(Array(data[center..<center+4]) == [255,0,0,255])
        let invalid = RenderSurface(geometry: rect(0,0),color: SIMD4(1,0,0,1))
        renderer.setScene(RenderScene(surfaces: [back,invalid])); data = try pixels(renderer)
        #expect(Array(data[center..<center+4]) == [255,0,0,255])
        renderer.setScene(RenderScene(surfaces: [])); data = try pixels(renderer)
        #expect(Array(data[center..<center+4]) == [0,0,0,255])
        #expect(renderer.diagnosticTexture === texture)
    }
    @Test func continuousTiledFacesMatchOneSharedCanvasAndRepeatDiffers() throws {
        let whole = try MetalRenderer(scene: RenderScene(geometry: rect(0,1),color: SIMD4(1,1,1,1),content: .diagnosticGrid))
        let reference = try pixels(whole)
        let tiled = try MetalRenderer(scene: RenderScene(surfaces: [
            RenderSurface(geometry: rect(0,0.5),color: SIMD4(1,1,1,1),content: .diagnosticGrid,inputMap: FaceInputMap(size: SIMD2(0.5,1))),
            RenderSurface(geometry: rect(0.5,0.5),color: SIMD4(1,1,1,1),content: .diagnosticGrid,inputMap: FaceInputMap(origin: SIMD2(0.5,0),size: SIMD2(0.5,1))) ]))
        let continuous = try pixels(tiled)
        #expect(zip(reference,continuous).allSatisfy { abs(Int($0)-Int($1)) <= 2 })
        tiled.setScene(RenderScene(surfaces: tiled.scene.surfaces.map { item in var copy = item; copy.inputMap = .full; return copy }))
        let repeated = try pixels(tiled)
        #expect(zip(continuous,repeated).filter { abs(Int($0)-Int($1)) > 20 }.count > 1000)
    }
    @Test func projectVisibilityGroupingAndPreviewOutputSnapshotsMatchGPU() throws {
        let session = EditorSession(); session.addSurface()
        let a = session.project.surfaces[0].id, b = session.project.surfaces[1].id
        session.setSurfaceContent(.solid); session.setSourceColor(SIMD4(1,0,0,1))
        session.selectSurface(b); session.setSurfaceContent(.solid); session.setSourceColor(SIMD4(0,1,0,1))
        let preview = try MetalRenderer(scene: session.scene), output = try MetalRenderer(scene: session.scene)
        #expect(try pixels(preview) == pixels(output))
        session.setVisible(false,faceID: a)
        preview.setScene(session.scene); output.setScene(session.scene)
        let hidden = try pixels(preview), center = (64*128+64)*4
        #expect(Array(hidden[center..<center+4]) == [0,255,0,255])
        session.createObject(faceIDs: [a,b]); session.setSurfaceContent(.diagnosticGrid)
        preview.setScene(session.scene); output.setScene(session.scene)
        #expect(try pixels(preview) == pixels(output))
        let texture = preview.diagnosticTexture
        let originalID = try #require(session.selectedObjectID)
        for _ in 0..<12 {
            session.duplicateObject(originalID); preview.setScene(session.scene)
            session.deleteObject(try #require(session.selectedObjectID))
        }
        #expect(preview.diagnosticTexture === texture)
    }
}
