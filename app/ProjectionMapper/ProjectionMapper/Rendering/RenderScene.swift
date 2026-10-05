enum SurfaceContent: String, CaseIterable, Identifiable, Sendable {
    case diagnosticGrid, solid
    var id: String { rawValue }
    var title: String { self == .diagnosticGrid ? "Diagnostic grid" : "Solid fill" }
}

/// Immutable drawing snapshot derived from the project surface for both renderers.
struct RenderScene: Equatable, Sendable {
    let geometry: NormalizedRectangle
    let color: SIMD4<Float>
    var content: SurfaceContent = .solid
    var perspective: PerspectiveTransform? { PerspectiveTransform(geometry) }

    // Preserve the original solid fixture for lifecycle and performance comparisons.
    static let diagnostic = RenderScene(geometry: .diagnostic, color: SIMD4(1, 0.25, 0, 1))
    static let diagnosticGrid = RenderScene(geometry: .diagnostic, color: diagnostic.color, content: .diagnosticGrid)
}
