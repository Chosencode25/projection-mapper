import Foundation

/// One immutable monotonic-clock snapshot for every renderer. Never written to the project.
struct ShowOutputState: Equatable, Sendable {
    private struct Fade: Equatable, Sendable {
        let start: Float
        let target: Float
        let anchor: TimeInterval
        let duration: Double
    }

    private var heldGain: Float = 1
    private var transition: Fade?
    private(set) var isBlackout = false
    var targetGain: Float { isBlackout ? 0 : transition?.target ?? heldGain }

    func gain(at uptime: TimeInterval) -> Float {
        guard !isBlackout else { return 0 }
        guard let transition else { return heldGain }
        guard uptime.isFinite, uptime >= 0 else { return transition.start }
        let fraction = min(1, max(0, (uptime - transition.anchor) / transition.duration))
        return transition.start + (transition.target - transition.start) * Float(fraction)
    }

    func isFading(at uptime: TimeInterval) -> Bool {
        guard !isBlackout, let transition, uptime.isFinite, uptime >= 0 else { return false }
        return uptime - transition.anchor < transition.duration
    }

    mutating func fade(to target: Float, duration: Double, at uptime: TimeInterval) {
        guard !isBlackout, target.isFinite, (0...1).contains(target), duration.isFinite,
              (0...30).contains(duration), uptime.isFinite, uptime >= 0,
              target != targetGain else { return }
        let current = gain(at: uptime)
        if duration == 0 || current == target {
            heldGain = target
            transition = nil
        } else {
            transition = Fade(start: current, target: target, anchor: uptime, duration: duration)
        }
    }

    mutating func blackout() {
        isBlackout = true
        heldGain = 0
        transition = nil
    }

    mutating func restore(duration: Double, at uptime: TimeInterval) {
        // Invalid actions must not release a latched blackout.
        guard duration.isFinite, (0...30).contains(duration), uptime.isFinite, uptime >= 0 else { return }
        isBlackout = false
        fade(to: 1, duration: duration, at: uptime)
    }
}
