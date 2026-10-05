import AppKit
import MetalKit

/// The output surface is fitted in points; its configured pixel resolution stays independent.
class MetalSceneView: NSView {
    private let surface: NSView
    private let renderer: MetalRenderer?
    private(set) var renderingError: String?
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
                message.widthAnchor.constraint(lessThanOrEqualTo: surface.widthAnchor, constant: -32)
            ])
        }
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.backgroundColor = NSColor.black.cgColor
        surface.wantsLayer = true
        surface.layer?.backgroundColor = NSColor.black.cgColor
        addSubview(surface)
        setAccessibilityElement(true)
        setAccessibilityRole(.group)
        setAccessibilityLabel(renderingError ?? "Test output — orange rectangle on black")
        setAccessibilityValue("\(TestResolution.hd.dimensions) px")
    }
    required init?(coder: NSCoder) { fatalError("MetalSceneView is created in code") }
    override var isOpaque: Bool { true }
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
        surface.needsDisplay = true
    }
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
