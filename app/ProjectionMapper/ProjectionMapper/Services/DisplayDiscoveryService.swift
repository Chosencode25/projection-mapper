import AppKit
import CoreGraphics

@MainActor
final class DisplayDiscoveryService: NSObject {
    let output: OutputSelectionState
    private weak var editorWindow: NSWindow?
    private var pendingRefresh: Task<Void, Never>?

    init(output: OutputSelectionState) {
        self.output = output
        super.init()
        let center = NotificationCenter.default
        center.addObserver(self, selector: #selector(scheduleRefresh), name: NSApplication.didChangeScreenParametersNotification, object: nil)
        center.addObserver(self, selector: #selector(scheduleRefresh), name: NSApplication.didBecomeActiveNotification, object: nil)
        NSWorkspace.shared.notificationCenter.addObserver(self, selector: #selector(scheduleRefresh), name: NSWorkspace.didWakeNotification, object: nil)
    }
    deinit {
        NotificationCenter.default.removeObserver(self)
        NSWorkspace.shared.notificationCenter.removeObserver(self)
    }
    func start(editorWindow: NSWindow) {
        self.editorWindow = editorWindow
        refresh()
    }
    @objc func scheduleRefresh() {
        pendingRefresh?.cancel()
        pendingRefresh = Task { [weak self] in
            do { try await Task.sleep(for: .milliseconds(150)) } catch { return }
            self?.refresh()
        }
    }
    func refresh() {
        guard let editorID = Self.displayID(editorWindow?.screen) else {
            output.update([], error: "Editor display is not yet available")
            return
        }
        do { output.update(try Self.discover(editorDisplayID: editorID)) }
        catch { output.update([], error: "Display discovery is unavailable") }
    }
    static func displayID(_ screen: NSScreen?) -> UInt32? {
        (screen?.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber)?.uint32Value
    }

    /// Read-only snapshot. Never changes the user's display configuration.
    static func discover(editorDisplayID: UInt32) throws -> [DisplayDescriptor] {
        var count: UInt32 = 0
        guard CGGetOnlineDisplayList(0, nil, &count) == .success, count > 0 else { throw DiscoveryError.incomplete }
        var ids = [CGDirectDisplayID](repeating: 0, count: Int(count) + 8)
        let capacity = UInt32(ids.count)
        guard CGGetOnlineDisplayList(capacity, &ids, &count) == .success, count < capacity else { throw DiscoveryError.incomplete }
        let screens = NSScreen.screens
        let online = Array(ids.prefix(Int(count)))
        guard online.contains(editorDisplayID), !screens.isEmpty else { throw DiscoveryError.incomplete }
        return online.map { id in
            let screen = screens.first { displayID($0) == id }
            let mode = CGDisplayCopyDisplayMode(id)
            var width = mode.map { Int($0.pixelWidth) }
            var height = mode.map { Int($0.pixelHeight) }
            // Match the mode's orientation to the current drawable desktop bounds.
            // This avoids double-swapping on SDKs/drivers that already rotate mode dimensions.
            let bounds = CGDisplayBounds(id)
            if let w = width, let h = height, w != h, bounds.width != bounds.height,
               (w > h) != (bounds.width > bounds.height) { swap(&width, &height) }
            var estimated = false
            if (width ?? 0) <= 0 || (height ?? 0) <= 0, let screen {
                let backing = screen.convertRectToBacking(screen.frame)
                width = Int(backing.width.rounded())
                height = Int(backing.height.rounded())
                estimated = true
            }
            let uuid = CGDisplayCreateUUIDFromDisplayID(id).map { CFUUIDCreateString(nil, $0.takeRetainedValue()) as String }
            return DisplayDescriptor(id: id, uuid: uuid,
                name: screen?.localizedName ?? "Display \(id)",
                isBuiltIn: CGDisplayIsBuiltin(id) != 0,
                desktopFrame: screen?.frame,
                renderWidth: width, renderHeight: height,
                isRenderSizeEstimated: estimated,
                scale: screen.map { Double($0.backingScaleFactor) },
                refreshRate: mode?.refreshRate,
                isMirrored: CGDisplayIsInMirrorSet(id) != 0 || CGDisplayMirrorsDisplay(id) != kCGNullDirectDisplay,
                hasIndependentScreen: screen != nil,
                isEditorDisplay: id == editorDisplayID)
        }.sorted { lhs, rhs in
            if lhs.name == rhs.name { return lhs.id < rhs.id }
            return lhs.name.localizedStandardCompare(rhs.name) == .orderedAscending
        }
    }
    private enum DiscoveryError: Error { case incomplete }
}
