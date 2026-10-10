import SwiftUI

struct EditorWindowView: View {
    @Bindable var session: EditorSession
    let newProject: () -> Void
    let projectChanged: () -> Void
    let refreshDisplays: () -> Void
    let openOutput: () -> Void

    var openProject: () -> Void = {}
    var saveProject: () -> Void = {}

    var body: some View {
        VStack(spacing: 0) {
            EditorToolbar(session: session, newProject: newProject, openOutput: openOutput, openProject: openProject, saveProject: saveProject)
            Divider()
            VSplitView {
            HStack(spacing: 0) {
                if session.isSidebarVisible {
                    SurfaceSidebarView(session: session).frame(width: 220)
                    Divider()
                }
                EditorCanvasView(session: session).frame(maxWidth: .infinity, maxHeight: .infinity)
                if session.isInspectorVisible {
                    Divider()
                    ProjectInspectorView(session: session, refreshDisplays: refreshDisplays, openOutput: openOutput).frame(width: 310)
                }
            }
            .frame(minHeight: 240)
            PlaybackTimelineView(session: session).frame(minHeight: 170, idealHeight: 240, maxHeight: 480)
            }
            Divider()
            EditorStatusView(session: session)
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .preferredColorScheme(.dark)
        .tint(.purple)
        .onChange(of: session.project) { _, _ in projectChanged() }
        .onChange(of: session.output.destination) { _, destination in
            session.testOutput.destinationDidChange(destination)
        }
    }
}
