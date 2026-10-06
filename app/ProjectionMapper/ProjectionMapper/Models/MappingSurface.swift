import Foundation
import simd

/// Declarative content sampling and appearance; independent from output geometry and clocks.
struct ContentCrop: Equatable, Sendable, Codable {
    var origin = SIMD2<Float>(0,0)
    var size = SIMD2<Float>(1,1)
    var isValid: Bool { FaceInputMap(origin: origin,size: size).isValid }
}
struct SurfaceAppearance: Equatable, Sendable, Codable {
    var opacity: Float = 1
    var brightness: Float = 1
    var crop = ContentCrop()
    var flipHorizontal = false
    var flipVertical = false
    static let defaults = Self()
    var isValid: Bool {
        opacity.isFinite && (0...1).contains(opacity) && brightness.isFinite && (0...2).contains(brightness) && crop.isValid
    }
    /// Crop the selected source region, then flip its displayed orientation.
    var matrix: simd_float3x3 {
        let x: Float = flipHorizontal ? -1 : 1, y: Float = flipVertical ? -1 : 1
        let origin = crop.origin + crop.size * SIMD2(flipHorizontal ? 1 : 0,flipVertical ? 1 : 0)
        return simd_float3x3(columns: (SIMD3(crop.size.x*x,0,0),SIMD3(0,crop.size.y*y,0),SIMD3(origin.x,origin.y,1)))
    }
}

struct SurfaceSource: Equatable, Sendable, Codable {
    var id = UUID()
    var content: SurfaceContent = .diagnosticGrid
    var generator: GeneratorSettings = .defaults
    var color: SIMD4<Float> = SIMD4(1, 0.25, 0, 1)
    var primaryBinding: ColorBinding?
    var secondaryBinding: ColorBinding?
    func independentCopy() -> Self { var copy = self; copy.id = UUID(); return copy }
}

enum ObjectContentMode: String, CaseIterable, Identifiable, Sendable, Codable {
    case continuous, repeatContent
    var id: Self { self }
    var title: String { self == .continuous ? "Continuous canvas" : "Repeat on every face" }
}

/// Input coordinates are separate from projector/output corners.
struct FaceInputMap: Equatable, Sendable, Codable {
    var origin = SIMD2<Float>(0, 0)
    var size = SIMD2<Float>(1, 1)
    var quarterTurns = 0
    var mirrored = false
    static let full = Self()
    var isValid: Bool {
        origin.x.isFinite && origin.y.isFinite && size.x.isFinite && size.y.isFinite &&
        origin.x >= 0 && origin.y >= 0 && size.x > 0.0001 && size.y > 0.0001 &&
        origin.x + size.x <= 1.00001 && origin.y + size.y <= 1.00001 && (0...3).contains(quarterTurns)
    }
    func sample(_ point: SIMD2<Float>) -> SIMD2<Float> {
        var uv = point
        if mirrored { uv.x = 1 - uv.x }
        for _ in 0..<max(0, min(3, quarterTurns)) { uv = SIMD2(1 - uv.y, uv.x) }
        return origin + uv * size
    }
    var matrix: simd_float3x3 {
        let zero = sample(.zero), x = sample(SIMD2(1, 0)) - zero, y = sample(SIMD2(0, 1)) - zero
        return simd_float3x3(columns: (SIMD3(x.x, x.y, 0), SIMD3(y.x, y.y, 0), SIMD3(zero.x, zero.y, 1)))
    }
}

enum FaceEdge: String, CaseIterable, Identifiable, Sendable, Codable {
    case top, right, bottom, left
    var id: Self { self }
    var title: String { rawValue.capitalized }
    var endpoints: (SIMD2<Float>, SIMD2<Float>) {
        switch self {
        case .top: (SIMD2(0,0), SIMD2(1,0))
        case .right: (SIMD2(1,0), SIMD2(1,1))
        case .bottom: (SIMD2(1,1), SIMD2(0,1))
        case .left: (SIMD2(0,1), SIMD2(0,0))
        }
    }
}

struct FaceEdgeLink: Identifiable, Equatable, Sendable, Codable {
    var id = UUID()
    var firstFace: UUID
    var firstEdge: FaceEdge
    var secondFace: UUID
    var secondEdge: FaceEdge
    var reversed = true
    var isSeam = false
}

struct MappingObject: Identifiable, Equatable, Sendable, Codable {
    var id = UUID()
    var name: String
    var source: SurfaceSource
    var appearance = SurfaceAppearance.defaults
    var isGeometryLocked = false
    var mode: ObjectContentMode = .continuous
    var isVisible = true
    var tags: [String] = []
    var links: [FaceEdgeLink] = []
}

struct SurfaceLayout: Equatable, Sendable, Codable {
    var corners: NormalizedRectangle = .diagnostic
    var isGeometryLocked = false
    var inputMap: FaceInputMap = .full
    var objectID: UUID?
    var isVisible = true
}

struct MappingSurface: Identifiable, Equatable, Sendable, Codable {
    static let defaultName = "Surface 1"
    let id: UUID
    var name: String
    var layout: SurfaceLayout
    var source: SurfaceSource
    var tags: [String] = []
    var appearance = SurfaceAppearance.defaults
    var appearanceOverride: SurfaceAppearance?
    var corners: NormalizedRectangle {
        get { layout.corners }
        set { layout.corners = newValue }
    }
    var color: SIMD4<Float> { get { source.color } set { source.color = newValue } }
    var content: SurfaceContent { get { source.content } set { source.content = newValue } }
    init(id: UUID = UUID(), name: String = MappingSurface.defaultName,
         corners: NormalizedRectangle = .diagnostic, color: SIMD4<Float> = SIMD4(1, 0.25, 0, 1),
         content: SurfaceContent = .diagnosticGrid) {
        self.id = id; self.name = name
        layout = SurfaceLayout(corners: corners)
        source = SurfaceSource(content: content, color: color)
    }
    var hasDefaultContent: Bool {
        name == Self.defaultName && layout == SurfaceLayout() && tags.isEmpty && appearance == .defaults && appearanceOverride == nil &&
        color == SIMD4(1, 0.25, 0, 1) && content == .diagnosticGrid && source.generator == .defaults &&
        source.primaryBinding == nil && source.secondaryBinding == nil
    }
    var renderScene: RenderScene { RenderScene(surfaces: [RenderSurface(geometry: corners, color: color, content: content, generator: source.generator, appearance: appearance)]) }
}

/// Reset scopes intentionally preserve layout membership, input maps, identities and runtime clocks.
enum FaceResetScope { case outputGeometry, appearance, cropAndFlip, generatorParameters, content, fullFace }
enum ObjectResetScope { case appearance, cropAndFlip, generatorParameters, content, inputLayout }
