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
                    SurfaceSidebarView(session: session).frame(width: 244)
                    Divider()
                }
                EditorCanvasView(session: session).frame(maxWidth: .infinity, maxHeight: .infinity)
                if session.isInspectorVisible {
                    Divider()
                    ProjectInspectorView(session: session, refreshDisplays: refreshDisplays, openOutput: openOutput).frame(width: 320)
                }
            }
            .frame(minHeight: 240)
            if session.isTimelineVisible {
                PlaybackTimelineView(session: session).frame(minHeight: 184, idealHeight: 224, maxHeight: 300)
            }
            }
            Divider()
            EditorStatusView(session: session)
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .preferredColorScheme(.dark)
        .tint(Color(red: 0.57, green: 0.52, blue: 0.96))
        .onChange(of: session.project) { _, _ in projectChanged() }
        .onChange(of: session.output.destination) { _, destination in
            session.outputDestinationChanged()
        }
    }
}
