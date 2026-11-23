import Foundation
import UniformTypeIdentifiers

enum ShowSectionAction: String, Identifiable {
    case save, insert
    var id: Self { self }
    var title: String { self == .save ? "Save Show Section" : "Insert Show Section" }
}

struct SectionTarget: Codable, Identifiable, Equatable {
    enum Kind: Codable, Equatable {
        case projection
        case visual(VisualSourceKind, region: Bool)
        case fixture(FixtureKind)

        var label: String {
            switch self {
            case .projection: "Projection"
            case .visual(let visual, let region): region ? "Region · \(visual.title)" : "Layer · \(visual.title)"
            case .fixture(let fixture): fixture.rawValue
            }
        }
    }
    var id: UUID
    var name: String
    var kind: Kind
    var context: String? = nil

    var displayName: String { context.map { "\(name) · \($0)" } ?? name }
}

extension MappingProject {
    var sectionTargets: [SectionTarget] {
        let ownerNames = Dictionary(objects.map { ($0.id, $0.name) } + surfaces.map { ($0.id, $0.name) },
                                    uniquingKeysWith: { first, _ in first })
        let controllers = Dictionary(lighting.controllers.map { ($0.id, $0.name) },
                                     uniquingKeysWith: { first, _ in first })
        return timelineTracks.map { track in
            SectionTarget(id: track.id, name: track.name,
                          kind: track.visualKind.map { .visual($0, region: track.isRegion) } ?? .projection,
                          context: track.visualKind == nil ? nil : ownerNames[track.targetID])
        } + lighting.fixtures.map {
            SectionTarget(id: $0.id, name: $0.name, kind: .fixture($0.kind), context: controllers[$0.controllerID])
        }
    }
}

struct ShowSection: Codable {
    var version = 1
    var name: String
    var duration: Double
    var roles: [SectionTarget]
    var clips: [EffectClip]
    var cues: [LightingCue]
    var images: [ImageAsset]
    var videos: [VideoAsset]

    static func capture(_ project: MappingProject, name: String, start: Double, end: Double) throws -> Self {
        guard (0...3600).contains(start), (0...3600).contains(end), end - start >= 0.1 else {
            throw DeliveryError.invalid("Choose a start and end at least 0.1 seconds apart within the show timeline.")
        }
        let selected = project.timelineClips.filter { $0.start < end && $0.end > start }
        for clip in selected {
            let fade = clip.transition ?? 0
            if fade > 0 && ((clip.start <= start && start < clip.start + fade) || (clip.start < end && end < clip.start + fade)) {
                throw DeliveryError.invalid("The range cuts through a crossfade. Move the range edge outside the fade.")
            }
        }
        var clips: [EffectClip] = []
        let byLane = Dictionary(grouping: selected, by: \.sourceID)
        let targets = project.sectionTargets
        for lane in targets {
            let sorted = byLane[lane.id, default: []].sorted { $0.start < $1.start }
            for (index, clip) in sorted.enumerated() {
                let begin = max(start, clip.start)
                let finish = min(end, clip.end)
                var relative = clip.trimming(start: begin, duration: finish - begin)
                relative.start = begin - start
                if index == 0 || sorted[index - 1].end <= begin {
                    relative.transition = nil
                    relative.transitionCurve = nil
                }
                clips.append(relative)
            }
        }
        guard EffectClip.validSequence(clips) else {
            throw DeliveryError.invalid("The range creates a clip or video source trim that is too short. Adjust the range.")
        }
        let cues = project.lighting.cues.filter { !$0.isManual && $0.time >= start && $0.time < end }.map { cue in
            var copy = cue
            copy.time -= start
            copy.lead = min(copy.lead, copy.time)
            return copy
        }
        let usedTargets = Set(selected.map(\.sourceID) + cues.flatMap { $0.entries.map(\.id) })
        let imageIDs = Set(clips.compactMap { $0.source.image?.assetID })
        let videoIDs = Set(clips.compactMap { $0.source.video?.assetID })
        let section = Self(name: name, duration: end - start, roles: targets.filter { usedTargets.contains($0.id) },
                           clips: clips, cues: cues, images: project.imageAssets.filter { imageIDs.contains($0.id) },
                           videos: project.videoAssets.filter { videoIDs.contains($0.id) })
        try section.validate()
        return section
    }

    func validate() throws {
        func validName(_ name: String) -> Bool {
            !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && name.count <= 80
        }
        guard version == 1, validName(name), (0.1...3600).contains(duration), !roles.isEmpty,
              roles.count <= 2256, Set(roles.map(\.id)).count == roles.count, roles.allSatisfy({ validName($0.name) }),
              EffectClip.validSequence(clips), cues.count <= 2000, Set(cues.map(\.id)).count == cues.count else {
            throw DeliveryError.invalid("The range is empty or the show section contains unsupported programming.")
        }
        let kinds = Dictionary(uniqueKeysWithValues: roles.map { ($0.id, $0.kind) })
        let media = Dictionary(grouping: videos, by: \.id)
        guard images.count <= 64, videos.count <= 128, Set(images.map(\.id)).count == images.count,
              media.values.allSatisfy({ $0.count == 1 }), images.allSatisfy(\.isValid), videos.allSatisfy(\.isValid),
              videos.reduce(0, { $0 + $1.byteCount }) <= VideoImportService.maximumProjectBytes else {
            throw DeliveryError.invalid("The show section has invalid or oversized media.")
        }
        guard Set(clips.map(\.sourceID) + cues.flatMap { $0.entries.map(\.id) }) == Set(kinds.keys),
              Set(clips.compactMap { $0.source.image?.assetID }) == Set(images.map(\.id)),
              Set(clips.compactMap { $0.source.video?.assetID }) == Set(videos.map(\.id)) else {
            throw DeliveryError.invalid("The show section has missing target or media references.")
        }
        for clip in clips {
            if clip.end > duration + 0.00001 || (clip.source.video.map { $0.outPoint > (media[$0.assetID]?.first?.duration ?? 0) + 0.00001 } ?? false) {
                throw DeliveryError.invalid("A clip extends past the section or its source video.")
            }
            if case .fixture = kinds[clip.sourceID] { throw DeliveryError.invalid("A projection clip cannot target a fixture.") }
        }
        for cue in cues {
            guard validName(cue.name), !cue.isManual, cue.time >= 0, cue.time < duration, (0...cue.time).contains(cue.lead),
                  (0...3600).contains(cue.dimmerFade ?? 0), !cue.entries.isEmpty,
                  Set(cue.entries.map(\.id)).count == cue.entries.count else {
                throw DeliveryError.invalid("The show section has an invalid lighting cue.")
            }
            for entry in cue.entries {
                guard kinds[entry.id] == .fixture(entry.state.kind) else {
                    throw DeliveryError.invalid("A cue contains an incompatible fixture state.")
                }
                if case .head(let head) = entry.state, !head.isValid {
                    throw DeliveryError.invalid("A moving-head cue has invalid settings.")
                }
            }
        }
    }

    struct Insertion {
        let project: MappingProject
        let images: [UUID: UUID]
        let videos: [UUID: UUID]
    }

    func insertion(into project: MappingProject, matching assignments: [UUID: UUID], at time: Double) throws -> Insertion {
        try validate()
        guard (0...3600).contains(time), time + duration <= 3600 else {
            throw DeliveryError.invalid("The section would extend past the one-hour timeline.")
        }
        guard assignments.count == roles.count, Set(assignments.values).count == roles.count else {
            throw DeliveryError.invalid("Assign each role to its own destination before inserting.")
        }
        let targets = project.sectionTargets
        for role in roles {
            guard let target = assignments[role.id],
                  targets.contains(where: { $0.id == target && $0.kind == role.kind }) else {
                throw DeliveryError.invalid("Choose a compatible destination for “\(role.name)”.")
            }
        }
        let imageIDs = Dictionary(uniqueKeysWithValues: images.map { ($0.id, UUID()) })
        let videoIDs = Dictionary(uniqueKeysWithValues: videos.map { ($0.id, UUID()) })
        var candidate = project
        for var image in images { image.id = imageIDs[image.id]!; candidate.imageAssets.append(image) }
        for var video in videos { video.id = videoIDs[video.id]!; candidate.videoAssets.append(video) }
        let existing = Dictionary(grouping: project.timelineClips, by: \.sourceID)
        for var clip in clips {
            clip.id = UUID()
            clip.sourceID = assignments[clip.sourceID]!
            clip.start += time
            if let image = clip.source.image { clip.source.image?.assetID = imageIDs[image.assetID]! }
            if let video = clip.source.video { clip.source.video?.assetID = videoIDs[video.assetID]! }
            if existing[clip.sourceID, default: []].contains(where: {
                min($0.end, clip.end) - max($0.start, clip.start) > 0.000001
            }) {
                let label = targets.first { $0.id == clip.sourceID }?.name ?? "the selected track"
                throw DeliveryError.invalid("An existing clip overlaps the section on “\(label)”. Move the playhead or choose another track.")
            }
            candidate.timelineClips.append(clip)
        }
        for var cue in cues {
            cue.id = UUID()
            cue.time += time
            cue.entries = cue.entries.map { FixtureLookEntry(id: assignments[$0.id]!, state: $0.state) }
            candidate.lighting.cues.append(cue)
        }
        try ProjectCodec.validate(ProjectDocument(project: candidate))
        return Insertion(project: candidate, images: imageIDs, videos: videoIDs)
    }
}

enum ShowSectionStore {
    static let contentType = UTType(exportedAs: "local.keith.projectionsection", conformingTo: .package)
    private static let limit = 16 * 1024 * 1024

    static func read(_ url: URL) throws -> ShowSection {
        let folder = try url.resourceValues(forKeys: [.isDirectoryKey, .isSymbolicLinkKey])
        let file = url.appendingPathComponent("section.json")
        let info = try file.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey, .fileSizeKey])
        guard folder.isDirectory == true, folder.isSymbolicLink != true, info.isRegularFile == true,
              info.isSymbolicLink != true, (info.fileSize ?? Int.max) <= limit else {
            throw DeliveryError.invalid("This is not a readable show-section package.")
        }
        let section = try JSONDecoder().decode(ShowSection.self, from: Data(contentsOf: file))
        try section.validate()
        return section
    }

    static func write(_ bytes: Data, to destination: URL, images: [UUID: Data], videos: [UUID: URL]) throws {
        guard bytes.count <= limit else { throw DeliveryError.invalid("The section manifest exceeds 16 MB.") }
        let section = try JSONDecoder().decode(ShowSection.self, from: bytes)
        try section.validate()
        try DeliveryFile.requireVacant(destination)
        let files = FileManager.default
        let stage = destination.deletingLastPathComponent().appendingPathComponent(".section-\(UUID().uuidString)", isDirectory: true)
        let assets = stage.appendingPathComponent("assets", isDirectory: true)
        try files.createDirectory(at: stage, withIntermediateDirectories: false)
        defer { try? files.removeItem(at: stage) }
        try files.createDirectory(at: assets, withIntermediateDirectories: false)
        for asset in section.images {
            try Task.checkCancellation()
            guard let bytes = images[asset.id], bytes.count <= ImageImportService.maximumFileBytes else {
                throw DeliveryError.invalid("Relink “\(asset.name)” before saving the section.")
            }
            let url = assets.appendingPathComponent(asset.fileName)
            try bytes.write(to: url)
            let image = try ImageImportService.read(url)
            guard image.pixels.width == asset.width, image.pixels.height == asset.height else {
                throw DeliveryError.invalid("The image “\(asset.name)” changed. Relink it before saving.")
            }
        }
        for asset in section.videos {
            try Task.checkCancellation()
            guard let original = videos[asset.id], try VideoImportService.safeFile(original) == asset.byteCount else {
                throw DeliveryError.invalid("Relink “\(asset.name)” before saving the section.")
            }
            try VideoImportService.copy(original, to: assets.appendingPathComponent(asset.fileName))
        }
        try bytes.write(to: stage.appendingPathComponent("section.json"))
        try DeliveryFile.publish(stage, to: destination)
    }
}
