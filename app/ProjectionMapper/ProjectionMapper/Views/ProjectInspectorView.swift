import SwiftUI

struct ProjectInspectorView: View {
    @Bindable var session: EditorSession
    let refreshDisplays: () -> Void
    let openOutput: () -> Void
    @FocusState private var nameIsFocused: Bool

    @ViewBuilder private var surfaceDetails: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("SURFACE").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
            if let surface = session.selectedSurface {
                Text(surface.name).font(.subheadline.weight(.medium)).textSelection(.enabled)
                Text(session.selectedCorner.map { "Active corner: \($0.title)" } ?? "Click a corner handle to edit")
                    .font(.caption).foregroundStyle(.secondary)
                Text("Arrow keys nudge 0.1%; hold Shift for 1%. Escape clears the corner selection.")
                    .font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                Text("Normalized corners").font(.caption).foregroundStyle(.secondary)
                corner("Top left", surface.corners.topLeft)
                corner("Top right", surface.corners.topRight)
                corner("Bottom right", surface.corners.bottomRight)
                corner("Bottom left", surface.corners.bottomLeft)
                Text("Coordinates run from 0 to 1, with the origin at the top left.")
                    .font(.caption).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                Text("No surface selected").font(.subheadline)
                Text("Select Surface 1 in the sidebar to inspect its corners.")
                    .font(.caption).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func corner(_ name: String, _ point: SIMD2<Float>) -> some View {
        LabeledContent(name, value: String(format: "%.3f, %.3f", point.x, point.y))
            .font(.caption).monospacedDigit()
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("PROJECT").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                VStack(alignment: .leading, spacing: 8) {
                    Text("Name").font(.caption).foregroundStyle(.secondary)
                    TextField("Project name", text: Binding(
                        get: { session.project.name },
                        set: { session.renameProject($0) }
                    ))
                    .textFieldStyle(.roundedBorder)
                    .accessibilityLabel("Project name")
                    .focused($nameIsFocused)
                    .onSubmit { session.finishNameEditing(); nameIsFocused = false }
                    .onChange(of: nameIsFocused) { _, focused in
                        if !focused { session.finishNameEditing() }
                    }
                }
                Divider()
                LabeledContent("Surfaces", value: "1")
                Divider()
                surfaceDetails
                Divider()
                OutputDetailsView(session: session, refreshDisplays: refreshDisplays, openOutput: openOutput)
                Spacer()
                Label("Projects stay in memory. Saving arrives in v1.14.", systemImage: "info.circle")
                    .font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            }
            .font(.subheadline)
            .padding(20)
        }
        .frame(maxHeight: .infinity)
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.45))
    }
}
