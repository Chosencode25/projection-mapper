import SwiftUI

struct EditorToolbar: View {
    @Bindable var session: EditorSession
    let newProject: () -> Void
    let openOutput: () -> Void
    var openProject: () -> Void = {}
    var saveProject: () -> Void = {}

    var body: some View {
        ViewThatFits(in: .horizontal) {
            controls
            controls.labelStyle(.iconOnly)
        }.padding(.horizontal, 14).frame(height: 48)
    }

    private var controls: some View {
        HStack(spacing: 12) {
            Button(action: { session.isSidebarVisible.toggle() }) { Image(systemName: "sidebar.left") }
                .help(session.isSidebarVisible ? "Hide sidebar" : "Show sidebar")
                .accessibilityLabel("Toggle sidebar")
            Menu("Project", systemImage: "folder") {
                Button("New project…", action: newProject)
                Button("Open project…", action: openProject)
                Button("Save project", action: saveProject)
                Divider()
                Button("Project settings & libraries") { showInspector(.project) }
            }
            Menu("Add", systemImage: "plus") {
                Button("Surface") { session.addSurface() }
                Button("Group checked surfaces") { session.createObject() }
                    .disabled(session.groupingSelection.isEmpty)
            }
            Text(session.project.name).font(.headline).lineLimit(1).truncationMode(.middle)
                .frame(maxWidth: 180, alignment: .leading)
            Spacer(minLength: 8)
            Button(session.transport.isPlaying ? "Pause" : "Play", systemImage: session.transport.isPlaying ? "pause.fill" : "play.fill") {
                session.setPlaying(!session.transport.isPlaying)
            }.help("Play or pause all animated content")
            Menu("Guides", systemImage: "eye") { EditorDisplayMenu(session: session) }
                .help("Show or hide editor handles, outlines and labels")
                .accessibilityLabel("Editor guides")
            Menu("Calibrate", systemImage: "square.grid.3x3") { CalibrationPatternMenu(session: session) }
                .help("Calibration: " + session.calibration.pattern.title)
                .accessibilityLabel("Calibration patterns").accessibilityValue(session.calibration.pattern.title)
            Menu("Show", systemImage: "slider.horizontal.3") {
                Button("Playback & output settings") { showInspector(.show) }
                Button("Restart playback") { session.restartPlayback() }
                Divider()
                Button("Fade to black") { session.fadeToBlack() }
                Button("Restore brightness") { session.restoreOutput() }
            }
            Button("Blackout", systemImage: "lightbulb.slash.fill") { session.blackoutOutput() }
                .foregroundStyle(session.showOutput.isBlackout ? Color.orange : Color.primary)
                .help("Immediately black out all rendered content (Command-Shift-B)")
                .accessibilityLabel("Immediate output blackout")
            OutputSelectorView(output: session.output, compact: true)
            OutputWindowControls(session: session, openOutput: openOutput, compact: true)
            Button(action: { session.isInspectorVisible.toggle() }) { Image(systemName: "sidebar.right") }
                .help(session.isInspectorVisible ? "Hide inspector" : "Show inspector")
                .accessibilityLabel("Toggle inspector")
        }
        .buttonStyle(.borderless)

    }

    private func showInspector(_ tab: InspectorTab) {
        session.inspectorTab = tab
        session.isInspectorVisible = true
    }
}
