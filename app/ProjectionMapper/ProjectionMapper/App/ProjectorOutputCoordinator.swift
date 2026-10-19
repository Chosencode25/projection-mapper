import AppKit
import Observation

final class ProjectorWindow: NSWindow {
    var escape: (() -> Void)?
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
    override func cancelOperation(_ sender: Any?) { escape?() }
}

/// Fullscreen ownership has no transport or media player; it receives the shared clean scene.
@MainActor
@Observable
final class ProjectorOutputCoordinator: NSObject, NSWindowDelegate {
    enum State: Equatable { case closed, opening, open, unavailable, failed }
    private(set) var state: State = .closed
    private(set) var message: String?
    private(set) var activeDisplay: DisplayDescriptor?
    private(set) var window: NSWindow?
    private(set) var scene = RenderScene.diagnostic
    private(set) var diagnostic: OutputDiagnostic = .normal
    private(set) var cadence = OutputCadence()
    private var startedAt = 0.0
    @ObservationIgnored private var timer: Timer?
    @ObservationIgnored private var label: NSTextField?
    @ObservationIgnored private let createWindow: @MainActor (DisplayDescriptor, RenderScene) throws -> NSWindow
    @ObservationIgnored private let present: @MainActor (NSWindow) -> Void
    @ObservationIgnored private let validatePresentation: @MainActor (DisplayDescriptor) -> Bool
    var isOpen: Bool { state == .open }
    var statusText: String { message ?? (isOpen ? "Projector output open — \(activeDisplay?.name ?? "Display")" : "Projector output closed") }

    init(createWindow: @escaping @MainActor (DisplayDescriptor, RenderScene) throws -> NSWindow = ProjectorOutputCoordinator.nativeWindow,
         present: @escaping @MainActor (NSWindow) -> Void = { $0.orderFrontRegardless() },
         validatePresentation: @escaping @MainActor (DisplayDescriptor) -> Bool = ProjectorOutputCoordinator.nativeMatches) {
        self.createWindow = createWindow; self.present = present; self.validatePresentation = validatePresentation
        super.init()
        NSWorkspace.shared.notificationCenter.addObserver(self, selector: #selector(willSleep), name: NSWorkspace.willSleepNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(screenChanged), name: NSApplication.didChangeScreenParametersNotification, object: nil)
    }
    deinit {
        NotificationCenter.default.removeObserver(self)
        NSWorkspace.shared.notificationCenter.removeObserver(self)
    }
    static func nativeMatches(_ display: DisplayDescriptor) -> Bool {
        guard let screen = NSScreen.screens.first(where: { DisplayDiscoveryService.displayID($0) == display.id }),
              CGDisplayIsBuiltin(display.id) == 0, CGDisplayIsInMirrorSet(display.id) == 0,
              CGDisplayMirrorsDisplay(display.id) == kCGNullDirectDisplay,
              DisplayDiscoveryService.displayID(NSApp.mainWindow?.screen) != display.id else { return false }
        if let expected = display.uuid {
            let current = CGDisplayCreateUUIDFromDisplayID(display.id).map { CFUUIDCreateString(nil, $0.takeRetainedValue()) as String }
            guard expected == current else { return false }
        }
        return screen.frame == display.desktopFrame && Double(screen.backingScaleFactor) == display.scale
    }
    static func nativeWindow(_ display: DisplayDescriptor, _ scene: RenderScene) throws -> NSWindow {
        guard nativeMatches(display), let frame = display.desktopFrame, let aspect = display.aspectRatio else { throw OutputError.unavailable }
        let view = MetalSceneView(frame: CGRect(origin: .zero, size: frame.size), scene: scene)
        guard view.renderingError == nil else { throw OutputError.renderer(view.renderingError!) }
        view.outputAspectRatio = aspect
        let window = ProjectorWindow(contentRect: frame, styleMask: [.borderless], backing: .buffered, defer: false)
        window.backgroundColor = .black; window.isOpaque = true; window.isReleasedWhenClosed = false
        window.level = .screenSaver
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        window.hidesOnDeactivate = false; window.isMovable = false
        window.contentView = view
        return window
    }
    enum OutputError: LocalizedError {
        case unavailable, renderer(String)
        var errorDescription: String? {
            switch self { case .unavailable: "Selected display changed or is unavailable. Refresh and select it again."
            case .renderer(let text): text }
        }
    }
    static func validTarget(_ display: DisplayDescriptor, in snapshot: [DisplayDescriptor]) -> Bool {
        guard snapshot.contains(display), display.isEligible, let frame = display.desktopFrame, let aspect = display.aspectRatio,
              aspect.isFinite, frame.width.isFinite, frame.height.isFinite, frame.origin.x.isFinite, frame.origin.y.isFinite,
              frame.width > 0, frame.height > 0,
              let scale = display.scale, scale.isFinite, scale > 0 else { return false }
        if let uuid = display.uuid { return snapshot.filter { $0.uuid == uuid }.count == 1 }
        return snapshot.filter { $0.id == display.id }.count == 1
    }
    @discardableResult
    func open(_ display: DisplayDescriptor?, snapshot: [DisplayDescriptor], scene: RenderScene) -> Bool {
        guard let display, Self.validTarget(display, in: snapshot), validatePresentation(display) else {
            invalidate("Selected external display is unavailable or ambiguous. Refresh Displays and select it again."); return false
        }
        if isOpen, activeDisplay == display { return true }
        close(); state = .opening
        do {
            let candidate = try createWindow(display, scene)
            // A window factory or nested AppKit event may invalidate opening. Never present stale output.
            guard state == .opening, validatePresentation(display) else {
                (candidate.contentView as? MetalSceneView)?.stopRendering()
                candidate.contentView = nil
                candidate.close()
                if state == .opening {
                    invalidate("Selected display changed before output opened. Refresh Displays and explicitly reopen output.")
                }
                return false
            }
            guard let view = candidate.contentView as? MetalSceneView, view.renderingError == nil else { candidate.close(); throw OutputError.renderer("Output renderer is unavailable.") }
            self.scene = scene; activeDisplay = display; window = candidate; candidate.delegate = self
            (candidate as? ProjectorWindow)?.escape = { [weak self] in self?.close() }
            view.renderingFailed = { [weak self, weak view] reason in
                guard let self, let view, self.window?.contentView === view else { return }
                self.close(); self.state = .failed; self.message = "Projector output failed: " + reason
            }
            view.frameSubmitted = { [weak self] time in self?.cadence.record(at: time) }
            cadence = OutputCadence(); state = .open; message = nil
            present(candidate); view.updateRenderingAvailability()
            return isOpen
        } catch {
            close(); state = .failed; message = "Projector output failed: \(error.localizedDescription)"; return false
        }
    }
    func setScene(_ scene: RenderScene) { self.scene = scene; updateView() }
    func setDiagnostic(_ mode: OutputDiagnostic) {
        timer?.invalidate(); timer = nil; diagnostic = isOpen ? mode : .normal
        startedAt = ProcessInfo.processInfo.systemUptime; cadence = OutputCadence()
        if diagnostic != .normal {
            timer = Timer(timeInterval: diagnostic == .timing ? 1.0 / 60 : 0.1, repeats: true) { [weak self] _ in
                MainActor.assumeIsolated { self?.updateView() }
            }
            RunLoop.main.add(timer!, forMode: .common)
        }
        updateView()
    }
    private func updateView() {
        guard let view = window?.contentView as? MetalSceneView else { return }
        let elapsed = ProcessInfo.processInfo.systemUptime - startedAt
        view.setScene(diagnostic.scene(from: scene, elapsed: elapsed))
        if diagnostic == .normal { label?.removeFromSuperview(); label = nil; return }
        if label == nil {
            let text = NSTextField(wrappingLabelWithString: "")
            text.textColor = .white; text.backgroundColor = .black; text.drawsBackground = true
            text.alignment = .center; text.font = .monospacedSystemFont(ofSize: 24, weight: .bold)
            text.translatesAutoresizingMaskIntoConstraints = false; view.addSubview(text)
            NSLayoutConstraint.activate([text.centerXAnchor.constraint(equalTo: view.centerXAnchor), text.centerYAnchor.constraint(equalTo: view.centerYAnchor), text.widthAnchor.constraint(lessThanOrEqualTo: view.widthAnchor, multiplier: 0.8)])
            label = text
        }
        label?.isHidden = scene.effectiveGain(at: ProcessInfo.processInfo.systemUptime) <= 0
        label?.alphaValue = CGFloat(scene.effectiveGain(at: ProcessInfo.processInfo.systemUptime))
        label?.stringValue = "\(activeDisplay?.name ?? "Output") · \(activeDisplay?.renderSizeText ?? "")\nTOP ↑ · LEFT ← · \((activeDisplay?.aspectRatio ?? 1) < 1 ? "Portrait" : "Landscape")" + (diagnostic == .timing ? "\nFrame \(OutputDiagnostic.frame(at: elapsed)) · 60 fps fixture\nFlash each 60 frames (not a latency measurement)" : "\nOutput boundary grid · Finish to restore content")
    }
    func reconcile(destination: OutputDestination, snapshot: [DisplayDescriptor], error: String? = nil) {
        guard state == .open || state == .opening else { return }
        guard let activeDisplay, let current = snapshot.first(where: { $0.id == activeDisplay.id }),
              error == nil, destination == .display(activeDisplay.id), Self.validTarget(current, in: snapshot),
              current.uuid == activeDisplay.uuid, current.desktopFrame == activeDisplay.desktopFrame,
              current.renderWidth == activeDisplay.renderWidth, current.renderHeight == activeDisplay.renderHeight,
              current.scale == activeDisplay.scale, current.refreshRate == activeDisplay.refreshRate else {
            invalidate("Projector output closed: display changed or disconnected. Playback may still be running. Select the display and explicitly reopen output."); return
        }
    }
    @objc private func screenChanged() { invalidateIfActive("Display configuration changed. Refresh Displays and explicitly reopen projector output. Playback may still be running.") }
    @objc private func willSleep() { invalidateIfActive("Mac went to sleep. Explicitly reopen projector output after waking. Playback may still be running.") }
    func invalidateIfActive(_ reason: String) { if state == .open || state == .opening { invalidate(reason) } }
    func invalidate(_ reason: String) { close(); state = .unavailable; message = reason }
    func close() {
        timer?.invalidate(); timer = nil; diagnostic = .normal; label?.removeFromSuperview(); label = nil
        let old = window; window = nil; activeDisplay = nil
        (old?.contentView as? MetalSceneView)?.renderingFailed = nil
        (old?.contentView as? MetalSceneView)?.frameSubmitted = nil
        (old?.contentView as? MetalSceneView)?.stopRendering()
        old?.delegate = nil; (old as? ProjectorWindow)?.escape = nil; old?.contentView = nil; old?.close()
        state = .closed; message = nil
    }
    func windowWillClose(_ notification: Notification) { if notification.object as? NSWindow === window { close() } }
    func windowDidChangeScreen(_ notification: Notification) {
        guard notification.object as? NSWindow === window, let display = activeDisplay else { return }
        if DisplayDiscoveryService.displayID(window?.screen) != display.id { invalidate("Output screen changed. Explicitly reopen the intended display.") }
    }
    func windowDidChangeBackingProperties(_ notification: Notification) {
        guard notification.object as? NSWindow === window, let display = activeDisplay else { return }
        if window?.screen.map({ Double($0.backingScaleFactor) }) != display.scale {
            invalidateIfActive("Output backing scale changed. Refresh Displays and explicitly reopen output.")
        }
    }
}
