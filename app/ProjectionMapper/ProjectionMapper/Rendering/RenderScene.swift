/// Immutable drawing snapshot derived from the project surface for both renderers.
struct RenderScene: Equatable, Sendable {
    let geometry: NormalizedRectangle
    let color: SIMD4<Float>

    static let diagnostic = RenderScene(geometry: .diagnostic, color: SIMD4(1, 0.25, 0, 1))
}
