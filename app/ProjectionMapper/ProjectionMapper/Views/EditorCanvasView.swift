import AppKit
import SwiftUI

struct EditorCanvasView: View {
    let session: EditorSession
    @Environment(\.displayScale) private var displayScale
    @State private var pansCanvas = false
    @GestureState private var pinchScale = 1.0
    @GestureState private var panDelta = CGSize.zero
    @State private var pendingDrop: URL?
    @State private var dropFaceID: UUID?
    @State private var dropOwnerID: UUID?
    var output: OutputSelectionState { session.output }
    private var canvasHint: String {
        if session.isMaskEditing { return "Edit mask · Drag points; finish drawing to apply a new polygon" }
        if let face = session.selectedSurface {
            if session.project.isGeometryLocked(face) { return face.name + " · Corners locked" }
            return face.name + " · Drag a corner · Arrow keys nudge · Shift for larger steps"
        }
        if let object = session.selectedObject { return object.name + " · Drag the center handle to move its faces together" }
        return "Click a visible face to select it · Add a surface or drop image/video media"
    }
    var body: some View {
        VStack(spacing: 7) {
            GeometryReader { geometry in
                let viewport = geometry.size
                let ratio = output.aspectRatio
                let fitWidth = max(0, min(viewport.width - 40, (viewport.height - 16) * ratio))
                let fitted = CGSize(width: fitWidth, height: fitWidth / ratio)
                let zoom = CanvasNavigation.zoom(session.canvasZoom * pinchScale)
                let width = fitted.width * zoom
                let height = fitted.height * zoom
                let center = CanvasNavigation.center(session.canvasCenter, translation: panDelta,
                                                     viewport: viewport, fitted: fitted, zoom: zoom)
                ZStack {
                    ZStack {
                        Color.black
                        ReferencePhotoLayer(session: session)
                        MetalScenePreview(scene: session.editorScene, aspectRatio: ratio, outputDescription: output.renderSizeText)
                    }
                    .frame(width: fitted.width, height: fitted.height)
                    .scaleEffect(zoom)
                    .frame(width: width, height: height)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .overlay {
                        RoundedRectangle(cornerRadius: 8)
                            .strokeBorder(Color.white.opacity(0.13), lineWidth: 1)
                    }
                    .overlay {
                        let surface = session.selectedSurface
                        if session.isRegionEditing, let face = surface,
                           let region = session.project.regions.first(where: { $0.id == session.selectedVisualID && $0.faceID == face.id }) {
                            RegionCanvas(session: session, face: face, region: region, interactive: true)
                                .frame(width: width, height: height)
                        } else if session.isMaskEditing, session.editorDisplay.maskHandles, let face = surface, face.mask != nil {
                            MaskCanvas(session: session,face: face,projected: true)
                                .frame(width: width,height: height).id(face.id)
                        } else {
                            CornerOverlay(surfaceID: surface?.id, corners: surface?.corners ?? .diagnostic,
                                          activeCorner: session.selectedCorner,
                                          select: { session.selectCorner($0) },
                                          move: { point in
                                              if let id = surface?.id { session.moveSelectedCorner(to: point, surfaceID: id) }
                                          },
                                          nudge: { session.nudgeSelectedCorner(direction: $0, larger: $1) },
                                          beginEdit: { session.beginContinuousEdit("Move Mapping") },
                                          endEdit: { session.endContinuousEdit() },
                                          selectFace: { session.selectSurface(at: $0) },
                                          isLocked: surface.map { session.project.isGeometryLocked($0) } ?? session.selectedObject.map { !session.project.canMoveObject($0.id) } ?? false,
                                          showsHandles: session.editorDisplay.cornerHandles,
                                          showsOutlines: session.editorDisplay.outlines,
                                          objectID: session.selectedObjectID,
                                          objectBounds: session.selectedObjectID.flatMap { session.project.outputBounds(forObject: $0) },
                                          moveObject: { delta in if let id = session.selectedObjectID { session.moveObject(id,by: delta) } },
                                          nudgeObject: { session.nudgeSelectedObject(direction: $0,larger: $1) })
                                .frame(width: width + 24, height: height + 24)
                        }
                    }
                    .overlay {
                        ZStack {
                            if session.isMaskEditing, !session.editorDisplay.maskHandles, session.editorDisplay.outlines, let face = session.selectedSurface, face.mask != nil {
                                MaskCanvas(session: session,face: face,projected: true).allowsHitTesting(false)
                            }
                            if !session.isRegionEditing, session.editorDisplay.outlines, let face = session.selectedSurface,
                               let region = session.project.regions.first(where: { $0.id == session.selectedVisualID && $0.faceID == face.id }) {
                                RegionCanvas(session: session, face: face, region: region, interactive: false)
                            }
                            EditorLabelsOverlay(session: session)
                        }.frame(width: width,height: height).allowsHitTesting(false)
                    }
                    .dropDestination(for: URL.self) { urls, location in
                        guard urls.count == 1, let url = urls.first else { session.editMessage = "Drop one PNG, JPEG, MP4 or MOV at a time."; return false }
                        let fallback = session.selectedImageTarget
                        session.selectSurface(at: SIMD2(Float(location.x/max(1,width)),Float(location.y/max(1,height))))
                        if let face = session.selectedSurface, let object = session.project.object(for: face) {
                            pendingDrop = url; dropFaceID = face.id; dropOwnerID = object.source.id
                        } else {
                            let target = session.selectedImageTarget ?? fallback ?? .newFace
                            Task { await session.importMedia(from: url,target: target) }
                        }
                        return true
                    }
                    .position(x: viewport.width / 2 + (0.5 - center.x) * width,
                              y: viewport.height / 2 + (0.5 - center.y) * height)
                    .allowsHitTesting(!pansCanvas)
                    if pansCanvas {
                        Color.clear.contentShape(Rectangle())
                            .gesture(DragGesture()
                                .updating($panDelta) { value, state, _ in state = value.translation }
                                .onEnded { value in
                                    session.canvasCenter = CanvasNavigation.center(session.canvasCenter,
                                        translation: value.translation, viewport: viewport,
                                        fitted: fitted, zoom: zoom)
                                })
                            .accessibilityHidden(true)
                    }
                }
                .frame(width: viewport.width, height: viewport.height)
                .clipped()
                .contentShape(Rectangle())
                .background {
                    CanvasScrollMonitor { delta in
                        guard CanvasNavigation.canPan(viewport: viewport, fitted: fitted, zoom: zoom) else { return false }
                        session.canvasCenter = CanvasNavigation.center(session.canvasCenter, translation: delta,
                                                                         viewport: viewport, fitted: fitted, zoom: zoom)
                        return true
                    }
                }
                .simultaneousGesture(MagnifyGesture()
                    .updating($pinchScale) { value, state, _ in state = value.magnification }
                    .onEnded { value in
                        setZoom(session.canvasZoom * value.magnification)
                    })
                .overlay(alignment: .topLeading) {
                    canvasControls(fitted: fitted, viewport: viewport)
                        .padding(8)
                }
            }
            Text(pansCanvas ? "Drag to pan · turn off Pan to edit" : canvasHint)
                .font(.caption).foregroundStyle(.secondary).lineLimit(1)
                .help(canvasHint + " · " + output.selectedName + " · " + output.renderSizeText)
            Group {
                if session.scene.invalidCount > 0 || !session.project.joinWarnings.isEmpty || !session.imageProblems.isEmpty ||
                    !session.videoProblems.isEmpty || !session.videoPlayback.problems.isEmpty {
                    Label("Check mapping or missing media in the inspector", systemImage: "exclamationmark.triangle")
                        .font(.caption).foregroundStyle(.orange).lineLimit(1)
                } else {
                    Color.clear.accessibilityHidden(true)
                }
            }.frame(height: 16)
        }
        .padding(.bottom, 8)
        .onChange(of: session.project.id) { _, _ in fitCanvas() }
        .confirmationDialog("Import media for the shared object or just this face?",isPresented: Binding(get: { pendingDrop != nil },set: { if !$0 { pendingDrop = nil } }),titleVisibility: .visible) {
            if let url = pendingDrop, let owner = dropOwnerID, let face = dropFaceID {
                Button("Replace content on all object faces") { pendingDrop = nil; Task { await session.importMedia(from: url,target: .owner(owner)) } }
                Button("Detach and import on this face") {
                    pendingDrop = nil
                    guard let current = session.project.surfaces.first(where: { $0.id == face }), session.project.source(for: current).id == owner else {
                        session.editMessage = "The dropped-on face changed. Drop the media again."; return
                    }
                    Task { await session.importMedia(from: url,target: .detach(face)) }
                }
                Button("Cancel",role: .cancel) { pendingDrop = nil }
            }
        }
        .background(Color(red: 0.085, green: 0.09, blue: 0.105))
    }

    private var selectedBounds: NormalizedRectangle? {
        if let surface = session.selectedSurface { return surface.corners }
        return session.selectedObjectID.flatMap { session.project.outputBounds(forObject: $0) }
    }

    private func setZoom(_ zoom: Double) { session.canvasZoom = CanvasNavigation.zoom(zoom) }

    private func fitCanvas() {
        session.canvasZoom = 1
        session.canvasCenter = CGPoint(x: 0.5, y: 0.5)
    }

    private func canvasControls(fitted: CGSize, viewport: CGSize) -> some View {
        HStack(spacing: 7) {
            Button { setZoom(session.canvasZoom / 1.25) } label: { Image(systemName: "minus.magnifyingglass") }
                .accessibilityLabel("Zoom canvas out")
            Button { setZoom(session.canvasZoom * 1.25) } label: { Image(systemName: "plus.magnifyingglass") }
                .accessibilityLabel("Zoom canvas in")
            Button("Fit", action: fitCanvas)
            Button("100%") {
                let pixels = output.selectedDisplay?.renderWidth.map(Double.init) ?? output.testResolution.size.width
                setZoom(pixels / max(1, fitted.width * displayScale))
                session.canvasCenter = CGPoint(x: 0.5, y: 0.5)
            }.help("Match one output pixel to one screen pixel where zoom limits allow")
            Button("Selection") {
                guard let bounds = selectedBounds else { return }
                let target = CanvasNavigation.selection(bounds, viewport: viewport, fitted: fitted)
                session.canvasZoom = target.zoom
                session.canvasCenter = target.center
            }.disabled(selectedBounds == nil).help("Zoom to the selected face or object")
            Toggle("Pan", isOn: $pansCanvas).toggleStyle(.button)
            Text(session.canvasZoom.formatted(.number.precision(.fractionLength(0...1))) + "× Fit")
                .font(.caption.monospacedDigit()).foregroundStyle(.secondary)
        }.controlSize(.small).padding(5).background(.regularMaterial, in: RoundedRectangle(cornerRadius: 7))
    }

}


enum CanvasNavigation {
    static func zoom(_ value: Double) -> Double { min(16, max(0.25, value)) }

    static func canPan(viewport: CGSize, fitted: CGSize, zoom: Double) -> Bool {
        fitted.width * zoom > viewport.width || fitted.height * zoom > viewport.height
    }

    static func center(_ current: CGPoint, translation: CGSize, viewport: CGSize,
                       fitted: CGSize, zoom: Double) -> CGPoint {
        func axis(_ focus: Double, _ movement: Double, _ viewport: Double, _ length: Double) -> Double {
            guard length > viewport, length > 0 else { return 0.5 }
            let margin = viewport / (2 * length)
            return min(1 - margin, max(margin, focus - movement / length))
        }
        return CGPoint(x: axis(current.x, translation.width, viewport.width, fitted.width * zoom),
                       y: axis(current.y, translation.height, viewport.height, fitted.height * zoom))
    }

    static func selection(_ bounds: NormalizedRectangle, viewport: CGSize, fitted: CGSize)
        -> (zoom: Double, center: CGPoint) {
        let points = [bounds.topLeft, bounds.topRight, bounds.bottomRight, bounds.bottomLeft]
        let x = points.map { Double($0.x) }
        let y = points.map { Double($0.y) }
        let left = x.min() ?? 0
        let right = x.max() ?? 1
        let top = y.min() ?? 0
        let bottom = y.max() ?? 1
        let horizontal = max(1, viewport.width - 64) / max(1, (right - left) * fitted.width)
        let vertical = max(1, viewport.height - 64) / max(1, (bottom - top) * fitted.height)
        return (zoom(min(horizontal, vertical)), CGPoint(x: (left + right) / 2, y: (top + bottom) / 2))
    }
}


/// Observes precise scrolls only within the canvas without intercepting mapping clicks.
private struct CanvasScrollMonitor: NSViewRepresentable {
    let pan: (CGSize) -> Bool

    func makeNSView(context: Context) -> ScrollRegion { ScrollRegion() }

    func updateNSView(_ view: ScrollRegion, context: Context) { view.pan = pan }

    static func dismantleNSView(_ view: ScrollRegion, coordinator: ()) {
        view.stopMonitoring()
    }

    final class ScrollRegion: NSView {
        var pan: ((CGSize) -> Bool)?
        private var monitor: Any?

        override func hitTest(_ point: NSPoint) -> NSView? { nil }

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            stopMonitoring()
            guard window != nil else { return }
            monitor = NSEvent.addLocalMonitorForEvents(matching: .scrollWheel) { [weak self] event in
                guard let self, let window = self.window, event.window === window,
                      !self.isHiddenOrHasHiddenAncestor, event.hasPreciseScrollingDeltas,
                      self.visibleRect.contains(self.convert(event.locationInWindow, from: nil)) else { return event }
                let delta = CGSize(width: event.scrollingDeltaX, height: event.scrollingDeltaY)
                guard delta != .zero, self.pan?(delta) == true else { return event }
                return nil
            }
        }

        func stopMonitoring() {
            if let monitor { NSEvent.removeMonitor(monitor) }
            monitor = nil
        }
    }
}
