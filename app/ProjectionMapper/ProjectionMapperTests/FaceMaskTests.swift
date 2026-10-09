import Foundation
import MetalKit
import SwiftUI
import Testing

@MainActor
@Suite(.serialized)
struct FaceMaskTests {
    private func polygon(_ x0: Float,_ y0: Float,_ x1: Float,_ y1: Float) -> MaskPolygon {
        MaskPolygon(points: [SIMD2(x0,y0),SIMD2(x1,y0),SIMD2(x1,y1),SIMD2(x0,y1)])
    }
    private func mask() -> FaceMask {
        FaceMask(boundary: polygon(0.1,0.1,0.9,0.9),holes: [polygon(0.4,0.4,0.6,0.6)])
    }
    private func rect() -> NormalizedRectangle {
        NormalizedRectangle(topLeft: .zero,topRight: SIMD2(1,0),bottomRight: SIMD2(1,1),bottomLeft: SIMD2(0,1))
    }
    private func pixels(_ scene: RenderScene, at uptime: Double = 100) throws -> [UInt8] {
        let renderer = try MetalRenderer(scene: scene)
        let desc = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .bgra8Unorm,width: 128,height: 128,mipmapped: false)
        desc.storageMode = .shared; desc.usage = .renderTarget
        let texture = try #require(renderer.device.makeTexture(descriptor: desc))
        let pass = MTLRenderPassDescriptor(); pass.colorAttachments[0].texture = texture
        let command = try #require(renderer.encodeScene(to: pass,evaluationTime: 0.375,evaluationUptime: uptime))
        command.commit(); command.waitUntilCompleted()
        #expect(command.status == .completed && command.error == nil)
        var bytes = [UInt8](repeating: 0,count: 128*128*4)
        bytes.withUnsafeMutableBytes { texture.getBytes($0.baseAddress!,bytesPerRow: 128*4,from: MTLRegionMake2D(0,0,128,128),mipmapLevel: 0) }
        return bytes
    }
    private func rgb(_ bytes: [UInt8],_ x: Int,_ y: Int) -> [UInt8] { Array(bytes[(y*128+x)*4..<(y*128+x)*4+3]) }
    private func temp() throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("mask-tests-"+UUID().uuidString)
        try FileManager.default.createDirectory(at: url,withIntermediateDirectories: false); return url
    }
    @Test func productionEditorProjectionRoundTripsSkewedAndReversedFacesAndRejectsInvalidGeometry() throws {
        let skew = NormalizedRectangle(topLeft: SIMD2(0.05,0.15),topRight: SIMD2(0.9,0.05),bottomRight: SIMD2(0.8,0.95),bottomLeft: SIMD2(0.2,0.8))
        let reversed = NormalizedRectangle(topLeft: SIMD2(0.9,0.05),topRight: SIMD2(0.05,0.15),bottomRight: SIMD2(0.2,0.8),bottomLeft: SIMD2(0.8,0.95))
        for geometry in [skew,reversed] {
            for point: SIMD2<Float> in [.zero,SIMD2(1,1),SIMD2(0.2,0.6)] {
                let output = try #require(MaskEditorGeometry.project(point,corners: geometry))
                let local = try #require(MaskEditorGeometry.unproject(output,corners: geometry))
                #expect(abs(local.x-point.x) < 1e-6 && abs(local.y-point.y) < 1e-6)
            }
        }
        let invalid = NormalizedRectangle(topLeft: .zero,topRight: .zero,bottomRight: .zero,bottomLeft: .zero)
        #expect(MaskEditorGeometry.project(.zero,corners: invalid) == nil && MaskEditorGeometry.unproject(.zero,corners: invalid) == nil)
        #expect(MaskEditorGeometry.unproject(SIMD2(.nan,0),corners: nil) == nil)
        #expect(MaskEditorGeometry.unproject(SIMD2(0.2,0.6),corners: nil) == SIMD2(0.2,0.6))
    }
    @Test func concaveBothWindingsAndEdgeMembership() {
        var m = FaceMask(boundary: MaskPolygon(points: [SIMD2(0,0),SIMD2(1,0),SIMD2(1,0.4),SIMD2(0.4,0.4),SIMD2(0.4,1),SIMD2(0,1)]))
        #expect(m.validationMessage == nil && m.contains(SIMD2(0.2,0.8)) && !m.contains(SIMD2(0.8,0.8)))
        m.boundary.points.reverse(); #expect(m.validationMessage == nil && m.contains(SIMD2(0.2,0.8)))
        m = mask(); #expect(m.contains(SIMD2(0.1,0.3)) && !m.contains(SIMD2(0.4,0.5)))
        m.holes[0].points.reverse(); #expect(m.validationMessage == nil && !m.contains(SIMD2(0.5,0.5)))
    }
    @Test func degeneracyIntersectionsAndResourceBounds() {
        for points: [SIMD2<Float>] in [[],[SIMD2(0,0),SIMD2(1,1)], [SIMD2(0,0),SIMD2(1,1),SIMD2(0,1),SIMD2(1,0)], [SIMD2(0,0),SIMD2(1,0),SIMD2(0.5,0)], [SIMD2(0,0),SIMD2(1,0),SIMD2(1,0),SIMD2(0,1)]] {
            let m = FaceMask(boundary: MaskPolygon(points: points)); #expect(m.isBounded && m.validationMessage != nil && !m.allowsRendering)
        }
        var m = mask(); m.boundary.points[0].x = .nan; #expect(!m.isBounded)
        m = mask(); m.boundary.points[0].y = -.infinity; #expect(!m.isBounded)
        m = mask(); m.boundary.points[0].x = 1.1; #expect(!m.isBounded)
        m = mask(); m.boundary.points = Array(repeating: .zero,count: 33); #expect(!m.isBounded)
        m = mask(); m.holes = (0..<8).map { _ in polygon(0.2,0.2,0.3,0.3) }; #expect(!m.isBounded)
        m = mask(); m.holes[0].id = m.boundary.id; #expect(!m.isBounded)
    }
    @Test func holeContainmentTouchingOverlapAndNesting() {
        for hole in [polygon(0,0,0.2,0.2),polygon(0.1,0.2,0.3,0.3),polygon(0.8,0.2,1,0.3)] {
            var m = mask(); m.holes = [hole]; #expect(m.validationMessage != nil)
        }
        for hole in [polygon(0.5,0.5,0.7,0.7),polygon(0.45,0.45,0.55,0.55),polygon(0.3,0.3,0.7,0.7),polygon(0.6,0.4,0.7,0.6)] {
            var m = mask(); m.holes.append(hole); #expect(m.validationMessage != nil)
        }
        var m = mask(); m.holes.append(polygon(0.2,0.2,0.3,0.3)); #expect(m.validationMessage == nil)
        // Vertices inside a concave outer polygon are insufficient: an edge may cross its notch.
        m.boundary.points = [SIMD2(0,0),SIMD2(1,0),SIMD2(1,1),SIMD2(0.6,1),SIMD2(0.6,0.3),SIMD2(0.4,0.3),SIMD2(0.4,1),SIMD2(0,1)]
        m.holes = [polygon(0.2,0.5,0.8,0.8)]; #expect(m.validationMessage != nil)
    }
    @Test func maximumShaderPayloadClipsAllSevenHolesSafely() throws {
        func circle(_ center: SIMD2<Float>,_ radius: Float) -> MaskPolygon {
            MaskPolygon(points: (0..<32).map { i in
                let angle = Float(i)*2*Float.pi/32
                return center + SIMD2(cos(angle),sin(angle))*radius
            })
        }
        var m = FaceMask(boundary: circle(SIMD2(0.5,0.5),0.48))
        let centers = (0..<7).map { i -> SIMD2<Float> in let angle = Float(i)*2*Float.pi/7; return SIMD2(0.5,0.5)+SIMD2(cos(angle),sin(angle))*0.25 }
        m.holes = centers.map { circle($0,0.025) }
        #expect(m.isBounded && m.validationMessage == nil && m.shaderPoints.count == 256 && m.shaderRings.count == 8)
        #expect(m.shaderRings.last == SIMD2(224,32))
        let bytes = try pixels(RenderScene(surfaces: [RenderSurface(geometry: rect(),color: SIMD4(1,1,1,1),mask: m)]))
        for center in centers { #expect(rgb(bytes,Int(center.x*128),Int(center.y*128)) == [0,0,0]) }
        #expect(rgb(bytes,64,64) == [255,255,255] && rgb(bytes,0,0) == [0,0,0])
    }
    @Test func inspectorAndProjectedMaskEditorLayoutWithoutOpeningAWindow() throws {
        _ = NSApplication.shared
        let s = EditorSession(presentOutput: { _ in }); let id = try #require(s.selectedSurfaceID)
        s.createMask(faceID: id); s.beginMaskDrawing(hole: true)
        let face = try #require(s.selectedSurface)
        let inspector = NSHostingView(rootView: MaskControls(session: s,face: face))
        inspector.frame = CGRect(x: 0,y: 0,width: 280,height: 900); inspector.layoutSubtreeIfNeeded()
        let canvas = NSHostingView(rootView: MaskCanvas(session: s,face: face,projected: true))
        canvas.frame = CGRect(x: 0,y: 0,width: 640,height: 360); canvas.layoutSubtreeIfNeeded()
        #expect(inspector.window == nil && canvas.window == nil && s.maskDraft == [])
        #expect(s.selectedSurface?.corners == face.corners && s.project.surfaces.count == 1)
    }
    @Test func allContentAndCalibrationBranchesClipAndRevealLowerFaces() throws {
        let back = RenderSurface(geometry: rect(),color: SIMD4(0.02,0.04,0.08,1))
        for content in SurfaceContent.allCases.filter({ $0 != .image }) {
            for pattern in CalibrationPattern.allCases {
                let face = RenderSurface(geometry: rect(),color: SIMD4(1,0,0,1),content: content,mask: mask())
                let config = CalibrationState(pattern: pattern)
                let lower = try pixels(RenderScene(surfaces: [back],calibration: config))
                let combined = try pixels(RenderScene(surfaces: [back,face],calibration: config))
                let front = try pixels(RenderScene(surfaces: [face],calibration: config))
                #expect(rgb(combined,64,64) == rgb(lower,64,64))
                #expect(rgb(combined,4,4) == rgb(lower,4,4))
                #expect(rgb(front,64,64) == [0,0,0] && rgb(front,4,4) == [0,0,0])
                #expect(rgb(combined,32,32) == rgb(front,32,32))
            }
        }
    }
    @Test func GPUConcaveOutlineAndMultipleHolesMatchCPUAcrossInteriorSamples() throws {
        var m = FaceMask(boundary: MaskPolygon(points: [SIMD2(0.1,0.1),SIMD2(0.9,0.1),SIMD2(0.9,0.4),SIMD2(0.6,0.4),SIMD2(0.6,0.9),SIMD2(0.1,0.9)]))
        m.holes = [polygon(0.2,0.2,0.3,0.3),polygon(0.2,0.6,0.3,0.7)]
        #expect(m.validationMessage == nil)
        for reversed in [false,true] {
            if reversed { m.boundary.points.reverse(); for i in m.holes.indices { m.holes[i].points.reverse() } }
            let bytes = try pixels(RenderScene(surfaces: [RenderSurface(geometry: rect(),color: SIMD4(1,1,1,1),mask: m)]))
            for y in stride(from: 8,to: 128,by: 16) { for x in stride(from: 8,to: 128,by: 16) {
                let visible = m.contains(SIMD2((Float(x)+0.5)/128,(Float(y)+0.5)/128))
                #expect(rgb(bytes,x,y) == (visible ? [255,255,255] : [0,0,0]))
            } }
        }
    }
    @Test func masksStayInOriginalUVUnderCropFlipAndSharedInputChanges() throws {
        var face = RenderSurface(geometry: rect(),color: SIMD4(1,0,0,1),mask: mask())
        let plain = try pixels(RenderScene(surfaces: [face]))
        face.inputMap = FaceInputMap(origin: SIMD2(0.2,0.1),size: SIMD2(0.4,0.6),quarterTurns: 3,mirrored: true)
        face.appearance.crop = ContentCrop(origin: SIMD2(0.1,0.2),size: SIMD2(0.3,0.4)); face.appearance.flipHorizontal = true; face.appearance.flipVertical = true
        #expect(try pixels(RenderScene(surfaces: [face])) == plain)
        let calibration = CalibrationState(pattern: .white)
        #expect(try rgb(pixels(RenderScene(surfaces: [face],calibration: calibration)),64,64) == [0,0,0])
        // Geometry is immutable; projective copy carries the identical mask.
        let skew = NormalizedRectangle(topLeft: SIMD2(0.05,0.15),topRight: SIMD2(0.9,0.05),bottomRight: SIMD2(0.8,0.95),bottomLeft: SIMD2(0.2,0.8))
        let moved = RenderSurface(geometry: skew,color: face.color,mask: face.mask)
        let bytes = try pixels(RenderScene(surfaces: [moved],calibration: calibration))
        let transform = try #require(PerspectiveTransform(skew))
        for uv: SIMD2<Double> in [SIMD2(0.5,0.5),SIMD2(0.25,0.25),SIMD2(0.05,0.5)] {
            let p = transform.project(uv); let expected: [UInt8] = uv == SIMD2(0.25,0.25) ? [255,255,255] : [0,0,0]
            #expect(rgb(bytes,Int(p.x*128),Int(p.y*128)) == expected)
        }
    }
    @Test func invalidEnabledSuppressesDisabledDraftRendersAndDemandIdles() throws {
        var m = mask(); m.boundary.points = [SIMD2(0,0),SIMD2(1,1),SIMD2(0,1),SIMD2(1,0)]
        var face = RenderSurface(geometry: rect(),color: SIMD4(1,0,0,1),content: .gradient,mask: m)
        var scene = RenderScene(surfaces: [face]); scene.transport.setPlaying(true,at: 100)
        #expect(scene.invalidCount == 1 && !scene.needsContinuousRendering(at: 101))
        for pattern in CalibrationPattern.allCases {
            scene.calibration.pattern = pattern
            let bytes = try pixels(scene); #expect(stride(from: 0,to: bytes.count,by: 4).allSatisfy { bytes[$0] == 0 && bytes[$0+1] == 0 && bytes[$0+2] == 0 })
        }
        m.isEnabled = false; face.mask = m; scene = RenderScene(surfaces: [face],calibration: CalibrationState(pattern: .white))
        #expect(scene.invalidCount == 0)
        #expect(rgb(try pixels(scene),64,64) == [255,255,255])
    }
    @Test func opacityFadeBlackoutAndCalibrationOverridePreserveMasks() throws {
        let back = RenderSurface(geometry: rect(),color: SIMD4(0,0,1,1))
        var front = RenderSurface(geometry: rect(),color: SIMD4(1,0,0,1),mask: mask()); front.appearance.opacity = 0.5
        let data = try pixels(RenderScene(surfaces: [back,front]))
        #expect(rgb(data,64,64) == [255,0,0]); #expect(abs(Int(rgb(data,32,32)[0])-128) <= 1 && abs(Int(rgb(data,32,32)[2])-128) <= 1)
        var scene = RenderScene(surfaces: [front],calibration: CalibrationState(pattern: .white))
        scene.showOutput.fade(to: 0,duration: 4,at: 100)
        #expect(rgb(try pixels(scene,at: 102),64,64) == [0,0,0])
        #expect(abs(Int(rgb(try pixels(scene,at: 102),32,32)[0])-128) <= 1)
        scene.showOutput.blackout(); #expect(rgb(try pixels(scene,at: 102),32,32) == [0,0,0])
        #expect(scene.effectiveSurfaces[0].mask == front.mask && scene.surfaces[0].appearance.opacity == 0.5)
    }
    @Test func sessionDrawingIsTransactionalCancelsAndRejectsInvalidCreation() throws {
        let s = EditorSession(presentOutput: { _ in }); let id = try #require(s.selectedSurfaceID)
        s.createMask(faceID: id); let original = s.project
        s.beginMaskDrawing(hole: true); #expect(s.maskDraft == [])
        for p: SIMD2<Float> in [SIMD2(0.2,0.2),SIMD2(0.4,0.2),SIMD2(0.3,0.4)] { s.appendMaskDraft(p,faceID: id) }
        #expect(s.project == original); s.finishMaskDrawing(); #expect(s.project.surfaces[0].mask?.holes.count == 1 && s.maskDraft == nil)
        let finished = s.project
        s.beginMaskDrawing(hole: true)
        for p: SIMD2<Float> in [SIMD2(0,0),SIMD2(1,0),SIMD2(1,1)] { s.appendMaskDraft(p,faceID: id) }
        s.finishMaskDrawing(); #expect(s.project == finished && s.editMessage != nil && s.maskDraft != nil)
        s.cancelMaskDrawing(); #expect(s.project == finished)
        s.beginMaskDrawing(hole: false); s.addSurface(); #expect(s.maskDraft == nil && !s.isMaskEditing)
        s.appendMaskDraft(SIMD2(0.3,0.3),faceID: id); #expect(s.maskDraft == nil)
    }
    @Test func sessionPointEditsClampRejectNonfiniteAndStaleFaceWhileLocksAllowMasks() throws {
        let s = EditorSession(presentOutput: { _ in }); let face = try #require(s.selectedSurface)
        s.createMask(faceID: face.id); let ring = try #require(s.selectedSurface?.mask?.boundary)
        s.setGeometryLocked(true,faceID: face.id)
        s.moveMaskPoint(SIMD2(0.1,0.2),faceID: face.id,ringID: ring.id,index: 0)
        #expect(s.selectedSurface?.corners == face.corners && s.selectedSurface?.mask?.boundary.points[0] == SIMD2(0.1,0.2))
        let before = s.project
        s.moveMaskPoint(SIMD2(.nan,0),faceID: face.id,ringID: ring.id,index: 0); #expect(s.project == before)
        s.moveMaskPoint(SIMD2(-2,3),faceID: face.id,ringID: ring.id,index: 0); #expect(s.selectedSurface?.mask?.boundary.points[0] == SIMD2(0,1))
        s.selectedMaskVertex = 0; s.insertMaskPoint(); #expect(s.selectedSurface?.mask?.boundary.points.count == 5)
        s.deleteMaskPoint(); #expect(s.selectedSurface?.mask?.boundary.points.count == 4)
        s.addSurface(); let new = s.project
        s.moveMaskPoint(.zero,faceID: face.id,ringID: ring.id,index: 0); #expect(s.project == new)
    }
    @Test func groupingDuplicatesDetachResetAndLooksPreserveFaceMasks() throws {
        let s = EditorSession(presentOutput: { _ in }); let a = try #require(s.selectedSurfaceID)
        s.setMask(mask(),faceID: a); s.duplicateSurface(a)
        let b = try #require(s.selectedSurfaceID)
        #expect(s.selectedSurface?.mask?.boundary.id != s.project.surfaces.first { $0.id == a }?.mask?.boundary.id)
        s.toggleGrouping(a); s.toggleGrouping(b); s.createObject()
        let object = try #require(s.selectedObjectID)
        let originals = s.project.surfaces.filter { $0.layout.objectID == object }.map(\.mask)
        s.duplicateObject(object); let duplicate = try #require(s.selectedObjectID)
        #expect(s.project.surfaces.filter { $0.layout.objectID == duplicate }.allSatisfy { $0.mask?.validationMessage == nil })
        s.selectSurface(a); let kept = try #require(s.selectedSurface?.mask)
        for scope: FaceResetScope in [.outputGeometry,.appearance,.cropAndFlip,.generatorParameters,.content,.fullFace] { s.resetFace(a,scope: scope); #expect(s.selectedSurface?.mask == kept) }
        for scope: ObjectResetScope in [.appearance,.cropAndFlip,.generatorParameters,.content,.inputLayout] { s.resetObject(object,scope: scope) }
        #expect(s.project.surfaces.filter { $0.layout.objectID == object }.map(\.mask) == originals)
        let lookID = try #require(s.saveLook(name: "Mask-independent look"))
        s.setSurfaceContent(.noise); s.applyLook(lookID); #expect(s.selectedSurface?.mask == kept)
        s.detachSurface(a); #expect(s.selectedSurface?.mask == kept)
    }
    @Test func savedAndRecoveryPackagesRetainInvalidDraftAndFailedSavePreservesLastGood() throws {
        let directory = try temp(); defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("project.projectionmap")
        let s = EditorSession(presentOutput: { _ in }); let id = try #require(s.selectedSurfaceID)
        s.setMask(mask(),faceID: id); try s.save(to: url); #expect(!s.hasUserChanges)
        let good = try ProjectPackageStore().read(url)
        var invalid = mask(); invalid.holes[0].points[0] = .zero
        s.setMask(invalid,faceID: id); #expect(s.hasUserChanges && s.scene.invalidCount == 1)
        let recovery = ProjectRecoveryStore(directory: directory.appendingPathComponent("recovery")); s.configureRecovery(recovery); try s.flushRecovery()
        let copy = try #require(recovery.entries().first); #expect(copy.document.project.surfaces[0].mask == invalid)
        let failing = ProjectPackageStore(); failing.beforeCommit = { _ in throw ProjectFileError.io("injected") }
        #expect(throws: (any Error).self) { try s.save(to: url,store: failing) }; #expect(try ProjectPackageStore().read(url) == good)
        try s.save(to: url); #expect(!s.hasUserChanges)
        let loaded = try ProjectPackageStore().read(url); #expect(loaded.formatVersion == ProjectDocument.currentVersion && loaded.project.surfaces[0].mask == invalid)
        s.beginMaskDrawing(hole: false); try s.load(loaded,from: url); #expect(s.maskDraft == nil && !s.isMaskEditing && s.scene.invalidCount == 1)
        s.clearRecovery()
    }
    @Test func versionsOneThroughFiveMigrateWithoutMasksAndSixRejectsUnsafeValues() throws {
        var project = MappingProject(); project.surfaces[0].mask = mask()
        let document = ProjectDocument(project: project)
        let data = try ProjectCodec.encode(document)
        #expect(try ProjectCodec.decode(data) == document)
        for version in 1...5 {
            var json = try #require(JSONSerialization.jsonObject(with: data) as? [String:Any]); json["formatVersion"] = version
            let result = try ProjectCodec.decode(JSONSerialization.data(withJSONObject: json))
            #expect(result.formatVersion == ProjectDocument.currentVersion && result.project.surfaces[0].mask == nil)
        }
        project.surfaces[0].mask?.boundary.points[0].x = 2
        #expect(throws: (any Error).self) { try ProjectCodec.encode(ProjectDocument(project: project)) }
    }
    @Test func independentMaskEditDoesNotChangeObjectTimingOrJoinData() throws {
        let s = EditorSession(presentOutput: { _ in }); let a = try #require(s.selectedSurfaceID)
        s.addSurface(); let b = try #require(s.selectedSurfaceID)
        s.toggleGrouping(a); s.toggleGrouping(b); s.createObject(); let objectID = try #require(s.selectedObjectID)
        s.addLink(FaceEdgeLink(firstFace: a,firstEdge: .right,secondFace: b,secondEdge: .left),objectID: objectID,align: true)
        s.selectSurface(a); s.setSurfaceContent(.particles); s.setPlaying(true,at: 100); s.setSelectedPaused(true,at: 103)
        let object = s.project.objects[0], clock = s.selectedPlayback, maps = s.project.surfaces.map(\.layout.inputMap)
        s.setMask(mask(),faceID: a)
        #expect(s.project.objects[0] == object && s.selectedPlayback == clock && s.project.surfaces.map(\.layout.inputMap) == maps)
        #expect(s.project.surfaces.first { $0.id == b }?.mask == nil)
        #expect(s.scene.surfaces.filter { $0.mask != nil }.count == 1)
    }
}
