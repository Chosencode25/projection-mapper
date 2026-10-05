import AppKit
import MetalKit

/// The output surface is fitted in points; its configured pixel resolution stays independent.
final class TestOutputView: NSView {
    private let surface: NSView
    private let renderer: MetalRenderer?
    private(set) var renderingError: String?
    var metalView: MTKView? { surface as? MTKView }
    var outputFrame: CGRect { surface.frame }
    var resolution: TestResolution = .hd {
        didSet {
            needsLayout = true
            layoutSubtreeIfNeeded()
            setAccessibilityValue("\(resolution.dimensions) px")
        }
    }

    override convenience init(frame frameRect: NSRect) {
        self.init(frame: frameRect, rendererFactory: { try MetalRenderer() })
    }

    init(frame frameRect: NSRect, rendererFactory: () throws -> MetalRenderer) {
        do {
            let renderer = try rendererFactory()
            self.renderer = renderer
            let view = MTKView(frame: .zero, device: renderer.device)
            view.colorPixelFormat = .bgra8Unorm
            view.clearColor = MetalRenderer.diagnosticColor
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
        setAccessibilityLabel(renderingError ?? "Test output — Metal diagnostic color")
        setAccessibilityValue("\(resolution.dimensions) px")
    }
    required init?(coder: NSCoder) { fatalError("TestOutputView is created in code") }
    override var isOpaque: Bool { true }
    override func setFrameSize(_ newSize: NSSize) {
        super.setFrameSize(newSize)
        needsLayout = true
    }
    override func layout() {
        super.layout()
        surface.frame = resolution.fittedRect(in: bounds)
        surface.needsDisplay = true
    }
}
