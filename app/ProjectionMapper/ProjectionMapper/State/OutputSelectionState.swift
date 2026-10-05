import Foundation
import Observation

@MainActor
@Observable
final class OutputSelectionState {
    private(set) var displays: [DisplayDescriptor] = []
    private(set) var destination: OutputDestination = .testWindow
    private(set) var testResolution: TestResolution
    private(set) var recoveryMessage: String?
    private(set) var savedPreference: SavedOutputPreference
    private var didRestore = false
    private let preferences: OutputPreferences

    init(preferences: OutputPreferences = OutputPreferences()) {
        self.preferences = preferences
        savedPreference = preferences.load()
        testResolution = preferences.loadTestResolution()
    }
    var selectedDisplay: DisplayDescriptor? {
        guard case .display(let id) = destination else { return nil }
        return displays.first { $0.id == id }
    }
    var selectedName: String { selectedDisplay?.name ?? "Test Window" }
    var aspectRatio: Double {
        destination == .testWindow ? testResolution.aspectRatio : (selectedDisplay?.aspectRatio ?? 16.0 / 9.0)
    }
    var renderSizeText: String {
        destination == .testWindow ? "\(testResolution.dimensions) px" : (selectedDisplay?.renderSizeText ?? "Not reported")
    }
    func setTestResolution(_ resolution: TestResolution) {
        testResolution = resolution
        preferences.saveTestResolution(resolution)
    }
    var statusText: String { recoveryMessage ?? "\(selectedName) selected" }

    func menuName(for display: DisplayDescriptor) -> String {
        let duplicates = displays.filter { $0.name == display.name }
        let suffix = duplicates.count > 1 ? " (\((duplicates.firstIndex { $0.id == display.id } ?? 0) + 1))" : ""
        return display.name + suffix + (display.isBuiltIn ? " · Built-in" : "")
    }

    func select(_ choice: OutputDestination) {
        switch choice {
        case .testWindow:
            destination = choice
            persist(.testWindow)
            recoveryMessage = nil
        case .display(let id):
            guard let display = displays.first(where: { $0.id == id }), display.isEligible else { return }
            destination = choice
            let unique = display.uuid.map { uuid in displays.filter { $0.uuid == uuid }.count == 1 } ?? false
            persist(SavedOutputPreference(displayUUID: unique ? display.uuid : nil,
                                          displayName: display.name, requiresManualSelection: !unique))
            recoveryMessage = unique ? nil : "\(display.name) selected. Select it manually after restarting; its identity is unavailable or ambiguous."
        }
    }

    /// Restoration is attempted once, after the editor has a screen and discovery succeeds.
    func update(_ snapshot: [DisplayDescriptor], error: String? = nil) {
        let previous = selectedDisplay
        displays = snapshot
        if let error {
            destination = .testWindow
            recoveryMessage = "\(error) — Test Window selected. Refresh Displays to retry."
            return
        }
        if !didRestore {
            didRestore = true
            restore()
            return
        }
        guard case .display(let id) = destination else { return }
        // A driver's runtime ID may change while the same uniquely identified display remains online.
        let sameID = displays.first { $0.id == id && $0.uuid == previous?.uuid }
        let identityMatches = previous?.uuid.map { uuid in displays.filter { $0.uuid == uuid } } ?? []
        let resolved = sameID ?? (identityMatches.count == 1 ? identityMatches.first : nil)
        guard let current = resolved else {
            destination = .testWindow
            recoveryMessage = "\(previous?.name ?? "Selected display") disconnected — Test Window selected"
            return
        }
        destination = .display(current.id)
        if let reason = current.unavailableReason {
            destination = .testWindow
            recoveryMessage = "\(current.name): \(reason) — Test Window selected.\(current.isMirrored ? " Use an extended display in System Settings → Displays." : "")"
        }
    }

    private func restore() {
        guard !savedPreference.requiresManualSelection else {
            recoveryMessage = "Select \(savedPreference.displayName ?? "your display") manually; its saved identity is unavailable or ambiguous. Test Window selected."
            return
        }
        guard let uuid = savedPreference.displayUUID else { return }
        let matches = displays.filter { $0.uuid == uuid }
        guard matches.count == 1, let display = matches.first else {
            recoveryMessage = "\(savedPreference.displayName ?? "Saved display") \(matches.isEmpty ? "not connected" : "has an ambiguous identity") — Test Window selected"
            return
        }
        guard display.isEligible else {
            recoveryMessage = "\(display.name): \(display.unavailableReason ?? "Unavailable") — Test Window selected.\(display.isMirrored ? " Use an extended display in System Settings → Displays." : "")"
            return
        }
        destination = .display(display.id)
        recoveryMessage = nil
    }
    private func persist(_ value: SavedOutputPreference) {
        savedPreference = value
        preferences.save(value)
    }
}
