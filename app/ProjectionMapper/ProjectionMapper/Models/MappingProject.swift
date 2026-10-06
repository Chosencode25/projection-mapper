import Foundation
import simd

struct GeneratorPreset: Identifiable, Equatable, Codable {
    var id = UUID()
    var name: String
    var content: SurfaceContent
    var color: SIMD4<Float>
    var settings: GeneratorSettings
}

struct MappingProject: Equatable, Codable {
    static let defaultName = "Untitled Project"
    let id: UUID
    var name: String
    let createdAt: Date
    var modifiedAt: Date
    /// Topmost first, matching the sidebar. Draw in reverse order.
    var surfaces: [MappingSurface]
    var objects: [MappingObject] = []
    var generatorPresets: [GeneratorPreset] = []

    init(id: UUID = UUID(), name: String = MappingProject.defaultName, now: Date = .now,
         surface: MappingSurface = MappingSurface()) {
        self.id = id; self.name = name; createdAt = now; modifiedAt = now
        surfaces = [surface]
    }
    var hasDefaultContent: Bool {
        name == Self.defaultName && surfaces.count == 1 && surfaces[0].hasDefaultContent && objects.isEmpty && generatorPresets.isEmpty
    }
    func object(for face: MappingSurface) -> MappingObject? { objects.first { $0.id == face.layout.objectID } }
    func source(for face: MappingSurface) -> SurfaceSource { object(for: face)?.source ?? face.source }
    var renderScene: RenderScene {
        RenderScene(surfaces: surfaces.reversed().compactMap { face in
            guard face.layout.isVisible, object(for: face)?.isVisible != false else { return nil }
            let owner = source(for: face)
            let map = object(for: face)?.mode == .repeatContent ? .full : face.layout.inputMap
            return RenderSurface(geometry: face.corners, color: owner.color, content: owner.content, inputMap: map, generator: owner.generator, sourceID: owner.id)
        })
    }
    func joinMessage(_ link: FaceEdgeLink, objectID: UUID) -> String? {
        guard let a = surfaces.first(where: { $0.id == link.firstFace && $0.layout.objectID == objectID }),
              let b = surfaces.first(where: { $0.id == link.secondFace && $0.layout.objectID == objectID }), a.id != b.id else {
            return "Missing or invalid face reference"
        }
        if link.isSeam { return "Deliberate seam" }
        guard a.layout.inputMap.isValid, b.layout.inputMap.isValid else { return "Invalid input region" }
        let (a0,a1) = link.firstEdge.endpoints, (b0,b1) = link.secondEdge.endpoints
        let mapA = a.layout.inputMap, mapB = b.layout.inputMap
        let first = mapB.sample(link.reversed ? b1 : b0), second = mapB.sample(link.reversed ? b0 : b1)
        guard simd_length(mapA.sample(a0) - first) < 0.0001,
              simd_length(mapA.sample(a1) - second) < 0.0001 else { return "Input edges differ in position, direction or scale" }
        let direction = mapA.sample(a1) - mapA.sample(a0)
        let centerA = mapA.sample(SIMD2(0.5,0.5)) - mapA.sample(a0)
        let centerB = mapB.sample(SIMD2(0.5,0.5)) - mapA.sample(a0)
        let sideA = direction.x * centerA.y - direction.y * centerA.x
        let sideB = direction.x * centerB.y - direction.y * centerB.x
        guard sideA * sideB < 0 else { return "Joined input regions overlap on the same side of the edge" }
        return nil
    }
    var joinWarnings: [String] {
        objects.flatMap { object in object.links.compactMap { link in
            guard !link.isSeam, let message = joinMessage(link, objectID: object.id) else { return nil }
            return "\(object.name): \(message)"
        } }
    }
}
