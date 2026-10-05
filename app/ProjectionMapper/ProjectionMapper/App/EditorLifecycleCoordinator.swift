import AppKit
import SwiftUI

@MainActor
final class EditorLifecycleCoordinator: NSObject, NSApplicationDelegate, NSWindowDelegate {
    let session = EditorSession()
    private lazy var displayDiscovery = DisplayDiscoveryService(output: session.output)
    private var editorWindow: NSWindow?
    private var isPrompting = false
    private var isTerminationPending = false

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        showEditor()
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
                openOutput: { [weak self] in self?.openOutput() }
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
        session.testOutput.close()
        editorWindow?.contentView = nil
        editorWindow?.delegate = nil
        editorWindow = nil
    }

    func newProject() {
        guard !isPrompting else { return }
        showEditor()
        confirmDiscard(action: "start a new project") { [weak self] shouldDiscard in
            guard let self, shouldDiscard else { return }
            self.session.resetProject()
            self.updateWindowTitle()
        }
    }

    func windowShouldClose(_ sender: NSWindow) -> Bool {
        guard !isPrompting else { return false }
        guard session.hasUserChanges else { return true }
        confirmDiscard(action: "close this project") { [weak self] shouldDiscard in
            guard let self, shouldDiscard else { return }
            self.session.resetProject()
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
        confirmDiscard(action: "quit Projection Mapper") { [weak self] shouldDiscard in
            self?.isTerminationPending = false
            sender.reply(toApplicationShouldTerminate: shouldDiscard)
        }
        return .terminateLater
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        showEditor()
        return true
    }

    func showAbout() {
        NSApp.orderFrontStandardAboutPanel(options: [
            .applicationName: "Projection Mapper",
            .applicationVersion: AppVersion.version,
            .version: AppVersion.build,
            .credits: NSAttributedString(string: "A simple workspace for projection mapping.\nBasic Test Window · v\(AppVersion.version)")
        ])
    }

    private func updateWindowTitle() {
        editorWindow?.title = session.project.name
        editorWindow?.isDocumentEdited = session.hasUserChanges
    }

    private func confirmDiscard(action: String, completion: @escaping @MainActor (Bool) -> Void) {
        guard session.hasUserChanges else { completion(true); return }
        guard let window = editorWindow else { completion(false); return }
        isPrompting = true
        let alert = NSAlert()
        alert.messageText = "Discard changes?"
        alert.informativeText = "To \(action), discard your current changes. Projects stay in memory and cannot be saved yet."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Cancel")
        alert.addButton(withTitle: "Discard Changes")
        alert.beginSheetModal(for: window) { [weak self] response in
            self?.isPrompting = false
            completion(response == .alertSecondButtonReturn)
        }
    }
}
