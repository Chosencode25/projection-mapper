import SwiftUI

struct AppCommands: Commands {
    let coordinator: EditorLifecycleCoordinator

    var body: some Commands {
        CommandGroup(replacing: .newItem) {
            Button("New Project") { coordinator.newProject() }
                .keyboardShortcut("n", modifiers: .command)
        }
        CommandGroup(replacing: .appSettings) { }
        CommandGroup(replacing: .appInfo) {
            Button("About Projection Mapper") { coordinator.showAbout() }
        }
        CommandGroup(after: .windowArrangement) {
            Button("Show Editor") { coordinator.showEditor() }
        }
        CommandGroup(after: .sidebar) {
            Button(coordinator.session.isSidebarVisible ? "Hide Sidebar" : "Show Sidebar") {
                coordinator.session.isSidebarVisible.toggle()
            }
            .keyboardShortcut("s", modifiers: [.command, .control])
            Button(coordinator.session.isInspectorVisible ? "Hide Inspector" : "Show Inspector") {
                coordinator.session.isInspectorVisible.toggle()
            }
            .keyboardShortcut("i", modifiers: [.command, .control])
        }
    }
}
