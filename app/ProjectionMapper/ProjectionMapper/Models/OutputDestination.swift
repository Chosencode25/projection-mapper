import Foundation

/// Runtime IDs select a screen for this run; only a unique UUID is saved across runs.
enum OutputDestination: Hashable {
    case testWindow
    case display(UInt32)
}

struct SavedOutputPreference: Codable, Equatable {
    var displayUUID: String?
    var displayName: String?
    var requiresManualSelection = false
    static let testWindow = SavedOutputPreference()
}
