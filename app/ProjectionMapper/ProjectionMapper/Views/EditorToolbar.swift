import SwiftUI

struct EditorToolbar: View {
    @Bindable var session: EditorSession
    let newProject: () -> Void
    let openOutput: () -> Void
    var openProject: () -> Void = {}
    var saveProject: () -> Void = {}
    var savePlayground: () -> Void = {}
    var newPlaygroundShow: () -> Void = {}
    var choosePlayground: () -> Void = {}
    var managePlaygrounds: () -> Void = {}
    var showFixtures: () -> Void = {}

    var body: some View {
        ViewThatFits(in: .horizontal) {
            controls(compact: false)
            controls(compact: true)
        }
        .padding(.horizontal, 12).frame(height: 54)
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.7))
    }

    private func controls(compact: Bool) -> some View {
        HStack(spacing: 10) {
            Button { session.isSidebarVisible.toggle() } label: { Image(systemName: "sidebar.left") }
                .help(session.isSidebarVisible ? "Hide sidebar" : "Show sidebar")
                .accessibilityLabel("Toggle sidebar")
            Menu {
                Button("New project…", action: newProject)
                Button("Open project…", action: openProject)
                Button("Save project", action: saveProject)
                Divider()
                Button("Save Playground…", action: savePlayground)
                Button("New Show from This Playground…", action: newPlaygroundShow)
                Button("New Show from Playground…", action: choosePlayground)
                Button("Manage Playgrounds…", action: managePlaygrounds)
                Divider()
                if !session.availableDrafts.isEmpty {
                    Menu("Drafts") {
                        ForEach(session.availableDrafts, id: \.path) { url in
                            Button((try? ProjectPackageStore().read(url).project.name) ?? "Draft") { session.openDraft(url) }
                        }
                    }
                }
                if !session.availableCheckpoints.isEmpty {
                    Menu("Restore Checkpoint") {
                        ForEach(session.availableCheckpoints, id: \.path) { url in
                            Button(Date(timeIntervalSince1970: Double(url.deletingPathExtension().lastPathComponent) ?? 0).formatted()) { session.restoreCheckpoint(url) }
                        }
                    }
                }
                Divider()
                Button("Project settings & libraries") { showInspector(.project) }
            } label: { Label("Project", systemImage: "folder") }
            Button(action: saveProject) { Label("Save", systemImage: "square.and.arrow.down") }
                .labelStyle(ToolbarLabelStyle(compact: compact))
                .help("Save project (Command-S)").accessibilityLabel("Save project")
                .disabled(session.isSavingMedia)
            Menu {
                Button(session.undoTitle) { session.undoProjectEdit() }.disabled(!session.canUndo)
                Button(session.redoTitle) { session.redoProjectEdit() }.disabled(!session.canRedo)
            } label: { Image(systemName: "arrow.uturn.backward") }
                .accessibilityLabel("Project history").help("Undo or redo project edits")
            divider
            Menu {
                Button("Surface") { session.addSurface() }
                Button("Import image…") { session.chooseImage(target: session.selectedImageTarget ?? .newFace) }
                    .disabled(session.isImportingImage)
                Button("Import video…") { session.chooseVideo(target: session.selectedImageTarget ?? .newFace) }
                    .disabled(session.isImportingVideo)
                Divider()
                Button("Group faces…") { session.beginGroupingFaces() }
            } label: { Label("Add", systemImage: "plus") }
            Spacer(minLength: 0)
            Button {
                session.setPlaying(!session.transport.isPlaying)
            } label: {
                Label(session.transport.isPlaying ? "Pause" : "Play", systemImage: session.transport.isPlaying ? "pause.fill" : "play.fill")
            }
            .buttonStyle(.borderedProminent).controlSize(.small)
            .help("Play or pause all animated content (Space or Command-Return)")
            Menu {
                Menu("Editor guides") { EditorDisplayMenu(session: session) }
                Menu("Calibration patterns") { CalibrationPatternMenu(session: session) }
                Button(session.isTimelineVisible ? "Hide timeline" : "Show timeline") { session.isTimelineVisible.toggle() }
                Divider()
                Button("Fixtures & Simulation", action: showFixtures)
                Button("Playback readiness & output settings") { showInspector(.show) }
                Button("Reset workspace layout") {
                    session.isSidebarVisible = true; session.isInspectorVisible = true; session.isTimelineVisible = true
                    session.canvasZoom = 1; session.canvasCenter = CGPoint(x: 0.5, y: 0.5)
                    session.sidebarWidth = 244; session.inspectorWidth = 320; session.timelineHeight = 224; session.layoutRevision += 1
                }
                Button("Restart playback") { session.restartPlayback() }
                Button("Fade to black") { session.fadeToBlack() }
                Button("Restore output") { session.restoreOutput() }
            } label: { Label("Tools", systemImage: "slider.horizontal.3") }
                .labelStyle(ToolbarLabelStyle(compact: compact))
                .help("Editor guides, calibration, timeline and show controls")
            Button {
                if session.showOutput.isBlackout || session.showOutput.targetGain == 0 { session.restoreOutput() }
                else { session.blackoutOutput() }
            } label: {
                Label(session.showOutput.isBlackout || session.showOutput.targetGain == 0 ? "Restore" : "Blackout",
                      systemImage: session.showOutput.isBlackout || session.showOutput.targetGain == 0 ? "lightbulb.fill" : "lightbulb.slash")
            }
            .labelStyle(ToolbarLabelStyle(compact: compact))
            .foregroundStyle(session.showOutput.isBlackout || session.showOutput.targetGain == 0 ? Color.orange : Color.primary)
            .accessibilityLabel(session.showOutput.isBlackout || session.showOutput.targetGain == 0 ? "Restore output" : "Immediate output blackout")
            .help(session.showOutput.isBlackout || session.showOutput.targetGain == 0 ? "Restore output (Command-Shift-R)" : "Immediately black out output (Command-Shift-B)")
            divider
            OutputSelectorView(output: session.output, compact: true).frame(width: compact ? 112 : 148)
            OutputWindowControls(session: session, openOutput: openOutput, compact: compact)
            Button { session.isInspectorVisible.toggle() } label: { Image(systemName: "sidebar.right") }
                .help(session.isInspectorVisible ? "Hide inspector" : "Show inspector")
                .accessibilityLabel("Toggle inspector")
        }
        .buttonStyle(.borderless)
        .foregroundStyle(.primary)
        .fixedSize(horizontal: false, vertical: true)
    }

    private var divider: some View { Divider().frame(height: 20).padding(.horizontal, 1) }
    private func showInspector(_ tab: InspectorTab) { session.inspectorTab = tab; session.isInspectorVisible = true }
}

private struct ToolbarLabelStyle: LabelStyle {
    let compact: Bool
    func makeBody(configuration: Configuration) -> some View {
        if compact { configuration.icon }
        else { HStack(spacing: 5) { configuration.icon; configuration.title } }
    }
}
