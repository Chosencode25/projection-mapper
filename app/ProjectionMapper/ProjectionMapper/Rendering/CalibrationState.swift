import Foundation

/// Session-only display override, independent of saved SurfaceContent and appearance.
enum CalibrationPattern: UInt32, CaseIterable, Identifiable, Sendable {
    case normal = 0, grid, checkerboard, crosshair, white, black, verticalStripes, horizontalStripes
    var id: Self { self }
    var isActive: Bool { self != .normal }
    var usesCellCounts: Bool { self == .grid || self == .checkerboard || self == .verticalStripes || self == .horizontalStripes }
    var usesLineWidth: Bool { self == .grid || self == .crosshair }
    var title: String {
        switch self {
        case .normal: "Normal Content"
        case .grid: "Grid"
        case .checkerboard: "Checkerboard"
        case .crosshair: "Crosshair"
        case .white: "White Test"
        case .black: "Black Test"
        case .verticalStripes: "Vertical Stripes"
        case .horizontalStripes: "Horizontal Stripes"
        }
    }
}
struct CalibrationState: Equatable, Sendable {
    var pattern: CalibrationPattern = .normal
    var columns = 8
    var rows = 8
    var lineWidth: Float = 1
    var isValid: Bool {
        (2...64).contains(columns) && (2...64).contains(rows) && lineWidth.isFinite && (1...4).contains(lineWidth)
    }
    var shaderParameters: SIMD4<Float> { SIMD4(Float(pattern.rawValue), Float(columns), Float(rows), lineWidth) }
}
