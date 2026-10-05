import SwiftUI

struct EditorToolbar: View {
    @Bindable var session: EditorSession
    let newProject: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Button(action: { session.isSidebarVisible.toggle() }) {
                Image(systemName: "sidebar.left")
            }
            .help(session.isSidebarVisible ? "Hide sidebar" : "Show sidebar")
            .accessibilityLabel("Toggle sidebar")
            Button(action: newProject) { Label("New Project", systemImage: "doc.badge.plus") }
            Spacer()
            HStack(spacing: 8) {
                Image(systemName: "viewfinder").foregroundStyle(.purple)
                Text(session.project.name).font(.headline).lineLimit(1)
            }
            Spacer()
            OutputSelectorView(output: session.output, compact: true)
            Button(action: { session.isInspectorVisible.toggle() }) {
                Image(systemName: "sidebar.right")
            }
            .help(session.isInspectorVisible ? "Hide inspector" : "Show inspector")
            .accessibilityLabel("Toggle inspector")
        }
        .buttonStyle(.borderless)
        .padding(.horizontal, 18)
        .frame(height: 48)
    }
}
