import Foundation

enum SurfaceCorner: String, CaseIterable, Identifiable, Sendable {
    case topLeft, topRight, bottomRight, bottomLeft
    var id: Self { self }
    var title: String {
        switch self {
        case .topLeft: "Top left"
        case .topRight: "Top right"
        case .bottomRight: "Bottom right"
        case .bottomLeft: "Bottom left"
        }
    }
}

extension NormalizedRectangle {
    subscript(_ corner: SurfaceCorner) -> SIMD2<Float> {
        switch corner {
        case .topLeft: topLeft
        case .topRight: topRight
        case .bottomRight: bottomRight
        case .bottomLeft: bottomLeft
        }
    }
    func replacing(_ corner: SurfaceCorner, with point: SIMD2<Float>) -> Self {
        Self(topLeft: corner == .topLeft ? point : topLeft,
             topRight: corner == .topRight ? point : topRight,
             bottomRight: corner == .bottomRight ? point : bottomRight,
             bottomLeft: corner == .bottomLeft ? point : bottomLeft)
    }
}

/// UI points refer to the fitted preview only, not the surrounding canvas or backing pixels.
enum SurfaceCoordinates {
    static func position(_ point: SIMD2<Float>, in rect: CGRect) -> CGPoint {
        CGPoint(x: rect.minX + CGFloat(point.x) * rect.width,
                y: rect.minY + CGFloat(point.y) * rect.height)
    }
    static func normalized(_ point: CGPoint, in rect: CGRect) -> SIMD2<Float>? {
        guard point.x.isFinite, point.y.isFinite, rect.minX.isFinite, rect.minY.isFinite,
              rect.width.isFinite, rect.height.isFinite, rect.width > 0, rect.height > 0 else { return nil }
        return SIMD2(Float(min(1, max(0, (point.x - rect.minX) / rect.width))),
                     Float(min(1, max(0, (point.y - rect.minY) / rect.height))))
    }
}
