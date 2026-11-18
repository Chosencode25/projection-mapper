import AppKit
import SwiftUI
import simd

struct EditorCanvasView: View {
    let session: EditorSession
    @Environment(\.displayScale) private var displayScale
    @State private var pansCanvas = false
    @GestureState private var pinchScale = 1.0
    @GestureState private var panDelta = CGSize.zero
    @State private var pendingDrop: URL?
    @State private var isDropTarget = false
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
                        } else if let id = session.selectedVisualID, session.selectedClip == nil, !session.isMaskEditing {
                            VisualPlacementOverlay(session: session, visualID: id).frame(width: width, height: height)
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
                        session.selectSurface(at: SIMD2(Float(location.x/max(1,width)),Float(location.y/max(1,height))))
                        if let face = session.selectedSurface, let object = session.project.object(for: face) {
                            pendingDrop = url; dropFaceID = face.id; dropOwnerID = object.source.id
                        } else {
                            let target = session.selectedImageTarget ?? .newFace
                            Task { await session.importMedia(from: url,target: target) }
                        }
                        return true
                    } isTargeted: { isDropTarget = $0 }
                    .overlay {
                        if isDropTarget {
                            RoundedRectangle(cornerRadius: 8).stroke(Color.accentColor, lineWidth: 3).allowsHitTesting(false)
                            Label("Drop onto a face or empty canvas", systemImage: "square.and.arrow.down")
                                .padding(8).background(.regularMaterial, in: Capsule()).allowsHitTesting(false)
                        }
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
            if session.isMaskEditing || session.isRegionEditing {
                Text(canvasHint).font(.caption).foregroundStyle(.secondary).lineLimit(1)
            }
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


/// Converts between the selected visual's coordinates and the mapped face. Matches
/// the renderer's shared input/crop transform and region bounding-box coordinates.
struct VisualCanvasCoordinates {
    let corners: NormalizedRectangle
    let fromFace: simd_float3x3
    init(project: MappingProject, face: MappingSurface, visualID: UUID) {
        corners = face.corners
        if let region = project.regions.first(where: { $0.id == visualID }) {
            let origin = region.shape.points.reduce(SIMD2<Float>(repeating: 1), simd_min)
            let end = region.shape.points.reduce(SIMD2<Float>.zero, simd_max)
            let size = simd_max(end - origin, SIMD2<Float>(repeating: 0.00001))
            fromFace = simd_float3x3(columns: (SIMD3(1 / size.x, 0, 0), SIMD3(0, 1 / size.y, 0), SIMD3(-origin.x / size.x, -origin.y / size.y, 1)))
        } else {
            let map = project.object(for: face)?.mode == .repeatContent ? FaceInputMap.full : face.layout.inputMap
            fromFace = project.appearance(for: face).matrix * map.matrix
        }
    }
    func project(_ point: SIMD2<Float>) -> SIMD2<Float>? {
        let face = fromFace.inverse * SIMD3(point.x, point.y, 1)
        return MaskEditorGeometry.project(SIMD2(face.x, face.y), corners: corners)
    }
    func unproject(_ point: SIMD2<Float>) -> SIMD2<Float>? {
        guard let face = MaskEditorGeometry.unproject(point, corners: corners) else { return nil }
        let local = fromFace * SIMD3(face.x, face.y, 1)
        return SIMD2(local.x, local.y)
    }
}

private struct VisualPlacementOverlay: View {
    let session: EditorSession
    let visualID: UUID
    @State private var dragStart: VisualTrack?
    @State private var dragPoint: SIMD2<Float>?
    private var faces: [MappingSurface] {
        if let region = session.project.regions.first(where: { $0.id == visualID }) {
            return session.project.surfaces.filter { $0.id == region.faceID }
        }
        guard let layer = session.project.layers.first(where: { $0.id == visualID }) else { return [] }
        return session.project.surfaces.filter { session.project.source(for: $0).id == layer.ownerID && $0.layout.isVisible }
    }
    var body: some View {
        GeometryReader { geometry in
            if let track = session.project.visualTrack(visualID) {
                ForEach(faces) { face in
                    let coordinates = VisualCanvasCoordinates(project: session.project, face: face, visualID: visualID)
                    let corners = [SIMD2<Float>(-0.5, -0.5), SIMD2(0.5, -0.5), SIMD2(0.5, 0.5), SIMD2(-0.5, 0.5)]
                    Path { path in
                        let points = corners.compactMap { point(track, offset: $0, coordinates: coordinates, size: geometry.size) }
                        if let first = points.first {
                            path.move(to: first); points.dropFirst().forEach { path.addLine(to: $0) }; path.closeSubpath()
                        }
                    }.stroke(Color.accentColor, style: StrokeStyle(lineWidth: 1.5, dash: [5, 3])).allowsHitTesting(false)
                    handle(track, offset: .zero, mode: 0, coordinates: coordinates, size: geometry.size)
                    ForEach(corners.indices, id: \.self) { index in
                        handle(track, offset: corners[index], mode: 1, coordinates: coordinates, size: geometry.size)
                    }
                    handle(track, offset: SIMD2(0, -0.7), mode: 2, coordinates: coordinates, size: geometry.size)
                }
            }
        }.coordinateSpace(name: visualID)
    }
    private func point(_ track: VisualTrack, offset: SIMD2<Float>, coordinates: VisualCanvasCoordinates, size: CGSize) -> CGPoint? {
        let angle = track.rotation * .pi / 180, delta = offset * track.size
        let rotated = SIMD2(cos(angle) * delta.x - sin(angle) * delta.y, sin(angle) * delta.x + cos(angle) * delta.y)
        guard let output = coordinates.project(track.center + rotated), output.x.isFinite, output.y.isFinite else { return nil }
        return CGPoint(x: CGFloat(output.x) * size.width, y: CGFloat(output.y) * size.height)
    }
    @ViewBuilder private func handle(_ track: VisualTrack, offset: SIMD2<Float>, mode: Int, coordinates: VisualCanvasCoordinates, size: CGSize) -> some View {
        if let position = point(track, offset: offset, coordinates: coordinates, size: size) {
            Circle().fill(Color.accentColor).overlay(Circle().stroke(.white, lineWidth: 1))
                .frame(width: mode == 0 ? 14 : 10, height: mode == 0 ? 14 : 10).position(position)
                .help(mode == 0 ? "Move layer" : mode == 1 ? "Resize layer" : "Rotate layer")
                .accessibilityLabel(mode == 0 ? "Move selected layer" : mode == 1 ? "Resize selected layer" : "Rotate selected layer")
                .gesture(DragGesture(minimumDistance: 0, coordinateSpace: .named(visualID))
                    .onChanged { drag in
                        guard size.width > 0, size.height > 0,
                              let local = coordinates.unproject(SIMD2(Float(drag.location.x / size.width), Float(drag.location.y / size.height))) else { return }
                        if dragStart == nil { dragStart = track; dragPoint = local; session.beginContinuousEdit("Place Layer") }
                        guard let initial = dragStart, let start = dragPoint else { return }
                        session.updateVisual(visualID) { next in
                            if mode == 0 { next.center = simd_clamp(initial.center + local - start, SIMD2(repeating: -1), SIMD2(repeating: 2)) }
                            else if mode == 1 {
                                let delta = local - initial.center, angle = initial.rotation * .pi / 180
                                let unrotated = SIMD2(cos(angle) * delta.x + sin(angle) * delta.y, -sin(angle) * delta.x + cos(angle) * delta.y)
                                next.size = simd_clamp(abs(unrotated) * 2, SIMD2(repeating: 0.01), SIMD2(repeating: 4))
                            } else {
                                let delta = local - initial.center
                                var angle = atan2(delta.y, delta.x) * 180 / .pi + 90
                                if angle > 180 { angle -= 360 }; next.rotation = min(180, max(-180, angle))
                            }
                        }
                    }.onEnded { _ in dragStart = nil; dragPoint = nil; session.endContinuousEdit() })
        }
    }
}
