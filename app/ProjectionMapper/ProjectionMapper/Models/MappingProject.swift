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
    var palettes: [ColorPalette] = []
    var looks: [ProjectLook] = []
    var masterOutput = MasterOutputSettings.defaults

    init(id: UUID = UUID(), name: String = MappingProject.defaultName, now: Date = .now,
         surface: MappingSurface = MappingSurface()) {
        self.id = id; self.name = name; createdAt = now; modifiedAt = now
        surfaces = [surface]
    }
    var hasDefaultContent: Bool {
        name == Self.defaultName && surfaces.count == 1 && surfaces[0].hasDefaultContent && objects.isEmpty && generatorPresets.isEmpty &&
        palettes.isEmpty && looks.isEmpty && masterOutput == .defaults
    }
    func object(for face: MappingSurface) -> MappingObject? { objects.first { $0.id == face.layout.objectID } }
    func source(for face: MappingSurface) -> SurfaceSource { object(for: face)?.source ?? face.source }
    func paletteColor(for binding: ColorBinding) -> SIMD4<Float>? {
        palettes.first { $0.id == binding.paletteID }?.slots.first { $0.id == binding.slotID }?.color
    }
    /// Defensive in-memory fallback; package validation rejects unresolved references.
    func resolvedSource(_ source: SurfaceSource) -> SurfaceSource {
        var resolved = source
        if let binding = source.primaryBinding, let color = paletteColor(for: binding) { resolved.color = color }
        if let binding = source.secondaryBinding, let color = paletteColor(for: binding) { resolved.generator.secondaryColor = color }
        return resolved
    }
    func appearance(for face: MappingSurface) -> SurfaceAppearance {
        if let object = object(for: face) { return face.appearanceOverride ?? object.appearance }
        return face.appearance
    }
    func isGeometryLocked(_ face: MappingSurface) -> Bool { face.layout.isGeometryLocked || object(for: face)?.isGeometryLocked == true }
    func canMoveObject(_ id: UUID) -> Bool {
        let members = surfaces.filter { $0.layout.objectID == id }
        return objects.contains { $0.id == id } && !members.isEmpty && !members.contains { isGeometryLocked($0) }
    }
    func outputBounds(forObject id: UUID) -> NormalizedRectangle? {
        let points = surfaces.filter { $0.layout.objectID == id }.flatMap { face in SurfaceCorner.allCases.map { face.corners[$0] } }
        guard !points.isEmpty, points.allSatisfy({ $0.x.isFinite && $0.y.isFinite }) else { return nil }
        let minX = points.map(\.x).min()!, maxX = points.map(\.x).max()!, minY = points.map(\.y).min()!, maxY = points.map(\.y).max()!
        return NormalizedRectangle(topLeft: SIMD2(minX,minY),topRight: SIMD2(maxX,minY),bottomRight: SIMD2(maxX,maxY),bottomLeft: SIMD2(minX,maxY))
    }
    var renderScene: RenderScene {
        RenderScene(surfaces: surfaces.reversed().compactMap { face in
            guard face.layout.isVisible, object(for: face)?.isVisible != false else { return nil }
            let owner = resolvedSource(source(for: face))
            let map = object(for: face)?.mode == .repeatContent ? .full : face.layout.inputMap
            return RenderSurface(geometry: face.corners, color: owner.color, content: owner.content, inputMap: map, generator: owner.generator, sourceID: owner.id, appearance: appearance(for: face), mask: face.mask)
        }, masterBrightness: masterOutput.brightness)
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
        func sample(_ appearance: SurfaceAppearance,_ uv: SIMD2<Float>) -> SIMD2<Float> {
            let result = appearance.matrix * SIMD3(uv.x,uv.y,1); return SIMD2(result.x,result.y)
        }
        let appearanceA = appearance(for: a), appearanceB = appearance(for: b)
        guard simd_length(sample(appearanceA,mapA.sample(a0)) - sample(appearanceB,first)) < 0.0001,
              simd_length(sample(appearanceA,mapA.sample(a1)) - sample(appearanceB,second)) < 0.0001 else { return "Face crop/flip overrides differ at this join" }
        if appearanceA.opacity != appearanceB.opacity || appearanceA.brightness != appearanceB.brightness { return "Face appearance overrides differ at this join" }
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
