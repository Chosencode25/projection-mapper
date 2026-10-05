/// Four-corner surface geometry: origin at top-left, x rightward, y downward.
/// Coordinates describe fractions of the fitted output, excluding black margins.
struct NormalizedRectangle: Equatable, Sendable {
    let topLeft: SIMD2<Float>
    let topRight: SIMD2<Float>
    let bottomRight: SIMD2<Float>
    let bottomLeft: SIMD2<Float>

    static let diagnostic = NormalizedRectangle(
        topLeft: SIMD2(0.25, 0.25), topRight: SIMD2(0.75, 0.25),
        bottomRight: SIMD2(0.75, 0.75), bottomLeft: SIMD2(0.25, 0.75)
    )

    static func clipPosition(_ point: SIMD2<Float>) -> SIMD2<Float> {
        SIMD2(2 * point.x - 1, 1 - 2 * point.y)
    }

    var trianglePositions: [SIMD2<Float>] {
        [bottomLeft, bottomRight, topLeft, bottomRight, topRight, topLeft].map(Self.clipPosition)
    }
}
