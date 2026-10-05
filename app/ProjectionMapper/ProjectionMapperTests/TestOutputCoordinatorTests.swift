import AppKit
import Testing

@MainActor
@Suite(.serialized)
struct TestOutputCoordinatorTests {
    @Test func launchStartsClosedAndRepeatedOpenReusesOneWindow() {
        _ = NSApplication.shared
        let output = TestOutputCoordinator(presentWindow: { _ in })
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
        let output = TestOutputCoordinator(presentWindow: { _ in })
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
        let session = EditorSession(presentOutput: { _ in })
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
        let output = TestOutputCoordinator(presentWindow: { _ in })
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
        let session = EditorSession(presentOutput: { _ in })
        let original = session.project
        defer { session.testOutput.close() }
        session.testOutput.open(for: .testWindow)
        let window = session.testOutput.window!
        #expect(window.styleMask.contains([.titled, .closable, .resizable, .miniaturizable]))
        #expect(window.contentView is TestOutputView)
        #expect(window.contentMinSize == NSSize(width: 320, height: 180))
        let configuredTarget = session.output.renderSizeText
        window.setContentSize(NSSize(width: 800, height: 450))
        #expect(session.output.renderSizeText == configuredTarget)
        #expect(session.project == original)
        #expect(!session.hasUserChanges)
    }
    @Test func resetKeepsOpenOutputAndProjectorPreferenceIndependent() {
        _ = NSApplication.shared
        let session = EditorSession(presentOutput: { _ in })
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
        let output = TestOutputCoordinator(presentWindow: { _ in })
        defer { output.close() }
        output.open(for: .testWindow)
        let other = NSWindow(contentRect: .zero, styleMask: .titled, backing: .buffered, defer: false)
        other.isReleasedWhenClosed = false
        output.windowWillClose(Notification(name: NSWindow.willCloseNotification, object: other))
        #expect(output.isOpen)
    }
    @Test func testResolutionPersistsAndInvalidPreferenceDefaultsToHD() {
        let suite = "ProjectionMapper.ResolutionTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let preferences = OutputPreferences(defaults: defaults)
        #expect(OutputSelectionState(preferences: preferences).testResolution == .hd)
        for resolution in TestResolution.allCases {
            OutputSelectionState(preferences: preferences).setTestResolution(resolution)
            let restored = OutputSelectionState(preferences: preferences)
            #expect(restored.testResolution == resolution)
            #expect(restored.renderSizeText == "\(resolution.dimensions) px")
            #expect(restored.aspectRatio == resolution.aspectRatio)
        }
        defaults.set("invalid", forKey: "output.testResolution.v1")
        #expect(OutputSelectionState(preferences: preferences).testResolution == .hd)
    }
    @Test func presetsFitCenteredWithoutStretchingAcrossWindowShapes() {
        for resolution in TestResolution.allCases {
            for size in [CGSize(width: 640, height: 360), CGSize(width: 320, height: 700), CGSize(width: 800, height: 800)] {
                let bounds = CGRect(origin: CGPoint(x: 10, y: 20), size: size)
                let frame = resolution.fittedRect(in: bounds)
                #expect(abs(frame.width / frame.height - resolution.aspectRatio) < 0.0001)
                #expect(abs(frame.midX - bounds.midX) < 0.0001)
                #expect(abs(frame.midY - bounds.midY) < 0.0001)
                #expect(frame.width <= bounds.width + 0.0001 && frame.height <= bounds.height + 0.0001)
                #expect(abs(frame.width - bounds.width) < 0.0001 || abs(frame.height - bounds.height) < 0.0001)
            }
        }
        #expect(TestResolution.hd.fittedRect(in: .zero) == .zero)
    }
    @Test func liveResolutionUpdatesReuseWindowAndLeaveProjectClean() {
        _ = NSApplication.shared
        let suite = "ProjectionMapper.LiveResolutionTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let session = EditorSession(presentOutput: { _ in }, output: OutputSelectionState(preferences: OutputPreferences(defaults: defaults)))
        let original = session.project
        session.setTestResolution(.portrait)
        #expect(!session.testOutput.isOpen)
        session.testOutput.open(for: .testWindow, resolution: session.output.testResolution)
        defer { session.testOutput.close() }
        let window = session.testOutput.window!
        let windowFrame = window.frame
        let view = window.contentView as! TestOutputView
        #expect(view.resolution == .portrait)
        #expect(view.outputFrame == TestResolution.portrait.fittedRect(in: view.bounds))
        session.setTestResolution(.standard)
        #expect(session.testOutput.window === window)
        #expect(window.frame == windowFrame)
        #expect(view.outputFrame == TestResolution.standard.fittedRect(in: view.bounds))
        window.setContentSize(NSSize(width: 400, height: 600))
        view.layoutSubtreeIfNeeded()
        #expect(view.outputFrame == TestResolution.standard.fittedRect(in: view.bounds))
        #expect(session.output.testResolution == .standard)
        #expect(session.project == original && !session.hasUserChanges)
        session.resetProject()
        #expect(session.output.testResolution == .standard)
        let restarted = EditorSession(presentOutput: { _ in }, output: OutputSelectionState(preferences: OutputPreferences(defaults: defaults)))
        #expect(restarted.output.testResolution == .standard)
        #expect(!restarted.testOutput.isOpen)
    }

    @Test func framePreferencesRejectMalformedValues() {
        let suite = "ProjectionMapper.FrameTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let preferences = OutputPreferences(defaults: defaults)
        #expect(preferences.loadTestWindowFrame() == nil)
        for values in [[1.0, 2], [1, 2, -3, 4], [1, 2, 3, 0]] {
            defaults.set(values, forKey: "output.testWindowFrame.v1")
            #expect(preferences.loadTestWindowFrame() == nil)
        }
        let frame = CGRect(x: -900, y: 40, width: 700, height: 500)
        preferences.saveTestWindowFrame(frame)
        #expect(preferences.loadTestWindowFrame() == frame)
        preferences.saveTestWindowFrame(CGRect(x: CGFloat.infinity, y: 0, width: 1, height: 1))
        #expect(preferences.loadTestWindowFrame() == frame)
    }

    @Test func frameRecoveryHandlesChangedScreensAndMinimumSize() {
        let main = CGRect(x: 0, y: 25, width: 1200, height: 775)
        let second = CGRect(x: -1000, y: 25, width: 1000, height: 775)
        let minimum = CGSize(width: 320, height: 202)
        let saved = CGRect(x: -900, y: 80, width: 640, height: 382)
        #expect(TestOutputCoordinator.recoveredFrame(saved, screens: [main, second], minimum: minimum) == saved)
        #expect(main.contains(TestOutputCoordinator.recoveredFrame(saved, screens: [main], minimum: minimum)))
        for frame in [CGRect(x: 10000, y: -10000, width: 3000, height: 2000),
                      CGRect(x: 1190, y: 790, width: 20, height: 20)] {
            let recovered = TestOutputCoordinator.recoveredFrame(frame, screens: [main], minimum: minimum)
            #expect(main.contains(recovered))
            #expect(recovered.width >= minimum.width && recovered.height >= minimum.height)
        }
        #expect(TestOutputCoordinator.recoveredFrame(saved, screens: [], minimum: minimum) == saved)
    }

    @Test func normalFrameRestoresAcrossCloseAndNewCoordinator() {
        _ = NSApplication.shared
        let suite = "ProjectionMapper.WindowFrameTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let preferences = OutputPreferences(defaults: defaults)
        let screen = NSScreen.main!.visibleFrame
        let output = TestOutputCoordinator(preferences: preferences, visibleFrames: { [screen] })
        output.open(for: .testWindow, resolution: .portrait)
        let window = output.window!
        let frame = CGRect(x: screen.minX + 40, y: screen.minY + 40, width: 500, height: 450)
        window.setFrame(frame, display: true)
        output.windowDidMove(Notification(name: NSWindow.didMoveNotification, object: window))
        output.windowDidResize(Notification(name: NSWindow.didResizeNotification, object: window))
        #expect(preferences.loadTestWindowFrame() == frame)
        window.miniaturize(nil)
        output.windowDidMove(Notification(name: NSWindow.didMoveNotification, object: window))
        #expect(preferences.loadTestWindowFrame() == frame)
        output.open(for: .testWindow, resolution: .portrait)
        #expect(output.window === window && !window.isMiniaturized)
        #expect(window.frame == frame)
        window.zoom(nil)
        #expect(window.isZoomed)
        output.windowDidResize(Notification(name: NSWindow.didResizeNotification, object: window))
        #expect(preferences.loadTestWindowFrame() == frame)
        output.close()
        #expect(preferences.loadTestWindowFrame() == frame)
        let restarted = TestOutputCoordinator(preferences: preferences, visibleFrames: { [screen] })
        #expect(!restarted.isOpen)
        restarted.open(for: .testWindow)
        #expect(restarted.window!.frame == frame)
        restarted.close()
    }

    @Test func showRecoversExistingOffscreenWindowWithoutDuplicatingIt() {
        _ = NSApplication.shared
        let suite = "ProjectionMapper.RecoveryTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let screen = NSScreen.main!.visibleFrame
        let preferences = OutputPreferences(defaults: defaults)
        preferences.saveTestWindowFrame(CGRect(x: 30000, y: 30000, width: 3000, height: 2000))
        let output = TestOutputCoordinator(presentWindow: { _ in }, preferences: preferences, visibleFrames: { [screen] })
        defer { output.close() }
        output.open(for: .testWindow)
        let window = output.window!
        #expect(screen.contains(window.frame))
        window.setFrame(CGRect(x: -30000, y: -30000, width: 500, height: 450), display: false)
        output.open(for: .testWindow)
        #expect(output.window === window)
        #expect(screen.contains(window.frame))
    }

}
