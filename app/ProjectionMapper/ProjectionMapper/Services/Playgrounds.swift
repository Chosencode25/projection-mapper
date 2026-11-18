import Foundation
import UniformTypeIdentifiers

/// A local setup snapshot. Target IDs are scoped by the independent project identity.
enum PlaygroundExtraction {
    static func extract(_ document: ProjectDocument, name: String, now: Date = .now) throws -> ProjectDocument {
        try ProjectCodec.validate(document)
        let original = document.project
        var p = MappingProject(name: name.trimmingCharacters(in: .whitespacesAndNewlines), now: now)
        p.surfaces = original.surfaces
        p.objects = original.objects
        p.referencePhoto = original.referencePhoto
        p.imageAssets = original.imageAssets.filter { $0.id == original.referencePhoto?.assetID }
        p.visualLayers = original.visualLayers
        p.faceRegions = original.faceRegions
        p.regionShapePresets = original.regionShapePresets
        p.masterOutput.brightness = original.masterOutput.brightness
        p.lighting.controllers = original.lighting.controllers
        p.lighting.fixtures = original.lighting.fixtures
        for i in p.surfaces.indices { p.surfaces[i].source = emptySource(p.surfaces[i].source.id) }
        for i in p.objects.indices { p.objects[i].source = emptySource(p.objects[i].source.id) }
        for i in p.visualLayers?.indices ?? 0..<0 { clear(&p.visualLayers![i].track) }
        for i in p.faceRegions?.indices ?? 0..<0 { clear(&p.faceRegions![i].track) }
        let result = ProjectDocument(project: p, output: document.output)
        try ProjectCodec.validate(result)
        return result
    }
    private static func emptySource(_ id: UUID) -> SurfaceSource {
        var source = SurfaceSource(content: .solid, color: SIMD4(0, 0, 0, 1))
        source.id = id
        return source
    }
    private static func clear(_ track: inout VisualTrack) {
        track.source = emptySource(track.id)
        track.source.color.w = 0
        track.kind = .media
        track.mouthKeys = []
        track.text.mode = .greeting
        track.text.message = ""
        track.text.markerID = nil
        track.text.countdownEnd = 0
    }
    static func validateSetup(_ document: ProjectDocument) throws {
        var expected = try extract(document, name: document.project.name, now: document.project.createdAt)
        // Creation regenerates only the project identity and timestamps, not target relationships.
        var actual = try JSONSerialization.jsonObject(with: ProjectCodec.encode(document)) as! [String: Any]
        var project = actual["project"] as! [String: Any]
        project["id"] = expected.project.id.uuidString
        project["modifiedAt"] = project["createdAt"]
        actual["project"] = project
        expected.recovery = nil
        guard try ProjectCodec.decode(JSONSerialization.data(withJSONObject: actual)) == expected else {
            throw ProjectFileError.invalid("A playground must contain setup only, without show programming or recovery state.")
        }
    }
}

struct PlaygroundInfo: Codable, Equatable {
    static let currentVersion = 1
    var schemaVersion = currentVersion
    var id = UUID()
    var name: String
    var note = ""
    var modifiedAt = Date.now
    func validate() throws {
        guard schemaVersion == Self.currentVersion else { throw ProjectFileError.invalid("Unsupported playground version. Update Projection Mapper.") }
        guard !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, name.count <= 80,
              note.count <= 500, modifiedAt.timeIntervalSince1970.isFinite else {
            throw ProjectFileError.invalid("Use a playground name of 1–80 characters and a note of at most 500 characters.")
        }
    }
}

final class PlaygroundLibrary {
    struct Entry: Identifiable {
        var url: URL
        var info: PlaygroundInfo
        var id: UUID { info.id }
    }
    static let fileExtension = "projectionplayground"
    static let contentType = UTType(exportedAs: "local.keith.projectionplayground", conformingTo: .package)
    static var defaultDirectory: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("ProjectionMapper/Playgrounds", isDirectory: true)
    }
    let directory: URL
    init(directory: URL = defaultDirectory) { self.directory = directory }
    func entries() throws -> [Entry] {
        guard FileManager.default.fileExists(atPath: directory.path) else { return [] }
        return try FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)
            .filter { $0.pathExtension == Self.fileExtension }
            .map { Entry(url: $0, info: try read($0).info) }
            .sorted { $0.info.name.localizedStandardCompare($1.info.name) == .orderedAscending }
    }
    func read(_ url: URL) throws -> (info: PlaygroundInfo, document: ProjectDocument, images: [UUID: Data]) {
        let document = try ProjectPackageStore().read(url)
        let metadata = url.appendingPathComponent("playground.json")
        let values = try metadata.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey, .fileSizeKey])
        guard values.isRegularFile == true, values.isSymbolicLink != true, (values.fileSize ?? Int.max) <= 8192 else {
            throw ProjectFileError.invalid("Unsafe or missing playground metadata.")
        }
        let info = try JSONDecoder().decode(PlaygroundInfo.self, from: Data(contentsOf: metadata))
        try info.validate()
        try PlaygroundExtraction.validateSetup(document)
        guard document.project.name == info.name else { throw ProjectFileError.invalid("Playground names disagree.") }
        let images = ImageImportService.loadAssets(document.project, package: url)
        guard images.problems.isEmpty else { throw ProjectFileError.invalid("The playground reference photo is missing or damaged.") }
        return (info, document, images.files)
    }
    @discardableResult
    func save(_ document: ProjectDocument, info: PlaygroundInfo, images: [UUID: Data], to destination: URL? = nil,
              beforeCommit: ((URL) throws -> Void)? = nil) throws -> URL {
        var info = info
        info.name = info.name.trimmingCharacters(in: .whitespacesAndNewlines)
        try info.validate()
        try PlaygroundExtraction.validateSetup(document)
        guard document.project.name == info.name else { throw ProjectFileError.invalid("Playground names disagree.") }
        let target = destination ?? directory.appendingPathComponent(info.id.uuidString + "." + Self.fileExtension)
        try FileManager.default.createDirectory(at: target.deletingLastPathComponent(), withIntermediateDirectories: true)
        if FileManager.default.fileExists(atPath: target.path) { _ = try read(target) }
        let bytes = try JSONEncoder().encode(info)
        let store = ProjectPackageStore()
        store.beforeCommit = { stage in
            // Build from explicit retained bytes, without inheriting unrelated source assets.
            let assets = stage.appendingPathComponent("assets")
            let retained = Set(document.project.imageAssets.map(\.fileName))
            for item in try FileManager.default.contentsOfDirectory(at: assets, includingPropertiesForKeys: nil)
                where !retained.contains(item.lastPathComponent) { try FileManager.default.removeItem(at: item) }
            try bytes.write(to: stage.appendingPathComponent("playground.json"), options: .atomic)
            _ = try self.read(stage)
            try beforeCommit?(stage)
        }
        try store.write(document, to: target, imageFiles: images)
        return target
    }
    func copy(_ source: URL, name: String? = nil, note: String? = nil, to destination: URL? = nil) throws -> URL {
        let saved = try read(source)
        var info = saved.info
        info.id = UUID(); info.name = (name ?? info.name).trimmingCharacters(in: .whitespacesAndNewlines); info.note = note ?? info.note; info.modifiedAt = .now
        let document = try PlaygroundExtraction.extract(saved.document, name: info.name)
        return try save(document, info: info, images: saved.images, to: destination)
    }
    func rename(_ source: URL, name: String, note: String) throws {
        let saved = try read(source)
        var info = saved.info; info.name = name.trimmingCharacters(in: .whitespacesAndNewlines); info.note = note; info.modifiedAt = .now
        let document = try PlaygroundExtraction.extract(saved.document, name: info.name)
        try save(document, info: info, images: saved.images, to: source)
    }
}
