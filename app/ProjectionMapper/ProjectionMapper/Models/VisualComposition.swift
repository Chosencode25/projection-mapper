import Foundation
import simd

enum VisualBlendMode: String, CaseIterable, Codable, Identifiable, Sendable {
    case normal, add
    var id: Self { self }
    var title: String { rawValue.capitalized }
}

enum VisualSourceKind: String, CaseIterable, Codable, Identifiable, Sendable {
    case media, text, singingFace
    var id: Self { self }
    var title: String {
        switch self {
        case .media: "Effect or media"
        case .text: "Text"
        case .singingFace: "Singing face"
        }
    }
}

struct ProjectionText: Equatable, Codable, Sendable {
    enum Mode: String, CaseIterable, Codable, Identifiable, Sendable {
        case greeting, songTitle, countdown
        var id: Self { self }
        var title: String { self == .songTitle ? "Song title" : rawValue.capitalized }
    }
    enum Alignment: String, CaseIterable, Codable, Identifiable, Sendable {
        case leading, center, trailing
        var id: Self { self }
    }
    var mode: Mode = .greeting
    var message = "Happy Holidays"
    var font = ""
    var size: Float = 0.19
    var alignment: Alignment = .center
    var color = SIMD4<Float>(1, 1, 1, 1)
    var countdownEnd: Double = 10
    var markerID: UUID?

    var isValid: Bool {
        message.count <= 240 && font.count <= 120 && size.isFinite && (0.02...0.8).contains(size) &&
        color.indices.allSatisfy { (0...1).contains(color[$0]) } && (0...3600).contains(countdownEnd)
    }

    func displayedText(at time: Double, songTitle: String?, markers: [ShowMarker]) -> String {
        switch mode {
        case .greeting: return message
        case .songTitle: return songTitle ?? ""
        case .countdown:
            let target = markers.first { $0.id == markerID }?.time ?? countdownEnd
            let remaining = max(0, min(3600, target - (time.isFinite ? time : 0)))
            return String(Int(ceil(remaining)))
        }
    }
}

enum MouthShape: String, CaseIterable, Codable, Identifiable, Sendable {
    case rest, open, wide, rounded, closed
    var id: Self { self }
    var title: String { rawValue.capitalized }
}

struct MouthKey: Identifiable, Equatable, Codable, Sendable {
    var id = UUID()
    var time: Double
    var shape: MouthShape
}

struct VisualTrack: Equatable, Codable, Identifiable, Sendable {
    var source = SurfaceSource(content: .solid, color: SIMD4(1, 1, 1, 1))
    var id: UUID { source.id }
    var name: String
    var isVisible = true
    var blend: VisualBlendMode = .normal
    var opacity: Float = 1
    /// Position and size in owner or region coordinates. Rotation is about the box center.
    var center = SIMD2<Float>(0.5, 0.5)
    var size = SIMD2<Float>(1, 1)
    var rotation: Float = 0
    var kind: VisualSourceKind = .media
    var text = ProjectionText()
    var mouthKeys: [MouthKey] = []

    var isValid: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && name.count <= 80 &&
        (0...1).contains(opacity) && (-1...2).contains(center.x) && (-1...2).contains(center.y) &&
        (0.01...4).contains(size.x) && (0.01...4).contains(size.y) && (-180...180).contains(rotation) &&
        text.isValid && mouthKeys.count <= 2048 && Set(mouthKeys.map(\.id)).count == mouthKeys.count &&
        Set(mouthKeys.map(\.time)).count == mouthKeys.count && mouthKeys.allSatisfy { (0...3600).contains($0.time) }
    }

    func mouth(at time: Double, since clipStart: Double? = nil) -> MouthShape {
        mouthKeys.filter { $0.time <= time && $0.time >= (clipStart ?? 0) }
            .max { $0.time < $1.time }?.shape ?? .rest
    }

    func independentCopy() -> Self {
        var copy = self
        copy.source = source.independentCopy()
        copy.mouthKeys = mouthKeys.map { MouthKey(time: $0.time, shape: $0.shape) }
        return copy
    }
}

struct VisualLayer: Equatable, Codable, Identifiable, Sendable {
    let ownerID: UUID
    var track: VisualTrack
    var id: UUID { track.id }
}

struct FaceRegion: Equatable, Codable, Identifiable, Sendable {
    var faceID: UUID
    var track: VisualTrack
    var shape = MaskPolygon.rectangle
    /// Fraction of the shorter side of the reference face. Nil fills the region.
    var outline: Float?
    var id: UUID { track.id }
    var isValid: Bool {
        FaceMask(boundary: shape).validationMessage == nil &&
        (outline.map { (0.005...0.25).contains($0) } ?? true)
    }
}

struct RegionShapePreset: Identifiable, Equatable, Codable, Sendable {
    var id = UUID()
    var name: String
    var shape: MaskPolygon
}

extension MappingProject {
    static let maximumLayersPerOwner = 3
    static let maximumRegionsPerFace = 4

    var layers: [VisualLayer] { visualLayers ?? [] }
    var regions: [FaceRegion] { faceRegions ?? [] }
    var regionShapes: [RegionShapePreset] { regionShapePresets ?? [] }
    var additionalSources: [SurfaceSource] { layers.map(\.track.source) + regions.map(\.track.source) }
    var visualTracks: [VisualTrack] { layers.map(\.track) + regions.map(\.track) }

    func visualTrack(_ id: UUID) -> VisualTrack? {
        layers.first { $0.id == id }?.track ?? regions.first { $0.id == id }?.track
    }

    mutating func updateVisualTrack(_ id: UUID, _ edit: (inout VisualTrack) -> Void) {
        if let index = visualLayers?.firstIndex(where: { $0.id == id }) {
            edit(&visualLayers![index].track)
        } else if let index = faceRegions?.firstIndex(where: { $0.id == id }) {
            edit(&faceRegions![index].track)
        }
    }

    /// Reconcile stable targets after the existing face/object editing operations.
    mutating func removeOrphanedVisuals() {
        let ownerIDs = Set(surfaces.map { source(for: $0).id })
        let faceIDs = Set(surfaces.map(\.id))
        let removed = layers.filter { !ownerIDs.contains($0.ownerID) }.map(\.id) +
            regions.filter { !faceIDs.contains($0.faceID) }.map(\.id)
        guard !removed.isEmpty else { return }
        let ids = Set(removed)
        visualLayers?.removeAll { ids.contains($0.id) }
        faceRegions?.removeAll { ids.contains($0.id) }
        timelineClips.removeAll { ids.contains($0.sourceID) }
    }

    var visualValidationIssue: String? {
        let owners = Dictionary(grouping: surfaces, by: { source(for: $0).id })
        let faceIDs = Set(surfaces.map(\.id))
        guard layers.allSatisfy({ owners[$0.ownerID] != nil }),
              regions.allSatisfy({ faceIDs.contains($0.faceID) && $0.isValid }),
              Dictionary(grouping: layers, by: \.ownerID).values.allSatisfy({ $0.count <= Self.maximumLayersPerOwner }),
              Dictionary(grouping: regions, by: \.faceID).values.allSatisfy({ $0.count <= Self.maximumRegionsPerFace }),
              visualTracks.allSatisfy(\.isValid),
              regionShapes.count <= 64, Set(regionShapes.map(\.id)).count == regionShapes.count,
              regionShapes.allSatisfy({
                  !$0.name.isEmpty && $0.name.count <= 80 && FaceMask(boundary: $0.shape).validationMessage == nil
              }) else { return "Invalid layer, region, or shape preset." }
        guard !layers.isEmpty || !regions.isEmpty else { return nil }

        let clips = Dictionary(grouping: timelineClips, by: \.sourceID)
        let layersByOwner = Dictionary(grouping: layers, by: \.ownerID)
        let regionsByFace = Dictionary(grouping: regions, by: \.faceID)
        for (ownerID, faces) in owners {
            let added = (layersByOwner[ownerID] ?? []).map(\.track) +
                faces.flatMap { (regionsByFace[$0.id] ?? []).map(\.track) }
            guard !added.isEmpty, let face = faces.first else { continue }
            let sources = [source(for: face)] + added.filter { $0.isVisible && $0.opacity > 0 && $0.kind == .media }.map(\.source)
            var changes: [Double: Int] = [:]
            for source in sources {
                if let lane = clips[source.id], !lane.isEmpty {
                    for clip in lane where clip.source.content == .video {
                        changes[clip.start, default: 0] += 1
                        changes[clip.end, default: 0] -= 1
                    }
                } else if source.content == .video {
                    changes[0, default: 0] += 1
                }
            }
            var active = 0
            for time in changes.keys.sorted() {
                active += changes[time, default: 0]
                if active > 2 { return "\(face.name) exceeds two simultaneous videos at \(time.formatted(.number.precision(.fractionLength(2)))) s." }
            }
        }
        return nil
    }
}

struct RenderVisual: Equatable, Sendable {
    var track: VisualTrack
    var clips: [EffectClip]
    var region: FaceRegion?
    var songTitle: String?
    var countdownMarkerTime: Double?

    var isAnimated: Bool {
        !clips.isEmpty || track.source.content.isAnimated ||
        track.kind == .singingFace || (track.kind == .text && track.text.mode == .countdown)
    }

    struct Sample {
        let source: SurfaceSource
        let clipID: UUID?
        let frameID: UUID
        let elapsed: Double
        let start: Double?
    }

    struct Evaluation {
        let first: Sample
        let second: Sample?
        let fraction: Float
    }

    func frameID(forClipAt index: Int) -> UUID {
        let clip = clips[index]
        let needsIndependentFrame = (clip.transition ?? 0) > 0 ||
            (clips.indices.contains(index + 1) && (clips[index + 1].transition ?? 0) > 0)
        return needsIndependentFrame ? clip.id : track.id
    }

    func evaluate(at time: Double) -> Evaluation? {
        guard track.isVisible, track.opacity > 0 else { return nil }
        if clips.isEmpty {
            guard track.kind != .text else { return nil }
            return Evaluation(first: Sample(source: track.source, clipID: nil, frameID: track.id, elapsed: time, start: nil),
                              second: nil, fraction: -1)
        }
        guard let index = clips.lastIndex(where: { $0.contains(time) }) else { return nil }
        let incoming = clips[index]
        func sample(_ clip: EffectClip, index: Int) -> Sample {
            return Sample(source: clip.source.applying(to: track.source), clipID: clip.id,
                          frameID: frameID(forClipAt: index), elapsed: time - clip.start, start: clip.start)
        }
        let current = sample(incoming, index: index)
        if index > 0, let duration = incoming.transition, duration > 0, time < incoming.start + duration,
           clips[index - 1].contains(time) {
            let curve = incoming.transitionCurve == .eased ? CueCurve.eased : .linear
            return Evaluation(first: sample(clips[index - 1], index: index - 1), second: current,
                              fraction: Float(curve.evaluate((time - incoming.start) / duration)))
        }
        return Evaluation(first: current, second: nil, fraction: -1)
    }
}

extension MappingProject {
    func renderVisuals(owner: UUID, face: UUID) -> [RenderVisual] {
        func make(_ track: VisualTrack, region: FaceRegion? = nil) -> RenderVisual {
            var track = track
            track.source = resolvedSource(track.source)
            return RenderVisual(track: track, clips: timelineClips.filter { $0.sourceID == track.id }.sorted { $0.start < $1.start },
                                region: region, songTitle: song?.name,
                                countdownMarkerTime: showMarkers.first { $0.id == track.text.markerID }?.time)
        }
        return layers.filter { $0.ownerID == owner }.map { make($0.track) } +
            regions.filter { $0.faceID == face }.map { make($0.track, region: $0) }
    }
}
