import AppKit
import SwiftUI

struct CornerOverlay: NSViewRepresentable {
    let surfaceID: UUID?
    let corners: NormalizedRectangle
    let activeCorner: SurfaceCorner?
    let select: (SurfaceCorner?) -> Void
    let move: (SIMD2<Float>) -> Void
    let nudge: (SIMD2<Float>, Bool) -> Void
    var deselect: () -> Void = {}
    var selectFace: ((SIMD2<Float>?) -> Void)?
    var isLocked = false
    var objectID: UUID?
    var objectBounds: NormalizedRectangle?
    var moveObject: ((SIMD2<Float>) -> Void)?
    var nudgeObject: ((SIMD2<Float>,Bool) -> Void)?

    func makeNSView(context: Context) -> CornerOverlayView { CornerOverlayView() }
    func updateNSView(_ view: CornerOverlayView, context: Context) {
        view.configure(surfaceID: surfaceID, corners: corners, activeCorner: activeCorner,
                       select: select, move: move, nudge: nudge, deselect: deselect, selectFace: selectFace,isLocked: isLocked,objectID: objectID,objectBounds: objectBounds,moveObject: moveObject,nudgeObject: nudgeObject)
    }
}

/// Editor-only controls above the Metal preview. Native first-responder routing keeps arrows
/// out of text fields and lets key repeat work without an app-wide event monitor.
final class CornerOverlayView: NSView {
    private var surfaceID: UUID?
    private var corners = NormalizedRectangle.diagnostic
    private var activeCorner: SurfaceCorner?
    private var dragging: SurfaceCorner?
    private var grabOffset = CGSize.zero
    private var isLocked = false
    private var objectID: UUID?
    private var objectBounds: NormalizedRectangle?
    private var objectDragPoint: CGPoint?
    private var moveObject: ((SIMD2<Float>) -> Void)?
    private var nudgeObject: ((SIMD2<Float>,Bool) -> Void)?
    private var select: (SurfaceCorner?) -> Void = { _ in }
    private var move: (SIMD2<Float>) -> Void = { _ in }
    private var nudge: (SIMD2<Float>, Bool) -> Void = { _, _ in }
    private var deselect: () -> Void = {}
    private var selectFace: ((SIMD2<Float>?) -> Void)?
    var previewRect: CGRect { bounds.insetBy(dx: 12, dy: 12) }
    override var isFlipped: Bool { true }
    override var acceptsFirstResponder: Bool { true }

    override init(frame: NSRect) {
        super.init(frame: frame)
        setAccessibilityElement(true)
        setAccessibilityRole(.group)
        setAccessibilityLabel("Surface corner controls")
    }
    convenience init() { self.init(frame: .zero) }
    required init?(coder: NSCoder) { fatalError("CornerOverlayView is created in code") }

    func configure(surfaceID: UUID?, corners: NormalizedRectangle, activeCorner: SurfaceCorner?,
                   select: @escaping (SurfaceCorner?) -> Void, move: @escaping (SIMD2<Float>) -> Void,
                   nudge: @escaping (SIMD2<Float>, Bool) -> Void, deselect: @escaping () -> Void = {},
                   selectFace: ((SIMD2<Float>?) -> Void)? = nil,isLocked: Bool = false,
                   objectID: UUID? = nil,objectBounds: NormalizedRectangle? = nil,
                   moveObject: ((SIMD2<Float>) -> Void)? = nil,nudgeObject: ((SIMD2<Float>,Bool) -> Void)? = nil) {
        if self.surfaceID != surfaceID || self.objectID != objectID || isLocked || (dragging != nil && activeCorner != dragging) { dragging = nil; objectDragPoint = nil }
        self.isLocked = isLocked; self.objectID = objectID; self.objectBounds = objectBounds; self.moveObject = moveObject; self.nudgeObject = nudgeObject
        self.surfaceID = surfaceID
        self.corners = corners
        self.activeCorner = activeCorner
        self.select = select; self.move = move; self.nudge = nudge; self.deselect = deselect; self.selectFace = selectFace
        setAccessibilityValue(isLocked ? "Output geometry locked; select or unlock in inspector" : objectID != nil ? "Drag object center handle or use arrows to move all faces" : activeCorner.map { "\($0.title) selected" } ?? "Click a corner to edit")
        needsDisplay = true
    }

    override func draw(_ dirtyRect: NSRect) {
        guard previewRect.width > 0, previewRect.height > 0 else { return }
        if objectID != nil, let box = objectBounds {
            let topLeft = SurfaceCoordinates.position(box.topLeft,in: previewRect), bottomRight = SurfaceCoordinates.position(box.bottomRight,in: previewRect)
            let frame = CGRect(x: topLeft.x,y: topLeft.y,width: bottomRight.x-topLeft.x,height: bottomRight.y-topLeft.y)
            let outline = NSBezierPath(rect: frame); outline.lineWidth = 1.5
            outline.setLineDash([5,3],count: 2,phase: 0)
            (isLocked ? NSColor.systemGray : NSColor.systemPurple).setStroke(); outline.stroke()
            let handle = NSBezierPath(rect: CGRect(x: frame.midX-7,y: frame.midY-7,width: 14,height: 14))
            (isLocked ? NSColor.systemGray : NSColor.systemPurple).setFill(); handle.fill()
            return
        }
        guard surfaceID != nil else { return }
        let points = SurfaceCorner.allCases.map { SurfaceCoordinates.position(corners[$0], in: previewRect) }
        let outline = NSBezierPath()
        outline.move(to: points[0]); points.dropFirst().forEach { outline.line(to: $0) }; outline.close()
        (isLocked ? NSColor.systemGray : NSColor.systemPurple).setStroke(); outline.lineWidth = 1.5; outline.stroke()
        for (corner, point) in zip(SurfaceCorner.allCases, points) {
            let circle = NSBezierPath(ovalIn: CGRect(x: point.x - 6, y: point.y - 6, width: 12, height: 12))
            (isLocked ? NSColor.systemGray : corner == activeCorner ? NSColor.systemPurple : NSColor.white).setFill(); circle.fill()
            NSColor.black.setStroke(); circle.lineWidth = 2; circle.stroke()
        }
    }

    override func mouseDown(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        if objectID != nil, let box = objectBounds,previewRect.width > 0,previewRect.height > 0 {
            let center = SurfaceCoordinates.position((box.topLeft+box.bottomRight)*0.5,in: previewRect)
            if distance(point,center) <= 12 {
                dragging = nil; objectDragPoint = isLocked ? nil : point
                select(nil); window?.makeFirstResponder(self); needsDisplay = true; return
            }
        }
        objectDragPoint = nil
        // Prefer the inspector-selected handle when corners overlap, so each can be recovered.
        let activeHit = activeCorner.flatMap { corner in
            distance(point, SurfaceCoordinates.position(corners[corner], in: previewRect)) <= 12 ? corner : nil
        }
        let nearest = activeHit ?? SurfaceCorner.allCases.min {
            distance(point, SurfaceCoordinates.position(corners[$0], in: previewRect)) <
            distance(point, SurfaceCoordinates.position(corners[$1], in: previewRect))
        }
        guard surfaceID != nil, previewRect.width > 0, previewRect.height > 0, let corner = nearest,
              distance(point, SurfaceCoordinates.position(corners[corner], in: previewRect)) <= 12 else {
            dragging = nil; activeCorner = nil; select(nil)
            if let selectFace {
                selectFace(previewRect.contains(point) ? SurfaceCoordinates.normalized(point, in: previewRect) : nil)
            } else { deselect() }
            window?.makeFirstResponder(self); needsDisplay = true; return
        }
        let center = SurfaceCoordinates.position(corners[corner], in: previewRect)
        grabOffset = CGSize(width: point.x - center.x, height: point.y - center.y)
        dragging = isLocked ? nil : corner; activeCorner = corner
        select(corner); window?.makeFirstResponder(self); needsDisplay = true
    }
    override func mouseDragged(with event: NSEvent) {
        guard !isLocked else { return }
        let point = convert(event.locationInWindow, from: nil)
        if let previous = objectDragPoint,previewRect.width > 0,previewRect.height > 0 {
            objectDragPoint = point
            moveObject?(SIMD2(Float((point.x-previous.x)/previewRect.width),Float((point.y-previous.y)/previewRect.height)))
            return
        }
        guard dragging != nil else { return }
        if let normalized = SurfaceCoordinates.normalized(
            CGPoint(x: point.x - grabOffset.width, y: point.y - grabOffset.height), in: previewRect) {
            move(normalized)
        }
    }
    override func mouseUp(with event: NSEvent) { dragging = nil; objectDragPoint = nil }

    static func direction(keyCode: UInt16, modifiers: NSEvent.ModifierFlags) -> SIMD2<Float>? {
        guard modifiers.intersection([.command, .control, .option]).isEmpty else { return nil }
        switch keyCode {
        case 123: return SIMD2(-1, 0)
        case 124: return SIMD2(1, 0)
        case 125: return SIMD2(0, 1)
        case 126: return SIMD2(0, -1)
        default: return nil
        }
    }
    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 { activeCorner = nil; dragging = nil; objectDragPoint = nil; select(nil); needsDisplay = true; return }
        if let direction = Self.direction(keyCode: event.keyCode, modifiers: event.modifierFlags), objectID != nil || activeCorner != nil {
            guard !isLocked else { return }
            if objectID != nil { nudgeObject?(direction,event.modifierFlags.contains(.shift)) }
            else { nudge(direction, event.modifierFlags.contains(.shift)) }
        } else { super.keyDown(with: event) }
    }
    private func distance(_ a: CGPoint, _ b: CGPoint) -> CGFloat { hypot(a.x - b.x, a.y - b.y) }
}
