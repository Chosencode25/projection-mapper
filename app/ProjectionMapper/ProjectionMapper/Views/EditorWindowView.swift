import SwiftUI
import AppKit

struct EditorWindowView: View {
    @Bindable var session: EditorSession
    var phoneRemote: PhoneRemote? = nil
    @State private var showsPhone = false
    @State private var showsFixtures = false
    @State private var confirmsPauseToEdit = false
    let newProject: () -> Void
    let projectChanged: () -> Void
    let refreshDisplays: () -> Void
    let openOutput: () -> Void

    var openProject: () -> Void = {}
    var saveProject: () -> Void = {}
    var savePlayground: () -> Void = {}
    var newPlaygroundShow: () -> Void = {}
    var choosePlayground: () -> Void = {}
    var managePlaygrounds: () -> Void = {}
    var saveCopy: () -> Void = {}

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                Picker("Workspace", selection: Binding(get: { session.workspace }, set: { target in
                    if target == .edit && session.needsPauseToEdit { confirmsPauseToEdit = true }
                    else { session.switchWorkspace(to: target) }
                })) {
                    ForEach(ProjectWorkspace.allCases) { Text($0.rawValue).tag($0) }
                }.labelsHidden().pickerStyle(.segmented).fixedSize().accessibilityLabel("Workspace")
                Text(session.project.name).font(.subheadline).lineLimit(1)
                Text(session.saveStatus).font(.caption).foregroundStyle(session.autosaveError == nil ? Color.secondary : Color.orange)
                    .help(session.autosaveError ?? session.saveStatus)
                if session.autosaveError != nil {
                    Button("Retry") { Task { try? await session.flushAutosave() } }
                    Button("Save a Copy…", action: saveCopy)
                }
                Spacer()
                if let phoneRemote {
                    Button {
                        showsPhone.toggle()
                    } label: { Label("Phone Remote", systemImage: "iphone") }
                    .popover(isPresented: $showsPhone) { PhoneRemoteView(remote: phoneRemote) }
                }
                if session.workspace == .show {
                    Label("Rehearsal · editing locked", systemImage: "lock")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }.padding(.horizontal, 12).padding(.vertical, 8)
            Divider()
            if session.workspace == .edit {
                editWorkspace
            } else {
                ShowWorkspace(session: session, openOutput: openOutput)
            }
            Divider()
            EditorStatusView(session: session)
        }
        .confirmationDialog("Pause the show to edit?", isPresented: $confirmsPauseToEdit, titleVisibility: .visible) {
            Button("Pause and Edit") { session.switchWorkspace(to: .edit, pauseRunningShow: true) }
            Button("Keep Rehearsing", role: .cancel) {}
        } message: {
            Text("Playback pauses at the current position. The output window stays open.")
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .preferredColorScheme(.dark)
        .tint(Color(red: 0.57, green: 0.52, blue: 0.96))
        .onChange(of: session.project) { _, _ in projectChanged() }
        .onChange(of: session.output.destination) { _, destination in
            session.outputDestinationChanged()
        }
    }

    private var editWorkspace: some View {
        VStack(spacing: 0) {
            EditorToolbar(session: session, newProject: newProject, openOutput: openOutput, openProject: openProject, saveProject: saveProject, savePlayground: savePlayground, newPlaygroundShow: newPlaygroundShow, choosePlayground: choosePlayground, managePlaygrounds: managePlaygrounds, showFixtures: { showsFixtures.toggle() })
            Divider()
            VSplitView {
                Group {
                    if showsFixtures {
                        LightingWorkspace(session: session) { showsFixtures = false }
                    } else {
                        HSplitView {
                            if session.isSidebarVisible {
                                SurfaceSidebarView(session: session).frame(minWidth: 180, idealWidth: session.sidebarWidth, maxWidth: 400)
                                    .onGeometryChange(for: Double.self) { $0.size.width } action: { if NSEvent.pressedMouseButtons != 0 { session.sidebarWidth = $0 } }
                            }
                            EditorCanvasView(session: session).frame(minWidth: 260, maxWidth: .infinity, maxHeight: .infinity)
                                .background(SplitInitialPositionView(vertical: true,
                                    leading: session.isSidebarVisible ? session.sidebarWidth : nil,
                                    trailing: session.isInspectorVisible ? session.inspectorWidth : nil))
                            if session.isInspectorVisible {
                                ProjectInspectorView(session: session, refreshDisplays: refreshDisplays, openOutput: openOutput)
                                    .frame(minWidth: 270, idealWidth: session.inspectorWidth, maxWidth: 500)
                                    .onGeometryChange(for: Double.self) { $0.size.width } action: { if NSEvent.pressedMouseButtons != 0 { session.inspectorWidth = $0 } }
                            }
                        }
                    }
                }
                .frame(minHeight: 240)
                if session.isTimelineVisible {
                    PlaybackTimelineView(session: session).frame(minHeight: 184, idealHeight: session.timelineHeight, maxHeight: 400)
                        .background(SplitInitialPositionView(vertical: false, leading: nil, trailing: session.timelineHeight))
                        .onGeometryChange(for: Double.self) { $0.size.height } action: { if NSEvent.pressedMouseButtons != 0 { session.timelineHeight = $0 } }
                }
            }.id(session.layoutRevision)
        }
    }

}

private struct ShowWorkspace: View {
    let session: EditorSession
    let openOutput: () -> Void
    @State private var showsReadiness = false
    @State private var readiness: PlaybackReadinessReport?
    @State private var inspectedProject: MappingProject?
    @State private var showsFixtures = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            controls
            statusRow
            if let queued = session.queuedBeat {
                Label("Queued \(queued.name) · \(TimelinePresentation.timecode(queued.time))\(queued.wraps ? " after loop" : "")",
                      systemImage: "metronome").font(.caption).foregroundStyle(.orange)
            } else if let message = session.beatMessage {
                Text(message).font(.caption).foregroundStyle(.orange)
            }
            if let message = session.songMessage {
                Text(message).font(.caption).foregroundStyle(.orange)
            }
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Picker("Preview", selection: $showsFixtures) {
                            Text("Projection").tag(false)
                            Text("Fixtures").tag(true)
                        }.labelsHidden().pickerStyle(.segmented).fixedSize()
                        Spacer()
                        Text(session.outputStatusText).font(.caption).foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                    if showsFixtures {
                        FixturePreview(session: session, allowsPlacement: false)
                    } else {
                        MetalScenePreview(scene: session.scene, aspectRatio: session.output.aspectRatio,
                                          outputDescription: "Show projection preview")
                            .background(.black)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                }.frame(maxWidth: .infinity, maxHeight: .infinity)
                cuePanel
            }
        }.padding(12)
    }

    private var controls: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 10) {
                Button {
                    session.setPlaying(!session.transport.isPlaying)
                } label: {
                    Label(session.transport.isPlaying ? "Pause" : "Play",
                          systemImage: session.transport.isPlaying ? "pause.fill" : "play.fill")
                }.buttonStyle(.borderedProminent)
                Button { session.stopPlayback() } label: { Label("Stop", systemImage: "stop.fill") }
                BeatQueueMenu(session: session)
                Button("GO") { session.goManualCue() }
                    .disabled(session.manualCueList.isEmpty || session.songAudioOnly ||
                              (session.lastManualCueID != nil && session.nextManualCueID == nil))
                Divider().frame(height: 20)
                Button(session.showOutput.isBlackout || session.showOutput.targetGain == 0
                       ? "Restore Projection" : "Projection Blackout") {
                    if session.showOutput.isBlackout || session.showOutput.targetGain == 0 { session.restoreOutput() }
                    else { session.blackoutOutput() }
                }
                Button("Fade Projection") { session.fadeToBlack() }
                    .disabled(session.showOutput.isBlackout || session.showOutput.targetGain == 0)
                Button(session.lightingSimulation.blackout ? "Restore Fixtures" : "Fixture Blackout") {
                    session.lightingSimulation.blackout.toggle()
                    session.refreshLighting()
                }.disabled(session.project.lighting.fixtures.isEmpty)
                if session.project.song != nil {
                    Button(session.songMuted ? "Unmute Song" : "Mute Song") { session.songMuted.toggle() }
                } else if session.videoAudioEnabled {
                    Button("Mute Video Audio") { session.enableVideoAudio(false) }
                }
                Divider().frame(height: 20)
                OutputSelectorView(output: session.output, compact: true)
                Button(session.isOutputOpen ? "Close Output" : "Open Output") {
                    if session.isOutputOpen { session.closeOutput() }
                    else { openOutput() }
                }.disabled(!session.isOutputOpen && !session.canOpenOutput)

            }.padding(.vertical, 3)
        }.scrollIndicators(.automatic)
    }

    private var statusRow: some View {
        HStack(spacing: 12) {
            readinessButton
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 12) {
                    Label(session.output.selectedName, systemImage: "display")
                    Label(session.project.lighting.controllers.isEmpty ? "No fixtures" : "Fixture simulation",
                          systemImage: "light.beacon.max")
                    Label(session.project.song == nil ? "Elapsed-time clock" : "Song clock", systemImage: "clock")
                }
                Text(session.output.selectedName).lineLimit(1)
            }
            Spacer()
        }.font(.caption).foregroundStyle(.secondary)
    }

    private var readinessButton: some View {
        Button {
            checkReadiness()
            showsReadiness = true
        } label: {
            let stale = inspectedProject != session.project
            Label(stale ? "Check Readiness" : (readiness?.summary ?? "Check Readiness"),
                  systemImage: stale ? "checklist" : (readiness?.blockerCount == 0 ? "checkmark.circle" : "exclamationmark.circle"))
        }.popover(isPresented: $showsReadiness) {
            ScrollView {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Rehearsal Readiness").font(.headline)
                    Button("Check Again") { checkReadiness() }
                    if let readiness {
                        Text(readiness.summary).font(.caption.weight(.semibold))
                        ForEach(readiness.issues) { issue in
                            Text(issue.severity.rawValue + " · " + issue.message).font(.caption)
                        }
                        if readiness.omittedCount > 0 {
                            Text("\(readiness.omittedCount) more issues").font(.caption)
                        }
                    }
                }.frame(maxWidth: .infinity, alignment: .leading).padding(14)
            }.frame(width: 350, height: 340)
        }
    }

    private func checkReadiness() {
        readiness = session.playbackReadiness()
        inspectedProject = session.project
    }

    private var cuePanel: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                TimelineView(.animation(minimumInterval: 1.0 / 15, paused: !session.transport.isPlaying)) { _ in
                    let time = session.transport.elapsed(at: ProcessInfo.processInfo.systemUptime)
                    VStack(alignment: .leading, spacing: 9) {
                        Text(TimelinePresentation.timecode(time))
                            .font(.system(.title, design: .monospaced).weight(.semibold))
                            .accessibilityLabel("Playhead " + TimelinePresentation.timecode(time))
                        Text(session.project.song?.name ?? "Elapsed time")
                            .font(.caption).foregroundStyle(.secondary)
                        Divider()
                        Text("Upcoming timed cues").font(.headline)
                        let next = ShowCuePreview.upcoming(session.manualCueList, at: time,
                                                           loop: session.project.song?.loop,
                                                           songEnd: session.project.song?.duration)
                        if let first = next.first {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(first.afterWrap ? "NEXT AFTER LOOP" : "NEXT CUE").font(.caption2.bold())
                                Text(first.cue.name).font(.headline).lineLimit(2)
                                LabeledContent(TimelinePresentation.timecode(first.cue.time),
                                               value: String(format: "in %.1f s", first.delay)).font(.caption.monospacedDigit())
                            }.padding(9).background(.orange.opacity(0.12), in: RoundedRectangle(cornerRadius: 6))
                        } else {
                            Text("No upcoming cues").font(.caption).foregroundStyle(.secondary)
                        }
                        ForEach(Array(next.dropFirst())) { entry in
                            LabeledContent(entry.cue.name + (entry.afterWrap ? " · loop" : ""),
                                           value: TimelinePresentation.timecode(entry.cue.time)).font(.caption)
                        }
                    }
                }
                if !session.manualCueList.isEmpty {
                    Divider()
                    Picker("Next manual cue", selection: Binding(get: { session.nextManualCueID }, set: { session.nextManualCueID = $0 })) {
                        Text(session.lastManualCueID == nil ? "First Cue" : "End of List").tag(UUID?.none)
                        ForEach(session.manualCueList) { Text($0.name).tag(Optional($0.id)) }
                    }
                    Button("Release to Timeline") {
                        session.resetManualCues()
                        session.refreshLighting()
                    }.disabled(session.lastManualCueID == nil)
                }
            }.padding(12)
        }
        .frame(width: 260)
        .background(.white.opacity(0.04), in: RoundedRectangle(cornerRadius: 8))
    }
}


/// SwiftUI split views distribute their initial space equally despite ideal sizes.
/// Set the initial divider positions once, then leave resizing to AppKit/the user.
private struct SplitInitialPositionView: NSViewRepresentable {
    let vertical: Bool
    let leading: Double?
    let trailing: Double?
    func makeNSView(context: Context) -> SplitPositionAnchor {
        SplitPositionAnchor(vertical: vertical, leading: leading, trailing: trailing)
    }
    func updateNSView(_ view: SplitPositionAnchor, context: Context) {}
}

private final class SplitPositionAnchor: NSView {
    let vertical: Bool
    let leading: Double?
    let trailing: Double?
    private var configured = false
    private var queued = false
    init(vertical: Bool, leading: Double?, trailing: Double?) {
        self.vertical = vertical; self.leading = leading; self.trailing = trailing
        super.init(frame: .zero)
    }
    required init?(coder: NSCoder) { nil }
    override func hitTest(_ point: NSPoint) -> NSView? { nil }
    override func viewDidMoveToWindow() { super.viewDidMoveToWindow(); schedule() }
    override func layout() { super.layout(); schedule() }
    private func schedule() {
        guard !configured, !queued, window != nil else { return }
        queued = true
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }; self.queued = false
            var ancestor = self.superview
            while let candidate = ancestor {
                if let split = candidate as? NSSplitView, split.isVertical == self.vertical, split.arrangedSubviews.count > 1 {
                    let total = self.vertical ? split.bounds.width : split.bounds.height
                    guard total > 0 else { return }
                    self.configured = true
                    if let leading = self.leading { split.setPosition(leading, ofDividerAt: 0) }
                    if let trailing = self.trailing {
                        split.setPosition(total - trailing - split.dividerThickness, ofDividerAt: split.arrangedSubviews.count - 2)
                    }
                    return
                }
                ancestor = candidate.superview
            }
        }
    }
}
