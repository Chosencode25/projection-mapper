import Foundation

struct RenderTimingSample: Sendable, Codable {
    let view: String
    let width: Int
    let height: Int
    let encodeMilliseconds: Double
    let completionMilliseconds: Double
    let gpuMilliseconds: Double?
    let succeeded: Bool

    static func gpuDuration(start: Double, end: Double) -> Double? {
        guard start.isFinite, end.isFinite, start > 0, end >= start else { return nil }
        return (end - start) * 1_000
    }
}

struct RenderDiagnosticsSnapshot: Sendable {
    let submissions: Int
    let completions: Int
    let skips: [String: Int]
    let samples: [RenderTimingSample]
}

/// Optional and bounded. Metal completion handlers access only this lock-protected value store.
final class RenderDiagnostics: @unchecked Sendable {
    private let lock = NSLock()
    private let capacity: Int
    private var submissions = 0
    private var completions = 0
    private var skips: [String: Int] = [:]
    private var samples: [RenderTimingSample] = []

    init(capacity: Int = 512) { self.capacity = max(0, capacity) }

    func submitted() { lock.withLock { submissions += 1 } }
    func skipped(_ reason: String) { lock.withLock { skips[reason, default: 0] += 1 } }
    func completed(_ sample: RenderTimingSample) {
        lock.withLock {
            completions += 1
            if capacity > 0 {
                if samples.count == capacity { samples.removeFirst() }
                samples.append(sample)
            }
        }
    }
    func snapshot() -> RenderDiagnosticsSnapshot {
        lock.withLock { RenderDiagnosticsSnapshot(submissions: submissions, completions: completions,
                                                   skips: skips, samples: samples) }
    }
}
