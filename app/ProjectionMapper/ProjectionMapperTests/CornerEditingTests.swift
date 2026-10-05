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
        session.moveSelectedCorner(to: SIMD2(.nan,0.2), surfaceID: project.surface.id)
        session.moveSelectedCorner(to: project.surface.corners.topLeft, surfaceID: project.surface.id)
        #expect(session.project == project)
        let changed = Date(timeIntervalSince1970: 900)
        session.moveSelectedCorner(to: SIMD2(-3,2), surfaceID: project.surface.id, now: changed)
        #expect(session.project.surface.corners.topLeft == SIMD2(0,1))
        #expect(session.project.modifiedAt == changed && session.project.createdAt == project.createdAt)
        #expect(session.project.surface.id == project.surface.id && session.hasUserChanges)
        session.moveSelectedCorner(to: SIMD2(-3,2), surfaceID: project.surface.id, now: .distantFuture)
        #expect(session.project.modifiedAt == changed)
    }

    @Test func nudgesUseNormalAndShiftStepsAndRespectEdges() {
        let session = EditorSession()
        session.selectCorner(.topRight)
        session.nudgeSelectedCorner(direction: SIMD2(1,0), larger: false)
        #expect(abs(session.project.surface.corners.topRight.x - 0.751) < 0.000001)
        session.nudgeSelectedCorner(direction: SIMD2(0,-1), larger: true)
        #expect(abs(session.project.surface.corners.topRight.y - 0.24) < 0.000001)
        session.moveSelectedCorner(to: SIMD2(1,0), surfaceID: session.project.surface.id)
        let before = session.project
        session.nudgeSelectedCorner(direction: SIMD2(1,-1), larger: true)
        #expect(session.project == before)
    }

    @Test func selectionResetAndPresetsKeepCornerStateConsistent() {
        let session = EditorSession(presentOutput: { _ in })
        session.selectCorner(.bottomLeft)
        session.moveSelectedCorner(to: SIMD2(0.1,0.8), surfaceID: session.project.surface.id)
        let edited = session.project.surface
        for preset in TestResolution.allCases {
            session.setTestResolution(preset)
            session.testOutput.open(for: .testWindow, resolution: preset)
            session.testOutput.close()
            #expect(session.selectedCorner == .bottomLeft && session.project.surface == edited)
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
        #expect(session.scene == .diagnostic)
    }

    @Test func nativeDragPreservesGrabOffsetAndOwnsKeyboardFocus() throws {
        _ = NSApplication.shared
        let session = EditorSession()
        let view = CornerOverlayView(frame: CGRect(x: 0,y: 0,width: 424,height: 624))
        let window = NSWindow(contentRect: view.frame, styleMask: [.titled], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false; window.contentView = view
        defer { window.contentView = nil; window.close() }
        let id = session.project.surface.id
        view.configure(surfaceID: id, corners: session.project.surface.corners, activeCorner: nil,
                       select: { session.selectCorner($0) },
                       move: { session.moveSelectedCorner(to: $0, surfaceID: id) },
                       nudge: { session.nudgeSelectedCorner(direction: $0, larger: $1) })
        let center = SurfaceCoordinates.position(session.project.surface.corners.topLeft, in: view.previewRect)
        func mouse(_ type: NSEvent.EventType, _ point: CGPoint) throws -> NSEvent {
            try #require(NSEvent.mouseEvent(with: type, location: view.convert(point, to: nil),
                modifierFlags: [], timestamp: 0, windowNumber: window.windowNumber,
                context: nil, eventNumber: 1, clickCount: 1, pressure: 1))
        }
        view.mouseDown(with: try mouse(.leftMouseDown, CGPoint(x: center.x + 4, y: center.y + 3)))
        #expect(window.firstResponder === view && session.selectedCorner == .topLeft && !session.hasUserChanges)
        view.mouseDragged(with: try mouse(.leftMouseDragged, CGPoint(x: center.x + 44, y: center.y + 63)))
        #expect(abs(session.project.surface.corners.topLeft.x - 0.35) < 0.000001)
        #expect(abs(session.project.surface.corners.topLeft.y - 0.35) < 0.000001)
        let key = try #require(NSEvent.keyEvent(with: .keyDown, location: .zero, modifierFlags: .shift,
            timestamp: 0, windowNumber: window.windowNumber, context: nil, characters: "", charactersIgnoringModifiers: "",
            isARepeat: true, keyCode: 124))
        view.keyDown(with: key)
        #expect(abs(session.project.surface.corners.topLeft.x - 0.36) < 0.000001)
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
}
