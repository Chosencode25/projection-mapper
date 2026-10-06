import SwiftUI

struct AppCommands: Commands {
    let coordinator: EditorLifecycleCoordinator

    var body: some Commands {
        CommandGroup(replacing: .newItem) {
            Button("New Project") { coordinator.newProject() }
                .keyboardShortcut("n", modifiers: .command)
        }
        CommandGroup(replacing: .saveItem) {
            Button("Save Project") { coordinator.saveProject() }.keyboardShortcut("s", modifiers: .command)
            Button("Save Project As…") { coordinator.saveProject(asNew: true) }.keyboardShortcut("s", modifiers: [.command,.shift])
        }
        CommandGroup(after: .newItem) {
            Button("Open Project…") { coordinator.openProject() }.keyboardShortcut("o", modifiers: .command)
            Menu("Open Recent") {
                ForEach(coordinator.recentProjects, id: \.self) { url in
                    Button(url.deletingPathExtension().lastPathComponent) { coordinator.openProject(url) }
                }
            }
            Button("Recover Unsaved Project…") { coordinator.recoverProject() }
        }
        CommandGroup(replacing: .appSettings) { }
        CommandGroup(replacing: .appInfo) {
            Button("About Projection Mapper") { coordinator.showAbout() }
        }
        CommandGroup(after: .windowArrangement) {
            Button("Show Editor") { coordinator.showEditor() }
                .keyboardShortcut("e", modifiers: [.command, .control])
            Divider()
            Button("Show Output") { coordinator.openOutput() }
                .keyboardShortcut("o", modifiers: [.command, .control])
                .disabled(coordinator.session.output.destination != .testWindow)
            Button("Close Output") { coordinator.session.testOutput.close() }
                .disabled(!coordinator.session.testOutput.isOpen)
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
