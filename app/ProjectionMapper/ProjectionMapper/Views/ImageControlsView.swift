import SwiftUI

struct ImageContentControls: View {
    let session: EditorSession
    var body: some View {
        VStack(alignment: .leading,spacing: 8) {
            if let source = session.selectedSource {
                let object = session.selectedObject ?? session.selectedSurface.flatMap { session.project.object(for: $0) }
                Button(object.map { "Import image for \($0.name)…" } ?? "Import image…") {
                    session.chooseImage(target: .owner(source.id))
                }.disabled(session.isImportingImage)
                if let face = session.selectedSurface, object != nil {
                    Text("Importing for this object replaces content on all of its faces.").font(.caption).foregroundStyle(.secondary)
                    Button("Detach and import on this face…") { session.chooseImage(target: .detach(face.id)) }.disabled(session.isImportingImage)
                }
                if source.content == .image, let image = source.image {
                    Text(session.selectedImageName ?? "Image").font(.caption).lineLimit(2)
                    if let problem = session.imageProblems[image.assetID] {
                        Text(problem).font(.caption).foregroundStyle(.orange)
                    }
                    Picker("Placement",selection: Binding(get: { image.placement },set: { session.setImagePlacement($0) })) {
                        ForEach(ImagePlacement.allCases) { Text($0.title).tag($0) }
                    }
                    HStack {
                        Text("Canvas aspect")
                        TextField("Width / height",value: Binding(get: { Double(image.canvasAspect) },set: { session.setImageCanvasAspect(Float($0)) }),format: .number.precision(.fractionLength(0...3)))
                            .textFieldStyle(.roundedBorder).accessibilityLabel("Image canvas aspect ratio")
                    }.font(.caption)
                    Text("Fit shows the whole image; Fill crops to cover; Stretch fills without keeping proportions.").font(.caption).foregroundStyle(.secondary)
                    HStack {
                        Button("Relink image…") { session.chooseImage(target: .relink(image.assetID)) }.disabled(session.isImportingImage)
                        Button("Remove image") { session.removeSelectedImage() }
                    }
                    Text("Relinking updates every reference to this asset. Replace by importing a new image for this owner.").font(.caption).foregroundStyle(.secondary)
                }
                if session.isImportingImage { ProgressView("Preparing image…").controlSize(.small) }
            }
        }
    }
}

struct ReferencePhotoControls: View {
    @Bindable var session: EditorSession
    private func edit(_ change: (inout ReferencePhoto) -> Void) {
        guard var photo = session.project.referencePhoto else { return }; change(&photo); session.setReferencePhoto(photo)
    }
    var body: some View {
        VStack(alignment: .leading,spacing: 10) {
            Button(session.project.referencePhoto == nil ? "Import reference photo…" : "Replace reference photo…") { session.chooseImage(target: .reference) }
                .disabled(session.isImportingImage)
            Text("House or display photo, visible only in the editor. It never appears in Test Output.").font(.caption).foregroundStyle(.secondary)
            if let photo = session.project.referencePhoto {
                Toggle("Show reference photo",isOn: $session.referencePhotoVisible)
                Toggle("Lock photo alignment",isOn: Binding(get: { photo.isLocked },set: { value in edit { $0.isLocked = value } }))
                VStack(alignment: .leading,spacing: 8) {
                    Picker("Photo placement",selection: Binding(get: { photo.placement },set: { value in edit { $0.placement = value } })) {
                        ForEach(ImagePlacement.allCases) { Text($0.title).tag($0) }
                    }
                    HStack {
                        TextField("Center X",value: Binding(get: { Double(photo.center.x) },set: { value in edit { $0.center.x = Float(value) } }),format: .number).accessibilityLabel("Reference photo center X")
                        TextField("Center Y",value: Binding(get: { Double(photo.center.y) },set: { value in edit { $0.center.y = Float(value) } }),format: .number).accessibilityLabel("Reference photo center Y")
                    }.textFieldStyle(.roundedBorder)
                    Text("Photo scale")
                    Slider(value: Binding(get: { Double(photo.scale) },set: { value in edit { $0.scale = Float(value) } }),in: 0.1...4, onEditingChanged: session.continuousEditing).accessibilityLabel("Reference photo scale")
                    Button("Reset alignment") { edit { $0.center = SIMD2(0.5,0.5); $0.scale = 1; $0.placement = .fit } }
                }.disabled(photo.isLocked)
                Text("Photo opacity")
                Slider(value: Binding(get: { Double(photo.opacity) },set: { value in edit { $0.opacity = Float(value) } }),in: 0...1, onEditingChanged: session.continuousEditing).accessibilityLabel("Reference photo opacity")
                if let problem = session.imageProblems[photo.assetID] { Text(problem).font(.caption).foregroundStyle(.orange) }
                Button("Relink reference photo…") { session.chooseImage(target: .relink(photo.assetID)) }.disabled(session.isImportingImage)
                Button("Remove reference photo") { session.setReferencePhoto(nil) }
            }
        }
    }
}

struct ReferencePhotoLayer: View {
    let session: EditorSession
    var body: some View {
        GeometryReader { geometry in
            if session.referencePhotoVisible, let photo = session.project.referencePhoto,
               let pixels = session.imagePixels[photo.assetID], let image = pixels.cgImage {
                let scale = photo.placement.scale(imageAspect: Float(pixels.width)/Float(pixels.height),canvasAspect: Float(geometry.size.width/max(1,geometry.size.height)))
                Image(decorative: image,scale: 1).resizable()
                    .frame(width: geometry.size.width/Double(scale.x)*Double(photo.scale),height: geometry.size.height/Double(scale.y)*Double(photo.scale))
                    .position(x: geometry.size.width*Double(photo.center.x),y: geometry.size.height*Double(photo.center.y))
                    .opacity(Double(photo.opacity))
            }
        }.clipped().allowsHitTesting(false).accessibilityHidden(true)
    }
}
