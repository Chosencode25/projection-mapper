import SwiftUI

struct EditorCanvasView: View {
    let session: EditorSession
    @State private var pendingDrop: URL?
    @State private var dropFaceID: UUID?
    @State private var dropOwnerID: UUID?
    var output: OutputSelectionState { session.output }
    var body: some View {
        GeometryReader { geometry in
            let availableWidth = max(0, geometry.size.width - 56)
            let availableHeight = max(0, geometry.size.height - 100)
            let ratio = output.aspectRatio
            let width = min(availableWidth, availableHeight * ratio)
            let height = width / ratio
            VStack(spacing: 16) {
                ZStack {
                    Color.black
                    ReferencePhotoLayer(session: session)
                    MetalScenePreview(scene: session.editorScene, aspectRatio: ratio, outputDescription: output.renderSizeText)
                }
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .overlay {
                        RoundedRectangle(cornerRadius: 8)
                            .strokeBorder(Color.white.opacity(0.13), lineWidth: 1)
                    }
                .frame(width: width, height: height)
                .overlay {
                    let surface = session.selectedSurface
                    if session.isMaskEditing, session.editorDisplay.maskHandles, let face = surface, face.mask != nil {
                        MaskCanvas(session: session,face: face,projected: true)
                            .frame(width: width,height: height).id(face.id)
                    } else {
                    CornerOverlay(surfaceID: surface?.id, corners: surface?.corners ?? .diagnostic,
                                  activeCorner: session.selectedCorner,
                                  select: { session.selectCorner($0) },
                                  move: { point in
                                      if let id = surface?.id { session.moveSelectedCorner(to: point, surfaceID: id) }
                                  },
                                  nudge: { session.nudgeSelectedCorner(direction: $0, larger: $1) },
                                  beginEdit: { session.beginContinuousEdit("Move Mapping") },
                                  endEdit: { session.endContinuousEdit() },
                                  selectFace: { session.selectSurface(at: $0) },
                                  isLocked: surface.map { session.project.isGeometryLocked($0) } ?? session.selectedObject.map { !session.project.canMoveObject($0.id) } ?? false,
                                  showsHandles: session.editorDisplay.cornerHandles,
                                  showsOutlines: session.editorDisplay.outlines,
                                  objectID: session.selectedObjectID,
                                  objectBounds: session.selectedObjectID.flatMap { session.project.outputBounds(forObject: $0) },
                                  moveObject: { delta in if let id = session.selectedObjectID { session.moveObject(id,by: delta) } },
                                  nudgeObject: { session.nudgeSelectedObject(direction: $0,larger: $1) })
                        .frame(width: width + 24, height: height + 24)
                    }
                }
                .overlay {
                    ZStack {
                        if session.isMaskEditing, !session.editorDisplay.maskHandles, session.editorDisplay.outlines, let face = session.selectedSurface, face.mask != nil {
                            MaskCanvas(session: session,face: face,projected: true).allowsHitTesting(false)
                        }
                        EditorLabelsOverlay(session: session)
                    }.frame(width: width,height: height).allowsHitTesting(false)
                }
                .dropDestination(for: URL.self) { urls, location in
                    guard urls.count == 1, let url = urls.first else { session.editMessage = "Drop one PNG, JPEG, MP4 or MOV at a time."; return false }
                    let fallback = session.selectedImageTarget
                    session.selectSurface(at: SIMD2(Float(location.x/max(1,width)),Float(location.y/max(1,height))))
                    if let face = session.selectedSurface, let object = session.project.object(for: face) {
                        pendingDrop = url; dropFaceID = face.id; dropOwnerID = object.source.id
                    } else {
                        let target = session.selectedImageTarget ?? fallback ?? .newFace
                        Task { await session.importMedia(from: url,target: target) }
                    }
                    return true
                }
                Text("\(output.selectedName) · \(output.renderSizeText) · Editor preview").font(.caption).foregroundStyle(.secondary)
                    .lineLimit(2).multilineTextAlignment(.center)
                    .frame(maxWidth: max(0, availableWidth))
                    .help("\(output.selectedName) · \(output.renderSizeText)")
                // Reserve warning space so validation changes cannot move the canvas during a drag.
                Group {
                    if session.scene.invalidCount > 0 || !session.project.joinWarnings.isEmpty || !session.imageProblems.isEmpty {
                        Label("Check shapes, masks, joins or missing images in the inspector", systemImage: "exclamationmark.triangle")
                            .font(.caption).foregroundStyle(.orange).multilineTextAlignment(.center)
                    } else {
                        Color.clear.accessibilityHidden(true)
                    }
                }
                .frame(width: max(0, availableWidth), height: 32)
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
        }
        .confirmationDialog("Import media for the shared object or just this face?",isPresented: Binding(get: { pendingDrop != nil },set: { if !$0 { pendingDrop = nil } }),titleVisibility: .visible) {
            if let url = pendingDrop, let owner = dropOwnerID, let face = dropFaceID {
                Button("Replace content on all object faces") { pendingDrop = nil; Task { await session.importMedia(from: url,target: .owner(owner)) } }
                Button("Detach and import on this face") {
                    pendingDrop = nil
                    guard let current = session.project.surfaces.first(where: { $0.id == face }), session.project.source(for: current).id == owner else {
                        session.editMessage = "The dropped-on face changed. Drop the media again."; return
                    }
                    Task { await session.importMedia(from: url,target: .detach(face)) }
                }
                Button("Cancel",role: .cancel) { pendingDrop = nil }
            }
        }
        .background(Color(red: 0.085, green: 0.09, blue: 0.105))
    }
}
