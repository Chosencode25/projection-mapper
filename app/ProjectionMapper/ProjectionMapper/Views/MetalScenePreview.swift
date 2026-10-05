import SwiftUI

struct MetalScenePreview: NSViewRepresentable {
    let scene: RenderScene
    let aspectRatio: Double
    let outputDescription: String

    func makeNSView(context: Context) -> MetalSceneView {
        let view = MetalSceneView(frame: .zero, scene: scene)
        view.setAccessibilityLabel(view.renderingError ?? "Editor preview — project surface on black")
        return view
    }

    func updateNSView(_ view: MetalSceneView, context: Context) {
        view.setScene(scene)
        view.outputAspectRatio = aspectRatio
        view.setAccessibilityValue(outputDescription)
    }
}
