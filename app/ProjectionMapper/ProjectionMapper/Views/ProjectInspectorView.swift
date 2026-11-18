import SwiftUI

struct ProjectInspectorView: View {
    @Bindable var session: EditorSession
    let refreshDisplays: () -> Void
    let openOutput: () -> Void
    private var inspectorIdentity: String {
        let selection: UUID?
        if let id = session.selectedLightingCueID { selection = id }
        else if let id = session.selectedClipID { selection = id }
        else if let id = session.selectedMouthKeyID { selection = id }
        else if let id = session.selectedVisualID { selection = id }
        else if let id = session.selectedObjectID { selection = id }
        else { selection = session.selectedSurfaceID }
        return String(describing: session.inspectorTab) + ":" + (selection?.uuidString ?? "none")
    }
    var body: some View {
        VStack(spacing: 0) {
            Picker("Inspector section", selection: $session.inspectorTab) {
                Text("Selection").tag(InspectorTab.edit)
                Text("Output").tag(InspectorTab.show)
                Text("Project").tag(InspectorTab.project)
            }.pickerStyle(.segmented).labelsHidden().accessibilityLabel("Inspector section").padding(12)
            Divider()
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if let message = session.editMessage {
                        Text(message).font(.caption).foregroundStyle(.orange).fixedSize(horizontal: false, vertical: true)
                    }
                    switch session.inspectorTab {
                    case .edit:
                        if let cue = session.selectedLightingCue {
                            SelectedCueInspector(session: session, cue: cue)
                        } else if let clip = session.selectedClip {
                            SelectedClipInspector(session: session, clip: clip)
                        } else if let key = session.selectedMouthKey, let id = session.selectedVisualID {
                            SelectedMouthKeyInspector(session: session, trackID: id, key: key)
                        } else if let face = session.selectedSurface {
                            if session.selectedVisualID == nil { FaceInspector(session: session, face: face).id(face.id) }
                            VisualCompositionControls(session: session, ownerID: session.project.source(for: face).id, face: face) { SourceInspector(session: session) }.id(face.id)
                        } else if let object = session.selectedObject {
                            if session.selectedVisualID == nil { ObjectInspector(session: session, object: object).id(object.id) }
                            VisualCompositionControls(session: session, ownerID: object.source.id) { SourceInspector(session: session) }.id(object.id)
                        } else {
                            Label("Select a surface", systemImage: "cursorarrow.click").font(.headline)
                            Button("Add surface", systemImage: "plus") { session.addSurface() }
                        }
                    case .show:
                        PlaybackReadinessControls(session: session)
                        Divider()
                        PlaybackControls(session: session)
                        Divider()
                        VideoAudioControls(session: session)
                        Divider()
                        MasterOutputControls(session: session)
                        Divider()
                        InspectorSection("Calibration") { CalibrationControls(session: session) }
                        InspectorSection("Output destination & resolution") {
                            OutputDetailsView(session: session, refreshDisplays: refreshDisplays, openOutput: openOutput)
                        }
                    case .project:
                        Text("PROJECT").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                        NameEditor(name: session.project.name, title: "Project name", apply: { session.renameProject($0); session.finishNameEditing() }).id(session.project.id)
                        LabeledContent("Surfaces", value: "\(session.project.surfaces.count)")
                        LabeledContent("Objects", value: "\(session.project.objects.count)")
                        Divider()
                        InspectorSection("Reference photo") { ReferencePhotoControls(session: session) }
                        Divider()
                        LookLibraryControls(session: session).id(session.project.id)
                        Divider()
                        PaletteLibraryControls(session: session).id(session.project.id)
                    }
                }.font(.subheadline).padding(16).frame(maxWidth: .infinity, alignment: .leading)
            }.id(inspectorIdentity)
        }.frame(maxHeight: .infinity).background(Color(nsColor: .controlBackgroundColor).opacity(0.45))
    }
}

/// Keep infrequent controls reachable without making every task a long scroll.
private struct InspectorSection<Content: View>: View {
    let title: String
    @State private var expanded: Bool
    let content: Content
    init(_ title: String, expanded: Bool = false, @ViewBuilder content: () -> Content) {
        self.title = title
        _expanded = State(initialValue: expanded)
        self.content = content()
    }
    var body: some View {
        DisclosureGroup(title, isExpanded: $expanded) {
            VStack(alignment: .leading, spacing: 10) { content }
                .padding(.top, 10).frame(maxWidth: .infinity, alignment: .leading)
        }.padding(10).background(.quaternary.opacity(0.3), in: RoundedRectangle(cornerRadius: 8))
    }
}

struct SourceInspector: View {
    let session: EditorSession
    private var bindingFaceID: UUID? {
        if let face = session.selectedSurface { return face.id }
        guard let object = session.selectedObject else { return nil }
        return session.project.surfaces.first { $0.layout.objectID == object.id }?.id
    }
    var body: some View {
        if let selectedSource = session.selectedSource {
            let source = session.project.resolvedSource(selectedSource)
            Picker("Content", selection: Binding(get: { source.content }, set: { session.setSurfaceContent($0) })) {
                ForEach(SurfaceContent.allCases.filter { ($0 != .image || source.image != nil) && ($0 != .video || source.video != nil) }) { Text($0.title).tag($0) }
            }
            ImageContentControls(session: session)
            VideoContentControls(session: session)
            if source.content == .solid || (source.content.isProceduralAnimation && source.content != .video) {
                ColorPicker(source.content.isProceduralAnimation ? "Color 1" : "Fill color", selection: Binding(get: {
                    Color(.sRGB, red: Double(source.color.x), green: Double(source.color.y), blue: Double(source.color.z), opacity: 1)
                }, set: { color in
                    if let rgb = NSColor(color).usingColorSpace(.deviceRGB) {
                        session.setSourceColor(SIMD4(Float(rgb.redComponent),Float(rgb.greenComponent),Float(rgb.blueComponent),1))
                    }
                }), supportsOpacity: false)
                if let faceID = bindingFaceID {
                    SourcePaletteBindingControl(session: session, source: source, faceID: faceID, channel: .primary)
                }
            }
            if source.content.isProceduralAnimation && source.content != .video {
                ColorPicker("Color 2", selection: Binding(get: {
                    let rgb = source.generator.secondaryColor
                    return Color(.sRGB, red: Double(rgb.x), green: Double(rgb.y), blue: Double(rgb.z), opacity: 1)
                }, set: { color in
                    if let rgb = NSColor(color).usingColorSpace(.deviceRGB) {
                        session.setSecondaryColor(SIMD4(Float(rgb.redComponent),Float(rgb.greenComponent),Float(rgb.blueComponent),1))
                    }
                }), supportsOpacity: false)
                if let faceID = bindingFaceID {
                    SourcePaletteBindingControl(session: session, source: source, faceID: faceID, channel: .secondary)
                }
                GeneratorControls(session: session, source: source)
                if session.selectedClip == nil {
                    HStack {
                        Button(session.selectedPlayback.isPaused ? "Resume owner" : "Pause owner") {
                            session.setSelectedPaused(!session.selectedPlayback.isPaused)
                        }
                        Button("Restart owner") { session.restartSelectedPlayback() }
                    }.disabled(session.project.timelineClips.contains { $0.sourceID == source.id })
                }
            }
            InspectorSection("Effect presets") { GeneratorPresetControls(session: session).id(source.id) }
        }
    }
}

private struct GeneratorPresetControls: View {
    let session: EditorSession
    @State private var name = ""
    @State private var selectedID: UUID?
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Menu("Holiday Presets") {
                ForEach(SurfaceContent.holidayPresets) { content in
                    Button(content.title) { session.applyHolidayPreset(content) }
                }
            }
            Text("EFFECT PRESETS").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
            TextField("New preset name", text: $name).textFieldStyle(.roundedBorder)
            Button("Save new preset") {
                selectedID = session.saveGeneratorPreset(name: name)
            }.disabled(session.selectedSource?.content.isProceduralAnimation != true)
            Picker("Preset", selection: $selectedID) {
                Text("Choose preset").tag(Optional<UUID>.none)
                ForEach(session.project.generatorPresets) { preset in Text(preset.name).tag(Optional(preset.id)) }
            }
            HStack {
                Button("Apply") { if let id = selectedID { session.applyGeneratorPreset(id) } }.disabled(selectedID == nil)
                Button("Update") { if let id = selectedID { session.updateGeneratorPreset(id) } }
                    .disabled(selectedID == nil || session.selectedSource?.content.isProceduralAnimation != true)
                Button("Delete") { if let id = selectedID { session.deleteGeneratorPreset(id); selectedID = nil } }.disabled(selectedID == nil)
            }
            Button("Reset effect settings") { session.resetGeneratorSettings() }
                .disabled(session.selectedSource?.content.isProceduralAnimation != true)
        }
    }
}

private struct GeneratorControls: View {
    let session: EditorSession
    let source: SurfaceSource
    private func edit(_ change: (inout GeneratorSettings) -> Void) {
        var settings = source.generator; change(&settings); session.setGeneratorSettings(settings)
    }
    private func slider(_ title: String, value: Float, range: ClosedRange<Double>, set: @escaping (inout GeneratorSettings, Float) -> Void) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text("\(title) · \(Double(value).formatted(.number.precision(.fractionLength(2))))").font(.caption)
            Slider(value: Binding(get: { Double(value) }, set: { number in edit { set(&$0,Float(number)) } }), in: range, onEditingChanged: session.continuousEditing)
                .accessibilityLabel(title)
        }
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            slider("Effect speed", value: source.generator.rate, range: 0.25...4) { $0.rate = $1 }
            if source.content != .particles {
                slider(source.content == .movingLines ? "Line spacing / scale" : "Scale", value: source.generator.scale, range: 0.5...4) { $0.scale = $1 }
            }
            if source.content != .noise {
                Picker("Direction", selection: Binding(get: { source.generator.direction }, set: { value in edit { $0.direction = value } })) {
                    ForEach(0..<8) { value in Text("\(value * 45)°").tag(value) }
                }
            }
            if source.content == .noise || source.content == .plasma || SurfaceContent.holidayPresets.contains(source.content) {
                slider("Contrast", value: source.generator.intensity, range: 0.1...1) { $0.intensity = $1 }
            }
            if source.content == .particles || SurfaceContent.holidayPresets.contains(source.content) {
                Stepper("Particles · \(source.generator.density * source.generator.density)", value: Binding(get: { source.generator.density }, set: { value in edit { $0.density = value } }), in: 4...16)
                slider("Particle size", value: source.generator.particleSize, range: 0.04...0.35) { $0.particleSize = $1 }
            }
            if source.content == .noise || source.content == .particles || SurfaceContent.holidayPresets.contains(source.content) {
                Stepper("Seed · \(source.generator.seed)", value: Binding(get: { Int(source.generator.seed) }, set: { value in edit { $0.seed = UInt32(value) } }), in: 0...999999)
            }
        }
    }
}

private struct PlaybackControls: View {
    let session: EditorSession
    @State private var seekSeconds: Double = 0
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("PLAYBACK · ALL ANIMATED FACES").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
            HStack {
                Button(session.transport.isPlaying ? "Pause" : "Play", systemImage: session.transport.isPlaying ? "pause.fill" : "play.fill") {
                    session.setPlaying(!session.transport.isPlaying)
                }
                Button("Restart", systemImage: "backward.end.fill") { session.restartPlayback() }
            }
            Picker("Speed", selection: Binding(get: { session.transport.speed }, set: { session.setPlaybackSpeed($0) })) {
                ForEach([0.25, 0.5, 1.0, 2.0, 4.0], id: \.self) { speed in Text("\(speed.formatted())×").tag(speed) }
            }
            TimelineView(.animation(minimumInterval: 0.2, paused: !session.transport.isPlaying)) { _ in
                Text("Time · \(session.transport.elapsed(at: ProcessInfo.processInfo.systemUptime).formatted(.number.precision(.fractionLength(2)))) s")
                    .font(.caption).monospacedDigit()
            }
            HStack {
                TextField("Seek seconds", value: $seekSeconds, format: .number.precision(.fractionLength(0...2)))
                    .textFieldStyle(.roundedBorder).accessibilityLabel("Seek seconds")
                    .onSubmit { session.seekPlayback(to: seekSeconds) }
                Button("Seek") { session.seekPlayback(to: seekSeconds) }
                    .disabled(!seekSeconds.isFinite || !(0...3600).contains(seekSeconds))
            }
            Slider(value: Binding(get: { min(60,max(0,seekSeconds)) }, set: { value in seekSeconds = value; session.seekPlayback(to: value) }), in: 0...60)
                .accessibilityLabel("Scrub first 60 seconds")
            Text(session.transport.isPlaying ? "Playing · all animations share one clock" : "Paused · choose an animated content type, then Play")
                .font(.caption).foregroundStyle(.secondary)
        }
    }
}

private struct FaceInspector: View {
    let session: EditorSession
    let face: MappingSurface
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("SURFACE").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
            NameEditor(name: face.name, title: "Surface name", apply: { session.renameSurface(face.id, $0) }).id(face.id)
            Toggle("Visible", isOn: Binding(get: { face.layout.isVisible }, set: { session.setVisible($0, faceID: face.id) }))
            Toggle("Lock output corners",isOn: Binding(get: { face.layout.isGeometryLocked },set: { session.setGeometryLocked($0,faceID: face.id) }))
            if session.project.object(for: face)?.isGeometryLocked == true {
                Text("Corners locked by this object. Unlock the object to edit them.").font(.caption).foregroundStyle(.orange)
            }
            if PerspectiveTransform(face.corners) == nil {
                Text("Invalid output shape. Expand Output corners or drag a corner to restore it.").font(.caption).foregroundStyle(.orange)
            }
            Menu("Surface actions") {
                Button("Duplicate") { session.duplicateSurface(face.id) }
                Button("Bring forward") { session.moveSurface(face.id, offset: -1) }.disabled(session.project.surfaces.first?.id == face.id)
                Button("Send backward") { session.moveSurface(face.id, offset: 1) }.disabled(session.project.surfaces.last?.id == face.id)
                Button("Delete", role: .destructive) { session.deleteSurface(face.id) }.disabled(session.project.isGeometryLocked(face))
            }
            if let object = session.project.object(for: face) {
                VStack(alignment: .leading, spacing: 5) {
                    Label("Shared with " + object.name, systemImage: "cube.fill").font(.caption.weight(.medium))
                    Button("Edit shared object") { session.selectObject(object.id) }.buttonStyle(.borderless).font(.caption)
                }.padding(10).frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.accentColor.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
            }
            InspectorSection("Content", expanded: true) { SourceInspector(session: session) }
            InspectorSection("Object membership & tags") {
                TagsEditor(tags: face.tags, apply: { session.setTags($0, faceID: face.id) }).id(face.id)
                if let object = session.project.object(for: face) {
                    Button("Inspect object") { session.selectObject(object.id) }
                    Button("Detach to independent content") { session.detachSurface(face.id) }
                }
                Menu(face.layout.objectID == nil ? "Attach to object" : "Move to object") {
                    ForEach(session.project.objects) { object in
                        Button(object.name) { session.attachSurface(face.id, to: object.id) }
                    }
                }.disabled(session.project.objects.isEmpty)
            }
            InspectorSection("Appearance") {
                if let object = session.project.object(for: face) {
                    Toggle("Override object appearance on this face",isOn: Binding(get: { face.appearanceOverride != nil },set: { session.setAppearanceOverride($0,faceID: face.id) }))
                    Text(face.appearanceOverride == nil ? "Inherited from \(object.name). Inspect the object to change all faces." : "Face override · crop, flips or appearance may break continuity at joined edges.")
                        .font(.caption).foregroundStyle(face.appearanceOverride == nil ? Color.secondary : Color.orange)
                }
                AppearanceEditor(session: session,value: session.project.appearance(for: face),scope: face.layout.objectID == nil ? "Face appearance" : "Face appearance override",apply: { session.setAppearance($0,faceID: face.id) })
                    .disabled(face.layout.objectID != nil && face.appearanceOverride == nil)
            }
            InspectorSection("Input mapping") { InputMapEditor(session: session, face: face) }
            InspectorSection("Masks", expanded: face.mask != nil) { MaskControls(session: session,face: face).id(face.id) }
            InspectorSection("Output corners") {
                Picker("Edit corner", selection: Binding<SurfaceCorner?>(get: { session.selectedCorner }, set: { session.selectCorner($0) })) {
                    Text("None").tag(Optional<SurfaceCorner>.none)
                    ForEach(SurfaceCorner.allCases) { Text($0.title).tag(Optional($0)) }
                }
                .disabled(session.project.isGeometryLocked(face))

                if !session.editorDisplay.cornerHandles {
                    Text("Corner handles are hidden. Restore them from Editor Guides in the toolbar or View menu.").font(.caption).foregroundStyle(.secondary)
                }
                Text(session.project.isGeometryLocked(face) ? "Output geometry is locked; select or unlock this face." : "Drag handles or use arrows; Shift nudges 1%.").font(.caption).foregroundStyle(.secondary)
                if PerspectiveTransform(face.corners) == nil {
                    Text("Invalid output shape. Move a corner to restore this face.").font(.caption).foregroundStyle(.orange)
                }
                ForEach(SurfaceCorner.allCases) { corner in
                    LabeledContent(corner.title, value: String(format: "%.3f, %.3f", face.corners[corner].x, face.corners[corner].y))
                        .font(.caption).monospacedDigit()
                }
            }
            FaceResetControls(session: session,face: face).id(face.id)
        }
    }
}

private struct InputMapEditor: View {
    let session: EditorSession
    let face: MappingSurface
    @State private var invalidRegion = false
    private func change(_ edit: (inout FaceInputMap) -> Void) {
        var map = face.layout.inputMap; edit(&map); invalidRegion = !map.isValid
        if map.isValid { session.setInputMap(map, faceID: face.id) }
    }
    private func field(_ title: String, get: @escaping (FaceInputMap) -> Float, set: @escaping (inout FaceInputMap, Float) -> Void) -> some View {
        HStack {
            Text(title).font(.caption)
            TextField(title, value: Binding(get: { Double(get(face.layout.inputMap)) }, set: { value in change { set(&$0, Float(value)) } }), format: .number.precision(.fractionLength(0...4)))
                .textFieldStyle(.roundedBorder).accessibilityLabel("Input \(title)")
        }
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("INPUT · SHARED CANVAS REGION").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
            field("X", get: { $0.origin.x }, set: { $0.origin.x = $1 })
            field("Y", get: { $0.origin.y }, set: { $0.origin.y = $1 })
            field("Width", get: { $0.size.x }, set: { $0.size.x = $1 })
            field("Height", get: { $0.size.y }, set: { $0.size.y = $1 })
            Picker("Rotation", selection: Binding(get: { face.layout.inputMap.quarterTurns }, set: { turn in change { $0.quarterTurns = turn } })) {
                ForEach(0..<4) { Text("\($0 * 90)°").tag($0) }
            }
            Toggle("Mirror input", isOn: Binding(get: { face.layout.inputMap.mirrored }, set: { mirror in change { $0.mirrored = mirror } }))
            Button("Use whole canvas") { session.setInputMap(.full, faceID: face.id); invalidRegion = false }
            if invalidRegion { Text("Region must fit within 0–1 with positive size.").font(.caption).foregroundStyle(.orange) }
            if session.project.object(for: face)?.mode == .repeatContent {
                Text("Repeat mode uses the whole canvas; this region is retained for Continuous mode.").font(.caption).foregroundStyle(.secondary)
            }
            Text("Input edits never move output corners.").font(.caption).foregroundStyle(.secondary)
        }.id(face.id)
    }
}

private struct ObjectInspector: View {
    let session: EditorSession
    let object: MappingObject
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("OBJECT · SHARED CONTENT").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
            NameEditor(name: object.name, title: "Object name", apply: { session.renameObject(object.id, $0) }).id(object.id)
            InspectorSection("Content", expanded: true) { SourceInspector(session: session) }
            InspectorSection("Object geometry & tags") {
                TagsEditor(tags: object.tags, apply: { session.setTags($0, objectID: object.id) }).id(object.id)
                Toggle("Lock all member output geometry",isOn: Binding(get: { object.isGeometryLocked },set: { session.setGeometryLocked($0,objectID: object.id) }))
                ObjectMoveControls(session: session,objectID: object.id).id(object.id)
                ObjectResetControls(session: session,objectID: object.id).id(object.id)
                Toggle("Object visible", isOn: Binding(get: { object.isVisible }, set: { session.setVisible($0, objectID: object.id) }))
                Picker("Mapping", selection: Binding(get: { object.mode }, set: { session.setObjectMode($0, id: object.id) })) {
                    ForEach(ObjectContentMode.allCases) { Text($0.title).tag($0) }
                }
            }
            InspectorSection("Appearance") {
                AppearanceEditor(session: session,value: object.appearance,scope: "Object appearance · inherited by faces",apply: { session.setAppearance($0,objectID: object.id) })
            }
            InspectorSection("Members & object actions") {
                HStack {
                    Button("Duplicate object") { session.duplicateObject(object.id) }
                    Button("Ungroup") { session.ungroupObject(object.id) }
                }
                Button("Delete object and faces") { session.deleteObject(object.id) }.disabled(!session.project.canMoveObject(object.id))
                ForEach(session.project.surfaces.filter { $0.layout.objectID == object.id }) { face in
                    Button("Edit \(face.name)") { session.selectSurface(face.id) }
                }
            }
            InspectorSection("Edge joins & inspection") {
                JoinInspectionControls(session: session,object: object)
                EdgeLinkEditor(session: session, object: object).id(object.id)
            }
        }
    }
}

private struct EdgeLinkEditor: View {
    let session: EditorSession
    let object: MappingObject
    @State private var first: UUID?
    @State private var second: UUID?
    @State private var firstEdge: FaceEdge = .right
    @State private var secondEdge: FaceEdge = .left
    @State private var reversed = true
    @State private var seam = false
    private var faces: [MappingSurface] { session.project.surfaces.filter { $0.layout.objectID == object.id } }
    private func link(align: Bool) {
        guard let first, let second else { return }
        session.addLink(FaceEdgeLink(firstFace: first, firstEdge: firstEdge, secondFace: second, secondEdge: secondEdge, reversed: reversed, isSeam: seam), objectID: object.id, align: align)
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("EDGE JOINS").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
            ForEach(object.links) { edge in
                VStack(alignment: .leading, spacing: 4) {
                    Text("\(faces.first { $0.id == edge.firstFace }?.name ?? "Missing") \(edge.firstEdge.title) ↔ \(faces.first { $0.id == edge.secondFace }?.name ?? "Missing") \(edge.secondEdge.title)").font(.caption)
                    Text(session.project.joinMessage(edge, objectID: object.id) ?? "Aligned · matching input edges")
                        .font(.caption).foregroundStyle(edge.isSeam ? Color.secondary : session.project.joinMessage(edge, objectID: object.id) == nil ? Color.green : Color.orange)
                    Button("Remove join") { session.removeLink(edge.id, objectID: object.id) }.font(.caption)
                }
            }
            Picker("First face", selection: $first) {
                Text("Choose").tag(Optional<UUID>.none)
                ForEach(faces) { Text($0.name).tag(Optional($0.id)) }
            }
            Picker("First edge", selection: $firstEdge) { ForEach(FaceEdge.allCases) { Text($0.title).tag($0) } }
            Picker("Second face", selection: $second) {
                Text("Choose").tag(Optional<UUID>.none)
                ForEach(faces.filter { $0.id != first }) { Text($0.name).tag(Optional($0.id)) }
            }
            Picker("Second edge", selection: $secondEdge) { ForEach(FaceEdge.allCases) { Text($0.title).tag($0) } }
            Toggle("Reverse edge direction", isOn: $reversed)
            Toggle("Deliberate seam", isOn: $seam)
            Button("Link without moving input") { link(align: false) }.disabled(first == nil || second == nil || first == second)
            Button("Align second input and link") { link(align: true) }.disabled(first == nil || second == nil || first == second || seam)
        }
    }
}

private struct TagsEditor: View {
    let tags: [String]
    let apply: (String) -> Void
    @State private var draft = ""
    @FocusState private var focused: Bool
    var body: some View {
        TextField("Tags, comma separated", text: $draft)
            .accessibilityLabel("Tags, comma separated").focused($focused)
            .onAppear { draft = tags.joined(separator: ", ") }
            .onSubmit { apply(draft); focused = false }
            .onChange(of: focused) { _, value in if !value { apply(draft) } }
            .onChange(of: tags) { _, value in if !focused { draft = value.joined(separator: ", ") } }
    }
}

private struct NameEditor: View {
    let name: String
    let title: String
    let apply: (String) -> Void
    @State private var draft = ""
    @FocusState private var focused: Bool
    var body: some View {
        TextField(title, text: $draft).textFieldStyle(.roundedBorder)
            .accessibilityLabel(title).focused($focused)
            .onAppear { draft = name }
            .onSubmit { apply(draft); focused = false }
            .onChange(of: focused) { _, value in if !value { apply(draft) } }
            .onChange(of: name) { _, value in if !focused { draft = value } }
            .onExitCommand { draft = name; focused = false }
    }
}

private struct AppearanceEditor: View {
    let session: EditorSession
    let value: SurfaceAppearance
    let scope: String
    let apply: (SurfaceAppearance) -> Void
    @State private var invalidCrop = false
    private func change(_ edit: (inout SurfaceAppearance) -> Void) {
        var next = value; edit(&next); invalidCrop = !next.isValid
        if next.isValid { apply(next) }
    }
    private func cropField(_ title: String,get: @escaping (ContentCrop) -> Float,set: @escaping (inout ContentCrop,Float) -> Void) -> some View {
        HStack {
            Text(title).font(.caption)
            TextField(title,value: Binding(get: { Double(get(value.crop)) },set: { next in change { set(&$0.crop,Float(next)) } }),format: .number.precision(.fractionLength(0...4)))
                .textFieldStyle(.roundedBorder).accessibilityLabel(scope + " crop " + title)
        }
    }
    var body: some View {
        VStack(alignment: .leading,spacing: 8) {
            Text(scope.uppercased()).font(.caption.weight(.semibold)).foregroundStyle(.secondary)
            HStack { Text("Opacity"); Spacer(); Text(value.opacity.formatted(.percent.precision(.fractionLength(0)))).monospacedDigit() }.font(.caption)
            Slider(value: Binding(get: { Double(value.opacity) },set: { next in change { $0.opacity = Float(next) } }),in: 0...1, onEditingChanged: session.continuousEditing).accessibilityLabel(scope + " opacity")
            HStack { Text("Brightness"); Spacer(); Text(value.brightness.formatted(.percent.precision(.fractionLength(0)))).monospacedDigit() }.font(.caption)
            Slider(value: Binding(get: { Double(value.brightness) },set: { next in change { $0.brightness = Float(next) } }),in: 0...2, onEditingChanged: session.continuousEditing).accessibilityLabel(scope + " brightness")
            Toggle("Flip horizontally",isOn: Binding(get: { value.flipHorizontal },set: { next in change { $0.flipHorizontal = next } }))
            Toggle("Flip vertically",isOn: Binding(get: { value.flipVertical },set: { next in change { $0.flipVertical = next } }))
            Text("Crop · source coordinates 0–1").font(.caption).foregroundStyle(.secondary)
            cropField("X",get: { $0.origin.x },set: { $0.origin.x = $1 })
            cropField("Y",get: { $0.origin.y },set: { $0.origin.y = $1 })
            cropField("Width",get: { $0.size.x },set: { $0.size.x = $1 })
            cropField("Height",get: { $0.size.y },set: { $0.size.y = $1 })
            if invalidCrop { Text("Crop must have positive size and fit inside 0–1. Reduce its size before moving its origin.").font(.caption).foregroundStyle(.orange) }
        }
    }
}

private struct FaceResetControls: View {
    let session: EditorSession
    let face: MappingSurface
    @State private var confirmFull = false
    var body: some View {
        Menu("Reset this face…") {
            Button("Output corners only") { session.resetFace(face.id,scope: .outputGeometry) }.disabled(session.project.isGeometryLocked(face))
            Button("Opacity and brightness only") { session.resetFace(face.id,scope: .appearance) }.disabled(face.layout.objectID != nil && face.appearanceOverride == nil)
            Button("Crop and flips only") { session.resetFace(face.id,scope: .cropAndFlip) }.disabled(face.layout.objectID != nil && face.appearanceOverride == nil)
            Button("Generator settings and colors only") { session.resetFace(face.id,scope: .generatorParameters) }.disabled(face.layout.objectID != nil)
            Button("Content defaults only") { session.resetFace(face.id,scope: .content) }.disabled(face.layout.objectID != nil)
            Divider()
            Button("All face controls and output…") { confirmFull = true }.disabled(session.project.isGeometryLocked(face))
        }
        .confirmationDialog("Reset face controls and output?",isPresented: $confirmFull,titleVisibility: .visible) {
            Button("Reset face controls and output",role: .destructive) { session.resetFace(face.id,scope: .fullFace) }
        } message: {
            Text("Restores this face's output corners, visibility and appearance. Independent content returns to defaults; grouped faces return to object appearance. IDs, names/tags, masks, input regions, membership and links are kept. Shared object content is kept.")
        }
    }
}
private struct ObjectResetControls: View {
    let session: EditorSession
    let objectID: UUID
    @State private var confirmLayout = false
    var body: some View {
        Menu("Reset shared object controls…") {
            Button("Object opacity and brightness only") { session.resetObject(objectID,scope: .appearance) }
            Button("Object crop and flips only") { session.resetObject(objectID,scope: .cropAndFlip) }
            Button("Shared generator settings and colors only") { session.resetObject(objectID,scope: .generatorParameters) }
            Button("Shared content defaults only") { session.resetObject(objectID,scope: .content) }
            Divider()
            Button("Arrange input regions side by side…") { confirmLayout = true }
        }
        .confirmationDialog("Reset shared input layout?",isPresented: $confirmLayout,titleVisibility: .visible) {
            Button("Arrange input regions side by side",role: .destructive) { session.resetObject(objectID,scope: .inputLayout) }
        } message: {
            Text("Resets current member input regions and their orientation. Output corners, appearance, membership and all link identities/directions/seams stay intact. Custom links may show join warnings afterwards.")
        }
    }
}
private struct ObjectMoveControls: View {
    let session: EditorSession
    let objectID: UUID
    @State private var step = 0.01
    @State private var x = 0.0
    @State private var y = 0.0
    var body: some View {
        VStack(alignment: .leading,spacing: 8) {
            Text("MOVE ALL OUTPUT FACES").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
            VStack(spacing: 8) {
                Picker("Step",selection: $step) {
                    Text("0.1%").tag(0.001); Text("1%").tag(0.01); Text("5%").tag(0.05)
                }
                HStack {
                    Button("Left",systemImage: "arrow.left") { session.moveObject(objectID,by: SIMD2(Float(-step),0)) }
                    Button("Up",systemImage: "arrow.up") { session.moveObject(objectID,by: SIMD2(0,Float(-step))) }
                    Button("Down",systemImage: "arrow.down") { session.moveObject(objectID,by: SIMD2(0,Float(step))) }
                    Button("Right",systemImage: "arrow.right") { session.moveObject(objectID,by: SIMD2(Float(step),0)) }
                }.labelStyle(.iconOnly)
                HStack {
                    TextField("X offset",value: $x,format: .number).textFieldStyle(.roundedBorder).accessibilityLabel("Object X movement offset")
                    TextField("Y offset",value: $y,format: .number).textFieldStyle(.roundedBorder).accessibilityLabel("Object Y movement offset")
                }
                Button("Move by X / Y") { session.moveObject(objectID,by: SIMD2(Float(x),Float(y))) }
                    .disabled(!x.isFinite || !y.isFinite || !Float(x).isFinite || !Float(y).isFinite)
            }.disabled(!session.project.canMoveObject(objectID))
            Text(session.project.canMoveObject(objectID) ? "Click or drag the center square; arrows move the object and Shift moves 1%. Offsets are normalized 0–1 and stop at canvas edges." : "Unlock the object and every locked member face to move all faces together.").font(.caption).foregroundStyle(.secondary)
        }
    }
}

private struct SelectedClipInspector: View {
    let session: EditorSession
    let clip: EffectClip
    @State private var transition = false
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(session.project.timelineTracks.first { $0.id == clip.sourceID }?.name ?? "Clip").font(.headline)
            LabeledContent("Start (s)") {
                TextField("Start", value: Binding(get: { clip.start }, set: { value in
                    var next = clip; next.start = value; _ = session.updateTimelineClip(next)
                }), format: .number)
            }
            LabeledContent("Duration (s)") {
                TextField("Duration", value: Binding(get: { clip.duration }, set: { value in
                    _ = session.updateTimelineClip(clip.trimming(start: clip.start, duration: value))
                }), format: .number)
            }
            SourceInspector(session: session)
            Button("Transition…") { transition = true }
                .popover(isPresented: $transition) { ClipTransitionEditor(session: session, clip: clip) }
            if clip.source.content == .video {
                Button("Split at Playhead") { session.splitSelectedVideoClip(at: session.transport.elapsed(at: ProcessInfo.processInfo.systemUptime)) }
            }
            if let message = session.timelineMessage { Text(message).font(.caption).foregroundStyle(.orange) }
            HStack {
                Button("Capture Base Content") {
                    if let base = session.project.timelineTracks.first(where: { $0.id == clip.sourceID })?.source {
                        var next = clip; next.source = SourceLook(source: base); _ = session.updateTimelineClip(next)
                    }
                }
                Button("Duplicate") { session.duplicateTimelineClip(clip.id) }
                Button("Delete", role: .destructive) { session.deleteTimelineClip(clip.id) }
            }
        }.textFieldStyle(.roundedBorder)
    }
}

private struct SelectedCueInspector: View {
    let session: EditorSession
    let cue: LightingCue
    private func binding<Value>(_ path: WritableKeyPath<LightingCue, Value>) -> Binding<Value> {
        Binding(get: { cue[keyPath: path] }, set: { value in
            var next = cue; next[keyPath: path] = value; session.putLightingCue(next)
        })
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Lighting cue").font(.headline)
            NameEditor(name: cue.name, title: "Cue name", apply: { value in
                var next = cue; next.name = value; session.putLightingCue(next)
            }).id(cue.id)
            LabeledContent("Time (s)") { TextField("Time", value: binding(\.time), format: .number) }
            LabeledContent("Move lead (s)") { TextField("Lead", value: binding(\.lead), format: .number) }
            Picker("Movement", selection: Binding(get: { cue.motionCurve ?? .snap }, set: { value in
                var next = cue; next.motionCurve = value; session.putLightingCue(next)
            })) { ForEach(CueCurve.allCases) { Text($0.rawValue).tag($0) } }
            LabeledContent("Dimmer fade (s)") {
                TextField("Fade", value: Binding(get: { cue.dimmerFade ?? 0 }, set: { value in
                    var next = cue; next.dimmerFade = value; session.putLightingCue(next)
                }), format: .number)
            }
            Toggle("Manual only", isOn: Binding(get: { cue.isManual }, set: { value in
                var next = cue; next.manualOnly = value; session.putLightingCue(next)
            }))
            HStack {
                Button("GO") { session.nextManualCueID = cue.id; session.goManualCue() }
                Button("Duplicate") { session.duplicateLightingCue(cue, at: session.transport.elapsed(at: ProcessInfo.processInfo.systemUptime)) }
                Button("Delete", role: .destructive) { session.editLighting { $0.cues.removeAll { $0.id == cue.id } } }
            }
            if let message = session.lightingMessage { Text(message).font(.caption).foregroundStyle(.orange) }
        }.textFieldStyle(.roundedBorder)
    }
}


private struct SelectedMouthKeyInspector: View {
    let session: EditorSession
    let trackID: UUID
    let key: MouthKey
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Mouth Key").font(.headline)
            LabeledContent("Time (s)") {
                TextField("Time", value: Binding(get: { key.time }, set: { value in
                    session.updateVisual(trackID) { track in
                        guard let index = track.mouthKeys.firstIndex(where: { $0.id == key.id }) else { return }
                        track.mouthKeys[index].time = value
                    }
                }), format: .number)
            }
            Picker("Shape", selection: Binding(get: { key.shape }, set: { shape in
                session.updateVisual(trackID) { track in
                    guard let index = track.mouthKeys.firstIndex(where: { $0.id == key.id }) else { return }
                    track.mouthKeys[index].shape = shape
                }
            })) { ForEach(MouthShape.allCases) { Text($0.title).tag($0) } }
            HStack {
                Button("Duplicate") { session.duplicateSelectedMouthKey() }
                Button("Delete", role: .destructive) { session.deleteSelectedMouthKey() }
            }
        }.textFieldStyle(.roundedBorder)
    }
}
