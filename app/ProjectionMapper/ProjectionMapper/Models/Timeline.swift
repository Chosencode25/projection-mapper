import Foundation

/// One content owner owns one lane, including every connected object face.
struct EffectClip: Identifiable, Equatable, Sendable, Codable {
    var id = UUID()
    var sourceID: UUID
    var start: Double
    var duration: Double
    var source: SourceLook
    var transition: Double?
    var transitionCurve: CueCurve?
    var end: Double { start + duration }
    var isValid: Bool {
        start.isFinite && duration.isFinite && start >= 0 && duration >= 0.1 && end <= 3600 &&
        (0...duration).contains(transition ?? 0) && source.isValid && source.primaryBinding == nil && source.secondaryBinding == nil &&
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
            if let first = sorted.first, (first.transition ?? 0) > 0 { return false }
            for i in sorted.indices.dropFirst() {
                let incoming = sorted[i], outgoing = sorted[i-1]
                let overlap = max(0, outgoing.end - incoming.start)
                if overlap == 0 && (incoming.transition ?? 0) == 0 { continue }
                guard overlap > 0, abs(overlap - (incoming.transition ?? 0)) < 0.00001,
                      incoming.start > outgoing.start, incoming.end >= outgoing.end,
                      i < 2 || sorted[i-2].end <= incoming.start else { return false }
            }
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
    var visualKind: VisualSourceKind? = nil
    var isRegion = false
}
extension MappingProject {
    var baseTimelineTracks: [TimelineTrack] {
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
    var timelineTracks: [TimelineTrack] {
        baseTimelineTracks.flatMap { owner in
            let faces = surfaces.filter { source(for: $0).id == owner.id }
            let overlays = layers.filter { $0.ownerID == owner.id }.map {
                TimelineTrack(id: $0.id, targetID: owner.targetID, isObject: owner.isObject,
                              name: $0.track.name, faceCount: owner.faceCount,
                              isVisible: owner.isVisible && $0.track.isVisible, source: $0.track.source,
                              visualKind: $0.track.kind)
            }
            let subregions = faces.flatMap { face in
                regions.filter { $0.faceID == face.id }.map {
                    TimelineTrack(id: $0.id, targetID: face.id, isObject: false,
                                  name: $0.track.name, faceCount: 1,
                                  isVisible: owner.isVisible && face.layout.isVisible && $0.track.isVisible,
                                  source: $0.track.source, visualKind: $0.track.kind, isRegion: true)
                }
            }
            return [owner] + overlays + subregions
        }
    }
}

enum ShowMarkerKind: String, Codable, CaseIterable, Identifiable {
    case beat = "Beat", lyric = "Lyric", section = "Section"
    var id: Self { self }
}

struct ShowMarker: Codable, Equatable, Identifiable {
    var id = UUID()
    var time: Double
    var kind: ShowMarkerKind
    var downbeat: Bool?
    var name: String

    var isValid: Bool {
        (0...3600).contains(time) && !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && name.count <= 120
    }

    static func importRows(_ text: String) throws -> [Self] {
        let lines = text.split(whereSeparator: \.isNewline)
        guard lines.count <= 2048 else { throw ProjectFileError.invalid("A show can have up to 2,048 markers.") }
        return try lines.enumerated().map { index, line in
            let fields = line.split(separator: "\t", maxSplits: 2, omittingEmptySubsequences: false)
            guard fields.count == 3, let time = Double(fields[0]),
                  let kind = ShowMarkerKind.allCases.first(where: { $0.rawValue.lowercased() == fields[1].lowercased() }) else {
                throw ProjectFileError.invalid("Marker line \(index + 1) needs seconds, kind, and name separated by tabs.")
            }
            let marker = Self(time: time, kind: kind, name: String(fields[2]).trimmingCharacters(in: .whitespaces))
            guard marker.isValid else { throw ProjectFileError.invalid("Invalid marker on line \(index + 1).") }
            return marker
        }
    }

    static func suggestedBeats(peaks: [Float], duration: Double) -> [Self] {
        guard peaks.count > 2, let maxPeak = peaks.max(), maxPeak > 0.01 else { return [] }
        let step = duration / Double(peaks.count)
        var last = -1.0
        var markers: [Self] = []
        for index in peaks.indices.dropFirst().dropLast() {
            let time = (Double(index) + 0.5) * step
            guard time - last >= 0.2, peaks[index] >= maxPeak * 0.35,
                  peaks[index] > peaks[index - 1] * 1.7, peaks[index] >= peaks[index + 1] else { continue }
            markers.append(Self(time: time, kind: .beat, name: "Suggested Beat"))
            last = time
        }
        return markers
    }
}

enum ShowCuePreview {
    struct Entry: Identifiable {
        var cue: LightingCue
        var afterWrap: Bool
        var delay: Double
        var id: UUID { cue.id }
    }

    static func upcoming(_ sortedCues: [LightingCue], at time: Double, loop: SongLoop?, songEnd: Double?) -> [Entry] {
        let timed = sortedCues.filter { !$0.isManual }
        if let loop {
            let current = min(loop.end, max(loop.start, time))
            let withinLoop = timed.filter { (loop.start..<loop.end).contains($0.time) }
            let now = withinLoop.filter { $0.time > current || (time < loop.start && $0.time == loop.start) }
                .map { Entry(cue: $0, afterWrap: false, delay: $0.time - current) }
            let wrapped = withinLoop.filter { $0.time <= current && !(time < loop.start && $0.time == loop.start) }
                .map { Entry(cue: $0, afterWrap: true, delay: loop.end - current + $0.time - loop.start) }
            return Array((now + wrapped).prefix(5))
        }
        return Array(timed.lazy.filter { $0.time > time && $0.time <= (songEnd ?? 3600) }
            .prefix(5).map { Entry(cue: $0, afterWrap: false, delay: $0.time - time) })
    }
}

enum ChoreographyPattern: String, Codable, CaseIterable, Identifiable, Sendable {
    case forward = "Forward", reverse = "Reverse", bounce = "Bounce", wave = "Wave"
    var id: Self { self }
}

enum ChoreographyTargetKind: String, Codable, CaseIterable, Identifiable, Sendable {
    case projection = "Projection", fixture = "Fixtures"
    var id: Self { self }
}

struct ChoreographyTarget: Codable, Identifiable, Equatable, Sendable {
    var id: UUID
    var position: FixturePreviewPoint
}

/// A reusable recipe. Target IDs, positions and start times belong to each placement.
struct LightingEffectPreset: Codable, Equatable, Identifiable {
    var id = UUID()
    var name: String
    var pattern: ChoreographyPattern
    var colors: [SIMD4<Float>]
    var interval: Double
    var repeats: Int
    var angle: Double

    init(clip: ChoreographyClip) {
        name = clip.name.trimmingCharacters(in: .whitespacesAndNewlines)
        pattern = clip.pattern
        colors = clip.colors
        interval = clip.interval
        repeats = clip.repeats
        angle = clip.angle
    }

    var isValid: Bool {
        !name.isEmpty && name.count <= 80 &&
            (1...16).contains(colors.count) &&
            colors.allSatisfy { color in (0..<4).allSatisfy { (0...1).contains(color[$0]) } } &&
            (0.05...60).contains(interval) && (1...64).contains(repeats) && (-360...360).contains(angle)
    }

    func apply(to clip: inout ChoreographyClip) {
        clip.name = name
        clip.pattern = pattern
        clip.colors = colors
        clip.interval = interval
        clip.repeats = repeats
        clip.angle = angle
    }
}

struct ChoreographyClip: Codable, Identifiable, Equatable, Sendable {
    var id = UUID()
    var name = "Color Chase"
    var kind = ChoreographyTargetKind.fixture
    var pattern = ChoreographyPattern.forward
    var targets: [ChoreographyTarget] = []
    var colors: [SIMD4<Float>] = [SIMD4(1, 0, 0, 1), SIMD4(0, 0.5, 1, 1)]
    var start = 0.0
    var interval = 0.5
    var repeats = 1
    var angle = 0.0

    private var steps: Int { pattern == .bounce ? max(1, targets.count * 2 - 2) : targets.count }
    var duration: Double { interval * Double(steps * repeats) }
    var end: Double { start + duration }
    var isValid: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && name.count <= 80 &&
        (1...128).contains(targets.count) && targets.allSatisfy { $0.position.isValid } &&
        Set(targets.map(\.id)).count == targets.count && (1...16).contains(colors.count) &&
        colors.allSatisfy { c in (0..<4).allSatisfy { (0...1).contains(c[$0]) } } &&
        (0...3600).contains(start) && (0.05...60).contains(interval) && (1...64).contains(repeats) &&
        (-360...360).contains(angle) && end <= 3600
    }

    func sample(at time: Double, target id: UUID) -> (color: SIMD4<Float>, active: Bool, stepStart: Double)? {
        guard time >= start, time < end, let index = targets.firstIndex(where: { $0.id == id }) else { return nil }
        let step = min(steps * repeats - 1, Int((time - start) / interval))
        let phase = step % steps
        let active: Bool
        switch pattern {
        case .forward: active = index == phase
        case .reverse: active = index == targets.count - phase - 1
        case .bounce: active = index == min(phase, steps - phase)
        case .wave:
            let radians = angle * .pi / 180
            func coordinate(_ target: ChoreographyTarget) -> Double {
                target.position.x * cos(radians) + target.position.y * sin(radians)
            }
            let values = targets.map(coordinate)
            let minimum = values.min() ?? 0
            let span = (values.max() ?? minimum) - minimum
            let slot = span > 0.00001 ? Int(((values[index] - minimum) / span * Double(steps - 1)).rounded()) : 0
            active = phase == slot
        }
        return (colors[step % colors.count], active, start + Double(step) * interval)
    }

    static func validSequence(_ clips: [Self]) -> Bool {
        guard clips.count <= 128, Set(clips.map(\.id)).count == clips.count, clips.allSatisfy(\.isValid) else { return false }
        for (index, clip) in clips.enumerated() {
            let ids = Set(clip.targets.map(\.id))
            if clips[..<index].contains(where: { other in
                clip.kind == other.kind && clip.start < other.end && other.start < clip.end &&
                    other.targets.contains { ids.contains($0.id) }
            }) { return false }
        }
        return true
    }
}

enum BeatBoundary: String, CaseIterable, Identifiable {
    case beat = "Next Beat", bar = "Next Bar"
    var id: Self { self }

    func next(in markers: [ShowMarker], after time: Double, loop: SongLoop?, end: Double) -> (time: Double, wraps: Bool)? {
        let times = markers.filter { marker in
            marker.kind == .beat && (self == .beat || marker.downbeat == true) &&
                marker.time < end && (loop.map { ($0.start..<$0.end).contains(marker.time) } ?? true)
        }.map(\.time).sorted()
        if let next = times.first(where: { $0 > time }) { return (next, false) }
        if loop != nil, let first = times.first { return (first, true) }
        return nil
    }
}
