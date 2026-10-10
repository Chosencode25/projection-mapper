import AppKit
import SwiftUI

@MainActor
final class EditorLifecycleCoordinator: NSObject, NSApplicationDelegate, NSWindowDelegate {
    let session = EditorSession()
    private lazy var displayDiscovery = DisplayDiscoveryService(output: session.output)
    private var editorWindow: NSWindow?
    private var isPrompting = false
    private var isTerminationPending = false
    private let recovery = ProjectRecoveryStore(directory: ProjectRecoveryStore.defaultDirectory)
    var recentProjects: [URL] { session.recentProjectURLs }

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        session.configureRecovery(recovery)
        showEditor()
        DispatchQueue.main.async { [weak self] in self?.recoverProject() }
    }

    func showEditor() {
        if editorWindow == nil {
            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 1200, height: 800),
                styleMask: [.titled, .closable, .miniaturizable, .resizable],
                backing: .buffered,
                defer: false
            )
            window.title = session.project.name
            window.minSize = NSSize(width: 900, height: 600)
            window.isReleasedWhenClosed = false
            window.appearance = NSAppearance(named: .darkAqua)
            window.delegate = self
            window.contentView = NSHostingView(rootView: EditorWindowView(
                session: session,
                newProject: { [weak self] in self?.newProject() },
                projectChanged: { [weak self] in self?.updateWindowTitle() },
                refreshDisplays: { [weak self] in self?.displayDiscovery.refresh() },
                openOutput: { [weak self] in self?.openOutput() },
                openProject: { [weak self] in self?.openProject() },
                saveProject: { [weak self] in self?.saveProject() }
            ))
            window.center()
            editorWindow = window
        }
        if editorWindow?.isMiniaturized == true { editorWindow?.deminiaturize(nil) }
        editorWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        if let editorWindow { displayDiscovery.start(editorWindow: editorWindow) }
    }

    func windowDidChangeScreen(_ notification: Notification) { displayDiscovery.scheduleRefresh() }

    func openOutput() {
        guard !isPrompting else { return }
        session.testOutput.open(for: session.output.destination, resolution: session.output.testResolution)
    }

    func windowWillClose(_ notification: Notification) {
        if let closing = notification.object as? NSWindow, closing === editorWindow {
            session.testOutput.close()
            closing.contentView = nil
            closing.delegate = nil
            editorWindow = nil
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        session.releaseRuntimeResources()
        session.testOutput.close()
        editorWindow?.contentView = nil
        editorWindow?.delegate = nil
        editorWindow = nil
    }

    func newProject() {
        guard !isPrompting else { return }
        showEditor()
        confirmSaveChanges(action: "start a new project") { [weak self] shouldDiscard in
            guard let self, shouldDiscard else { return }
            self.session.resetProject()
            self.updateWindowTitle()
        }
    }

    func windowShouldClose(_ sender: NSWindow) -> Bool {
        guard !isPrompting else { return false }
        guard session.hasUserChanges else { return true }
        confirmSaveChanges(action: "close this project") { [weak self] shouldDiscard in
            guard let self, shouldDiscard else { return }
            if self.session.hasUserChanges { self.session.resetProject() }
            self.updateWindowTitle()
            // Finish dismissing the sheet before closing its parent window.
            DispatchQueue.main.async { sender.close() }
        }
        return false
    }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        guard !isPrompting else { return .terminateCancel }
        guard session.hasUserChanges else { return .terminateNow }
        guard !isTerminationPending else { return .terminateCancel }
        isTerminationPending = true
        showEditor()
        confirmSaveChanges(action: "quit Projection Mapper") { [weak self] shouldDiscard in
            self?.isTerminationPending = false
            if shouldDiscard, self?.session.hasUserChanges == true { self?.session.clearRecovery() }
            sender.reply(toApplicationShouldTerminate: shouldDiscard)
        }
        return .terminateLater
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        showEditor()
        return true
    }

    // Keep text-field undo in the native field editor; project history applies outside text editing.
    private var textEditor: NSTextView? { editorWindow?.firstResponder as? NSTextView }
    var canUndo: Bool { textEditor?.undoManager?.canUndo ?? session.canUndo }
    var canRedo: Bool { textEditor?.undoManager?.canRedo ?? session.canRedo }
    func undo() { if let editor = textEditor { editor.undoManager?.undo() } else { session.undoProjectEdit(); updateWindowTitle() } }
    func redo() { if let editor = textEditor { editor.undoManager?.redo() } else { session.redoProjectEdit(); updateWindowTitle() } }
    func openDemo() {
        guard let url = Bundle.main.url(forResource: "V1-Demo",withExtension: "projectionmap") else {
            session.fileMessage = "The demo package is unavailable; reinstall the complete app."; return
        }
        // Reuse Save/Discard/Cancel and the normal portable-media loading path.
        openProject(url)
    }
    func showWelcome() {
        showEditor()
        guard !isPrompting, let window = editorWindow else { return }
        let alert = NSAlert(); alert.messageText = "Welcome to Projection Mapper"
        alert.informativeText = "Map effects, images and video onto faces or connected objects, then arrange them on the timeline. V1 includes a resizable Test Window. Start with the portable demo or read the guide. Opening the demo protects unsaved work with Save / Discard / Cancel."
        alert.addButton(withTitle: "Open Demo"); alert.addButton(withTitle: "Guide"); alert.addButton(withTitle: "Keep Editing")
        isPrompting = true
        alert.beginSheetModal(for: window) { [weak self] response in
            guard let self else { return }; self.isPrompting = false
            if response == .alertFirstButtonReturn { self.openDemo() }
            else if response == .alertSecondButtonReturn { self.showHelp() }
        }
    }
    func showHelp() {
        let alert = NSAlert(); alert.messageText = "Projection Mapper · V1 Guide"
        alert.informativeText = "Add faces, drag their corners, and group checked faces into an object. Continuous mode shares one canvas; input maps and edge links establish continuity. Repeat shows the same content on each face.\n\nChoose effects, PNG/JPEG images or SDR H.264/HEVC MP4/MOV. Capture content with + in an object timeline row. Empty rows show live content; gaps in populated rows are dark. Move clips to move timing, drag edges to trim, and scrub the ruler. Audio starts muted.\n\nCommand-Z / Shift-Command-Z undo and redo project edits. Save with Command-S; .projectionmap packages include referenced media. Open the V1 Demo from Help; unsaved work is protected. Check Playback Readiness in Show before playback. Identification temporarily isolates the selected owner; Finish Identification restores normal output.\n\nV1 uses a resizable Test Window. Fullscreen projector output, music waveforms/sequencing, lights and layered crossfades remain V2."
        alert.addButton(withTitle: "Done")
        if let window = editorWindow { alert.beginSheetModal(for: window) { _ in } }
    }

    func showAbout() {
        NSApp.orderFrontStandardAboutPanel(options: [
            .applicationName: "Projection Mapper",
            .applicationVersion: AppVersion.version,
            .version: AppVersion.build,
            .credits: NSAttributedString(string: "A simple workspace for projection mapping.\nTest Mode · effects, connected faces, images and video · v\(AppVersion.version)")
        ])
    }

    private func updateWindowTitle() {
        editorWindow?.title = session.project.name
        editorWindow?.isDocumentEdited = session.hasUserChanges
        editorWindow?.representedURL = session.documentURL
    }

    func saveProject(asNew: Bool = false, completion: @escaping @MainActor (Bool) -> Void = { _ in }) {
        guard !isPrompting else { completion(false); return }
        showEditor()
        if !asNew, let url = session.documentURL { writeProject(to: url, completion: completion); return }
        guard let window = editorWindow else { completion(false); return }
        let panel = NSSavePanel()
        panel.allowedContentTypes = [ProjectPackageStore.contentType]
        panel.canCreateDirectories = true
        panel.nameFieldStringValue = session.project.name.replacingOccurrences(of: "/", with: "-") + ".projectionmap"
        panel.directoryURL = session.documentURL?.deletingLastPathComponent()
        isPrompting = true
        panel.beginSheetModal(for: window) { [weak self] response in
            guard let self else { completion(false); return }
            self.isPrompting = false
            guard response == .OK, let url = panel.url else { completion(false); return }
            self.writeProject(to: url, completion: completion)
        }
    }
    private func writeProject(to url: URL, completion: @escaping @MainActor (Bool) -> Void) {
        isPrompting = true
        Task { @MainActor in
            defer { isPrompting = false }
            do { try await session.saveMedia(to: url); remember(url); updateWindowTitle(); completion(true) }
            catch { showFileError(error); completion(false) }
        }
    }
    private func remember(_ url: URL) {
        let paths = [url.path] + recentProjects.map(\.path).filter { $0 != url.path }
        session.recentProjectURLs = Array(paths.prefix(10)).map { URL(fileURLWithPath: $0) }
        UserDefaults.standard.set(Array(paths.prefix(10)), forKey: "recentProjects")
    }
    func openProject(_ url: URL? = nil) {
        guard !isPrompting else { return }
        showEditor()
        if let url { readProject(url); return }
        guard let window = editorWindow else { return }
        let panel = NSOpenPanel(); panel.allowedContentTypes = [ProjectPackageStore.contentType]
        panel.canChooseDirectories = false; panel.allowsMultipleSelection = false
        isPrompting = true
        panel.beginSheetModal(for: window) { [weak self] response in
            self?.isPrompting = false
            if response == .OK, let url = panel.url { self?.readProject(url) }
        }
    }
    private func readProject(_ url: URL) {
        do {
            _ = try ProjectPackageStore().read(url)
            confirmSaveChanges(action: "open another project") { [weak self] proceed in
                guard let self, proceed else { return }
                self.isPrompting = true
                Task { @MainActor in
                    defer { self.isPrompting = false }
                    do {
                        // Reread after any Save. Decode large image assets off the main thread.
                        let isDemo = url == Bundle.main.url(forResource: "V1-Demo",withExtension: "projectionmap")
                        let original = try ProjectPackageStore().read(url)
                        let document = isDemo ? try ProjectCodec.freshDemo(original) : original
                        let baseline = self.session.project
                        let assets = document.project.imageAssets
                        let media = await Task.detached(priority: .userInitiated) { ImageImportService.loadAssets(assets,package: url) }.value
                        guard baseline == self.session.project else {
                            self.session.fileMessage = "The current mapping changed while images loaded. Open the project again."; return
                        }
                        let videos = await VideoImportService.loadAssets(document.project.videoAssets,package: url)
                        defer { self.removeUnadoptedVideoStages(videos.urls) }
                        guard self.session.project == baseline else { throw ProjectFileError.io("Project changed while opening; try again.") }
                        try self.session.load(document,from: url,recovering: isDemo,loadedMedia: media,loadedVideos: videos)
                        if !isDemo { self.remember(url) }; self.updateWindowTitle()
                    } catch { self.showFileError(error) }
                }
            }
        } catch { showFileError(error) }
    }
    func application(_ application: NSApplication, open urls: [URL]) { if let url = urls.first { openProject(url) } }
    func recoverProject() {
        guard !isPrompting, let window = editorWindow else { return }
        let entries = recovery.entries(); guard !entries.isEmpty else { return }
        let picker = NSPopUpButton(frame: NSRect(x: 0,y: 0,width: 360,height: 28))
        picker.addItems(withTitles: entries.map { $0.document.project.name + " · " + ($0.document.recovery?.savedAt.formatted() ?? "") })
        let alert = NSAlert(); alert.messageText = "Recover unsaved work?"
        alert.informativeText = "Restore a recovery copy, keep it for later, or delete the selected copy. Restored projects start paused and need Save."
        alert.accessoryView = picker
        alert.addButton(withTitle: "Restore"); alert.addButton(withTitle: "Later"); alert.addButton(withTitle: "Delete Copy")
        isPrompting = true
        alert.beginSheetModal(for: window) { [weak self] response in
            guard let self else { return }; self.isPrompting = false
            let entry = entries[max(0,picker.indexOfSelectedItem)]
            if response == .alertThirdButtonReturn { self.recovery.remove(projectID: entry.document.project.id); return }
            guard response == .alertFirstButtonReturn else { return }
            // Save/Discard may remove the current project's recovery. Preserve the chosen copy first.
            let snapshot = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".projectionmap")
            self.isPrompting = true
            Task { @MainActor in
                do {
                    let data = try ProjectCodec.encode(entry.document)
                    try await Task.detached(priority: .userInitiated) {
                        try ProjectPackageStore().write(ProjectCodec.decode(data),to: snapshot,assetsFrom: entry.url)
                    }.value
                    self.isPrompting = false
                    self.confirmSaveChanges(action: "restore this recovery copy") { proceed in
                        guard proceed else { try? FileManager.default.removeItem(at: snapshot); return }
                        self.isPrompting = true
                        let baseline = self.session.project
                        Task { @MainActor in
                            defer { try? FileManager.default.removeItem(at: snapshot) }
                            do {
                                try await Task.detached(priority: .userInitiated) {
                                    try ProjectPackageStore().write(ProjectCodec.decode(data),to: entry.url,assetsFrom: snapshot)
                                }.value
                                let images = await Task.detached(priority: .userInitiated) {
                                    ImageImportService.loadAssets(entry.document.project.imageAssets,package: entry.url)
                                }.value
                                let videos = await VideoImportService.loadAssets(entry.document.project.videoAssets,package: entry.url)
                                defer { self.removeUnadoptedVideoStages(videos.urls) }
                                guard baseline == self.session.project else { throw ProjectFileError.io("Mapping changed during recovery; restore again.") }
                                try self.session.load(entry.document,from: entry.url,recovering: true,loadedMedia: images,loadedVideos: videos)
                                self.isPrompting = false
                                self.updateWindowTitle()
                            } catch { self.isPrompting = false; self.showFileError(error) }
                        }
                    }
                } catch {
                    self.isPrompting = false
                    try? FileManager.default.removeItem(at: snapshot)
                    self.showFileError(error)
                }
            }
        }
    }
    private func removeUnadoptedVideoStages(_ urls: [UUID:URL]) {
        let adopted = Set(session.videoFiles.values)
        for url in urls.values where !adopted.contains(url) && url.deletingLastPathComponent() == VideoImportService.stagingDirectory {
            try? FileManager.default.removeItem(at: url)
        }
    }
    private func showFileError(_ error: Error) {
        session.fileMessage = error.localizedDescription
        guard let window = editorWindow else { return }
        let alert = NSAlert(); alert.messageText = "Project could not be saved or opened"
        alert.informativeText = error.localizedDescription; alert.alertStyle = .warning
        isPrompting = true
        alert.beginSheetModal(for: window) { [weak self] _ in self?.isPrompting = false }
    }
    private func confirmSaveChanges(action: String, completion: @escaping @MainActor (Bool) -> Void) {
        guard session.hasUserChanges else { completion(true); return }
        guard let window = editorWindow else { completion(false); return }
        isPrompting = true
        let alert = NSAlert(); alert.messageText = "Save changes to \(session.project.name)?"
        alert.informativeText = "Save your work before you \(action)."
        alert.addButton(withTitle: "Save"); alert.addButton(withTitle: "Discard Changes"); alert.addButton(withTitle: "Cancel")
        alert.beginSheetModal(for: window) { [weak self] response in
            guard let self else { completion(false); return }; self.isPrompting = false
            let choice: ProjectCloseChoice = response == .alertFirstButtonReturn ? .save : response == .alertSecondButtonReturn ? .discard : .cancel
            if choice == .save { self.saveProject { completion(choice.canProceed(saveSucceeded: $0)) } }
            else {
                // The requested action owns the replacement, so a failed Open retains current content.
                completion(choice.canProceed(saveSucceeded: false))
            }
        }
    }
}
