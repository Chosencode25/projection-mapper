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
                    let surface = session.selectedSurface
                    CornerOverlay(surfaceID: surface?.id, corners: surface?.corners ?? .diagnostic,
                                  activeCorner: session.selectedCorner,
                                  select: { session.selectCorner($0) },
                                  move: { point in
                                      if let id = surface?.id { session.moveSelectedCorner(to: point, surfaceID: id) }
                                  },
                                  nudge: { session.nudgeSelectedCorner(direction: $0, larger: $1) },
                                  selectFace: { session.selectSurface(at: $0) },
                                  isLocked: surface.map { session.project.isGeometryLocked($0) } ?? session.selectedObject.map { !session.project.canMoveObject($0.id) } ?? false,
                                  objectID: session.selectedObjectID,
                                  objectBounds: session.selectedObjectID.flatMap { session.project.outputBounds(forObject: $0) },
                                  moveObject: { delta in if let id = session.selectedObjectID { session.moveObject(id,by: delta) } },
                                  nudgeObject: { session.nudgeSelectedObject(direction: $0,larger: $1) })
                        .frame(width: width + 24, height: height + 24)
                }
                Text("\(output.selectedName) · \(output.renderSizeText) · Editor preview").font(.caption).foregroundStyle(.secondary)
                    .lineLimit(2).multilineTextAlignment(.center)
                    .frame(maxWidth: max(0, availableWidth))
                    .help("\(output.selectedName) · \(output.renderSizeText)")
                // Reserve warning space so validation changes cannot move the canvas during a drag.
                Group {
                    if session.scene.invalidCount > 0 || !session.project.joinWarnings.isEmpty {
                        Label("Check invalid shapes or input joins in the inspector", systemImage: "exclamationmark.triangle")
                            .font(.caption).foregroundStyle(.orange).multilineTextAlignment(.center)
                    } else {
                        Color.clear.accessibilityHidden(true)
                    }
                }
                .frame(width: max(0, availableWidth), height: 32)
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
        }
        .background(Color(red: 0.085, green: 0.09, blue: 0.105))
    }
}
