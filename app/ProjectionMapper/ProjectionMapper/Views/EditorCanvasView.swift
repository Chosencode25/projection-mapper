import SwiftUI

struct EditorCanvasView: View {
    let session: EditorSession
    var output: OutputSelectionState { session.output }
    var body: some View {
        GeometryReader { geometry in
            let availableWidth = max(0, geometry.size.width - 56)
            let availableHeight = max(0, geometry.size.height - 100)
            let ratio = output.aspectRatio
            let width = min(availableWidth, availableHeight * ratio)
            let height = width / ratio
            VStack(spacing: 16) {
                MetalScenePreview(scene: session.scene, aspectRatio: ratio, outputDescription: output.renderSizeText)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .overlay {
                        RoundedRectangle(cornerRadius: 8)
                            .strokeBorder(Color.white.opacity(0.13), lineWidth: 1)
                    }
                .frame(width: width, height: height)
                .overlay {
                    if let surface = session.selectedSurface {
                        CornerOverlay(surfaceID: surface.id, corners: surface.corners,
                                      activeCorner: session.selectedCorner,
                                      select: { session.selectCorner($0) },
                                      move: { session.moveSelectedCorner(to: $0, surfaceID: surface.id) },
                                      nudge: { session.nudgeSelectedCorner(direction: $0, larger: $1) })
                            .frame(width: width + 24, height: height + 24)
                    }
                }
                Text("\(output.selectedName) · \(output.renderSizeText) · Editor preview").font(.caption).foregroundStyle(.secondary)
                    .lineLimit(2).multilineTextAlignment(.center)
                    .frame(maxWidth: max(0, availableWidth))
                    .help("\(output.selectedName) · \(output.renderSizeText)")
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
        }
        .background(Color(red: 0.085, green: 0.09, blue: 0.105))
    }
}
