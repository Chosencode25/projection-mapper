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

    func makeNSView(context: Context) -> CornerOverlayView { CornerOverlayView() }
    func updateNSView(_ view: CornerOverlayView, context: Context) {
        view.configure(surfaceID: surfaceID, corners: corners, activeCorner: activeCorner,
                       select: select, move: move, nudge: nudge, deselect: deselect, selectFace: selectFace)
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
                   selectFace: ((SIMD2<Float>?) -> Void)? = nil) {
        if self.surfaceID != surfaceID || (dragging != nil && activeCorner != dragging) { dragging = nil }
        self.surfaceID = surfaceID
        self.corners = corners
        self.activeCorner = activeCorner
        self.select = select; self.move = move; self.nudge = nudge; self.deselect = deselect; self.selectFace = selectFace
        setAccessibilityValue(activeCorner.map { "\($0.title) selected" } ?? "Click a corner to edit")
        needsDisplay = true
    }

    override func draw(_ dirtyRect: NSRect) {
        guard surfaceID != nil, previewRect.width > 0, previewRect.height > 0 else { return }
        let points = SurfaceCorner.allCases.map { SurfaceCoordinates.position(corners[$0], in: previewRect) }
        let outline = NSBezierPath()
        outline.move(to: points[0]); points.dropFirst().forEach { outline.line(to: $0) }; outline.close()
        NSColor.systemPurple.setStroke(); outline.lineWidth = 1.5; outline.stroke()
        for (corner, point) in zip(SurfaceCorner.allCases, points) {
            let circle = NSBezierPath(ovalIn: CGRect(x: point.x - 6, y: point.y - 6, width: 12, height: 12))
            (corner == activeCorner ? NSColor.systemPurple : NSColor.white).setFill(); circle.fill()
            NSColor.black.setStroke(); circle.lineWidth = 2; circle.stroke()
        }
    }

    override func mouseDown(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
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
        dragging = corner; activeCorner = corner
        select(corner); window?.makeFirstResponder(self); needsDisplay = true
    }
    override func mouseDragged(with event: NSEvent) {
        guard dragging != nil else { return }
        let point = convert(event.locationInWindow, from: nil)
        if let normalized = SurfaceCoordinates.normalized(
            CGPoint(x: point.x - grabOffset.width, y: point.y - grabOffset.height), in: previewRect) {
            move(normalized)
        }
    }
    override func mouseUp(with event: NSEvent) { dragging = nil }

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
        if event.keyCode == 53 { activeCorner = nil; dragging = nil; select(nil); needsDisplay = true; return }
        if activeCorner != nil, let direction = Self.direction(keyCode: event.keyCode, modifiers: event.modifierFlags) {
            nudge(direction, event.modifierFlags.contains(.shift))
        } else { super.keyDown(with: event) }
    }
    private func distance(_ a: CGPoint, _ b: CGPoint) -> CGFloat { hypot(a.x - b.x, a.y - b.y) }
}
