import SwiftUI
import simd

struct MaskControls: View {
    @Bindable var session: EditorSession
    let face: MappingSurface
    @State private var confirmRemove = false
    private var ring: MaskPolygon? { face.mask?.rings.first { $0.id == session.selectedMaskRingID } }
    var body: some View {
        VStack(alignment: .leading,spacing: 8) {
            Text("FACE MASK & CUTOUTS").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
            if let mask = face.mask {
                Toggle("Enable mask",isOn: Binding(get: { mask.isEnabled },set: { enabled in var next = mask; next.isEnabled = enabled; session.setMask(next,faceID: face.id) }))
                Toggle("Edit mask in preview",isOn: Binding(get: { session.isMaskEditing },set: { enabled in
                    if enabled { var display = session.editorDisplay; display.maskHandles = true; session.setEditorDisplay(display) }
                    session.isMaskEditing = enabled
                }))
                    .onChange(of: session.isMaskEditing) { _, enabled in
                        if enabled, session.selectedMaskRingID == nil { session.selectMaskRing(mask.boundary.id) }
                        if !enabled { session.cancelMaskDrawing() }
                    }
                Picker("Polygon",selection: Binding(get: { session.selectedMaskRingID ?? mask.boundary.id },set: { session.selectMaskRing($0) })) {
                    Text("Outer boundary").tag(mask.boundary.id)
                    ForEach(Array(mask.holes.enumerated()),id: \.element.id) { index,hole in Text("Hole \(index+1)").tag(hole.id) }
                }
                if session.maskDraft != nil {
                    Text("Click points in the preview or square below, then Finish (3–32 points). Drawing stays unsaved until Finish.").font(.caption)
                    Text("\(session.maskDraft?.count ?? 0) points").font(.caption)
                    HStack {
                        Button("Finish") { session.finishMaskDrawing() }.disabled((session.maskDraft?.count ?? 0) < 3)
                        Button("Back") { session.removeLastMaskDraftPoint() }.disabled(session.maskDraft?.isEmpty != false)
                        Button("Cancel") { session.cancelMaskDrawing() }
                    }
                } else {
                    HStack {
                        Button("Draw boundary") { session.beginMaskDrawing(hole: false) }
                        Button("Draw hole") { session.beginMaskDrawing(hole: true) }.disabled(mask.holes.count >= FaceMask.maxHoles)
                    }
                    HStack {
                        Button("Add point") { session.insertMaskPoint() }.disabled((ring?.points.count ?? 32) >= 32)
                        Button("Delete point") { session.deleteMaskPoint() }.disabled(session.selectedMaskVertex == nil || (ring?.points.count ?? 0) <= 3)
                    }
                    Button("Remove selected hole") { session.removeSelectedMaskHole() }.disabled(ring?.id == mask.boundary.id || ring == nil)
                }
                MaskCanvas(session: session,face: face,projected: false)
                    .frame(width: 160,height: 160).background(Color.black.opacity(0.25)).border(Color.secondary.opacity(0.4))
                if let ring, let i = session.selectedMaskVertex, ring.points.indices.contains(i) {
                    Text("Point \(i+1) · original face coordinates").font(.caption)
                    ForEach(0..<2,id: \.self) { axis in
                        HStack {
                        Text(axis == 0 ? "X" : "Y").font(.caption)
                        TextField(axis == 0 ? "X" : "Y",value: Binding(get: { Double(ring.points[i][axis]) },set: { value in
                            var p = ring.points[i]; p[axis] = Float(value)
                            session.moveMaskPoint(p,faceID: face.id,ringID: ring.id,index: i)
                        }),format: .number.precision(.fractionLength(0...4)))
                        .textFieldStyle(.roundedBorder).accessibilityLabel("Mask point \(axis == 0 ? "X" : "Y")")
                        }
                    }
                }
                if let message = mask.validationMessage {
                    Text(message + (mask.isEnabled ? " This face is suppressed until repaired or disabled." : " Mask is disabled; repair it before enabling."))
                        .font(.caption).foregroundStyle(.orange).fixedSize(horizontal: false,vertical: true)
                }
                Button("Remove mask…",role: .destructive) { confirmRemove = true }
                Text("Drag points in either editor. Add point splits the selected edge. Holes reveal lower faces. Masks follow output corners and stay fixed when content crops or input regions change.")
                    .font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false,vertical: true)
                if PerspectiveTransform(face.corners) == nil {
                    Text("Output corners are invalid; use the face-local square to repair your mask.").font(.caption).foregroundStyle(.orange)
                }
            } else { Button("Add face mask") { session.createMask(faceID: face.id) } }
        }
        .onAppear {
            if let mask = face.mask, !mask.rings.contains(where: { $0.id == session.selectedMaskRingID }) { session.selectMaskRing(mask.boundary.id) }
        }
        .confirmationDialog("Remove this face's boundary and all cutout holes?",isPresented: $confirmRemove,titleVisibility: .visible) {
            Button("Remove mask",role: .destructive) { session.setMask(nil,faceID: face.id) }
        }
    }
}

/// Editor-only. Both the projected preview and local fallback edit the same original UV data.
struct MaskCanvas: View {
    @Bindable var session: EditorSession
    let face: MappingSurface
    let projected: Bool
    private var space: String { "mask-\(face.id)-\(projected)" }
    private func display(_ p: SIMD2<Float>,size: CGSize) -> CGPoint? {
        guard let uv = MaskEditorGeometry.project(p,corners: projected ? face.corners : nil) else { return nil }
        return CGPoint(x: Double(uv.x)*size.width,y: Double(uv.y)*size.height)
    }
    private func local(_ p: CGPoint,size: CGSize) -> SIMD2<Float>? {
        guard size.width > 0, size.height > 0 else { return nil }
        return MaskEditorGeometry.unproject(SIMD2(Float(p.x/size.width),Float(p.y/size.height)),corners: projected ? face.corners : nil)
    }
    private func path(_ points: [SIMD2<Float>],size: CGSize,closed: Bool) -> Path {
        Path { path in
            let vertices = points.compactMap { display($0,size: size) }
            if let first = vertices.first { path.move(to: first); for point in vertices.dropFirst() { path.addLine(to: point) }; if closed { path.closeSubpath() } }
        }
    }
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color.clear.contentShape(Rectangle())
                    .onTapGesture(coordinateSpace: .local) { position in
                        guard let uv = local(position,size: geometry.size) else { return }
                        if session.maskDraft != nil { session.appendMaskDraft(uv,faceID: face.id) }
                        else { session.selectedMaskVertex = nil }
                    }
                ForEach(face.mask?.rings ?? []) { ring in
                    if !projected || session.editorDisplay.outlines {
                    path(ring.points,size: geometry.size,closed: true)
                        .stroke(ring.id == face.mask?.boundary.id ? Color.cyan : Color.orange,
                                style: StrokeStyle(lineWidth: ring.id == session.selectedMaskRingID ? 2 : 1,dash: [4,3]))
                        .allowsHitTesting(false)
                    }
                    if session.maskDraft == nil && (!projected || session.editorDisplay.maskHandles) {
                        ForEach(Array(ring.points.enumerated()),id: \.offset) { index,point in
                            if let position = display(point,size: geometry.size) {
                                Circle().fill(ring.id == session.selectedMaskRingID && index == session.selectedMaskVertex ? Color.yellow : Color.white)
                                    .overlay(Circle().stroke(Color.black,lineWidth: 1)).frame(width: 12,height: 12)
                                    .position(position)
                                    .gesture(DragGesture(minimumDistance: 0,coordinateSpace: .named(space))
                                        .onChanged { drag in
                                            guard !projected || session.editorDisplay.maskHandles else { return }
                                            session.selectedMaskRingID = ring.id; session.selectedMaskVertex = index
                                            if let uv = local(drag.location,size: geometry.size) {
                                                session.moveMaskPoint(uv,faceID: face.id,ringID: ring.id,index: index)
                                            }
                                        })
                                    .accessibilityLabel("\(ring.id == face.mask?.boundary.id ? "Boundary" : "Hole") point \(index+1)")
                            }
                        }
                    }
                }
                if let draft = session.maskDraft {
                    path(draft,size: geometry.size,closed: false).stroke(Color.yellow,lineWidth: 2).allowsHitTesting(false)
                    ForEach(Array(draft.enumerated()),id: \.offset) { _,point in
                        if let position = display(point,size: geometry.size) { Circle().fill(Color.yellow).frame(width: 7,height: 7).position(position).allowsHitTesting(false) }
                    }
                }
            }.coordinateSpace(name: space)
        }
    }
}
