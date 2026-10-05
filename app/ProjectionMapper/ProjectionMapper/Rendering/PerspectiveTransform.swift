import simd

/// A single projective transform for the entire surface, independent of its triangulation.
struct PerspectiveTransform: Sendable {
    let forward: simd_double3x3
    let inverse: simd_double3x3

    init?(_ geometry: NormalizedRectangle) {
        let points = [geometry.topLeft, geometry.topRight, geometry.bottomRight, geometry.bottomLeft]
            .map { SIMD2<Double>(Double($0.x), Double($0.y)) }
        guard points.allSatisfy({ $0.x.isFinite && $0.y.isFinite &&
            (0...1).contains($0.x) && (0...1).contains($0.y) }) else { return nil }
        var turns: [Double] = []
        for i in 0..<4 {
            let first = points[(i + 1) % 4] - points[i]
            let second = points[(i + 2) % 4] - points[(i + 1) % 4]
            turns.append(first.x * second.y - first.y * second.x)
        }
        // Both windings are supported. Strict convexity excludes intersections and zero-area edges.
        guard turns.allSatisfy({ $0 > 1e-6 }) || turns.allSatisfy({ $0 < -1e-6 }) else { return nil }
        let p0 = points[0], p1 = points[1], p2 = points[2], p3 = points[3]
        let delta1 = p1 - p2, delta2 = p3 - p2, delta3 = p0 - p1 + p2 - p3
        let denominator = delta1.x * delta2.y - delta2.x * delta1.y
        let g = (delta3.x * delta2.y - delta2.x * delta3.y) / denominator
        let h = (delta1.x * delta3.y - delta3.x * delta1.y) / denominator
        guard [1.0, 1 + g, 1 + h, 1 + g + h].allSatisfy({ $0.isFinite && $0 > 1e-7 }) else { return nil }
        let matrix = simd_double3x3(columns: (
            SIMD3(p1.x - p0.x + g * p1.x, p1.y - p0.y + g * p1.y, g),
            SIMD3(p3.x - p0.x + h * p3.x, p3.y - p0.y + h * p3.y, h),
            SIMD3(p0.x, p0.y, 1)))
        guard matrix.determinant.isFinite, abs(matrix.determinant) > 1e-12 else { return nil }
        let inverted = matrix.inverse
        guard (0..<3).allSatisfy({ column in (0..<3).allSatisfy { inverted[column][$0].isFinite } }) else { return nil }
        forward = matrix
        inverse = inverted
    }

    func project(_ uv: SIMD2<Double>) -> SIMD2<Double> {
        let result = forward * SIMD3(uv.x, uv.y, 1)
        return SIMD2(result.x, result.y) / result.z
    }

    /// Common scale is immaterial after homogeneous division; bound Float conversion error.
    var shaderInverse: simd_float3x3 {
        let scale = (0..<3).flatMap { c in (0..<3).map { abs(inverse[c][$0]) } }.max()!
        return simd_float3x3(columns: (
            SIMD3<Float>(inverse[0] / scale), SIMD3<Float>(inverse[1] / scale), SIMD3<Float>(inverse[2] / scale)))
    }
}
