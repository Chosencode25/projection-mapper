import AppKit
import Observation

@MainActor
@Observable
final class TestOutputCoordinator: NSObject, NSWindowDelegate {
    private(set) var window: NSWindow?
    private var isChangingPresentation = false
    private let preferences: OutputPreferences
    private let visibleFrames: () -> [CGRect]
    private(set) var scene: RenderScene
    private let presentWindow: (NSWindow) -> Void

    init(presentWindow: @escaping (NSWindow) -> Void = { $0.makeKeyAndOrderFront(nil) },
         scene: RenderScene = .diagnostic, preferences: OutputPreferences = OutputPreferences(),
         visibleFrames: @escaping () -> [CGRect] = { NSScreen.screens.map(\.visibleFrame) }) {
        self.presentWindow = presentWindow
        self.preferences = preferences
        self.scene = scene
        self.visibleFrames = visibleFrames
        super.init()
    }

    /// Keeps the complete window, including its title bar, reachable on one current screen.
    static func recoveredFrame(_ frame: CGRect, screens: [CGRect], minimum: CGSize) -> CGRect {
        let screens = screens.filter { $0.width > 0 && $0.height > 0 }
        guard let screen = screens.max(by: {
            let a = frame.intersection($0), b = frame.intersection($1)
            return (a.isNull ? 0 : a.width * a.height) < (b.isNull ? 0 : b.width * b.height)
        }) else { return frame }
        let size = CGSize(width: min(max(frame.width, minimum.width), screen.width),
                          height: min(max(frame.height, minimum.height), screen.height))
        return CGRect(x: min(max(frame.minX, screen.minX), screen.maxX - size.width),
                      y: min(max(frame.minY, screen.minY), screen.maxY - size.height),
                      width: size.width, height: size.height)
    }

    private func recover(_ output: NSWindow, frame: CGRect) {
        let minimum = output.frameRect(forContentRect: CGRect(origin: .zero, size: output.contentMinSize)).size
        output.setFrame(Self.recoveredFrame(frame, screens: visibleFrames(), minimum: minimum), display: true)
    }

    private func saveNormalFrame() {
        guard !isChangingPresentation, let window, !window.isMiniaturized, !window.isZoomed,
              !window.styleMask.contains(.fullScreen) else { return }
        preferences.saveTestWindowFrame(window.frame)
    }

    func windowShouldZoom(_ window: NSWindow, toFrame newFrame: NSRect) -> Bool {
        saveNormalFrame()
        isChangingPresentation = true
        DispatchQueue.main.async { [weak self] in
            self?.isChangingPresentation = false
            self?.saveNormalFrame()
        }
        return true
    }
    func windowWillEnterFullScreen(_ notification: Notification) {
        saveNormalFrame()
        isChangingPresentation = true
    }
    func windowDidEnterFullScreen(_ notification: Notification) { isChangingPresentation = false }
    func windowWillExitFullScreen(_ notification: Notification) { isChangingPresentation = true }
    func windowDidExitFullScreen(_ notification: Notification) {
        isChangingPresentation = false
        saveNormalFrame()
    }

    func windowDidMove(_ notification: Notification) {
        guard notification.object as? NSWindow === window else { return }
        saveNormalFrame()
    }
    func windowDidResize(_ notification: Notification) {
        guard notification.object as? NSWindow === window else { return }
        saveNormalFrame()
    }

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
            output.contentView = TestOutputView(frame: NSRect(x: 0, y: 0, width: 640, height: 360), scene: scene)
            output.center()
            if let saved = preferences.loadTestWindowFrame() { recover(output, frame: saved) }
            window = output
            output.delegate = self
        }
        setResolution(resolution)
        if window?.isMiniaturized == true { window?.deminiaturize(nil) }
        if let window, !window.isZoomed, !window.styleMask.contains(.fullScreen) {
            recover(window, frame: window.frame)
        }
        if let window { presentWindow(window) }
        (window?.contentView as? TestOutputView)?.updateRenderingAvailability()
        return true
    }

    func setScene(_ scene: RenderScene) {
        self.scene = scene
        (window?.contentView as? TestOutputView)?.setScene(scene)
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
        saveNormalFrame()
        (closing.contentView as? TestOutputView)?.stopRendering()
        closing.contentView = nil
        closing.delegate = nil
        window = nil
    }
}
