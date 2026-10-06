import SwiftUI

struct EditorToolbar: View {
    @Bindable var session: EditorSession
    let newProject: () -> Void
    let openOutput: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Button(action: { session.isSidebarVisible.toggle() }) {
                Image(systemName: "sidebar.left")
            }
            .help(session.isSidebarVisible ? "Hide sidebar" : "Show sidebar")
            .accessibilityLabel("Toggle sidebar")
            Button(action: newProject) { Label("New Project", systemImage: "doc.badge.plus") }
            Button("Add Surface", systemImage: "plus") { session.addSurface() }
            Spacer()
            HStack(spacing: 8) {
                Image(systemName: "viewfinder").foregroundStyle(.purple)
                Text(session.project.name).font(.headline).lineLimit(1)
            }
            Spacer()
            Button("Blackout", systemImage: "lightbulb.slash.fill") { session.blackoutOutput() }
                .foregroundStyle(session.showOutput.isBlackout ? Color.orange : Color.primary)
                .help("Immediately black out all rendered content (Command-Shift-B)")
                .accessibilityLabel("Immediate output blackout")
            Button("Restore", systemImage: "lightbulb.fill") { session.restoreOutput() }
                .help("Restore output using the configured fade duration (Command-Shift-R)")
                .accessibilityLabel("Restore output brightness")
            OutputSelectorView(output: session.output, compact: true)
            OutputWindowControls(session: session, openOutput: openOutput, compact: true)
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
