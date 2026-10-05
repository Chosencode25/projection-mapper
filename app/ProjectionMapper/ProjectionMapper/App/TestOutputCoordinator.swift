import AppKit
import Observation

@MainActor
@Observable
final class TestOutputCoordinator: NSObject, NSWindowDelegate {
    private(set) var window: NSWindow?
    var isOpen: Bool { window != nil }
    var statusText: String { isOpen ? "Test Window open" : "Test Window closed" }

    @discardableResult
    func open(for destination: OutputDestination, resolution: TestResolution = .hd) -> Bool {
        guard destination == .testWindow else { close(); return false }
        if window == nil {
            let output = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 640, height: 360),
                                  styleMask: [.titled, .closable, .miniaturizable, .resizable],
                                  backing: .buffered, defer: false)
            output.title = "Test Output"
            output.contentMinSize = NSSize(width: 320, height: 180)
            output.isReleasedWhenClosed = false
            output.appearance = NSAppearance(named: .darkAqua)
            output.backgroundColor = .black
            output.contentView = TestOutputView(frame: NSRect(x: 0, y: 0, width: 640, height: 360))
            output.delegate = self
            output.center()
            window = output
        }
        setResolution(resolution)
        if window?.isMiniaturized == true { window?.deminiaturize(nil) }
        window?.makeKeyAndOrderFront(nil)
        return true
    }

    func setResolution(_ resolution: TestResolution) {
        (window?.contentView as? TestOutputView)?.resolution = resolution
        window?.title = "Test Output — \(resolution.dimensions)"
    }

    func close() { window?.close() }

    func destinationDidChange(_ destination: OutputDestination) {
        if destination != .testWindow { close() }
    }

    func windowWillClose(_ notification: Notification) {
        guard let closing = notification.object as? NSWindow, closing === window else { return }
        window = nil
    }
}
