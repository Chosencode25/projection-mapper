import Foundation
import CoreGraphics

struct DisplayDescriptor: Identifiable, Equatable {
    var id: UInt32
    var uuid: String?
    var name: String
    var isBuiltIn = false
    var desktopFrame: CGRect?
    var renderWidth: Int?
    var renderHeight: Int?
    var isRenderSizeEstimated = false
    var scale: Double?
    var refreshRate: Double?
    var isMirrored = false
    var hasIndependentScreen = true
    var isEditorDisplay = false

    var unavailableReason: String? {
        if isBuiltIn { return "Built-in display" }
        if isMirrored { return "Mirroring enabled" }
        if isEditorDisplay { return "Editor display" }
        if !hasIndependentScreen { return "Display unavailable" }
        return nil
    }
    var isEligible: Bool { unavailableReason == nil }
    var aspectRatio: Double? {
        guard let width = renderWidth, let height = renderHeight, width > 0, height > 0 else { return nil }
        return Double(width) / Double(height)
    }
    var renderSizeText: String {
        guard aspectRatio != nil, let width = renderWidth, let height = renderHeight else { return "Not reported" }
        return "\(width) × \(height) px\(isRenderSizeEstimated ? " (estimated)" : "")"
    }
    var desktopSizeText: String {
        guard let frame = desktopFrame, frame.width.isFinite, frame.height.isFinite,
              frame.width > 0, frame.height > 0 else { return "Not reported" }
        return "\(Self.number(frame.width)) × \(Self.number(frame.height)) pt"
    }
    var scaleText: String {
        guard let scale, scale.isFinite, scale > 0 else { return "Not reported" }
        return "\(Self.number(scale))×"
    }
    var refreshText: String {
        guard let refreshRate, refreshRate.isFinite, refreshRate > 0 else { return "Not reported" }
        return "\(Self.number(refreshRate)) Hz"
    }
    static func number(_ value: Double) -> String {
        value.formatted(.number.precision(.fractionLength(0...2)))
    }
}
