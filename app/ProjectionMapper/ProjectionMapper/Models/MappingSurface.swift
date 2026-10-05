import Foundation

/// Project-owned geometry; normalized coordinates are independent of output size and selection.
struct MappingSurface: Identifiable, Equatable, Sendable {
    static let defaultName = "Surface 1"
    let id: UUID
    var name: String
    var corners: NormalizedRectangle
    var color: SIMD4<Float>

    init(id: UUID = UUID(), name: String = MappingSurface.defaultName,
         corners: NormalizedRectangle = .diagnostic, color: SIMD4<Float> = RenderScene.diagnostic.color) {
        self.id = id
        self.name = name
        self.corners = corners
        self.color = color
    }

    var hasDefaultContent: Bool {
        name == Self.defaultName && corners == .diagnostic && color == RenderScene.diagnostic.color
    }
    var renderScene: RenderScene { RenderScene(geometry: corners, color: color) }
}
