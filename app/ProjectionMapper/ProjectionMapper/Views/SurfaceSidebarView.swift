import SwiftUI

struct SurfaceSidebarView: View {
    let session: EditorSession
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("SURFACES").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                .padding(20)
            List(selection: Binding<UUID?>(
                get: { session.selectedSurfaceID },
                set: { session.selectSurface($0) }
            )) {
                Label(session.project.surface.name, systemImage: "rectangle")
                    .tag(session.project.surface.id)
                    .accessibilityLabel(session.project.surface.name)
            }
            .listStyle(.sidebar)
            Button("Deselect Surface") { session.selectSurface(nil) }
                .disabled(session.selectedSurface == nil)
                .font(.caption)
                .padding(20)
        }
        .frame(maxHeight: .infinity)
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.45))
    }
}
