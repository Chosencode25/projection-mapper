import SwiftUI

/// Project-wide libraries and output controls remain available regardless of selection.
struct ProjectShowControls: View {
    let session: EditorSession

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            VideoAudioControls(session: session)
            Divider()
            MasterOutputControls(session: session)
            Divider()
            LookLibraryControls(session: session).id(session.project.id)
            Divider()
            PaletteLibraryControls(session: session).id(session.project.id)
        }
    }
}

struct MasterOutputControls: View {
    let session: EditorSession
    @State private var statusClockActive = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("MASTER OUTPUT").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
            HStack {
                Text("Brightness")
                Spacer()
                Text(session.project.masterOutput.brightness.formatted(.percent.precision(.fractionLength(0))))
                    .monospacedDigit()
            }.font(.caption)
            Slider(value: Binding(get: { Double(session.project.masterOutput.brightness) }, set: {
                session.setMasterBrightness(Float($0))
            }), in: 0...1).accessibilityLabel("Master output brightness")
            HStack {
                Text("Fade duration")
                TextField("Seconds", value: Binding(get: { session.project.masterOutput.fadeDuration }, set: {
                    session.setFadeDuration($0)
                }), format: .number.precision(.fractionLength(0...2)))
                    .textFieldStyle(.roundedBorder).accessibilityLabel("Fade duration in seconds, zero to thirty")
                Text("s").foregroundStyle(.secondary)
            }
            HStack {
                Button("Fade to Black") { session.fadeToBlack() }
                Button("Restore") { session.restoreOutput() }
            }
            TimelineView(.animation(minimumInterval: 0.1, paused: !statusClockActive)) { _ in
                let uptime = ProcessInfo.processInfo.systemUptime
                let fading = session.showOutput.isFading(at: uptime)
                let gain = session.showOutput.gain(at: uptime)
                Label(status(fading: fading, gain: gain), systemImage: session.showOutput.isBlackout ? "lightbulb.slash.fill" : "lightbulb")
                    .font(.caption).foregroundStyle(session.showOutput.isBlackout ? Color.orange : Color.secondary)
                    .accessibilityLabel("Output status: " + status(fading: fading, gain: gain))
                    .onChange(of: fading) { _, active in statusClockActive = active }
            }
            .onChange(of: session.showOutput, initial: true) { _, state in
                statusClockActive = state.isFading(at: ProcessInfo.processInfo.systemUptime)
            }
            Text("Brightness and duration are saved. Fades and blackout are temporary; Restore returns to the saved brightness. Duration accepts 0–30 seconds.")
                .font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
        }
    }

    private func status(fading: Bool, gain: Float) -> String {
        if session.showOutput.isBlackout { return "Blackout · Restore to resume output" }
        let percent = gain.formatted(.percent.precision(.fractionLength(0)))
        if fading { return session.showOutput.targetGain == 0 ? "Fading to black · \(percent)" : "Restoring · \(percent)" }
        if gain == 0 { return "Faded to black" }
        if session.project.masterOutput.brightness == 0 { return "Master brightness is zero" }
        return "Normal · \(session.project.masterOutput.brightness.formatted(.percent.precision(.fractionLength(0)))) brightness"
    }
}

struct LookLibraryControls: View {
    let session: EditorSession
    @State private var newName = ""
    @State private var selectedID: UUID?
    @State private var pendingUpdate: UUID?
    @State private var pendingDelete: UUID?
    @State private var confirmUpdate = false
    @State private var confirmDelete = false
    private var selectedLook: ProjectLook? { session.project.looks.first { $0.id == selectedID } }

    var body: some View {
        DisclosureGroup("Looks") {
            VStack(alignment: .leading, spacing: 8) {
                TextField("New look name", text: $newName).textFieldStyle(.roundedBorder)
                    .accessibilityLabel("New look name")
                Button("Save New Look") {
                    if let id = session.saveLook(name: newName) { selectedID = id; newName = "" }
                }.disabled(!validLibraryName(newName) || session.project.looks.count >= 100)
                Picker("Look", selection: $selectedID) {
                    Text("Choose look").tag(Optional<UUID>.none)
                    ForEach(session.project.looks) {
                        Text($0.name).lineLimit(1).truncationMode(.middle).help($0.name).tag(Optional($0.id))
                    }
                }
                .help(selectedLook?.name ?? "Choose a saved look")
                if let look = selectedLook {
                    LibraryNameField(name: look.name, title: "Look name") { session.renameLook(look.id, name: $0) }.id(look.id)
                    Button("Apply Look") { session.applyLook(look.id) }
                    Button("Update from Current…") { pendingUpdate = look.id; confirmUpdate = true }
                    Button("Delete…") { pendingDelete = look.id; confirmDelete = true }
                    Text("\(look.entries.count) saved targets").font(.caption).foregroundStyle(.secondary)
                }
                if let report = session.lastLookReport {
                    Text(report).font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                }
                Text("Looks recall all captured content and appearance. Corners, input maps, locks and playback stay in place. Missing or regrouped targets are reported after applying.")
                    .font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            }.padding(.top, 8)
        }
        .confirmationDialog("Update this look from the current project?", isPresented: $confirmUpdate, titleVisibility: .visible) {
            Button("Replace Saved Look", role: .destructive) {
                if let id = pendingUpdate { session.updateLook(id) }
                pendingUpdate = nil
            }
            Button("Cancel", role: .cancel) { pendingUpdate = nil }
        } message: {
            Text("Replaces the content and appearance stored in \(session.project.looks.first { $0.id == pendingUpdate }?.name ?? "this look"). The current mapping stays in place.")
        }
        .confirmationDialog("Delete saved look?", isPresented: $confirmDelete, titleVisibility: .visible) {
            Button("Delete Look", role: .destructive) {
                if let id = pendingDelete { session.deleteLook(id); if selectedID == id { selectedID = nil } }
                pendingDelete = nil
            }
            Button("Cancel", role: .cancel) { pendingDelete = nil }
        } message: {
            Text("Removes \(session.project.looks.first { $0.id == pendingDelete }?.name ?? "this look") from the project library. The current content stays in place.")
        }
        .onChange(of: session.project.looks.map(\.id)) { _, ids in
            if let selectedID, !ids.contains(selectedID) { self.selectedID = nil }
        }
    }
}

struct PaletteLibraryControls: View {
    let session: EditorSession
    @State private var newName = ""
    @State private var newSlotName = ""
    @State private var selectedID: UUID?
    @State private var pendingPalette: UUID?
    @State private var pendingSlot: UUID?
    @State private var confirmPaletteDelete = false
    @State private var confirmSlotDelete = false
    private var palette: ColorPalette? { session.project.palettes.first { $0.id == selectedID } }

    var body: some View {
        DisclosureGroup("Palettes") {
            VStack(alignment: .leading, spacing: 8) {
                TextField("New palette name", text: $newName).textFieldStyle(.roundedBorder)
                    .accessibilityLabel("New palette name")
                Button("Create Palette") {
                    if let id = session.createPalette(name: newName) { selectedID = id; newName = "" }
                }.disabled(!validLibraryName(newName) || session.project.palettes.count >= 100)
                Picker("Palette", selection: $selectedID) {
                    Text("Choose palette").tag(Optional<UUID>.none)
                    ForEach(session.project.palettes) {
                        Text($0.name).lineLimit(1).truncationMode(.middle).help($0.name).tag(Optional($0.id))
                    }
                }
                .help(palette?.name ?? "Choose a project palette")
                if let palette {
                    LibraryNameField(name: palette.name, title: "Palette name") { session.renamePalette(palette.id, name: $0) }.id(palette.id)
                    ForEach(Array(palette.slots.enumerated()), id: \.element.id) { index, slot in
                        VStack(alignment: .leading, spacing: 6) {
                            LibraryNameField(name: slot.name, title: "Slot name") {
                                session.renamePaletteSlot(palette.id, slotID: slot.id, name: $0)
                            }.id(slot.id)
                            ColorPicker("Slot color", selection: Binding(get: { swiftUIColor(slot.color) }, set: {
                                if let rgba = rgbaColor($0) { session.setPaletteColor(palette.id, slotID: slot.id, color: rgba) }
                            }), supportsOpacity: true).accessibilityLabel("Color for \(slot.name)")
                            HStack {
                                Button("Move Up", systemImage: "arrow.up") { session.movePaletteSlot(palette.id, slotID: slot.id, offset: -1) }
                                    .labelStyle(.iconOnly).disabled(index == 0).accessibilityLabel("Move \(slot.name) up")
                                Button("Move Down", systemImage: "arrow.down") { session.movePaletteSlot(palette.id, slotID: slot.id, offset: 1) }
                                    .labelStyle(.iconOnly).disabled(index == palette.slots.count - 1).accessibilityLabel("Move \(slot.name) down")
                                Spacer()
                                Button("Remove Slot…") { pendingPalette = palette.id; pendingSlot = slot.id; confirmSlotDelete = true }
                            }
                            Divider()
                        }
                    }
                    TextField("New slot name", text: $newSlotName).textFieldStyle(.roundedBorder).accessibilityLabel("New palette slot name")
                    Button("Add Color Slot") {
                        if session.addPaletteSlot(palette.id, name: newSlotName, color: SIMD4<Float>(1, 1, 1, 1)) != nil { newSlotName = "" }
                    }.disabled(!validLibraryName(newSlotName) || palette.slots.count >= 32)
                    Button("Delete Palette…") { pendingPalette = palette.id; pendingSlot = nil; confirmPaletteDelete = true }
                }
                Text("Choose a slot beside a content color to share it across objects or faces. Removing a slot or palette retains its current colors in content and saved looks.")
                    .font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            }.padding(.top, 8)
        }
        .confirmationDialog("Delete palette and keep its current colors?", isPresented: $confirmPaletteDelete, titleVisibility: .visible) {
            Button("Keep Colors and Delete Palette", role: .destructive) {
                if let id = pendingPalette { session.deletePalette(id); if selectedID == id { selectedID = nil } }
                pendingPalette = nil
            }
            Button("Cancel", role: .cancel) { pendingPalette = nil }
        } message: {
            Text("\(paletteDeletionCount) color references in content and saved looks will become independent colors. Their current appearance is retained.")
        }
        .confirmationDialog("Remove slot and keep its current color?", isPresented: $confirmSlotDelete, titleVisibility: .visible) {
            Button("Keep Color and Remove Slot", role: .destructive) {
                if let id = pendingPalette, let slotID = pendingSlot { session.deletePaletteSlot(id, slotID: slotID) }
                pendingPalette = nil; pendingSlot = nil
            }
            Button("Cancel", role: .cancel) { pendingPalette = nil; pendingSlot = nil }
        } message: {
            Text("\(slotDeletionCount) color references in content and saved looks will become independent colors. Their current appearance is retained.")
        }
        .onChange(of: session.project.palettes.map(\.id)) { _, ids in
            if let selectedID, !ids.contains(selectedID) { self.selectedID = nil }
        }
        .onChange(of: selectedID) { _, _ in newSlotName = "" }
    }

    private var paletteDeletionCount: Int {
        pendingPalette.map { session.paletteReferenceCount($0) } ?? 0
    }
    private var slotDeletionCount: Int {
        guard let id = pendingPalette, let slotID = pendingSlot else { return 0 }
        return session.paletteReferenceCount(id, slotID: slotID)
    }
}

/// Selecting a face of an object edits that object's shared content color.
struct SourcePaletteBindingControl: View {
    let session: EditorSession
    let source: SurfaceSource
    let faceID: UUID
    let channel: ColorChannel

    private struct SlotChoice: Identifiable {
        let binding: ColorBinding
        let name: String
        var id: String { binding.paletteID.uuidString + ":" + binding.slotID.uuidString }
    }
    private var choices: [SlotChoice] {
        session.project.palettes.flatMap { palette in palette.slots.map {
            SlotChoice(binding: ColorBinding(paletteID: palette.id, slotID: $0.id), name: palette.name + " / " + $0.name)
        } }
    }
    private var currentBinding: ColorBinding? { channel == .primary ? source.primaryBinding : source.secondaryBinding }
    private var selectedKey: String? { currentBinding.map { $0.paletteID.uuidString + ":" + $0.slotID.uuidString } }

    var body: some View {
        Picker(channel == .primary ? "Color 1 palette" : "Color 2 palette", selection: Binding(get: { selectedKey }, set: { key in
            session.bindColor(faceID: faceID, channel: channel, binding: choices.first { $0.id == key }?.binding)
        })) {
            Text("Independent color").tag(Optional<String>.none)
            ForEach(choices) {
                Text($0.name).lineLimit(1).truncationMode(.middle).help($0.name).tag(Optional($0.id))
            }
        }
        .accessibilityLabel(channel.title + " content color palette slot")
        .help((choices.first { $0.id == selectedKey }.map { $0.name + "\n" } ?? "") + "Shared object colors affect every member face. Choosing Independent color retains the current color.")
    }
}

private struct LibraryNameField: View {
    let name: String
    let title: String
    let apply: (String) -> Void
    @State private var draft = ""
    @FocusState private var focused: Bool

    var body: some View {
        TextField(title, text: $draft).textFieldStyle(.roundedBorder).accessibilityLabel(title).focused($focused)
            .onAppear { draft = name }
            .onSubmit { commit(); focused = false }
            .onChange(of: focused) { _, value in if !value { commit() } }
            .onChange(of: name) { _, value in if !focused { draft = value } }
    }
    private func commit() {
        if validLibraryName(draft) { apply(draft) } else { draft = name }
    }
}

private func validLibraryName(_ value: String) -> Bool {
    let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
    return !trimmed.isEmpty && trimmed.count <= 80
}
private func swiftUIColor(_ rgba: SIMD4<Float>) -> Color {
    Color(.sRGB, red: Double(rgba.x), green: Double(rgba.y), blue: Double(rgba.z), opacity: Double(rgba.w))
}
private func rgbaColor(_ color: Color) -> SIMD4<Float>? {
    guard let rgb = NSColor(color).usingColorSpace(.deviceRGB) else { return nil }
    return SIMD4<Float>(Float(rgb.redComponent), Float(rgb.greenComponent), Float(rgb.blueComponent), Float(rgb.alphaComponent))
}
