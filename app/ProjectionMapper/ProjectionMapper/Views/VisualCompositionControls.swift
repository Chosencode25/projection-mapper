import SwiftUI

struct VisualCompositionControls<SourceControls: View>: View {
    let session: EditorSession
    let ownerID: UUID
    var face: MappingSurface?
    @ViewBuilder let sourceControls: () -> SourceControls

    private var layers: [VisualLayer] { session.project.layers.filter { $0.ownerID == ownerID } }
    private var regions: [FaceRegion] { session.project.regions.filter { $0.faceID == face?.id } }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let region = regions.first(where: { $0.id == session.selectedVisualID }), let face {
                RegionControls(session: session, region: region, face: face)
                VisualTrackControls(session: session, track: region.track, sourceControls: sourceControls).id(region.id)
            } else if let layer = layers.first(where: { $0.id == session.selectedVisualID }) {
                VisualTrackControls(session: session, track: layer.track, sourceControls: sourceControls).id(layer.id)
            }
            HStack {
                Button("Add Layer", systemImage: "plus") { session.addLayer(ownerID: ownerID) }
                    .disabled(layers.count >= MappingProject.maximumLayersPerOwner)
                if let face {
                    Button("Add Region", systemImage: "plus") { session.addRegion(faceID: face.id) }
                        .disabled(regions.count >= MappingProject.maximumRegionsPerFace)
                }
            }.controlSize(.small)
        }
    }


}

private struct VisualTrackControls<SourceControls: View>: View {
    let session: EditorSession
    let track: VisualTrack
    @ViewBuilder let sourceControls: () -> SourceControls
    @State private var name = ""
    @FocusState private var naming: Bool
    @State private var mouth = MouthShape.open
    @State private var snapMouth = true

    private var clips: [EffectClip] { session.project.timelineClips.filter { $0.sourceID == track.id } }

    private func bind<Value>(_ keyPath: WritableKeyPath<VisualTrack, Value>) -> Binding<Value> {
        Binding(get: { track[keyPath: keyPath] }, set: { value in
            session.updateVisual(track.id) { $0[keyPath: keyPath] = value }
        })
    }

    var body: some View {
        Divider()
        TextField("Name", text: $name)
            .textFieldStyle(.roundedBorder)
            .onAppear { name = track.name }
            .focused($naming)
            .onSubmit { session.renameVisual(track.id, name); naming = false }
            .onChange(of: naming) { _, focused in if !focused { session.renameVisual(track.id, name) } }
            .onExitCommand { name = track.name; naming = false }
        Picker("Source", selection: bind(\.kind)) {
            ForEach(VisualSourceKind.allCases) { Text($0.title).tag($0) }
        }
        Picker("Blend", selection: bind(\.blend)) {
            ForEach(VisualBlendMode.allCases) { Text($0.title).tag($0) }
        }
        Slider(value: bind(\.opacity), in: 0...1, onEditingChanged: session.continuousEditing) {
            Text("Opacity")
        }
        DisclosureGroup("Placement") {
            coordinate("Center X", keyPath: \.center.x)
            coordinate("Center Y", keyPath: \.center.y)
            coordinate("Width", keyPath: \.size.x)
            coordinate("Height", keyPath: \.size.y)
            coordinate("Rotation", keyPath: \.rotation)
        }
        switch track.kind {
        case .media: mediaControls
        case .text: textControls
        case .singingFace: mouthControls
        }
        Button("Add clip at playhead", systemImage: "plus.rectangle") {
            let time = session.transport.elapsed(at: ProcessInfo.processInfo.systemUptime)
            let available = (session.project.song?.duration ?? 3600) - time
            session.addTimelineClip(sourceID: track.id, at: time, duration: min(5, max(0.1, available)))
        }
        if track.kind == .text && clips.isEmpty {
            Text("Add a clip to show this text during playback.").font(.caption).foregroundStyle(.secondary)
        }
    }

    private func coordinate(_ title: String, keyPath: WritableKeyPath<VisualTrack, Float>) -> some View {
        LabeledContent(title) {
            TextField(title, value: bind(keyPath), format: .number.precision(.fractionLength(0...3)))
                .labelsHidden().textFieldStyle(.roundedBorder).frame(width: 70)
        }
    }

    private var mediaControls: some View { sourceControls() }

    private func color(_ keyPath: WritableKeyPath<VisualTrack, SIMD4<Float>>) -> Binding<Color> {
        Binding(get: {
            let rgba = track[keyPath: keyPath]
            return Color(.sRGB, red: Double(rgba.x), green: Double(rgba.y), blue: Double(rgba.z), opacity: Double(rgba.w))
        }, set: { value in
            if let rgba = NSColor(value).usingColorSpace(.sRGB) {
                session.updateVisual(track.id) {
                    $0[keyPath: keyPath] = SIMD4(Float(rgba.redComponent), Float(rgba.greenComponent),
                                                 Float(rgba.blueComponent), Float(rgba.alphaComponent))
                }
            }
        })
    }

    private var textControls: some View {
        Group {
            Picker("Text type", selection: bind(\.text.mode)) {
                ForEach(ProjectionText.Mode.allCases) { Text($0.title).tag($0) }
            }
            switch track.text.mode {
            case .greeting:
                TextField("Projected text", text: bind(\.text.message), axis: .vertical).lineLimit(2...4)
            case .songTitle:
                LabeledContent("Song", value: session.project.song?.name ?? "Choose a soundtrack")
            case .countdown:
                Picker("Count down to", selection: bind(\.text.markerID)) {
                    Text("Time").tag(nil as UUID?)
                    ForEach(session.project.showMarkers.sorted { $0.time < $1.time }) { marker in
                        Text(marker.name).tag(Optional(marker.id))
                    }
                }
                if track.text.markerID == nil {
                    TextField("Target seconds", value: bind(\.text.countdownEnd), format: .number)
                }
            }
            TextField("Font name (optional)", text: bind(\.text.font))
            Slider(value: bind(\.text.size), in: 0.02...0.8, onEditingChanged: session.continuousEditing) { Text("Text size") }
            Picker("Alignment", selection: bind(\.text.alignment)) {
                ForEach(ProjectionText.Alignment.allCases) { Text($0.rawValue.capitalized).tag($0) }
            }
            ColorPicker("Text color", selection: color(\.text.color))
        }
    }

    private var mouthControls: some View {
        Group {
            Picker("Mouth shape", selection: $mouth) {
                ForEach(MouthShape.allCases) { Text($0.title).tag($0) }
            }
            Toggle("Snap to nearby marker", isOn: $snapMouth)
            Button("Key mouth at playhead", systemImage: "diamond") {
                let playhead = session.transport.elapsed(at: ProcessInfo.processInfo.systemUptime)
                let marker = session.project.showMarkers.min { abs($0.time - playhead) < abs($1.time - playhead) }
                let nearby = marker.flatMap { abs($0.time - playhead) <= 0.15 ? $0.time : nil }
                let time = snapMouth ? (nearby ?? playhead) : playhead
                session.setMouthShape(mouth, on: track.id, at: time)
            }
        }
    }
}

private struct RegionControls: View {
    let session: EditorSession
    let region: FaceRegion
    let face: MappingSurface

    var body: some View {
        Toggle("Outline only", isOn: Binding(get: { region.outline != nil }, set: { value in
            session.updateRegion(region.id) { $0.outline = value ? 0.03 : nil }
        }))
        if let thickness = region.outline {
            Slider(value: Binding(get: { thickness }, set: { value in session.updateRegion(region.id) { $0.outline = value } }),
                   in: 0.005...0.25, onEditingChanged: session.continuousEditing) {
                Text("Thickness")
            }
        }
        Menu("Region shape") {
            Button("Full face rectangle") { session.setRegionPoints(region.id, points: MaskPolygon.rectangle.points) }
            if let mask = face.mask {
                Button("Copy face mask boundary") { session.setRegionPoints(region.id, points: mask.boundary.points) }
            }
            ForEach(session.project.regionShapes) { preset in
                Button("Use " + preset.name) { session.setRegionPoints(region.id, points: preset.shape.points) }
            }
            Divider()
            Button("Save current shape") { session.saveRegionShape(region.id) }
                .disabled(session.project.regionShapes.count >= 64)
            if !session.project.regionShapes.isEmpty {
                Menu("Delete saved shape") {
                    ForEach(session.project.regionShapes) { preset in
                        Button(preset.name, role: .destructive) { session.deleteRegionShape(preset.id) }
                    }
                }
            }
        }
        Menu("Move to face") {
            ForEach(session.project.surfaces.filter { $0.id != face.id }) { target in
                Button(target.name) { session.reassignRegion(region.id, to: target.id) }
                    .disabled(session.project.regions.filter { $0.faceID == target.id }.count >= MappingProject.maximumRegionsPerFace)
            }
        }.disabled(session.project.surfaces.count < 2)
        Toggle("Edit region on canvas", isOn: Binding(get: { session.isRegionEditing }, set: { editing in
            session.isRegionEditing = editing
            session.isMaskEditing = false
            session.cancelMaskDrawing()
            if !editing { session.regionDraft = nil }
        }))
        if session.isRegionEditing {
            if let draft = session.regionDraft {
                Text("Click the face to add points, then finish the polygon.").font(.caption)
                HStack {
                    Button("Finish") {
                        if FaceMask(boundary: MaskPolygon(points: draft)).validationMessage == nil {
                            session.regionDraft = nil
                        }
                        session.setRegionPoints(region.id, points: draft)
                    }.disabled(draft.count < 3)
                    Button("Back") { session.regionDraft?.removeLast() }.disabled(draft.isEmpty)
                    Button("Cancel") { session.regionDraft = nil }
                }
            } else {
                Button("Draw polygon") { session.regionDraft = [] }
            }
        }
    }
}

struct RegionCanvas: View {
    let session: EditorSession
    let face: MappingSurface
    let region: FaceRegion
    var interactive: Bool

    var body: some View {
        GeometryReader { geometry in
            let size = geometry.size
            let vertices = session.regionDraft ?? region.shape.points
            let points = vertices.map { point in
                MaskEditorGeometry.project(point, corners: face.corners).map {
                    CGPoint(x: CGFloat($0.x) * size.width, y: CGFloat($0.y) * size.height)
                }
            }
            ZStack {
                if interactive, session.regionDraft != nil {
                    Color.clear.contentShape(Rectangle()).onTapGesture { position in
                        if let point = local(position, size: size), (0...1).contains(point.x), (0...1).contains(point.y),
                           (session.regionDraft?.count ?? 0) < FaceMask.maxPoints {
                            session.regionDraft?.append(point)
                        }
                    }
                }
                Path { path in
                    guard let first = points.first ?? nil else { return }
                    path.move(to: first)
                    for point in points.dropFirst().compactMap({ $0 }) { path.addLine(to: point) }
                    if session.regionDraft == nil { path.closeSubpath() }
                }.stroke(.mint, style: StrokeStyle(lineWidth: 2, dash: [4, 3])).allowsHitTesting(false)
                if interactive, session.regionDraft == nil {
                    ForEach(points.indices, id: \.self) { index in
                        if let point = points[index] {
                            Circle().fill(.mint).overlay(Circle().stroke(.black)).frame(width: 12, height: 12)
                                .position(point)
                                .gesture(DragGesture(minimumDistance: 0, coordinateSpace: .named(region.id))
                                    .onChanged { drag in
                                        guard let next = local(drag.location, size: size) else { return }
                                        session.beginContinuousEdit("Move Region Point")
                                        var vertices = region.shape.points
                                        vertices[index] = SIMD2(min(1, max(0, next.x)), min(1, max(0, next.y)))
                                        if FaceMask(boundary: MaskPolygon(points: vertices)).validationMessage == nil {
                                            session.setRegionPoints(region.id, points: vertices)
                                        }
                                    }.onEnded { _ in session.endContinuousEdit() })
                                .accessibilityLabel("Region point \(index + 1)")
                        }
                    }
                }
            }.coordinateSpace(name: region.id)
        }
    }

    private func local(_ position: CGPoint, size: CGSize) -> SIMD2<Float>? {
        guard size.width > 0, size.height > 0 else { return nil }
        return MaskEditorGeometry.unproject(
            SIMD2(Float(position.x / size.width), Float(position.y / size.height)), corners: face.corners)
    }
}
