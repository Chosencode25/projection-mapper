import SwiftUI

struct EditorDisplayMenu: View {
    let session: EditorSession
    private func binding(_ key: WritableKeyPath<EditorDisplayState,Bool>) -> Binding<Bool> {
        Binding(get: { session.editorDisplay[keyPath: key] },set: { next in var value = session.editorDisplay; value[keyPath: key] = next; session.setEditorDisplay(value) })
    }
    var body: some View {
        Toggle("Corner and object handles",isOn: binding(\.cornerHandles))
        Toggle("Mask handles",isOn: binding(\.maskHandles))
        Toggle("Mapping outlines",isOn: binding(\.outlines))
        Divider()
        Toggle("Face and object names",isOn: binding(\.faceLabels))
        Toggle("Selected face/object edge labels",isOn: binding(\.edgeLabels))
        Divider()
        Button("Restore editor guides") { session.resetEditorDisplay() }
    }
}

struct EditorLabelsOverlay: View {
    let session: EditorSession
    private func color(_ status: EditorEdgeStatus) -> Color {
        switch status { case .warning: .orange; case .seam: .cyan; case .joined: .green; case .unlinked: .white }
    }
    private func position(_ p: SIMD2<Float>,in size: CGSize) -> CGPoint {
        CGPoint(x: min(max(0,Double(p.x)*size.width),size.width),y: min(max(0,Double(p.y)*size.height),size.height))
    }
    var body: some View {
        GeometryReader { geometry in
            if session.editorDisplay.faceLabels || session.editorDisplay.edgeLabels {
                ForEach(session.editorLabels) { face in
                    if session.editorDisplay.faceLabels {
                        Text(face.title).font(.caption.weight(.semibold)).lineLimit(1)
                            .padding(4).background(.black.opacity(0.8),in: RoundedRectangle(cornerRadius: 4))
                            .foregroundStyle(.white).frame(maxWidth: max(0,geometry.size.width-16))
                            .position(position(face.position,in: geometry.size))
                    }
                    if session.editorDisplay.edgeLabels {
                        ForEach(face.edges) { edge in
                            Text(edge.title).font(.caption2).lineLimit(1)
                                .padding(3).background(.black.opacity(0.8),in: RoundedRectangle(cornerRadius: 3))
                                .foregroundStyle(color(edge.status)).position(position(edge.position,in: geometry.size))
                        }
                    }
                }
            }
        }.allowsHitTesting(false).accessibilityHidden(true)
    }
}

struct JoinInspectionControls: View {
    let session: EditorSession
    let object: MappingObject
    var body: some View {
        VStack(alignment: .leading,spacing: 8) {
            Text("INSPECT CONNECTED FACES").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
            HStack {
                Button("Vertical stripes") { session.inspectJoins(objectID: object.id,pattern: .verticalStripes) }
                Button("Horizontal stripes") { session.inspectJoins(objectID: object.id,pattern: .horizontalStripes) }
            }
            Button("Shared checkerboard") { session.inspectJoins(objectID: object.id,pattern: .checkerboard) }
            if session.calibration.pattern.isActive { Button("Return to Normal Content") { session.setCalibrationPattern(.normal) } }
            Text(object.mode == .continuous ? "Patterns use each face's shared input region. Check their alignment across linked edges." : "Repeat mode repeats the whole pattern on each face; choose Continuous to inspect a shared canvas.")
                .font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false,vertical: true)
            Text("Edge labels: green joined, cyan deliberate seam, orange mismatch. Arrows follow edge order on the output face. Calibration bypasses appearance/crop/flips, so normal-content appearance warnings may not appear in the test pattern. Masks remain active.")
                .font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false,vertical: true)
        }
    }
}
