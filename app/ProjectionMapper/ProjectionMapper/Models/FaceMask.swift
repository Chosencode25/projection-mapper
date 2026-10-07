import Foundation
import simd

struct MaskPolygon: Identifiable, Equatable, Sendable, Codable {
    var id = UUID()
    var points: [SIMD2<Float>]
    static let rectangle = Self(points: [SIMD2(0,0), SIMD2(1,0), SIMD2(1,1), SIMD2(0,1)])
}

/// Original face UV, independent of content sampling. Invalid bounded drafts remain recoverable.
struct FaceMask: Equatable, Sendable, Codable {
    static let maxPoints = 32
    static let maxHoles = 7
    var isEnabled = true
    var boundary = MaskPolygon.rectangle
    var holes: [MaskPolygon] = []
    var rings: [MaskPolygon] { [boundary] + holes }
    var isBounded: Bool {
        holes.count <= Self.maxHoles && Set(rings.map(\.id)).count == rings.count &&
        rings.allSatisfy { $0.points.count <= Self.maxPoints && $0.points.allSatisfy {
            $0.x.isFinite && $0.y.isFinite && (0...1).contains($0.x) && (0...1).contains($0.y)
        } }
    }
    var validationMessage: String? {
        guard isBounded else { return "Mask exceeds point limits or contains invalid coordinates." }
        for (index, ring) in rings.enumerated() {
            if !Self.isSimple(ring.points) { return "\(index == 0 ? "Boundary" : "Hole \(index)") needs at least three distinct points with area and no crossing edges." }
        }
        for hole in holes {
            guard hole.points.allSatisfy({ Self.location($0, in: boundary.points) == 1 }),
                  !Self.intersects(hole.points, boundary.points) else { return "Every hole must be strictly inside the boundary without touching it." }
        }
        for i in holes.indices {
            for j in holes.indices where j > i {
                let a = holes[i].points, b = holes[j].points
                if Self.intersects(a,b) || Self.location(a[0],in: b) >= 0 || Self.location(b[0],in: a) >= 0 {
                    return "Holes must not overlap, touch, or contain one another."
                }
            }
        }
        return nil
    }
    var allowsRendering: Bool { !isEnabled || validationMessage == nil }
    func contains(_ point: SIMD2<Float>) -> Bool {
        guard isEnabled else { return true }
        guard validationMessage == nil else { return false }
        return Self.location(point,in: boundary.points) >= 0 && holes.allSatisfy { Self.location(point,in: $0.points) < 0 }
    }
    func independentCopy() -> Self {
        var copy = self; copy.boundary.id = UUID()
        for i in copy.holes.indices { copy.holes[i].id = UUID() }
        return copy
    }
    // GPU payload: fixed 8 uint2 ring descriptors and at most 256 float2 points (<4 KB).
    var shaderRings: [SIMD2<UInt32>] {
        guard isEnabled, validationMessage == nil else { return Array(repeating: .zero,count: 8) }
        var offset: UInt32 = 0
        let values = rings.map { ring -> SIMD2<UInt32> in
            defer { offset += UInt32(ring.points.count) }
            return SIMD2(offset,UInt32(ring.points.count))
        }
        return values + Array(repeating: .zero,count: 8-values.count)
    }
    var shaderPoints: [SIMD2<Float>] { rings.flatMap(\.points) }
    private static let epsilon: Float = 1e-6
    private static func cross(_ a: SIMD2<Float>,_ b: SIMD2<Float>) -> Float { a.x*b.y-a.y*b.x }
    private static func onSegment(_ p: SIMD2<Float>,_ a: SIMD2<Float>,_ b: SIMD2<Float>) -> Bool {
        abs(cross(b-a,p-a)) <= epsilon && dot(p-a,p-b) <= epsilon
    }
    /// -1 outside, 0 boundary, 1 inside; both windings and concave polygons supported.
    static func location(_ p: SIMD2<Float>, in points: [SIMD2<Float>]) -> Int {
        guard points.count >= 3 else { return -1 }
        var inside = false
        for i in points.indices {
            let a = points[i], b = points[(i+1)%points.count]
            if onSegment(p,a,b) { return 0 }
            if (a.y > p.y) != (b.y > p.y), p.x < (b.x-a.x)*(p.y-a.y)/(b.y-a.y)+a.x { inside.toggle() }
        }
        return inside ? 1 : -1
    }
    private static func segments(_ a: SIMD2<Float>,_ b: SIMD2<Float>,_ c: SIMD2<Float>,_ d: SIMD2<Float>) -> Bool {
        if onSegment(a,c,d) || onSegment(b,c,d) || onSegment(c,a,b) || onSegment(d,a,b) { return true }
        let x = cross(b-a,c-a), y = cross(b-a,d-a), z = cross(d-c,a-c), w = cross(d-c,b-c)
        return ((x > epsilon && y < -epsilon) || (x < -epsilon && y > epsilon)) &&
               ((z > epsilon && w < -epsilon) || (z < -epsilon && w > epsilon))
    }
    private static func intersects(_ a: [SIMD2<Float>],_ b: [SIMD2<Float>]) -> Bool {
        a.indices.contains { i in b.indices.contains { j in segments(a[i],a[(i+1)%a.count],b[j],b[(j+1)%b.count]) } }
    }
    private static func isSimple(_ p: [SIMD2<Float>]) -> Bool {
        guard p.count >= 3 else { return false }
        var area: Float = 0
        for i in p.indices {
            let next = (i+1)%p.count, after = (i+2)%p.count
            guard length_squared(p[next]-p[i]) > epsilon*epsilon else { return false }
            if abs(cross(p[next]-p[i],p[after]-p[next])) <= epsilon && dot(p[next]-p[i],p[after]-p[next]) < 0 { return false }
            area += cross(p[i],p[next])
            for j in p.indices where j > i && j != next && (j+1)%p.count != i {
                if segments(p[i],p[next],p[j],p[(j+1)%p.count]) { return false }
            }
        }
        return abs(area) > epsilon
    }
}

/// Shared editor hit/drag conversion. Nil geometry means the local inspector fallback.
enum MaskEditorGeometry {
    static func project(_ point: SIMD2<Float>, corners: NormalizedRectangle?) -> SIMD2<Float>? {
        guard point.x.isFinite, point.y.isFinite else { return nil }
        guard let corners else { return point }
        guard let transform = PerspectiveTransform(corners) else { return nil }
        let result = transform.project(SIMD2(Double(point.x),Double(point.y)))
        return SIMD2(Float(result.x),Float(result.y))
    }
    static func unproject(_ point: SIMD2<Float>, corners: NormalizedRectangle?) -> SIMD2<Float>? {
        guard point.x.isFinite, point.y.isFinite else { return nil }
        guard let corners else { return point }
        guard let transform = PerspectiveTransform(corners) else { return nil }
        let uv = transform.inverse * SIMD3(Double(point.x),Double(point.y),1)
        guard uv.z.isFinite, abs(uv.z) > 1e-12 else { return nil }
        let result = SIMD2(Float(uv.x/uv.z),Float(uv.y/uv.z))
        return result.x.isFinite && result.y.isFinite ? result : nil
    }
}
