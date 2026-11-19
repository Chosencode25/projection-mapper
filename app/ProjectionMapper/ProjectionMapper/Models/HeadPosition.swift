import Foundation
import CoreGraphics

/// The curve belongs to the segment arriving at this key. Position never changes light output.
struct HeadPositionKey: Identifiable, Codable, Equatable, Sendable {
    var id = UUID()
    var fixtureID: UUID
    var time: Double
    var pan: Double
    var tilt: Double
    var curve: CueCurve = .linear
    var isValid: Bool {
        time.isFinite && (0...3600).contains(time) && pan.isFinite && tilt.isFinite &&
        (0...1).contains(pan) && (0...1).contains(tilt)
    }
}

struct HeadPositionSchedule {
    private var tracks: [UUID: [HeadPositionKey]] = [:]
    init(keys: [HeadPositionKey] = []) {
        tracks = Dictionary(grouping: keys, by: \.fixtureID).mapValues { $0.sorted { $0.time < $1.time } }
    }
    /// Before the first key the cue-provided position remains authoritative; afterward keys hold.
    func applying(to state: FixtureState, fixtureID: UUID, at time: Double) -> FixtureState {
        guard time.isFinite, case .head(var head) = state, let keys = tracks[fixtureID],
              let first = keys.first, time >= first.time else { return state }
        var lower = 0, upper = keys.count
        while lower < upper {
            let middle = (lower + upper) / 2
            if keys[middle].time <= time { lower = middle + 1 } else { upper = middle }
        }
        let previous = keys[lower - 1]
        head.pan = previous.pan; head.tilt = previous.tilt
        if lower < keys.count, keys[lower].curve != .snap {
            let next = keys[lower]
            let fraction = next.curve.evaluate((time - previous.time) / (next.time - previous.time))
            head.pan += (next.pan - previous.pan) * fraction
            head.tilt += (next.tilt - previous.tilt) * fraction
        }
        return .head(head)
    }
}

/// Schematic authoring chart in normalized pan/tilt coordinates, independent of fixture placement.
enum HeadPathGeometry {
    static func point(pan: Double, tilt: Double, size: CGSize) -> CGPoint {
        CGPoint(x: 16 + pan * max(1, size.width - 32), y: 16 + (1 - tilt) * max(1, size.height - 32))
    }
    static func position(at point: CGPoint, size: CGSize) -> (pan: Double, tilt: Double)? {
        guard size.width > 32, size.height > 32, size.width.isFinite, size.height.isFinite,
              point.x.isFinite, point.y.isFinite else { return nil }
        return (min(1, max(0, (point.x - 16) / (size.width - 32))),
                min(1, max(0, 1 - (point.y - 16) / (size.height - 32))))
    }
}
