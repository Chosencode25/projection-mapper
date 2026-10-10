import Foundation

enum SurfaceContent: String, CaseIterable, Identifiable, Sendable, Codable {
    case diagnosticGrid, solid, gradient, movingLines, movingCheckers, plasma, noise, particles, image, video
    var id: String { rawValue }
    var title: String {
        switch self {
        case .diagnosticGrid: "Diagnostic grid"
        case .solid: "Solid fill"
        case .gradient: "Animated gradient"
        case .movingLines: "Moving lines"
        case .movingCheckers: "Moving checkers"
        case .plasma: "Plasma"
        case .noise: "Animated noise"
        case .particles: "Particles"
        case .image: "Image"
        case .video: "Video"
        }
    }
    var isAnimated: Bool { self != .solid && self != .diagnosticGrid && self != .image }
    var isProceduralAnimation: Bool { isAnimated && self != .video }
    var shaderKind: UInt32 {
        switch self { case .solid: 0; case .diagnosticGrid: 1; case .gradient: 2; case .movingLines: 3; case .movingCheckers: 4; case .plasma: 5; case .noise: 6; case .particles: 7; case .image, .video: 8 }
    }
}

/// Immutable clock anchor shared by every view. Runtime transport is outside project data.
struct AnimationTransport: Equatable, Sendable {
    private(set) var isPlaying = false
    private(set) var speed: Double = 1
    private(set) var position: Double = 0
    private(set) var anchor: TimeInterval = 0
    func elapsed(at uptime: TimeInterval) -> Double {
        position + (isPlaying ? max(0, uptime - anchor) * speed : 0)
    }
    mutating func setPlaying(_ playing: Bool, at uptime: TimeInterval) {
        guard playing != isPlaying, uptime.isFinite else { return }
        position = elapsed(at: uptime); anchor = uptime; isPlaying = playing
    }
    mutating func setSpeed(_ value: Double, at uptime: TimeInterval) {
        guard value.isFinite, (0.1...4).contains(value), uptime.isFinite, speed != value else { return }
        position = elapsed(at: uptime); anchor = uptime; speed = value
    }
    mutating func seek(to seconds: Double, at uptime: TimeInterval) {
        guard seconds.isFinite, (0...3600).contains(seconds), uptime.isFinite else { return }
        position = seconds; anchor = uptime
    }
    mutating func restart(at uptime: TimeInterval) {
        guard uptime.isFinite else { return }; position = 0; anchor = uptime
    }
}

struct SourcePlayback: Equatable, Sendable {
    var offset: Double = 0
    var frozenTime: Double?
    var isPaused: Bool { frozenTime != nil }
    func elapsed(at globalTime: Double) -> Double { max(0, frozenTime ?? (globalTime + offset)) }
    mutating func setPaused(_ paused: Bool, at globalTime: Double) {
        guard paused != isPaused else { return }
        if paused { frozenTime = elapsed(at: globalTime) }
        else { offset = frozenTime! - globalTime; frozenTime = nil }
    }
    mutating func restart(at globalTime: Double) {
        offset = -globalTime; if isPaused { frozenTime = 0 }
    }
}

struct GeneratorSettings: Equatable, Sendable, Codable {
    var secondaryColor = SIMD4<Float>(0.15, 0.05, 1, 1)
    var rate: Float = 1
    var scale: Float = 1
    var direction: Int = 0
    var intensity: Float = 1
    var density: Int = 8
    var particleSize: Float = 0.15
    var seed: UInt32 = 1
    var isValid: Bool {
        (0..<4).allSatisfy { secondaryColor[$0].isFinite && (0...1).contains(secondaryColor[$0]) } &&
        rate.isFinite && (0.25...4).contains(rate) && scale.isFinite && (0.5...4).contains(scale) &&
        (0..<8).contains(direction) && intensity.isFinite && (0.1...1).contains(intensity) &&
        (4...16).contains(density) && particleSize.isFinite && (0.04...0.35).contains(particleSize) && seed <= 999999
    }
    var motion: SIMD2<Float> {
        [SIMD2<Float>(1,0),SIMD2(1,1),SIMD2(0,1),SIMD2(-1,1),SIMD2(-1,0),SIMD2(-1,-1),SIMD2(0,-1),SIMD2(1,-1)][max(0,min(7,direction))]
    }
    static let defaults = Self()
}

struct RenderSurface: Equatable, Sendable {
    let geometry: NormalizedRectangle
    var color: SIMD4<Float>
    var content: SurfaceContent = .solid
    var inputMap: FaceInputMap = .full
    var generator: GeneratorSettings = .defaults
    var sourceID: UUID?
    var appearance = SurfaceAppearance.defaults
    var mask: FaceMask?
    var image: ImageContent?
    var video: VideoContent?
    var timelineClips: [EffectClip] = []
    var playback = SourcePlayback()
    /// Gaps in sequenced tracks are dark. Empty tracks preserve the live editor source.
    func evaluated(at time: Double, calibrationActive: Bool = false) -> Self {
        guard !timelineClips.isEmpty else { return self }
        var copy = self
        guard let clip = timelineClips.first(where: { $0.contains(time) }) else {
            if !calibrationActive { copy.appearance.opacity = 0 }
            return copy
        }
        copy.content = clip.source.content; copy.color = clip.source.color
        copy.generator = clip.source.generator; copy.image = clip.source.image; copy.video = clip.source.video
        copy.playback = SourcePlayback(offset: -clip.start)
        return copy
    }
    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.geometry == rhs.geometry && lhs.color == rhs.color && lhs.content == rhs.content && (lhs.content != .video || lhs.sourceID == rhs.sourceID) &&
        lhs.inputMap == rhs.inputMap && lhs.generator == rhs.generator && lhs.playback == rhs.playback && lhs.appearance == rhs.appearance && lhs.mask == rhs.mask && lhs.image == rhs.image && lhs.video == rhs.video && lhs.timelineClips == rhs.timelineClips
    }
    var perspective: PerspectiveTransform? { inputMap.isValid && appearance.isValid && (mask?.allowsRendering ?? true) ? PerspectiveTransform(geometry) : nil }
}

/// Immutable collection shared by preview/output; items already in back-to-front draw order.
struct RenderScene: Equatable, Sendable {
    let surfaces: [RenderSurface]
    var images: [UUID:ImagePixels] = [:]
    var videoFrames: [UUID:VideoFrame] = [:]
    var editorTransparentBackground = false
    var transport = AnimationTransport()
    var masterBrightness: Float = 1
    var showOutput = ShowOutputState()
    var calibration = CalibrationState()
    /// Calibration appearance is a render-only copy, retaining maps, source IDs and clocks.
    var effectiveSurfaces: [RenderSurface] {
        guard calibration.isValid else { return [] }
        guard calibration.pattern.isActive else { return surfaces }
        return surfaces.map { original in
            var copy = original; copy.appearance = .defaults; return copy
        }
    }
    var hasAnimation: Bool { surfaces.contains { $0.content.isAnimated && $0.appearance.opacity > 0 && $0.perspective != nil } }
    var needsContinuousRendering: Bool { needsContinuousRendering(at: ProcessInfo.processInfo.systemUptime) }
    func effectiveGain(at uptime: TimeInterval) -> Float {
        let brightness = masterBrightness.isFinite ? min(1, max(0, masterBrightness)) : 0
        return brightness * showOutput.gain(at: uptime)
    }
    func needsContinuousRendering(at uptime: TimeInterval) -> Bool {
        let visible = effectiveSurfaces.filter { $0.appearance.opacity > 0 && $0.perspective != nil }
        return needsContinuousRendering(at: uptime, hasVisibleSurface: !visible.isEmpty,
                                        hasRunningAnimation: visible.contains { $0.content.isAnimated && !$0.playback.isPaused })
    }
    /// The renderer supplies eligibility cached alongside its prepared geometry.
    func needsContinuousRendering(at uptime: TimeInterval, hasVisibleSurface: Bool, hasRunningAnimation: Bool) -> Bool {
        guard calibration.isValid, calibration.pattern != .black, masterBrightness.isFinite, masterBrightness > 0, !showOutput.isBlackout else { return false }
        if showOutput.isFading(at: uptime), hasVisibleSurface { return true }
        return !calibration.pattern.isActive && effectiveGain(at: uptime) > 0 && transport.isPlaying && (hasRunningAnimation || (hasVisibleSurface && surfaces.contains { !$0.timelineClips.isEmpty }))
    }
    init(surfaces: [RenderSurface], transport: AnimationTransport = AnimationTransport(),
         masterBrightness: Float = 1, showOutput: ShowOutputState = ShowOutputState(),
         calibration: CalibrationState = CalibrationState()) {
        self.surfaces = surfaces; self.transport = transport
        self.masterBrightness = masterBrightness; self.showOutput = showOutput; self.calibration = calibration
    }
    init(geometry: NormalizedRectangle, color: SIMD4<Float>, content: SurfaceContent = .solid) {
        surfaces = [RenderSurface(geometry: geometry, color: color, content: content)]
    }
    // Single-surface fixture access for the existing renderer/warp regressions.
    var geometry: NormalizedRectangle { surfaces.first?.geometry ?? .diagnostic }
    var color: SIMD4<Float> { surfaces.first?.color ?? SIMD4(0,0,0,1) }
    var content: SurfaceContent { surfaces.first?.content ?? .solid }
    var perspective: PerspectiveTransform? { surfaces.first?.perspective }
    var invalidCount: Int { surfaces.filter { $0.perspective == nil }.count }
    static let diagnostic = RenderScene(geometry: .diagnostic, color: SIMD4(1, 0.25, 0, 1))
    static let diagnosticGrid = RenderScene(geometry: .diagnostic, color: diagnostic.color, content: .diagnosticGrid)
}
