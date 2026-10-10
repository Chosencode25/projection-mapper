import Foundation
import Darwin
import UniformTypeIdentifiers

struct ProjectOutputSettings: Codable, Equatable {
    var destination: SavedOutputPreference = .testWindow
    var resolution: TestResolution = .hd
}
struct RecoveryMetadata: Codable, Equatable {
    var originalPath: String?
    var savedAt: Date = .now
}
struct ProjectDocument: Codable, Equatable {
    static let currentVersion = 9
    var formatVersion = currentVersion
    var project: MappingProject
    var output = ProjectOutputSettings()
    var recovery: RecoveryMetadata?
}
enum ProjectFileError: LocalizedError {
    case invalid(String), newer(Int), io(String)
    var errorDescription: String? {
        switch self {
        case .invalid(let message): "Invalid project: \(message)"
        case .newer(let version): "This project uses format \(version). Update Projection Mapper before opening it."
        case .io(let message): "Project file operation failed: \(message)"
        }
    }
}

/// Decode fully before replacing editor state. Runtime clocks and view ownership are never encoded.
enum ProjectCodec {
    static func encode(_ document: ProjectDocument) throws -> Data {
        try validate(document)
        let encoder = JSONEncoder(); encoder.outputFormatting = [.prettyPrinted,.sortedKeys]
        let data = try encoder.encode(document)
        guard data.count <= 16 * 1024 * 1024 else { throw ProjectFileError.invalid("manifest exceeds 16 MB") }
        return data
    }
    static func decode(_ data: Data) throws -> ProjectDocument {
        guard data.count <= 16 * 1024 * 1024 else { throw ProjectFileError.invalid("manifest exceeds 16 MB") }
        do {
            guard var json = try JSONSerialization.jsonObject(with: data) as? [String:Any],
                  let version = json["formatVersion"] as? Int else { throw ProjectFileError.invalid("missing format version") }
            if version > ProjectDocument.currentVersion { throw ProjectFileError.newer(version) }
            guard (1...ProjectDocument.currentVersion).contains(version) else { throw ProjectFileError.invalid("unsupported format version") }
            if version == 1 {
                guard var project = json["project"] as? [String:Any] else { throw ProjectFileError.invalid("missing project") }
                project["generatorPresets"] = project["generatorPresets"] ?? []
                json["project"] = project
                if json["output"] == nil {
                    json["output"] = ["destination":["requiresManualSelection":false],"resolution":"hd"]
                }
                json["formatVersion"] = 2
            }
            if version <= 2 {
                guard var project = json["project"] as? [String:Any] else { throw ProjectFileError.invalid("missing project") }
                let defaults = try JSONSerialization.jsonObject(with: JSONEncoder().encode(SurfaceAppearance.defaults))
                for key in ["surfaces","objects"] {
                    guard let values = project[key] as? [[String:Any]] else { throw ProjectFileError.invalid("missing " + key) }
                    project[key] = values.map { item in var item = item; item["appearance"] = defaults; item.removeValue(forKey: "appearanceOverride"); return item }
                }
                json["project"] = project; json["formatVersion"] = ProjectDocument.currentVersion
            }
            if version <= 3 {
                guard var project = json["project"] as? [String:Any],
                      let faces = project["surfaces"] as? [[String:Any]],let objects = project["objects"] as? [[String:Any]] else { throw ProjectFileError.invalid("missing layout collections") }
                project["surfaces"] = try faces.map { face in
                    var face = face
                    guard var layout = face["layout"] as? [String:Any] else { throw ProjectFileError.invalid("missing face layout") }
                    layout["isGeometryLocked"] = false; face["layout"] = layout; return face
                }
                project["objects"] = objects.map { object in var object = object; object["isGeometryLocked"] = false; return object }
                json["project"] = project; json["formatVersion"] = ProjectDocument.currentVersion
            }
            if version <= 4 {
                guard var project = json["project"] as? [String:Any] else { throw ProjectFileError.invalid("missing project") }
                project["palettes"] = []; project["looks"] = []
                project["masterOutput"] = try JSONSerialization.jsonObject(with: JSONEncoder().encode(MasterOutputSettings.defaults))
                json["project"] = project; json["formatVersion"] = ProjectDocument.currentVersion
            }
            if version <= 5 {
                guard var project = json["project"] as? [String:Any], let faces = project["surfaces"] as? [[String:Any]] else { throw ProjectFileError.invalid("missing faces") }
                project["surfaces"] = faces.map { face in var face = face; face.removeValue(forKey: "mask"); return face }
                json["project"] = project; json["formatVersion"] = ProjectDocument.currentVersion
            }
            if version <= 6 {
                guard var project = json["project"] as? [String:Any] else { throw ProjectFileError.invalid("missing project") }
                project["imageAssets"] = []; project.removeValue(forKey: "referencePhoto")
                json["project"] = project; json["formatVersion"] = ProjectDocument.currentVersion
            }
            if version <= 7 {
                guard var project = json["project"] as? [String:Any] else { throw ProjectFileError.invalid("missing project") }
                project["timelineClips"] = []; json["project"] = project
                json["formatVersion"] = ProjectDocument.currentVersion
            }
            if version <= 8 {
                guard var project = json["project"] as? [String:Any] else { throw ProjectFileError.invalid("missing project") }
                project["videoAssets"] = []; project["videoAudio"] = ["volume":1]
                json["project"] = project; json["formatVersion"] = ProjectDocument.currentVersion
            }
            let migrated = try JSONSerialization.data(withJSONObject: json)
            let document = try JSONDecoder().decode(ProjectDocument.self, from: migrated)
            try validate(document); return document
        } catch let error as ProjectFileError { throw error }
        catch { throw ProjectFileError.invalid("manifest is corrupt or contains unsupported values: \(error.localizedDescription)") }
    }
    static func validate(_ document: ProjectDocument) throws {
        func check(_ condition: Bool, _ text: String) throws { if !condition { throw ProjectFileError.invalid(text) } }
        let p = document.project
        try check(document.formatVersion == ProjectDocument.currentVersion, "unsupported write version")
        try check(!p.name.isEmpty && p.name.count <= 80, "project name")
        try check(p.createdAt.timeIntervalSince1970.isFinite && p.modifiedAt.timeIntervalSince1970.isFinite, "timestamps")
        try check(p.surfaces.count <= 1000 && p.objects.count <= 1000 && p.generatorPresets.count <= 100 && p.palettes.count <= 100 && p.looks.count <= 100 && p.objects.reduce(0, { $0 + $1.links.count }) <= 10000, "collection limits")
        try check(Set(p.surfaces.map(\.id)).count == p.surfaces.count && Set(p.objects.map(\.id)).count == p.objects.count && Set(p.generatorPresets.map(\.id)).count == p.generatorPresets.count && Set(p.palettes.map(\.id)).count == p.palettes.count && Set(p.looks.map(\.id)).count == p.looks.count, "duplicate IDs")
        try check(p.imageAssets.count <= 64 && Set(p.imageAssets.map(\.id)).count == p.imageAssets.count && p.imageAssets.allSatisfy(\.isValid), "image asset metadata")
        try check(p.imageAssets.reduce(Int64(0), { $0 + Int64($1.width)*Int64($1.height)*4 }) <= ImageImportService.maximumDecodedBytes, "image memory limit")
        try check(p.videoAudio.isValid && p.videoAssets.count <= 64 && Set(p.videoAssets.map(\.id)).count == p.videoAssets.count && p.videoAssets.allSatisfy(\.isValid), "video asset/audio metadata")
        try check(p.videoAssets.reduce(Int64(0), { $0+$1.byteCount }) <= VideoImportService.maximumProjectBytes, "project video bytes")
        try check(p.referencedVideoIDs.isSubset(of: Set(p.videoAssets.map(\.id))), "missing video asset identity")
        let allVideos = (p.surfaces.map(\.source)+p.objects.map(\.source)).compactMap(\.video) + p.timelineClips.compactMap { $0.source.video } + p.looks.flatMap(\.entries).compactMap { $0.source?.video }
        try check(allVideos.allSatisfy { !p.videoProblem($0) }, "video source range")
        try check(p.timelineClips.allSatisfy { !p.videoProblem($0.source.video) }, "video clip range")
        let assetIDs = Set(p.imageAssets.map(\.id))
        try check(p.referencedImageIDs.isSubset(of: assetIDs), "missing asset identity")
        try check(p.referencePhoto?.isValid ?? true, "reference photo settings")
        try check(EffectClip.validSequence(p.timelineClips), "timeline clips or overlaps")
        let activeOwners = Set(p.timelineTracks.map(\.id))
        try check(p.timelineClips.allSatisfy { activeOwners.contains($0.sourceID) }, "missing timeline target")
        let sources = p.surfaces.map(\.source) + p.objects.map(\.source)
        try check(Set(sources.map(\.id)).count == sources.count, "duplicate content-owner IDs")
        func color(_ value: SIMD4<Float>) -> Bool { (0..<4).allSatisfy { value[$0].isFinite && (0...1).contains(value[$0]) } }
        func tags(_ value: [String]) -> Bool { value.count <= 16 && Set(value).count == value.count && value.allSatisfy { !$0.isEmpty && $0.count <= 80 } }
        func name(_ value: String) -> Bool { !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && value.count <= 80 }
        try check(p.masterOutput.isValid, "master output settings")
        for palette in p.palettes {
            try check(name(palette.name) && palette.slots.count <= 32, "palette name/slot limit")
            try check(Set(palette.slots.map(\.id)).count == palette.slots.count, "duplicate palette slot IDs")
            for slot in palette.slots { try check(name(slot.name) && color(slot.color), "palette slot") }
        }
        func binding(_ value: ColorBinding?) -> Bool {
            guard let value else { return true }
            return p.paletteColor(for: value) != nil
        }
        for source in sources {
            try check(source.generator.isValid && color(source.color) && (source.image?.isValid ?? true) && (source.content != .image || source.image != nil) && (source.content != .video || source.video != nil), "content settings")
            try check(binding(source.primaryBinding) && binding(source.secondaryBinding), "missing palette reference")
        }
        for look in p.looks {
            try check(name(look.name) && look.entries.count <= 2000, "look name/target limit")
            let keys = look.entries.map { $0.kind.rawValue + ":" + $0.targetID.uuidString }
            try check(Set(keys).count == keys.count, "duplicate look targets")
            for entry in look.entries {
                switch entry.kind {
                case .object, .standaloneFace:
                    try check(entry.expectedObjectID == nil && entry.source != nil && entry.appearance != nil, "look target payload")
                case .memberFace:
                    try check(entry.expectedObjectID != nil && entry.source == nil, "member look payload")
                }
                try check(entry.appearance?.isValid ?? true, "look appearance")
                if let source = entry.source {
                    try check(source.isValid && (source.image?.isValid ?? true) && (source.content != .image || source.image != nil) && (source.content != .video || source.video != nil) && binding(source.primaryBinding) && binding(source.secondaryBinding), "look content/palette reference")
                }
            }
        }
        for face in p.surfaces {
            try check(!face.name.isEmpty && face.name.count <= 80 && tags(face.tags), "face name/tags")
            try check(face.layout.inputMap.isValid, "input map")
            try check(face.mask?.isBounded ?? true, "mask coordinates, IDs or collection limits")
            try check(face.appearance.isValid && (face.appearanceOverride?.isValid ?? true) && (face.appearanceOverride == nil || face.layout.objectID != nil), "face appearance")
            let corners = [face.corners.topLeft,face.corners.topRight,face.corners.bottomRight,face.corners.bottomLeft]
            try check(corners.allSatisfy { $0.x.isFinite && $0.y.isFinite && (0...1).contains($0.x) && (0...1).contains($0.y) }, "output coordinates")
            if let objectID = face.layout.objectID { try check(p.objects.contains { $0.id == objectID }, "missing object reference") }
        }
        var linkIDs: Set<UUID> = []
        for object in p.objects {
            try check(object.appearance.isValid, "object appearance")
            try check(!object.name.isEmpty && object.name.count <= 80 && tags(object.tags), "object name/tags")
            let members = Set(p.surfaces.filter { $0.layout.objectID == object.id }.map(\.id))
            try check(!members.isEmpty && object.links.count <= 4000, "empty object or link limit")
            for link in object.links {
                try check(linkIDs.insert(link.id).inserted && link.firstFace != link.secondFace && members.contains(link.firstFace) && members.contains(link.secondFace), "invalid edge reference")
            }
        }
        for preset in p.generatorPresets {
            try check(!preset.name.isEmpty && preset.name.count <= 80 && preset.content.isProceduralAnimation && preset.settings.isValid && color(preset.color), "generator preset")
        }
        try check((document.output.destination.displayUUID?.count ?? 0) <= 256 && (document.output.destination.displayName?.count ?? 0) <= 256, "output identity")
        if let recovery = document.recovery { try check((recovery.originalPath?.count ?? 0) <= 4096 && recovery.savedAt.timeIntervalSince1970.isFinite, "recovery metadata") }
    }
}

final class ProjectPackageStore {
    static let fileExtension = "projectionmap"
    static let contentType = UTType(exportedAs: "local.keith.projectionmap", conformingTo: .package)
    let files = FileManager.default
    /// Failure injection runs after staging validation, before changing the destination.
    var beforeCommit: ((URL) throws -> Void)?
    func read(_ url: URL) throws -> ProjectDocument {
        let values = try url.resourceValues(forKeys: [.isDirectoryKey,.isSymbolicLinkKey])
        guard values.isDirectory == true, values.isSymbolicLink != true else { throw ProjectFileError.invalid("not a project package") }
        let manifest = url.appendingPathComponent("manifest.json")
        let info = try manifest.resourceValues(forKeys: [.isRegularFileKey,.isSymbolicLinkKey,.fileSizeKey])
        guard info.isRegularFile == true, info.isSymbolicLink != true, (info.fileSize ?? Int.max) <= 16*1024*1024 else { throw ProjectFileError.invalid("manifest is unavailable or unsafe") }
        return try ProjectCodec.decode(Data(contentsOf: manifest))
    }
    func write(_ document: ProjectDocument, to destination: URL, assetsFrom source: URL? = nil, imageFiles: [UUID:Data] = [:], videoFiles: [UUID:URL] = [:]) throws {
        let data = try ProjectCodec.encode(document)
        let parent = destination.deletingLastPathComponent()
        let stage = parent.appendingPathComponent(".\(destination.lastPathComponent).\(UUID().uuidString).staging",isDirectory: true)
        try files.createDirectory(at: stage,withIntermediateDirectories: false)
        defer { try? files.removeItem(at: stage) }
        let assets = stage.appendingPathComponent("assets",isDirectory: true)
        let oldAssets = (source ?? (files.fileExists(atPath: destination.path) ? destination : nil))?.appendingPathComponent("assets",isDirectory: true)
        if let oldAssets, files.fileExists(atPath: oldAssets.path) {
            let info = try oldAssets.resourceValues(forKeys: [.isDirectoryKey,.isSymbolicLinkKey])
            guard info.isDirectory == true, info.isSymbolicLink != true else { throw ProjectFileError.invalid("unsafe asset directory") }
            if let items = files.enumerator(at: oldAssets,includingPropertiesForKeys: [.isSymbolicLinkKey]) {
                for case let item as URL in items {
                    guard try item.resourceValues(forKeys: [.isSymbolicLinkKey]).isSymbolicLink != true else { throw ProjectFileError.invalid("linked asset file") }
                }
            }
            try files.createDirectory(at: assets,withIntermediateDirectories: false)
            var videoNames = Set(document.project.videoAssets.map(\.fileName))
            if let old = try? read(oldAssets.deletingLastPathComponent()) { videoNames.formUnion(old.project.videoAssets.map(\.fileName)) }
            // Videos always use cancellable chunked I/O below, including Save As/recovery.
            for item in try files.contentsOfDirectory(at: oldAssets,includingPropertiesForKeys: nil) where !videoNames.contains(item.lastPathComponent) {
                try Task.checkCancellation()
                try files.copyItem(at: item,to: assets.appendingPathComponent(item.lastPathComponent))
            }
        } else { try files.createDirectory(at: assets,withIntermediateDirectories: false) }
        // UUID-derived paths cannot escape the package. Remove only known orphaned assets.
        if let source = source ?? (files.fileExists(atPath: destination.path) ? destination : nil), let old = try? read(source) {
            let live = Set(document.project.imageAssets.map(\.id))
            for asset in old.project.imageAssets where !live.contains(asset.id) {
                let item = assets.appendingPathComponent(asset.fileName)
                if files.fileExists(atPath: item.path) { try files.removeItem(at: item) }
            }
        }
        if let source = source ?? (files.fileExists(atPath: destination.path) ? destination : nil), let old = try? read(source) {
            let live = Set(document.project.videoAssets.map(\.id))
            for asset in old.project.videoAssets where !live.contains(asset.id) {
                let item = assets.appendingPathComponent(asset.fileName)
                if files.fileExists(atPath: item.path) { try files.removeItem(at: item) }
            }
        }
        for asset in document.project.videoAssets {
            let target = assets.appendingPathComponent(asset.fileName)
            guard let video = videoFiles[asset.id] ?? oldAssets?.appendingPathComponent(asset.fileName) else {
                throw ProjectFileError.invalid("missing video; relink before saving")
            }
            try VideoImportService.copy(video,to: target)
            guard try VideoImportService.safeFile(target) == asset.byteCount else { throw ProjectFileError.invalid("video size changed; relink it") }
        }
        for asset in document.project.imageAssets {
            let target = assets.appendingPathComponent(asset.fileName)
            if let bytes = imageFiles[asset.id] {
                guard bytes.count <= ImageImportService.maximumFileBytes else { throw ProjectFileError.invalid("image file size") }
                try bytes.write(to: target,options: .atomic)
            }
            let decoded = try ImageImportService.read(target)
            guard decoded.pixels.width == asset.width, decoded.pixels.height == asset.height else { throw ProjectFileError.invalid("image dimensions") }
        }
        try data.write(to: stage.appendingPathComponent("manifest.json"),options: .atomic)
        _ = try read(stage)
        try Task.checkCancellation()
        try beforeCommit?(stage)
        if files.fileExists(atPath: destination.path) {
            _ = try read(destination) // Never replace an unrelated folder or malformed project.
            let result = stage.path.withCString { from in destination.path.withCString { to in
                renameatx_np(AT_FDCWD,from,AT_FDCWD,to,UInt32(RENAME_SWAP))
            } }
            guard result == 0 else { throw ProjectFileError.io(String(cString: strerror(errno))) }
        } else {
            let result = stage.path.withCString { from in destination.path.withCString { to in rename(from,to) } }
            guard result == 0 else { throw ProjectFileError.io(String(cString: strerror(errno))) }
        }
    }
}

final class ProjectRecoveryStore {
    struct Entry { let url: URL; let document: ProjectDocument }
    let directory: URL
    let packages: ProjectPackageStore
    init(directory: URL, packages: ProjectPackageStore = ProjectPackageStore()) { self.directory = directory; self.packages = packages }
    static var defaultDirectory: URL {
        FileManager.default.urls(for: .applicationSupportDirectory,in: .userDomainMask)[0]
            .appendingPathComponent("ProjectionMapper/Recovery",isDirectory: true)
    }
    func entries() -> [Entry] {
        let urls = (try? FileManager.default.contentsOfDirectory(at: directory,includingPropertiesForKeys: nil)) ?? []
        return urls.filter { $0.pathExtension == ProjectPackageStore.fileExtension }.compactMap { url in
            guard let doc = try? packages.read(url), doc.recovery != nil else { return nil }; return Entry(url: url,document: doc)
        }.sorted { ($0.document.recovery?.savedAt ?? .distantPast) > ($1.document.recovery?.savedAt ?? .distantPast) }
    }
    func save(_ document: ProjectDocument, original: URL?, assetsFrom: URL? = nil, imageFiles: [UUID:Data] = [:], videoFiles: [UUID:URL] = [:]) throws {
        try FileManager.default.createDirectory(at: directory,withIntermediateDirectories: true)
        var copy = document; copy.recovery = RecoveryMetadata(originalPath: original?.path)
        try packages.write(copy,to: directory.appendingPathComponent("\(copy.project.id).projectionmap"),assetsFrom: assetsFrom ?? original, imageFiles: imageFiles, videoFiles: videoFiles)
        for entry in entries().dropFirst(10) { try? FileManager.default.removeItem(at: entry.url) }
    }
    func remove(projectID: UUID) { try? FileManager.default.removeItem(at: directory.appendingPathComponent("\(projectID).projectionmap")) }
}

/// Tests exercise the same save/discard/cancel continuation rule used by native lifecycle sheets.
enum ProjectCloseChoice { case save, discard, cancel
    func canProceed(saveSucceeded: Bool) -> Bool { switch self { case .save: saveSucceeded; case .discard: true; case .cancel: false } }
}
