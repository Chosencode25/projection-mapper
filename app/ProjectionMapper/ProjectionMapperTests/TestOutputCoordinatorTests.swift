import AppKit
import Testing

@MainActor
@Suite(.serialized)
struct TestOutputCoordinatorTests {
    @Test func launchStartsClosedAndRepeatedOpenReusesOneWindow() {
        _ = NSApplication.shared
        let output = TestOutputCoordinator()
        defer { output.close() }
        #expect(!output.isOpen)
        #expect(output.open(for: .testWindow))
        let first = output.window
        #expect(output.isOpen)
        #expect(output.open(for: .testWindow))
        #expect(output.window === first)
        #expect(NSApp.windows.filter { $0 === first }.count == 1)
        #expect(output.statusText == "Test Window open")
    }
    @Test func nativeCloseUpdatesStatusAndReopenCreatesOneFreshWindow() {
        _ = NSApplication.shared
        let output = TestOutputCoordinator()
        defer { output.close() }
        output.open(for: .testWindow)
        let first = output.window
        first?.performClose(nil)
        #expect(output.window == nil)
        #expect(output.statusText == "Test Window closed")
        output.open(for: .testWindow)
        #expect(output.window !== first)
        #expect(output.isOpen)
    }
    @Test func closeIsSafeWhenRepeatedAndPreservesProjectData() {
        _ = NSApplication.shared
        let session = EditorSession()
        session.renameProject("House")
        let original = session.project
        session.testOutput.open(for: .testWindow)
        session.testOutput.close(); session.testOutput.close()
        #expect(!session.testOutput.isOpen)
        #expect(session.project == original)
        #expect(session.hasUserChanges)
    }
    @Test func realDisplayCannotOpenOutputAndDestinationChangeClosesTest() {
        _ = NSApplication.shared
        let output = TestOutputCoordinator()
        defer { output.close() }
        #expect(!output.open(for: .display(2)))
        #expect(!output.isOpen)
        output.open(for: .testWindow)
        output.destinationDidChange(.testWindow)
        #expect(output.isOpen)
        output.destinationDidChange(.display(2))
        #expect(!output.isOpen)
    }
    @Test func windowHasNormalControlsAndResizingPreservesConfiguredTarget() {
        _ = NSApplication.shared
        let session = EditorSession()
        let original = session.project
        defer { session.testOutput.close() }
        session.testOutput.open(for: .testWindow)
        let window = session.testOutput.window!
        #expect(window.styleMask.contains([.titled, .closable, .resizable, .miniaturizable]))
        #expect(window.contentView is TestOutputView)
        #expect(window.contentMinSize == NSSize(width: 320, height: 180))
        window.setContentSize(NSSize(width: 800, height: 450))
        #expect(session.output.renderSizeText == "1280 × 720 px")
        #expect(session.project == original)
        #expect(!session.hasUserChanges)
    }
    @Test func resetKeepsOpenOutputAndProjectorPreferenceIndependent() {
        _ = NSApplication.shared
        let session = EditorSession()
        defer { session.testOutput.close() }
        session.testOutput.open(for: .testWindow)
        let window = session.testOutput.window
        session.renameProject("House"); session.resetProject()
        #expect(session.testOutput.window === window)
        #expect(session.testOutput.isOpen)
        #expect(!session.hasUserChanges)
    }
    @Test func unrelatedWindowClosingDoesNotClearOutputOwnership() {
        _ = NSApplication.shared
        let output = TestOutputCoordinator()
        defer { output.close() }
        output.open(for: .testWindow)
        let other = NSWindow(contentRect: .zero, styleMask: .titled, backing: .buffered, defer: false)
        other.isReleasedWhenClosed = false
        output.windowWillClose(Notification(name: NSWindow.willCloseNotification, object: other))
        #expect(output.isOpen)
    }
}
