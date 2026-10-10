import Foundation

/// One content owner owns one lane, including every connected object face.
struct EffectClip: Identifiable, Equatable, Sendable, Codable {
    var id = UUID()
    var sourceID: UUID
    var start: Double
    var duration: Double
    var source: SourceLook
    var end: Double { start + duration }
    var isValid: Bool {
        start.isFinite && duration.isFinite && start >= 0 && duration >= 0.1 && end <= 3600 &&
        source.isValid && source.primaryBinding == nil && source.secondaryBinding == nil &&
        (source.image?.isValid ?? true) && (source.content != .image || source.image != nil) && (source.video?.isValid ?? true) && (source.content != .video || source.video != nil) &&
        (source.content != .video || source.video!.loops || duration <= source.video!.timelineDuration+0.00001)
    }
    func contains(_ time: Double) -> Bool { time >= start && time < end }
    func trimming(start newStart: Double, duration newDuration: Double) -> Self {
        var copy = self; copy.start = newStart; copy.duration = newDuration
        if source.content == .video, var video = source.video {
            let delta = (newStart-start)*video.rate
            if video.loops {
                let phase = ((video.loopOffset ?? 0)+delta).truncatingRemainder(dividingBy: video.rangeDuration)
                video.loopOffset = phase < 0 ? phase+video.rangeDuration : phase
            } else { video.inPoint += delta; video.outPoint = video.inPoint + newDuration*video.rate }
            copy.source.video = video
        }
        return copy
    }
    func replacingVideo(_ content: VideoContent) -> Self {
        var copy = self
        if let old = source.video, !content.loops {
            if old.inPoint != content.inPoint || old.outPoint != content.outPoint { copy.duration = content.timelineDuration }
            else if old.rate != content.rate { copy.duration *= old.rate/content.rate }
            copy.duration = min(copy.duration,content.timelineDuration)
        }
        copy.source.video = content
        return copy
    }
    static func validSequence(_ clips: [Self]) -> Bool {
        guard clips.count <= 2000, Set(clips.map(\.id)).count == clips.count, clips.allSatisfy(\.isValid) else { return false }
        for lane in Dictionary(grouping: clips, by: \.sourceID).values {
            let sorted = lane.sorted { $0.start < $1.start }
            for i in sorted.indices.dropFirst() where sorted[i].start < sorted[i-1].end { return false }
        }
        return true
    }
}
struct TimelineTrack: Identifiable {
    let id: UUID // source identity
    let targetID: UUID
    let isObject: Bool
    let name: String
    let faceCount: Int
    let isVisible: Bool
    let source: SurfaceSource
}
extension MappingProject {
    var timelineTracks: [TimelineTrack] {
        var seen = Set<UUID>()
        return surfaces.compactMap { face in
            let object = object(for: face), source = source(for: face)
            guard seen.insert(source.id).inserted else { return nil }
            return TimelineTrack(id: source.id, targetID: object?.id ?? face.id, isObject: object != nil,
                name: object?.name ?? face.name,
                faceCount: object.map { obj in surfaces.filter { $0.layout.objectID == obj.id }.count } ?? 1,
                isVisible: object?.isVisible != false && surfaces.contains { self.source(for: $0).id == source.id && $0.layout.isVisible }, source: source)
        }
    }
}
