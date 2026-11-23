import Foundation

enum ShowLayoutAction: String, Identifiable {
    case roles, apply
    var id: Self { self }
}

struct LayoutTargetID: Codable, Hashable, Sendable {
    enum Domain: String, Codable, Sendable { case face, object, fixture }
    var domain: Domain
    var id: UUID
}

struct LayoutRole: Codable, Equatable, Identifiable, Sendable {
    var id = UUID()
    var name: String
    var targets: [LayoutTargetID] = []
    static func key(_ name: String) -> String { name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
}

struct LayoutTarget: Identifiable, Equatable, Sendable {
    enum Kind: Equatable, Sendable {
        case surface, object, member, fixture(FixtureKind)

        var label: String {
            switch self {
            case .surface: "Surface"
            case .object: "Shared object"
            case .member: "Object face"
            case .fixture(let kind): kind.rawValue
            }
        }
    }
    let id: LayoutTargetID
    let name: String
    let kind: Kind
    var sourceID: UUID?
    var parentID: UUID?
    var group = ""
    var context = ""

    var displayName: String { context.isEmpty ? name : "\(name) · \(context)" }
}

extension MappingProject {
    var savedLayoutRoles: [LayoutRole] { layoutRoles ?? [] }

    var layoutTargets: [LayoutTarget] {
        let objectNames = Dictionary(objects.map { ($0.id, $0.name) }, uniquingKeysWith: { first, _ in first })
        let projectFixtures = lighting.fixtures.map { fixture in
            LayoutTarget(id: .init(domain: .fixture, id: fixture.id), name: fixture.name,
                         kind: .fixture(fixture.kind), group: fixture.group,
                         context: fixture.group.isEmpty ? fixture.kind.rawValue : fixture.group)
        }
        let projectObjects = objects.map {
            LayoutTarget(id: .init(domain: .object, id: $0.id), name: $0.name, kind: .object, sourceID: $0.source.id)
        }
        let projectFaces = surfaces.map { face in
            let parent = face.layout.objectID
            return LayoutTarget(id: .init(domain: .face, id: face.id), name: face.name,
                                kind: parent == nil ? .surface : .member,
                                sourceID: parent == nil ? face.source.id : nil,
                                parentID: parent, context: parent.flatMap { objectNames[$0] } ?? "")
        }
        return projectObjects + projectFaces + projectFixtures
    }

    var layoutRoleIssue: String? {
        let roles = savedLayoutRoles
        guard roles.count <= 128, Set(roles.map(\.id)).count == roles.count,
              Set(roles.map { LayoutRole.key($0.name) }).count == roles.count,
              roles.allSatisfy({ !LayoutRole.key($0.name).isEmpty && $0.name.count <= 80 }) else {
            return "Use distinct role names of 1–80 characters. A layout supports up to 128 roles."
        }
        guard !roles.isEmpty else { return nil }
        let targets = Set(layoutTargets.map(\.id))
        guard roles.allSatisfy({ Set($0.targets).count == $0.targets.count && Set($0.targets).isSubset(of: targets) }) else {
            return "A layout role contains an invalid or duplicate target."
        }
        return nil
    }

    mutating func removeMissingLayoutTargets() {
        guard layoutRoles != nil else { return }
        let targets = Set(layoutTargets.map(\.id))
        for index in layoutRoles!.indices {
            layoutRoles![index].targets.removeAll { !targets.contains($0) }
        }
    }
}

struct ShowLayoutPlan: Sendable {
    typealias Assignments = [LayoutTargetID: [LayoutTargetID]]
    let source: [LayoutTarget]
    let destination: [LayoutTarget]
    let sourceRoles: [LayoutRole]
    let destinationRoles: [LayoutRole]

    init(show: MappingProject, layout: MappingProject) {
        let fixtures = Set(show.lighting.cues.flatMap { $0.entries.map(\.id) }
                           + show.lighting.looks.flatMap { $0.entries.map(\.id) }
                           + show.lighting.positionKeys.map(\.fixtureID)
                           + show.choreographyClips.filter { $0.kind == .fixture }.flatMap { $0.targets.map(\.id) })
        let members = Set(show.regions.map(\.faceID)
                          + show.looks.flatMap(\.entries).filter { $0.kind == .memberFace }.map(\.targetID))
        source = show.layoutTargets.filter {
            switch $0.kind {
            case .fixture: fixtures.contains($0.id.id)
            case .member: members.contains($0.id.id)
            case .surface, .object: true
            }
        }
        destination = layout.layoutTargets
        sourceRoles = show.savedLayoutRoles
        destinationRoles = layout.savedLayoutRoles
    }

    func choices(for target: LayoutTarget, assignments: Assignments) -> [LayoutTarget] {
        let parents = target.parentID.map { assignments[.init(domain: .object, id: $0), default: []].map(\.id) }
        return destination.filter { choice in
            choice.kind == target.kind && (parents.map { parentIDs in
                choice.parentID.map { parentIDs.contains($0) } ?? false
            } ?? true)
        }
    }

    var suggestions: Assignments {
        var result: Assignments = [:]
        for target in source {
            let compatible = choices(for: target, assignments: result)
            let matches = Set(compatible.map(\.id))
            let sameName = compatible.filter { LayoutRole.key($0.name) == LayoutRole.key(target.name) }
            var proposals: [[LayoutTargetID]] = []
            var foundRole = false
            for role in sourceRoles where role.targets.contains(target.id) {
                guard let receiving = destinationRoles.first(where: { LayoutRole.key($0.name) == LayoutRole.key(role.name) }) else { continue }
                let destinations = receiving.targets.filter { matches.contains($0) }
                guard !destinations.isEmpty else { continue }
                foundRole = true
                let peers = role.targets.filter { id in source.contains { $0.id == id && $0.kind == target.kind && $0.parentID == target.parentID } }
                if peers.count == 1 { proposals.append(destinations) }
                else if peers.count == destinations.count, let index = peers.firstIndex(of: target.id) {
                    proposals.append([destinations[index]])
                }
            }
            if let proposal = proposals.first, proposals.allSatisfy({ $0 == proposal }) {
                result[target.id] = proposal
            } else if !foundRole {
                if matches.contains(target.id) { result[target.id] = [target.id] }
                else if sameName.count == 1 { result[target.id] = [sameName[0].id] }
            }
        }
        let claims = Dictionary(grouping: result.values.flatMap { $0 }, by: { $0 }).mapValues(\.count)
        for target in source {
            if let proposed = result[target.id], proposed.contains(where: { claims[$0, default: 0] > 1 }) ||
                proposed.contains(where: { id in !choices(for: target, assignments: result).contains { $0.id == id } }) {
                result.removeValue(forKey: target.id)
            }
        }
        return result
    }

    func issue(_ assignments: Assignments) -> String? {
        guard Set(assignments.keys) == Set(source.map(\.id)) else {
            return "Assign or skip every source target."
        }
        let assigned = assignments.values.flatMap { $0 }
        guard Set(assigned).count == assigned.count else { return "Each destination can receive only one source target." }
        for target in source {
            let valid = Set(choices(for: target, assignments: assignments).map(\.id))
            if !Set(assignments[target.id, default: []]).isSubset(of: valid) {
                return "Review the destinations for “\(target.name)”. Object faces must belong to the assigned object."
            }
        }
        return nil
    }
}

enum ShowLayoutCopy {
    struct Result {
        let document: ProjectDocument
        let photoAssetID: UUID?
    }

    static func create(show: ProjectDocument, layout: ProjectDocument, name: String,
                       assignments: ShowLayoutPlan.Assignments) throws -> Result {
        try ProjectCodec.validate(show)
        let original = show.project
        let base = layout.project
        let plan = ShowLayoutPlan(show: original, layout: base)
        if let issue = plan.issue(assignments) { throw DeliveryError.invalid(issue) }

        var copy = try PlaygroundExtraction.extract(layout, name: name).project
        let sourceToDestination = Dictionary(uniqueKeysWithValues: assignments.flatMap { key, destinations in
            destinations.map { ($0, key) }
        })
        let destinations = Dictionary(uniqueKeysWithValues: plan.destination.map { ($0.id, $0) })
        var lanes: [UUID: [UUID]] = [:]
        for target in plan.source {
            guard let id = target.sourceID else { continue }
            lanes[id] = assignments[target.id, default: []].compactMap { destinations[$0]?.sourceID }
        }
        let sources = Dictionary(uniqueKeysWithValues: (original.surfaces.map(\.source) + original.objects.map(\.source)).map { ($0.id, $0) })
        let originals = Dictionary(uniqueKeysWithValues: plan.source.map { ($0.id, $0) })
        func transferredSource(_ target: LayoutTargetID, retaining baseSource: SurfaceSource) -> SurfaceSource {
            guard let from = sourceToDestination[target], let sourceID = originals[from]?.sourceID, var source = sources[sourceID] else {
                return baseSource
            }
            source.id = baseSource.id
            return source
        }
        for index in copy.surfaces.indices {
            let face = copy.surfaces[index]
            copy.surfaces[index].source = transferredSource(.init(domain: .face, id: face.id), retaining: face.source)
        }
        for index in copy.objects.indices {
            let object = copy.objects[index]
            copy.objects[index].source = transferredSource(.init(domain: .object, id: object.id), retaining: object.source)
        }

        // Retain empty receiving scaffolds on unused targets and populate mapped targets with show artwork.
        let mappedOwners = Set(lanes.values.flatMap { $0 })
        let mappedFaces = Set(sourceToDestination.keys.filter { $0.domain == .face }.map(\.id))
        var layers = copy.layers.filter { !mappedOwners.contains($0.ownerID) }
        for layer in original.layers {
            for owner in lanes[layer.ownerID, default: []] {
                let track = layer.track.independentCopy()
                layers.append(VisualLayer(ownerID: owner, track: track))
                lanes[layer.id, default: []].append(track.id)
            }
        }
        copy.visualLayers = layers.isEmpty ? nil : layers

        var regions = copy.regions.filter { !mappedFaces.contains($0.faceID) }
        for region in original.regions {
            for target in assignments[.init(domain: .face, id: region.faceID), default: []] {
                var mapped = region
                mapped.faceID = target.id
                mapped.track = region.track.independentCopy()
                regions.append(mapped)
                lanes[region.id, default: []].append(mapped.id)
            }
        }
        copy.faceRegions = regions.isEmpty ? nil : regions
        copy.regionShapePresets = original.regionShapePresets
        let clipCount = original.timelineClips.reduce(0) { $0 + lanes[$1.sourceID, default: []].count }
        guard clipCount <= 2000 else { throw DeliveryError.invalid("The selected destinations exceed the 2,000-clip timeline limit.") }
        copy.timelineClips = original.timelineClips.flatMap { clip in
            lanes[clip.sourceID, default: []].map { id in
                var mapped = clip
                mapped.id = UUID()
                mapped.sourceID = id
                return mapped
            }
        }

        func fixtures(_ id: UUID) -> [UUID] { assignments[.init(domain: .fixture, id: id), default: []].map(\.id) }
        func fixtureEntries(_ entries: [FixtureLookEntry]) -> [FixtureLookEntry] {
            entries.flatMap { entry in fixtures(entry.id).map { FixtureLookEntry(id: $0, state: entry.state) } }
        }
        copy.lighting.cues = original.lighting.cues.compactMap { cue in
            var mapped = cue
            mapped.entries = fixtureEntries(cue.entries)
            return mapped.entries.isEmpty ? nil : mapped
        }
        copy.lighting.looks = original.lighting.looks.compactMap { look in
            var mapped = look
            mapped.entries = fixtureEntries(look.entries)
            return mapped.entries.isEmpty ? nil : mapped
        }
        let pathCount = original.lighting.positionKeys.reduce(0) { $0 + fixtures($1.fixtureID).count }
        guard pathCount <= 4096 else { throw DeliveryError.invalid("The selected destinations exceed the moving-head position key limit.") }
        let paths = original.lighting.positionKeys.flatMap { key in
            fixtures(key.fixtureID).map { id in
                var mapped = key
                mapped.id = UUID()
                mapped.fixtureID = id
                return mapped
            }
        }
        copy.lighting.headPositions = paths.isEmpty ? nil : paths
        copy.lighting.effectPresets = original.lighting.effectPresets

        let choreography = original.choreographyClips.compactMap { clip -> ChoreographyClip? in
            var mapped = clip
            mapped.targets = clip.targets.flatMap { target in
                let ids = clip.kind == .fixture ? fixtures(target.id) : lanes[target.id, default: []]
                return ids.map { ChoreographyTarget(id: $0, position: target.position) }
            }
            return mapped.targets.isEmpty ? nil : mapped
        }
        copy.choreography = choreography.isEmpty ? nil : choreography
        copy.looks = original.looks.compactMap { look in
            var mapped = look
            mapped.entries = look.entries.flatMap { entry -> [LookEntry] in
                let key = LayoutTargetID(domain: entry.kind == .object ? .object : .face, id: entry.targetID)
                guard let target = originals[key],
                      entry.expectedObjectID == target.parentID,
                      (entry.kind != .standaloneFace || target.kind == .surface) else { return [] }
                return assignments[key, default: []].map { id in
                    var replacement = entry
                    replacement.targetID = id.id
                    replacement.expectedObjectID = destinations[id]?.parentID
                    return replacement
                }
            }
            return mapped.entries.isEmpty ? nil : mapped
        }
        copy.palettes = original.palettes
        copy.generatorPresets = original.generatorPresets
        copy.markers = original.markers
        copy.song = original.song
        copy.masterOutput = original.masterOutput
        copy.videoAudio.volume = original.videoAudio.volume
        copy.videoAudio.deviceUID = base.videoAudio.deviceUID

        // The receiving photo may share an asset ID with imagery in a show derived from the same layout.
        let photo = copy.imageAssets.first
        copy.imageAssets = []
        if var photo {
            photo.id = UUID()
            copy.referencePhoto?.assetID = photo.id
            copy.imageAssets.append(photo)
        }
        let imageIDs = copy.referencedImageIDs
        let videoIDs = copy.referencedVideoIDs
        copy.imageAssets += original.imageAssets.filter { imageIDs.contains($0.id) }
        copy.videoAssets = original.videoAssets.filter { videoIDs.contains($0.id) }
        let document = ProjectDocument(project: copy, output: layout.output)
        try ProjectCodec.validate(document)
        return Result(document: document, photoAssetID: copy.referencePhoto?.assetID)
    }

    static func write(_ result: Result, source: URL, reviewed: ProjectDocument, photo: Data?, to destination: URL) throws {
        let store = ProjectPackageStore()
        guard try store.read(source) == reviewed else {
            throw DeliveryError.invalid("The source show changed. Choose it again to review its destinations.")
        }
        let project = result.document.project
        let assets = source.appendingPathComponent("assets", isDirectory: true)
        let hasMedia = project.imageAssets.contains { $0.id != result.photoAssetID } || !project.videoAssets.isEmpty || project.song != nil
        if hasMedia {
            let info = try assets.resourceValues(forKeys: [.isDirectoryKey, .isSymbolicLinkKey])
            guard info.isDirectory == true, info.isSymbolicLink != true else { throw DeliveryError.invalid("The source assets folder is unavailable.") }
        }
        let images = ImageImportService.loadAssets(project.imageAssets.filter { $0.id != result.photoAssetID }, package: source)
        guard images.problems.isEmpty else { throw DeliveryError.invalid("An image in the source show is missing or damaged.") }
        var imageFiles = images.files
        if let id = result.photoAssetID {
            guard let photo else { throw DeliveryError.invalid("The receiving layout’s reference photo could not be read.") }
            imageFiles[id] = photo
        }
        let videos = Dictionary(uniqueKeysWithValues: project.videoAssets.map { ($0.id, assets.appendingPathComponent($0.fileName)) })
        let song = try project.song.map { try PreparedSong.read(assets.appendingPathComponent($0.fileName), expected: $0).bytes }
        try Task.checkCancellation()
        try store.write(result.document, to: destination, imageFiles: imageFiles, videoFiles: videos, songBytes: song, replaceExisting: false)
    }
}
