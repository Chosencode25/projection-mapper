import AppKit

/// Window content only. Resolution fitting and the shared renderer arrive later.
final class TestOutputView: NSView {
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.backgroundColor = NSColor.black.cgColor
        setAccessibilityElement(true)
        setAccessibilityRole(.group)
        setAccessibilityLabel("Test output — blank black canvas")
    }
    required init?(coder: NSCoder) { fatalError("TestOutputView is created in code") }
    override var isOpaque: Bool { true }
}
