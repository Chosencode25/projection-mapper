import Foundation

/// Machine-local settings; never serialized into portable mapping packages.
struct OutputCalibrationProfile: Codable, Equatable {
    var version = 1
    var displayUUID: String
    var width: Int
    var height: Int
    var refresh: Double?
    var measuredDelayMilliseconds: Double = 0
    var compensationMilliseconds: Double = 0
    var notes = ""
    var isValid: Bool {
        version == 1 && !displayUUID.isEmpty && displayUUID.count <= 256 &&
        (1...16384).contains(width) && (1...16384).contains(height) &&
        (refresh == nil || (refresh!.isFinite && (0...1000).contains(refresh!))) &&
        measuredDelayMilliseconds.isFinite && (0...2000).contains(measuredDelayMilliseconds) &&
        compensationMilliseconds.isFinite && (-500...500).contains(compensationMilliseconds) && notes.count <= 2000
    }
    func matches(_ display: DisplayDescriptor) -> Bool {
        displayUUID == display.uuid && width == display.renderWidth && height == display.renderHeight && refresh == display.refreshRate
    }
    init?(display: DisplayDescriptor) {
        guard let uuid = display.uuid, !uuid.isEmpty,
              let width = display.renderWidth, let height = display.renderHeight else { return nil }
        displayUUID = uuid; self.width = width; self.height = height; refresh = display.refreshRate
        guard isValid else { return nil }
    }
}

/// Submission cadence is not optical display latency. Bounded interval history for diagnostics.
struct OutputCadence {
    private(set) var intervals: [Double] = []
    private(set) var frames = 0
    private var last: Double?
    mutating func record(at time: Double) {
        guard time.isFinite else { return }
        if let last {
            guard time > last else { return }
            if intervals.count == 240 { intervals.removeFirst() }
            intervals.append((time - last) * 1000)
        }
        last = time; frames += 1
    }
    var summary: String {
        guard !intervals.isEmpty else { return "Waiting for submitted frames" }
        let mean = intervals.reduce(0,+) / Double(intervals.count)
        return "\(frames) frames · \((1000 / mean).formatted(.number.precision(.fractionLength(1)))) submissions/s · interval \(mean.formatted(.number.precision(.fractionLength(2)))) ms · range \(intervals.min()!.formatted(.number.precision(.fractionLength(2))))–\(intervals.max()!.formatted(.number.precision(.fractionLength(2)))) ms"
    }
}

enum OutputDiagnostic: String, CaseIterable, Identifiable {
    case normal = "Normal Content", boundary = "Output Boundary / Identification", timing = "60 fps Frame / Flash Fixture"
    var id: Self { self }
    static let full = NormalizedRectangle(topLeft: SIMD2(0,0), topRight: SIMD2(1,0), bottomRight: SIMD2(1,1), bottomLeft: SIMD2(0,1))
    func scene(from original: RenderScene, elapsed: Double) -> RenderScene {
        guard self != .normal else { return original }
        let frame = Self.frame(at: elapsed)
        let color: SIMD4<Float> = self == .timing ? (frame % 60 == 0 ? SIMD4(1,1,1,1) : SIMD4(0.03,0.03,0.03,1)) : SIMD4(1,1,1,1)
        var result = RenderScene(geometry: Self.full, color: color)
        result.masterBrightness = original.masterBrightness; result.showOutput = original.showOutput
        result.outputTimingFixtureActive = self == .timing
        if self == .boundary { result.calibration.pattern = .grid; result.calibration.columns = 8; result.calibration.rows = 8 }
        return result
    }
    static func frame(at elapsed: Double) -> Int {
        guard elapsed.isFinite, elapsed > 0 else { return 0 }
        return Int(min(elapsed * 60, Double(Int.max / 2)).rounded(.down))
    }
}
