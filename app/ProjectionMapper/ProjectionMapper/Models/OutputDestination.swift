import Foundation
import CoreGraphics

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

enum TestResolution: String, CaseIterable, Identifiable, Codable {
    case hd, fullHD, standard, portrait, ultraHD
    var id: String { rawValue }
    var name: String {
        switch self {
        case .hd: "HD"
        case .fullHD: "Full HD"
        case .standard: "4:3"
        case .portrait: "Portrait"
        case .ultraHD: "4K"
        }
    }
    var size: CGSize {
        switch self {
        case .hd: CGSize(width: 1280, height: 720)
        case .fullHD: CGSize(width: 1920, height: 1080)
        case .standard: CGSize(width: 1024, height: 768)
        case .portrait: CGSize(width: 1080, height: 1920)
        case .ultraHD: CGSize(width: 3840, height: 2160)
        }
    }
    var aspectRatio: Double { size.width / size.height }
    var dimensions: String { "\(Int(size.width)) × \(Int(size.height))" }
    var label: String { "\(name) · \(dimensions)" }

    func fittedRect(in bounds: CGRect) -> CGRect {
        guard bounds.width > 0, bounds.height > 0 else { return .zero }
        let scale = min(bounds.width / size.width, bounds.height / size.height)
        let fitted = CGSize(width: size.width * scale, height: size.height * scale)
        return CGRect(x: bounds.midX - fitted.width / 2, y: bounds.midY - fitted.height / 2,
                      width: fitted.width, height: fitted.height)
    }
}
