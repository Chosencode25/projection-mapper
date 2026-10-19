import AppKit
import MetalKit

/// The output surface is fitted in points; its configured pixel resolution stays independent.
class MetalSceneView: NSView {
    private let surface: NSView
    private let renderer: MetalRenderer?
    private(set) var isRenderingActive = false
    private(set) var renderingError: String?
    var renderingFailed: ((String) -> Void)? {
        didSet { renderer?.renderingFailed = renderingFailed }
    }
    var frameSubmitted: ((TimeInterval) -> Void)? {
        didSet { renderer?.frameSubmitted = frameSubmitted }
    }
    var metalView: MTKView? { surface as? MTKView }
    var outputFrame: CGRect { surface.frame }
    var outputAspectRatio = TestResolution.hd.aspectRatio {
        didSet {
            needsLayout = true
            layoutSubtreeIfNeeded()
        }
    }

    convenience init(frame: NSRect, scene: RenderScene) {
        self.init(frame: frame, rendererFactory: { try MetalRenderer(scene: scene) })
    }

    override convenience init(frame frameRect: NSRect) {
        self.init(frame: frameRect, rendererFactory: { try MetalRenderer() })
    }

    init(frame frameRect: NSRect, rendererFactory: () throws -> MetalRenderer) {
        do {
            let renderer = try rendererFactory()
            self.renderer = renderer
            let view = MTKView(frame: .zero, device: renderer.device)
            view.colorPixelFormat = MetalRenderer.pixelFormat
            view.clearColor = MetalRenderer.backgroundColor
            // Native backing pixels follow the fitted view, independently of the simulated target.
            view.autoResizeDrawable = true
            view.isPaused = true
            view.enableSetNeedsDisplay = true
            view.delegate = renderer
            surface = view
        } catch {
            renderer = nil
            renderingError = error.localizedDescription
            let message = NSTextField(wrappingLabelWithString: error.localizedDescription)
            message.textColor = .white
            message.alignment = .center
            message.translatesAutoresizingMaskIntoConstraints = false
            surface = NSView()
            surface.addSubview(message)
            NSLayoutConstraint.activate([
                message.centerXAnchor.constraint(equalTo: surface.centerXAnchor),
                message.centerYAnchor.constraint(equalTo: surface.centerYAnchor),
                message.widthAnchor.constraint(lessThanOrEqualTo: surface.widthAnchor, multiplier: 0.9)
            ])
        }
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.backgroundColor = NSColor.black.cgColor
        surface.wantsLayer = true
        surface.layer?.backgroundColor = NSColor.black.cgColor
        addSubview(surface)
        renderer?.renderDemandDidChange = { [weak self] continuous in
            self?.configureDrawingMode(continuous: continuous)
        }
        VideoRenderAvailability.views.add(self)
        updateRenderingAvailability()
        setAccessibilityElement(true)
        setAccessibilityRole(.group)
        setAccessibilityLabel(renderingError ?? "Test output — project surface on black")
        setAccessibilityValue("\(TestResolution.hd.dimensions) px")
    }
    required init?(coder: NSCoder) { fatalError("MetalSceneView is created in code") }
    override var isOpaque: Bool { renderer?.scene.editorTransparentBackground != true }
    override func setFrameSize(_ newSize: NSSize) {
        super.setFrameSize(newSize)
        needsLayout = true
    }
    override func layout() {
        super.layout()
        let ratio = outputAspectRatio.isFinite && outputAspectRatio > 0 ? outputAspectRatio : 16.0 / 9.0
        let width = min(max(0, bounds.width), max(0, bounds.height) * ratio)
        let height = width / ratio
        surface.frame = CGRect(x: bounds.midX - width / 2, y: bounds.midY - height / 2,
                               width: width, height: height)
        updateRenderingAvailability()
    }

    private static let windowNotifications: [Notification.Name] = [
        NSWindow.didChangeOcclusionStateNotification, NSWindow.didMiniaturizeNotification,
        NSWindow.didDeminiaturizeNotification, NSWindow.didChangeBackingPropertiesNotification,
        NSWindow.willCloseNotification
    ]

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        for name in Self.windowNotifications {
            NotificationCenter.default.removeObserver(self, name: name, object: nil)
        }
        if let window {
            for name in Self.windowNotifications {
                NotificationCenter.default.addObserver(self, selector: #selector(windowAvailabilityChanged(_:)),
                                                       name: name, object: window)
            }
        }
        updateRenderingAvailability()
    }

    override func viewDidHide() { super.viewDidHide(); updateRenderingAvailability() }
    override func viewDidUnhide() { super.viewDidUnhide(); updateRenderingAvailability() }
    override func viewDidChangeBackingProperties() {
        super.viewDidChangeBackingProperties()
        needsLayout = true
        updateRenderingAvailability()
    }

    @objc private func windowAvailabilityChanged(_ notification: Notification) {
        guard notification.object as? NSWindow === window else { return }
        if notification.name == NSWindow.willCloseNotification { stopRendering() }
        else { updateRenderingAvailability() }
    }

    /// Also used by headless tests; window visibility is supplied without presenting a window.
    static func canRender(attached: Bool, visible: Bool, minimized: Bool, occluded: Bool,
                          hidden: Bool, size: CGSize) -> Bool {
        attached && visible && !minimized && !occluded && !hidden &&
        size.width.isFinite && size.height.isFinite && size.width > 0 && size.height > 0
    }

    func updateRenderingAvailability() {
        setRenderingActive(Self.canRender(attached: window != nil, visible: window?.isVisible == true,
                                          minimized: window?.isMiniaturized == true,
                                          occluded: window?.occlusionState.contains(.visible) != true,
                                          hidden: isHiddenOrHasHiddenAncestor, size: surface.bounds.size))
    }

    /// Availability and clock are explicit so native scheduling can be checked without a shown window.
    func setRenderingActive(_ active: Bool, at uptime: TimeInterval = ProcessInfo.processInfo.systemUptime) {
        isRenderingActive = active
        renderer?.isDrawingEnabled = active
        configureDrawingMode(continuous: renderer?.scene.needsContinuousRendering(at: uptime) == true)
        if let metalView {
            if active { renderer?.requestDraw(in: metalView) }
        }
    }

    private func configureDrawingMode(continuous: Bool) {
        guard let metalView else { return }
        let animate = isRenderingActive && continuous
        metalView.preferredFramesPerSecond = 60
        metalView.isPaused = !animate
        metalView.enableSetNeedsDisplay = isRenderingActive && !animate
    }

    func setScene(_ scene: RenderScene) {
        guard let renderer, renderer.scene != scene else { return }
        renderer.setScene(scene)
        let background = scene.editorTransparentBackground ? NSColor.clear.cgColor : NSColor.black.cgColor
        layer?.backgroundColor = background; surface.layer?.backgroundColor = background
        surface.layer?.isOpaque = !scene.editorTransparentBackground
        layer?.isOpaque = !scene.editorTransparentBackground
        setRenderingActive(isRenderingActive)
    }

    func stopRendering() {
        setRenderingActive(false)
        metalView?.releaseDrawables()
    }

    deinit { NotificationCenter.default.removeObserver(self) }

}

/// Test-window preset metadata is independent of the reusable scene drawing view.
final class TestOutputView: MetalSceneView {
    var resolution: TestResolution = .hd {
        didSet {
            outputAspectRatio = resolution.aspectRatio
            setAccessibilityValue("\(resolution.dimensions) px")
        }
    }
}
