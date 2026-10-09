import AppKit
import SwiftUI
import MetalKit
import Testing

@MainActor
@Suite(.serialized)
struct EditorDisplayTests {
    private func rect(_ x0: Float,_ x1: Float) -> NormalizedRectangle {
        NormalizedRectangle(topLeft: SIMD2(x0,0),topRight: SIMD2(x1,0),bottomRight: SIMD2(x1,1),bottomLeft: SIMD2(x0,1))
    }
    private func connected() -> MappingProject {
        let object = MappingObject(name: "House",source: SurfaceSource(content: .particles))
        var faces = (0..<3).map { i -> MappingSurface in
            var face = MappingSurface(name: "Face \(i+1)",corners: rect(Float(i)/3,Float(i+1)/3))
            face.layout.objectID = object.id
            face.layout.inputMap = FaceInputMap(origin: SIMD2(Float(i)/3,0),size: SIMD2(1/3,1))
            return face
        }
        // Last face's output and input both reverse, preserving shared canvas coordinates.
        faces[2].corners = NormalizedRectangle(topLeft: SIMD2(1,1),topRight: SIMD2(2/3,1),bottomRight: SIMD2(2/3,0),bottomLeft: SIMD2(1,0))
        faces[2].layout.inputMap.quarterTurns = 2
        var project = MappingProject(surface: faces[0]); project.surfaces = faces; project.objects = [object]
        project.objects[0].links = [FaceEdgeLink(firstFace: faces[0].id,firstEdge: .right,secondFace: faces[1].id,secondEdge: .left),FaceEdgeLink(firstFace: faces[1].id,firstEdge: .right,secondFace: faces[2].id,secondEdge: .right,reversed: true)]
        return project
    }
    private func pixels(_ scene: RenderScene) throws -> [UInt8] {
        let renderer = try MetalRenderer(scene: scene)
        let desc = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .bgra8Unorm,width: 192,height: 128,mipmapped: false)
        desc.storageMode = .shared; desc.usage = .renderTarget
        let texture = try #require(renderer.device.makeTexture(descriptor: desc))
        let pass = MTLRenderPassDescriptor(); pass.colorAttachments[0].texture = texture
        let buffer = try #require(renderer.encodeScene(to: pass,evaluationTime: 0.5,evaluationUptime: 102))
        buffer.commit(); buffer.waitUntilCompleted(); #expect(buffer.status == .completed && buffer.error == nil)
        var bytes = [UInt8](repeating: 0,count: 192*128*4)
        bytes.withUnsafeMutableBytes { texture.getBytes($0.baseAddress!,bytesPerRow: 192*4,from: MTLRegionMake2D(0,0,192,128),mipmapLevel: 0) }
        return bytes
    }
    @Test func inspectorNavigationIsTemporaryAndSelectionReturnsToEdit() throws {
        let s = EditorSession(presentOutput: { _ in })
        let saved = try ProjectCodec.encode(s.document)
        let scene = s.scene
        s.inspectorTab = .show
        s.selectSurface(s.project.surfaces[0].id)
        #expect(s.inspectorTab == .edit)
        s.inspectorTab = .project
        #expect(try ProjectCodec.encode(s.document) == saved)
        #expect(s.scene == scene && !s.hasUserChanges)
        s.selectSurface(UUID())
        #expect(s.inspectorTab == .project)
        s.resetProject()
        #expect(s.inspectorTab == .edit)
        s.inspectorTab = .show
        try s.load(s.document, from: URL(fileURLWithPath: "/tmp/UI-navigation.projectionmap"))
        #expect(s.inspectorTab == .edit && !s.hasUserChanges)
    }
    @Test func displayAndLabelsNeverDirtySaveOrChangeOutputAndResetOnOpenNew() throws {
        let s = EditorSession(presentOutput: { _ in }); let original = s.project, scene = s.scene
        let data = try ProjectCodec.encode(s.document)
        s.selectCorner(.topLeft); s.createMask(faceID: original.surfaces[0].id)
        s.beginMaskDrawing(hole: true)
        s.toggleEditorHandles(); #expect(!s.editorDisplay.hasHandles && s.selectedCorner == nil && s.maskDraft == nil)
        s.toggleEditorHandles(); #expect(s.editorDisplay.cornerHandles && s.editorDisplay.maskHandles)
        s.toggleEditorLabels(); var display = s.editorDisplay; display.outlines = false; display.edgeLabels = true; s.setEditorDisplay(display)
        let masked = s.document
        let before = s.project; s.resetEditorDisplay(); #expect(s.project == before && s.editorDisplay == .defaults)
        try s.load(try ProjectCodec.decode(data),from: URL(fileURLWithPath: "/tmp/unshown.projectionmap"))
        #expect(s.editorDisplay == .defaults && s.project == original && s.scene == scene && !s.hasUserChanges)
        s.setEditorDisplay(display); #expect(s.project == original && s.scene == scene && !s.hasUserChanges)
        #expect(try ProjectCodec.encode(s.document) == data)
        try s.load(masked,from: URL(fileURLWithPath: "/tmp/recovery.projectionmap"),recovering: true)
        #expect(s.editorDisplay == .defaults && s.hasUserChanges)
        s.setEditorDisplay(display); s.resetProject(); #expect(s.editorDisplay == .defaults && !s.hasUserChanges)
    }
    @Test func labelsRespectVisibilitySelectionDirectionsAndJoinSeverity() throws {
        var p = connected(); let object = p.objects[0]
        #expect(p.joinWarnings.isEmpty)
        var labels = EditorDecorations.labels(project: p,selectedFace: nil,selectedObject: object.id)
        #expect(labels.count == 3 && labels.allSatisfy { $0.title.hasPrefix("House · Face") && $0.edges.count == 4 })
        #expect(labels.flatMap(\.edges).filter { $0.status == .joined }.count == 4)
        #expect(labels.flatMap(\.edges).contains { $0.title.hasPrefix("Right ↓") })
        p.objects[0].links[0].isSeam = true
        p.surfaces[2].layout.inputMap.quarterTurns = 0
        labels = EditorDecorations.labels(project: p,selectedFace: nil,selectedObject: object.id)
        #expect(labels.flatMap(\.edges).filter { $0.status == .seam }.count == 2)
        #expect(labels.flatMap(\.edges).filter { $0.status == .warning }.count == 2)
        p.surfaces[0].layout.isVisible = false
        labels = EditorDecorations.labels(project: p,selectedFace: p.surfaces[1].id,selectedObject: nil)
        #expect(labels.count == 2 && labels.filter { !$0.edges.isEmpty }.count == 1)
        p.objects[0].isVisible = false
        #expect(EditorDecorations.labels(project: p,selectedFace: nil,selectedObject: object.id).isEmpty)
    }
    @Test func projectiveLabelsAreFiniteAndInvalidGeometryKeepsIdentification() throws {
        var face = MappingSurface(corners: NormalizedRectangle(topLeft: SIMD2(0.1,0.1),topRight: SIMD2(0.9,0.2),bottomRight: SIMD2(0.8,0.9),bottomLeft: SIMD2(0.2,0.8)))
        var p = MappingProject(surface: face)
        let label = try #require(EditorDecorations.labels(project: p,selectedFace: face.id,selectedObject: nil).first)
        let center = try #require(PerspectiveTransform(face.corners)).project(SIMD2(0.5,0.5))
        #expect(abs(Double(label.position.x)-center.x) < 1e-6 && abs(Double(label.position.y)-center.y) < 1e-6)
        face.corners = face.corners.replacing(.topRight,with: face.corners.topLeft); p.surfaces = [face]
        let invalid = try #require(EditorDecorations.labels(project: p,selectedFace: face.id,selectedObject: nil).first)
        #expect(invalid.position.x.isFinite && invalid.position.y.isFinite && invalid.edges.count == 4)
    }
    @Test func nativeHiddenHandlesCancelDragBlockKeysKeepPickingAndDoNotStealTyping() throws {
        _ = NSApplication.shared
        let s = EditorSession(presentOutput: { _ in }), id = s.project.surfaces[0].id
        let view = CornerOverlayView(frame: CGRect(x: 0,y: 0,width: 424,height: 424))
        let window = NSWindow(contentRect: view.frame,styleMask: [.titled],backing: .buffered,defer: false)
        window.isReleasedWhenClosed = false; window.contentView = view
        defer { window.contentView = nil; window.close() }
        var picked = false
        func configure(_ show: Bool) {
            view.configure(surfaceID: id,corners: s.project.surfaces[0].corners,activeCorner: s.selectedCorner,
                select: { s.selectCorner($0) },move: { s.moveSelectedCorner(to: $0,surfaceID: id) },nudge: { s.nudgeSelectedCorner(direction: $0,larger: $1) },
                selectFace: { _ in picked = true },showsHandles: show,showsOutlines: false)
        }
        func mouse(_ type: NSEvent.EventType,_ p: CGPoint) throws -> NSEvent {
            try #require(NSEvent.mouseEvent(with: type,location: view.convert(p,to: nil),modifierFlags: [],timestamp: 0,windowNumber: window.windowNumber,context: nil,eventNumber: 1,clickCount: 1,pressure: 1))
        }
        let point = SurfaceCoordinates.position(s.project.surfaces[0].corners.topLeft,in: view.previewRect)
        configure(true); view.mouseDown(with: try mouse(.leftMouseDown,point)); #expect(s.selectedCorner == .topLeft)
        configure(false); let before = s.project
        view.mouseDragged(with: try mouse(.leftMouseDragged,CGPoint(x: point.x+40,y: point.y+40)))
        let arrow = try #require(NSEvent.keyEvent(with: .keyDown,location: .zero,modifierFlags: [],timestamp: 0,windowNumber: window.windowNumber,context: nil,characters: "",charactersIgnoringModifiers: "",isARepeat: false,keyCode: 124))
        view.keyDown(with: arrow); #expect(s.project == before)
        view.mouseDown(with: try mouse(.leftMouseDown,point)); #expect(picked && s.selectedCorner == nil)
        let text = NSTextView(frame: CGRect(x: 0,y: 0,width: 100,height: 30)); view.addSubview(text); window.makeFirstResponder(text)
        configure(true); #expect(window.firstResponder === text && !window.isVisible)
        #expect(CornerOverlayView.direction(keyCode: 124,modifiers: [.control,.command]) == nil)
    }
    @Test func hiddenObjectCenterCannotDragOrNudge() throws {
        _ = NSApplication.shared
        let p = connected(), object = p.objects[0]
        let view = CornerOverlayView(frame: CGRect(x: 0,y: 0,width: 424,height: 424))
        let window = NSWindow(contentRect: view.frame,styleMask: [.titled],backing: .buffered,defer: false)
        window.isReleasedWhenClosed = false; window.contentView = view
        defer { window.contentView = nil; window.close() }
        var moved = false
        view.configure(surfaceID: nil,corners: .diagnostic,activeCorner: nil,select: { _ in },move: { _ in },nudge: { _,_ in },showsHandles: false,
            objectID: object.id,objectBounds: p.outputBounds(forObject: object.id),moveObject: { _ in moved = true },nudgeObject: { _,_ in moved = true })
        let point = SurfaceCoordinates.position(SIMD2(0.5,0.5),in: view.previewRect)
        for type in [NSEvent.EventType.leftMouseDown,.leftMouseDragged] {
            let event = try #require(NSEvent.mouseEvent(with: type,location: view.convert(point,to: nil),modifierFlags: [],timestamp: 0,windowNumber: window.windowNumber,context: nil,eventNumber: 1,clickCount: 1,pressure: 1)); type == .leftMouseDown ? view.mouseDown(with: event) : view.mouseDragged(with: event)
        }
        let key = try #require(NSEvent.keyEvent(with: .keyDown,location: .zero,modifierFlags: [],timestamp: 0,windowNumber: window.windowNumber,context: nil,characters: "",charactersIgnoringModifiers: "",isARepeat: false,keyCode: 124))
        view.keyDown(with: key); #expect(!moved && !window.isVisible)
    }
    @Test func threeFaceStripesAndCheckersMatchWholeCanvasWithReversedJoinRepeatDiffers() throws {
        var p = connected(); #expect(p.joinWarnings.isEmpty)
        for pattern in [CalibrationPattern.verticalStripes,.horizontalStripes,.checkerboard] {
            let calibration = CalibrationState(pattern: pattern,columns: 6,rows: 4)
            let reference = try pixels(RenderScene(surfaces: [RenderSurface(geometry: rect(0,1),color: SIMD4(1,1,1,1))],calibration: calibration))
            var scene = p.renderScene; scene.calibration = calibration
            let connectedPixels = try pixels(scene)
            #expect(zip(reference,connectedPixels).allSatisfy { abs(Int($0)-Int($1)) <= 2 })
            if pattern != .horizontalStripes {
                p.objects[0].mode = .repeatContent; scene = p.renderScene; scene.calibration = calibration
                #expect(zip(reference,try pixels(scene)).filter { abs(Int($0)-Int($1)) > 30 }.count > 1000)
                p.objects[0].mode = .continuous
            }
        }
    }
    @Test func joinInspectionPreservesClocksMappingMaskLookAndReturnsCurrentContentAfterBlackout() throws {
        var p = connected(); p.surfaces[0].mask = FaceMask(holes: [MaskPolygon(points: [SIMD2(0.3,0.3),SIMD2(0.7,0.3),SIMD2(0.7,0.7),SIMD2(0.3,0.7)])])
        p.surfaces[0].appearanceOverride = SurfaceAppearance(opacity: 0.2,brightness: 0.4,flipHorizontal: true)
        let s = EditorSession(presentOutput: { _ in },project: p)
        s.selectObject(p.objects[0].id); s.setPlaying(true,at: 100); s.setSelectedPaused(true,at: 101)
        let clock = s.selectedPlayback, transport = s.transport, project = s.project
        let normal = try pixels(s.scene)
        s.inspectJoins(objectID: p.objects[0].id,pattern: .verticalStripes)
        #expect(s.editorDisplay.faceLabels && s.editorDisplay.edgeLabels && s.project == project && s.selectedPlayback == clock && s.transport == transport)
        #expect(!s.scene.needsContinuousRendering(at: 102) && s.scene.effectiveSurfaces[0].appearance == .defaults)
        let striped = try pixels(s.scene)
        s.blackoutOutput()
        let black = try pixels(s.scene); #expect(stride(from: 0,to: black.count,by: 4).allSatisfy { black[$0] == 0 && black[$0+1] == 0 && black[$0+2] == 0 })
        s.setFadeDuration(0); s.restoreOutput(at: 102)
        #expect(try pixels(s.scene) == striped)
        s.setCalibrationPattern(.normal); #expect(try pixels(s.scene) == normal)
        #expect(s.project.surfaces == project.surfaces && s.selectedPlayback == clock)
    }
    @Test func labelsAndGuideSettingsAreAbsentFromBothOutputSceneAndPackage() throws {
        let s = EditorSession(presentOutput: { _ in },project: connected())
        s.selectObject(s.project.objects[0].id); let scene = s.scene, document = s.document
        var guides = s.editorDisplay; guides.faceLabels = true; guides.edgeLabels = true; guides.outlines = false; guides.cornerHandles = false; guides.maskHandles = false
        s.setEditorDisplay(guides)
        let host = NSHostingView(rootView: EditorLabelsOverlay(session: s)); host.frame = CGRect(x: 0,y: 0,width: 640,height: 360); host.layoutSubtreeIfNeeded()
        #expect(host.window == nil && s.scene == scene && s.document == document)
        #expect(try pixels(s.scene) == pixels(scene))
        let json = String(decoding: try ProjectCodec.encode(s.document),as: UTF8.self)
        #expect(!json.contains("editorDisplay") && !json.contains("edgeLabels") && !json.contains("calibration"))
    }
}
