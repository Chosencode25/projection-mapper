import AppKit
import Testing

@MainActor
struct CornerEditingTests {
    @Test func fittedCoordinateConversionHandlesMarginsShapesAndClamps() throws {
        for rect in [CGRect(x: 12,y: 12,width: 800,height: 450), CGRect(x: 103,y: 57,width: 400,height: 600),
                     CGRect(x: 12,y: 12,width: 600,height: 600)] {
            for point in [SIMD2<Float>(0,0), SIMD2(1,1), SIMD2(0.25,0.75)] {
                let result = try #require(SurfaceCoordinates.normalized(SurfaceCoordinates.position(point, in: rect), in: rect))
                #expect(abs(result.x - point.x) < 0.00001 && abs(result.y - point.y) < 0.00001)
            }
            #expect(SurfaceCoordinates.normalized(CGPoint(x: rect.minX - 100, y: rect.maxY + 100), in: rect) == SIMD2(0,1))
        }
        #expect(SurfaceCoordinates.normalized(.zero, in: .zero) == nil)
        #expect(SurfaceCoordinates.normalized(CGPoint(x: CGFloat.nan, y: 0), in: CGRect(x: 0,y: 0,width: 10,height: 10)) == nil)
    }

    @Test func editingEachCornerPreservesAllOthers() {
        let original = NormalizedRectangle.diagnostic
        for corner in SurfaceCorner.allCases {
            let edited = original.replacing(corner, with: SIMD2(0.1,0.2))
            for other in SurfaceCorner.allCases {
                #expect(edited[other] == (other == corner ? SIMD2(0.1,0.2) : original[other]))
            }
        }
    }

    @Test func geometryEditsValidateIdentityAndOnlyActualChangesTouchProject() {
        let session = EditorSession()
        let project = session.project
        session.selectCorner(.topLeft)
        #expect(!session.hasUserChanges && session.project == project)
        session.moveSelectedCorner(to: SIMD2(0.1,0.2), surfaceID: UUID())
        session.moveSelectedCorner(to: SIMD2(.nan,0.2), surfaceID: project.surfaces[0].id)
        session.moveSelectedCorner(to: project.surfaces[0].corners.topLeft, surfaceID: project.surfaces[0].id)
        #expect(session.project == project)
        let changed = Date(timeIntervalSince1970: 900)
        session.moveSelectedCorner(to: SIMD2(-3,2), surfaceID: project.surfaces[0].id, now: changed)
        #expect(session.project.surfaces[0].corners.topLeft == SIMD2(0,1))
        #expect(session.project.modifiedAt == changed && session.project.createdAt == project.createdAt)
        #expect(session.project.surfaces[0].id == project.surfaces[0].id && session.hasUserChanges)
        session.moveSelectedCorner(to: SIMD2(-3,2), surfaceID: project.surfaces[0].id, now: .distantFuture)
        #expect(session.project.modifiedAt == changed)
    }

    @Test func nudgesUseNormalAndShiftStepsAndRespectEdges() {
        let session = EditorSession()
        session.selectCorner(.topRight)
        session.nudgeSelectedCorner(direction: SIMD2(1,0), larger: false)
        #expect(abs(session.project.surfaces[0].corners.topRight.x - 0.751) < 0.000001)
        session.nudgeSelectedCorner(direction: SIMD2(0,-1), larger: true)
        #expect(abs(session.project.surfaces[0].corners.topRight.y - 0.24) < 0.000001)
        session.moveSelectedCorner(to: SIMD2(1,0), surfaceID: session.project.surfaces[0].id)
        let before = session.project
        session.nudgeSelectedCorner(direction: SIMD2(1,-1), larger: true)
        #expect(session.project == before)
    }

    @Test func selectionResetAndPresetsKeepCornerStateConsistent() {
        let session = EditorSession(presentOutput: { _ in })
        session.selectCorner(.bottomLeft)
        session.moveSelectedCorner(to: SIMD2(0.1,0.8), surfaceID: session.project.surfaces[0].id)
        let edited = session.project.surfaces[0]
        for preset in TestResolution.allCases {
            session.setTestResolution(preset)
            session.testOutput.open(for: .testWindow, resolution: preset)
            session.testOutput.close()
            #expect(session.selectedCorner == .bottomLeft && session.project.surfaces[0] == edited)
        }
        session.selectSurface(nil)
        #expect(session.selectedCorner == nil)
        session.selectCorner(.topLeft)
        #expect(session.selectedCorner == nil)
        session.selectSurface(edited.id); session.selectCorner(.topLeft)
        session.resetProject()
        #expect(session.selectedCorner == nil && !session.hasUserChanges)
        session.selectCorner(.topLeft)
        session.moveSelectedCorner(to: SIMD2(0,0), surfaceID: edited.id)
        #expect(session.scene == .diagnosticGrid)
    }

    @Test func nativeDragPreservesGrabOffsetAndOwnsKeyboardFocus() throws {
        _ = NSApplication.shared
        let session = EditorSession()
        let view = CornerOverlayView(frame: CGRect(x: 0,y: 0,width: 424,height: 624))
        let window = NSWindow(contentRect: view.frame, styleMask: [.titled], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false; window.contentView = view
        defer { window.contentView = nil; window.close() }
        let id = session.project.surfaces[0].id
        view.configure(surfaceID: id, corners: session.project.surfaces[0].corners, activeCorner: nil,
                       select: { session.selectCorner($0) },
                       move: { session.moveSelectedCorner(to: $0, surfaceID: id) },
                       nudge: { session.nudgeSelectedCorner(direction: $0, larger: $1) })
        let center = SurfaceCoordinates.position(session.project.surfaces[0].corners.topLeft, in: view.previewRect)
        func mouse(_ type: NSEvent.EventType, _ point: CGPoint) throws -> NSEvent {
            try #require(NSEvent.mouseEvent(with: type, location: view.convert(point, to: nil),
                modifierFlags: [], timestamp: 0, windowNumber: window.windowNumber,
                context: nil, eventNumber: 1, clickCount: 1, pressure: 1))
        }
        view.mouseDown(with: try mouse(.leftMouseDown, CGPoint(x: center.x + 4, y: center.y + 3)))
        #expect(window.firstResponder === view && session.selectedCorner == .topLeft && !session.hasUserChanges)
        view.mouseDragged(with: try mouse(.leftMouseDragged, CGPoint(x: center.x + 44, y: center.y + 63)))
        #expect(abs(session.project.surfaces[0].corners.topLeft.x - 0.35) < 0.000001)
        #expect(abs(session.project.surfaces[0].corners.topLeft.y - 0.35) < 0.000001)
        let key = try #require(NSEvent.keyEvent(with: .keyDown, location: .zero, modifierFlags: .shift,
            timestamp: 0, windowNumber: window.windowNumber, context: nil, characters: "", charactersIgnoringModifiers: "",
            isARepeat: true, keyCode: 124))
        view.keyDown(with: key)
        #expect(abs(session.project.surfaces[0].corners.topLeft.x - 0.36) < 0.000001)
        var clicks: [SIMD2<Float>?] = []
        view.configure(surfaceID: nil, corners: .diagnostic, activeCorner: nil,
                       select: { _ in }, move: { _ in }, nudge: { _,_ in }, selectFace: { clicks.append($0) })
        view.mouseDown(with: try mouse(.leftMouseDown, SurfaceCoordinates.position(SIMD2(0.5,0.5), in: view.previewRect)))
        #expect(clicks.count == 1 && clicks[0] == SIMD2(0.5,0.5))
        view.mouseDown(with: try mouse(.leftMouseDown, CGPoint(x: 2,y: 2)))
        #expect(clicks.count == 2 && clicks[1] == nil)
        let text = NSTextView(frame: .zero)
        window.contentView?.addSubview(text); window.makeFirstResponder(text)
        #expect(window.firstResponder === text) // Native field/editor focus replaces canvas routing.
    }

    @Test func nativeKeyRoutingIgnoresShortcutModifiersAndNonArrows() {
        #expect(CornerOverlayView.direction(keyCode: 123, modifiers: []) == SIMD2(-1,0))
        #expect(CornerOverlayView.direction(keyCode: 124, modifiers: .shift) == SIMD2(1,0))
        #expect(CornerOverlayView.direction(keyCode: 125, modifiers: []) == SIMD2(0,1))
        #expect(CornerOverlayView.direction(keyCode: 126, modifiers: []) == SIMD2(0,-1))
        for flags: NSEvent.ModifierFlags in [.command,.control,.option] {
            #expect(CornerOverlayView.direction(keyCode: 123, modifiers: flags) == nil)
        }
        #expect(CornerOverlayView.direction(keyCode: 0, modifiers: []) == nil)
    }
    @Test func nativeLocksBlockDragAndKeysAndCancelAnActiveDrag() throws {
        _ = NSApplication.shared
        let s = EditorSession(), id = s.project.surfaces[0].id
        let view = CornerOverlayView(frame: CGRect(x: 0,y: 0,width: 424,height: 424))
        let window = NSWindow(contentRect: view.frame,styleMask: [.titled],backing: .buffered,defer: false)
        window.isReleasedWhenClosed = false; window.contentView = view
        defer { window.contentView = nil; window.close() }
        func configure(_ locked: Bool) {
            view.configure(surfaceID: id,corners: s.project.surfaces[0].corners,activeCorner: s.selectedCorner,
                select: { s.selectCorner($0) },move: { s.moveSelectedCorner(to: $0,surfaceID: id) },
                nudge: { s.nudgeSelectedCorner(direction: $0,larger: $1) },isLocked: locked)
        }
        func mouse(_ type: NSEvent.EventType,_ point: CGPoint) throws -> NSEvent {
            try #require(NSEvent.mouseEvent(with: type,location: view.convert(point,to: nil),modifierFlags: [],timestamp: 0,
                windowNumber: window.windowNumber,context: nil,eventNumber: 1,clickCount: 1,pressure: 1))
        }
        let arrow = try #require(NSEvent.keyEvent(with: .keyDown,location: .zero,modifierFlags: .shift,timestamp: 0,windowNumber: window.windowNumber,context: nil,characters: "",charactersIgnoringModifiers: "",isARepeat: true,keyCode: 124))
        s.setGeometryLocked(true,faceID: id); configure(true); let before = s.project
        let center = SurfaceCoordinates.position(s.project.surfaces[0].corners.topLeft,in: view.previewRect)
        view.mouseDown(with: try mouse(.leftMouseDown,center)); view.mouseDragged(with: try mouse(.leftMouseDragged,CGPoint(x: center.x+40,y: center.y+40))); view.keyDown(with: arrow)
        #expect(s.project == before && s.selectedSurfaceID == id && window.firstResponder === view)
        s.setGeometryLocked(false,faceID: id); configure(false)
        view.mouseDown(with: try mouse(.leftMouseDown,center))
        s.setGeometryLocked(true,faceID: id); configure(true); let interrupted = s.project
        s.setGeometryLocked(false,faceID: id); configure(false)
        view.mouseDragged(with: try mouse(.leftMouseDragged,CGPoint(x: center.x+40,y: center.y+40)))
        #expect(s.project.surfaces[0].corners == interrupted.surfaces[0].corners)
        view.keyDown(with: arrow); #expect(abs(s.project.surfaces[0].corners.topLeft.x-0.26) < 0.000001)
    }
    @Test func nativeObjectCenterDragAndArrowKeysMoveTogetherAndHonorLocks() throws {
        _ = NSApplication.shared
        let s = EditorSession(); s.addSurface(); s.createObject(faceIDs: Set(s.project.surfaces.map(\.id)))
        let id = try #require(s.selectedObjectID)
        let view = CornerOverlayView(frame: CGRect(x: 0,y: 0,width: 424,height: 624))
        let window = NSWindow(contentRect: view.frame,styleMask: [.titled],backing: .buffered,defer: false)
        window.isReleasedWhenClosed = false; window.contentView = view
        defer { window.contentView = nil; window.close() }
        func configure() {
            view.configure(surfaceID: nil,corners: .diagnostic,activeCorner: nil,select: { s.selectCorner($0) },move: { _ in },nudge: { _,_ in },
                isLocked: !s.project.canMoveObject(id),objectID: id,objectBounds: s.project.outputBounds(forObject: id),
                moveObject: { s.moveObject(id,by: $0) },nudgeObject: { s.nudgeSelectedObject(direction: $0,larger: $1) })
        }
        func mouse(_ type: NSEvent.EventType,_ point: CGPoint) throws -> NSEvent {
            try #require(NSEvent.mouseEvent(with: type,location: view.convert(point,to: nil),modifierFlags: [],timestamp: 0,
                windowNumber: window.windowNumber,context: nil,eventNumber: 1,clickCount: 1,pressure: 1))
        }
        let arrow = try #require(NSEvent.keyEvent(with: .keyDown,location: .zero,modifierFlags: .shift,timestamp: 0,windowNumber: window.windowNumber,context: nil,characters: "",charactersIgnoringModifiers: "",isARepeat: true,keyCode: 124))
        configure(); let before = s.project
        let center = SurfaceCoordinates.position(SIMD2(0.5,0.5),in: view.previewRect)
        view.mouseDown(with: try mouse(.leftMouseDown,center)); view.mouseDragged(with: try mouse(.leftMouseDragged,CGPoint(x: center.x+40,y: center.y+60)))
        configure(); view.mouseUp(with: try mouse(.leftMouseUp,CGPoint(x: center.x+40,y: center.y+60))); view.keyDown(with: arrow)
        for (old,new) in zip(before.surfaces,s.project.surfaces) {
            #expect(abs(new.corners.topLeft.x-old.corners.topLeft.x-0.11) < 0.000001 && abs(new.corners.topLeft.y-old.corners.topLeft.y-0.1) < 0.000001)
            #expect(new.layout.inputMap == old.layout.inputMap)
        }
        s.setGeometryLocked(true,objectID: id); configure(); let locked = s.project
        view.keyDown(with: arrow)
        let movedCenter = SurfaceCoordinates.position(SIMD2(0.61,0.6),in: view.previewRect)
        view.mouseDown(with: try mouse(.leftMouseDown,movedCenter)); view.mouseDragged(with: try mouse(.leftMouseDragged,CGPoint(x: movedCenter.x+30,y: movedCenter.y+30)))
        #expect(s.project == locked && s.selectedObjectID == id)
    }

}
