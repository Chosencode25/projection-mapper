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
        CommandGroup(replacing: .undoRedo) {
            Button(coordinator.session.undoTitle) { coordinator.undo() }.keyboardShortcut("z", modifiers: .command)
                .disabled(!coordinator.canUndo)
            Button(coordinator.session.redoTitle) { coordinator.redo() }.keyboardShortcut("z", modifiers: [.command,.shift])
                .disabled(!coordinator.canRedo)
        }
        CommandGroup(after: .pasteboard) {
            Divider()
            ForEach(EditorAction.editing) { action in shortcutButton(action) }
        }
        CommandGroup(after: .importExport) {
            shortcutButton(.importImage)
            shortcutButton(.importVideo)
        }
        CommandGroup(replacing: .help) {
            Button("Keyboard Shortcuts…") { coordinator.showKeyboardShortcuts() }
                .keyboardShortcut("/", modifiers: .command)
            Divider()
            Button("Welcome to Projection Mapper") { coordinator.showWelcome() }
            Button("Projection Mapper Guide") { coordinator.showHelp() }
            Button("Open V1 Demo…") { coordinator.openDemo() }
        }
        CommandGroup(replacing: .appSettings) { }
        CommandGroup(replacing: .appInfo) {
            Button("About Projection Mapper") { coordinator.showAbout() }
        }
        CommandMenu("Show") {
            shortcutButton(.playPause)
            shortcutButton(.stop)
            Menu("Seek Playback") {
                ForEach([EditorAction.stepBack, .stepForward, .secondBack, .secondForward, .beginning, .sequenceEnd]) { action in
                    shortcutButton(action)
                }
            }
            shortcutButton(.muteAudio)
            Divider()
            Button("Playback Readiness") { coordinator.session.isInspectorVisible = true; coordinator.session.inspectorTab = .show }
            Button("Identify Selected Object") { coordinator.session.identifySelectedObject() }.disabled(coordinator.session.selectedSource == nil)
            Button("Finish Identification") { coordinator.session.finishIdentification() }.disabled(coordinator.session.identifyingSourceID == nil)
            Divider()
            Menu("Calibration") { CalibrationPatternMenu(session: coordinator.session) }
            Button(coordinator.session.calibration.pattern.isActive ? "Exit Calibration" : "Enter Calibration (Grid)") {
                coordinator.session.toggleCalibration()
            }.keyboardShortcut("c", modifiers: [.control, .command])
            Divider()
            Button("Immediate Blackout") { coordinator.session.blackoutOutput() }
                .keyboardShortcut("b", modifiers: [.command, .shift])
            Button("Fade to Black") { coordinator.session.fadeToBlack() }
            Button("Restore Output") { coordinator.session.restoreOutput() }
                .keyboardShortcut("r", modifiers: [.command, .shift])
        }
        CommandMenu("Timeline") {
            ForEach(EditorAction.timeline) { action in shortcutButton(action) }
        }
        CommandGroup(after: .windowArrangement) {
            Button("Show Editor") { coordinator.showEditor() }
                .keyboardShortcut("e", modifiers: [.command, .control])
            Divider()
            Button("Show Output") { coordinator.openOutput() }
                .keyboardShortcut("o", modifiers: [.command, .control])
                .disabled(!coordinator.session.canOpenOutput)
            shortcutButton(.closeOutput)
        }
        CommandGroup(after: .sidebar) {
            Menu("Editor Guides") { EditorDisplayMenu(session: coordinator.session) }
            Button(coordinator.session.editorDisplay.hasHandles ? "Hide All Editor Handles" : "Show All Editor Handles") {
                coordinator.session.toggleEditorHandles()
            }.keyboardShortcut("h",modifiers: [.control,.command])
            Button(coordinator.session.editorDisplay.faceLabels ? "Hide Face and Object Names" : "Show Face and Object Names") {
                coordinator.session.toggleEditorLabels()
            }.keyboardShortcut("l",modifiers: [.control,.command])
            Divider()
            shortcutButton(.editInspector)
            shortcutButton(.showInspector)
            shortcutButton(.projectInspector)
            Divider()
            Button(coordinator.session.isSidebarVisible ? "Hide Sidebar" : "Show Sidebar") {
                coordinator.session.isSidebarVisible.toggle()
            }
            .keyboardShortcut("s", modifiers: [.command, .control])
            Button(coordinator.session.isInspectorVisible ? "Hide Inspector" : "Show Inspector") {
                coordinator.session.isInspectorVisible.toggle()
            }
            .keyboardShortcut("i", modifiers: [.command, .control])
            Button(coordinator.session.isTimelineVisible ? "Hide Timeline" : "Show Timeline") {
                coordinator.session.isTimelineVisible.toggle()
            }.keyboardShortcut("t", modifiers: [.command, .control])
        }
    }

    private func shortcutButton(_ action: EditorAction) -> some View {
        Button(action.title) { coordinator.perform(action) }
            .keyboardShortcut(action.key, modifiers: action.modifiers)
            .disabled(!coordinator.canPerform(action))
    }
}
