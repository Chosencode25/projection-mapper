import AppKit

/// The output surface is fitted in points; its configured pixel resolution stays independent.
final class TestOutputView: NSView {
    private let surface = NSView()
    var outputFrame: CGRect { surface.frame }
    var resolution: TestResolution = .hd {
        didSet {
            needsLayout = true
            layoutSubtreeIfNeeded()
            setAccessibilityValue("\(resolution.dimensions) px")
        }
    }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.backgroundColor = NSColor.black.cgColor
        surface.wantsLayer = true
        surface.layer?.backgroundColor = NSColor.black.cgColor
        addSubview(surface)
        setAccessibilityElement(true)
        setAccessibilityRole(.group)
        setAccessibilityLabel("Test output — blank black canvas")
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
    }
}
