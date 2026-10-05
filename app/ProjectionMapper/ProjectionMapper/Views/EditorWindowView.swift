import SwiftUI

struct EditorWindowView: View {
    @Bindable var session: EditorSession
    let newProject: () -> Void
    let projectChanged: () -> Void
    let refreshDisplays: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            EditorToolbar(session: session, newProject: newProject)
            Divider()
            HStack(spacing: 0) {
                if session.isSidebarVisible {
                    SurfaceSidebarView().frame(width: 220)
                    Divider()
                }
                EditorCanvasView(output: session.output).frame(maxWidth: .infinity, maxHeight: .infinity)
                if session.isInspectorVisible {
                    Divider()
                    ProjectInspectorView(session: session, refreshDisplays: refreshDisplays).frame(width: 260)
                }
            }
            Divider()
            EditorStatusView(session: session)
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .preferredColorScheme(.dark)
        .tint(.purple)
        .onChange(of: session.project) { _, _ in projectChanged() }
    }
}
