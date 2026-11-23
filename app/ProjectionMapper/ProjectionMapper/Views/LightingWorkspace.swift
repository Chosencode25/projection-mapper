import SwiftUI
import AppKit

struct LightingWorkspace: View {
    @Bindable var session: EditorSession
    let close: () -> Void
    @State private var showsPreview = false
    @State private var controllerDraft: LightingController?
    @State private var fixtureDraft: PatchedFixture?
    @State private var fixtureKind = FixtureKind.movingHead
    @State private var removeFixture: PatchedFixture?
    @State private var includedFixtures: Set<UUID> = []
    @State private var lookName = ""
    @State private var editingLookID: UUID?

    private var lighting: ProjectLighting { session.project.lighting }
    private var simulation: LightingSimulation { session.lightingSimulation }
    private var compatibleControllers: [LightingController] {
        lighting.controllers.filter { $0.kind == fixtureKind.controllerKind }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Fixtures", systemImage: "light.beacon.max").font(.title2.bold())
                Text("SIMULATION").font(.caption.bold()).foregroundStyle(.orange)
                Spacer()
                Picker("Fixture workspace", selection: $showsPreview) {
                    Text("Setup & Monitor").tag(false)
                    Text("2D Preview").tag(true)
                }.pickerStyle(.segmented).fixedSize().labelsHidden()
                Button("Done", action: close)
            }
            HStack {
                Button("Resume Fixtures") { simulation.resume(); session.refreshLighting() }
                    .disabled(!simulation.isStopped)
                Button("Stop Fixtures") { session.stopManualFixtures() }
                    .disabled(simulation.isStopped)
                Toggle("Fixture Blackout", isOn: Binding(get: { simulation.blackout }, set: {
                    simulation.blackout = $0
                    session.refreshLighting()
                }))
                Spacer()
                if simulation.isStopped { Text("Stopped").foregroundStyle(.secondary) }
            }
            if let message = session.lightingMessage { Text(message).foregroundStyle(.orange) }
            Divider()
            if showsPreview {
                FixturePreview(session: session)
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        controllerSection
                        fixtureSection
                        looksSection
                        monitorSection
                    }.frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
        .padding(18)
        .sheet(item: $controllerDraft) { draft in
            LightingControllerEditor(session: session, draft: draft)
        }
        .sheet(item: $fixtureDraft) { draft in
            FixturePatchEditor(session: session, draft: draft)
        }
        .confirmationDialog("Remove fixture and its saved references?", isPresented: Binding(
            get: { removeFixture != nil }, set: { if !$0 { removeFixture = nil } }
        ), presenting: removeFixture) { fixture in
            Button("Remove \(fixture.name)", role: .destructive) {
                session.editLighting { $0.removeFixture(fixture.id) }
                includedFixtures.remove(fixture.id)
            }
        } message: { _ in
            Text("This also removes the fixture from saved lighting looks and cues. You can undo this edit.")
        }
    }

    private var controllerSection: some View {
        GroupBox("Controllers") {
            VStack(alignment: .leading) {
                ForEach(lighting.controllers) { controller in
                    HStack {
                        Text(controller.name).fontWeight(.medium)
                        Text("\(controller.kind.rawValue) · \(controller.capacity) outputs").foregroundStyle(.secondary)
                        Spacer()
                        Button("Edit") { controllerDraft = controller }
                        Button("Remove") { session.editLighting { $0.controllers.removeAll { $0.id == controller.id } } }
                            .disabled(lighting.fixtures.contains { $0.controllerID == controller.id })
                            .help("Remove or reassign this controller's fixtures first.")
                    }
                }
                HStack {
                    Button("Add DMX Controller") { controllerDraft = LightingController(name: "DMX Controller", kind: .dmx) }
                    Button("Add Arduino Controller") { controllerDraft = LightingController(name: "Arduino Controller", kind: .arduino) }
                }
            }.frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var fixtureSection: some View {
        GroupBox("Fixtures and Manual Tests") {
            VStack(alignment: .leading) {
                HStack {
                    Picker("Fixture type", selection: $fixtureKind) {
                        ForEach(FixtureKind.allCases) { Text($0.rawValue).tag($0) }
                    }.fixedSize()
                    Button("Add Fixture") {
                        guard let controller = compatibleControllers.first else { return }
                        fixtureDraft = PatchedFixture(name: fixtureKind.rawValue, kind: fixtureKind, controllerID: controller.id)
                    }.disabled(compatibleControllers.isEmpty)
                    if compatibleControllers.isEmpty { Text("Add a compatible controller first.").foregroundStyle(.secondary) }
                }
                if simulation.isStopped {
                    Text("Resume Fixtures to audition manual controls.").foregroundStyle(.secondary)
                }
                ForEach(lighting.fixtures) { fixture in
                    Divider()
                    HStack {
                        Toggle(isOn: Binding(get: { includedFixtures.contains(fixture.id) }, set: { included in
                            if included { includedFixtures.insert(fixture.id) }
                            else { includedFixtures.remove(fixture.id) }
                        })) {
                            Text(fixture.name).fontWeight(.medium)
                        }.help("Include in the next captured look")
                        Text(fixture.group).foregroundStyle(.secondary)
                        Spacer()
                        Button("Edit Patch") { fixtureDraft = fixture }
                        Button("Remove") { removeFixture = fixture }
                    }
                    FixtureTestControls(session: session, fixture: fixture)
                }
            }.frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var looksSection: some View {
        GroupBox("Lighting Looks") {
            VStack(alignment: .leading) {
                HStack {
                    TextField("Look name", text: $lookName)
                    Button(editingLookID == nil ? "Capture Selected Fixtures" : "Update Look") { captureLook() }
                        .disabled(lookName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
                                  lighting.fixtures.allSatisfy { !includedFixtures.contains($0.id) })
                    if editingLookID != nil {
                        Button("Cancel Edit") { editingLookID = nil; lookName = "" }
                    }
                }
                ForEach(lighting.looks) { look in
                    HStack {
                        Text(look.name)
                        Text("\(look.entries.count) fixtures").foregroundStyle(.secondary)
                        Spacer()
                        Button("Use on Timeline") {
                            session.selectedFixtureLookID = look.id
                            session.isTimelineVisible = true
                            close()
                        }
                        Button("Edit") {
                            editingLookID = look.id
                            lookName = look.name
                            includedFixtures = Set(look.entries.map(\.id))
                            if !simulation.isStopped {
                                for entry in look.entries {
                                    guard let fixture = lighting.fixtures.first(where: { $0.id == entry.id }) else { continue }
                                    simulation.override(entry.state, for: fixture)
                                }
                                session.refreshLighting()
                            }
                        }.disabled(simulation.isStopped)
                        Button("Remove") {
                            session.editLighting { $0.looks.removeAll { $0.id == look.id } }
                            if editingLookID == look.id { editingLookID = nil; lookName = "" }
                        }
                    }
                }
            }.frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var monitorSection: some View {
        GroupBox("Simulation Monitor") {
            VStack(alignment: .leading, spacing: 8) {
                if lighting.controllers.isEmpty { Text("Add a controller to see simulated output.").foregroundStyle(.secondary) }
                ForEach(lighting.controllers) { controller in
                    if let report = simulation.reports[controller.id] {
                        HStack {
                            Text(controller.name).fontWeight(.semibold)
                            Text(report.status.rawValue).foregroundStyle(.secondary)
                            Spacer()
                            Toggle("Inject Failure", isOn: Binding(get: { simulation.failures.contains(controller.id) }, set: {
                                simulation.setFailure($0, for: controller.id)
                                session.refreshLighting()
                            })).disabled(controller.profile != .simulation)
                        }
                        ForEach(report.fixtures) { output in
                            if let fixture = lighting.fixtures.first(where: { $0.id == output.id }) {
                                Text("\(fixture.name) · \(output.slots.map(String.init).joined(separator: ", "))").font(.caption.bold())
                                Text("Intended  \(output.intended.label)").font(.caption)
                                Text("Effective  \(output.effective.label)\(relayDescription(output))").font(.caption)
                            }
                        }
                        if let send = report.history.last {
                            Text("Last simulated send at \(send.time.formatted(.number.precision(.fractionLength(2)))) s · \(send.fixtureCount) fixtures")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }
            }.frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func relayDescription(_ output: SimulatedFixture) -> String {
        guard !output.relayValues.isEmpty else { return "" }
        let values = zip(output.slots, output.relayValues).map { "\($0.0)=\($0.1 ? "on" : "off")" }
        return " · " + values.joined(separator: ", ")
    }

    private func captureLook() {
        let intended = simulation.reports.values.flatMap(\.fixtures)
        let entries = lighting.fixtures.filter { includedFixtures.contains($0.id) }.map { fixture in
            FixtureLookEntry(id: fixture.id, state: intended.first { $0.id == fixture.id }?.intended ?? fixture.kind.dark)
        }
        let look = FixtureLook(id: editingLookID ?? UUID(), name: lookName.trimmingCharacters(in: .whitespacesAndNewlines), entries: entries)
        if session.editLighting({ lighting in
            if let index = lighting.looks.firstIndex(where: { $0.id == look.id }) { lighting.looks[index] = look }
            else { lighting.looks.append(look) }
        }) {
            session.selectedFixtureLookID = look.id
            editingLookID = nil
            lookName = ""
        }
    }
}

private struct LightingControllerEditor: View {
    let session: EditorSession
    @State var draft: LightingController
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        Form {
            TextField("Name", text: $draft.name)
            LabeledContent("Controller", value: draft.kind.rawValue)
            if draft.kind == .arduino {
                Stepper("Relay outputs: \(draft.relayCount)", value: $draft.relayCount, in: 1...512)
            }
            Picker("Profile", selection: $draft.profile) {
                ForEach(LightingSimulationProfile.allCases) { Text($0.rawValue).tag($0) }
            }
            if draft.profile != .simulation {
                Label("Simulation", systemImage: "testtube.2").foregroundStyle(.secondary)
            }
            if let message = session.lightingMessage { Text(message).foregroundStyle(.orange) }
            HStack {
                Button("Cancel") { dismiss() }.keyboardShortcut(.cancelAction)
                Spacer()
                Button("Apply") {
                    if session.editLighting({ lighting in
                        if let index = lighting.controllers.firstIndex(where: { $0.id == draft.id }) { lighting.controllers[index] = draft }
                        else { lighting.controllers.append(draft) }
                    }) { dismiss() }
                }.keyboardShortcut(.defaultAction)
            }
        }.formStyle(.grouped).frame(width: 460, height: 280)
        .onAppear { session.lightingMessage = nil }
    }
}

struct FixturePatchEditor: View {
    let session: EditorSession
    @State var draft: PatchedFixture
    @Environment(\.dismiss) private var dismiss
    private var controllers: [LightingController] {
        session.project.lighting.controllers.filter { $0.kind == draft.kind.controllerKind }
    }

    var body: some View {
        Form {
            TextField("Name", text: $draft.name)
            TextField("Group", text: $draft.group)
            Picker("Controller", selection: $draft.controllerID) {
                ForEach(controllers) { Text($0.name).tag($0.id) }
            }
            switch draft.kind {
            case .movingHead:
                Picker("Mode", selection: $draft.headChannels) {
                    Text("CH 9").tag(9)
                    Text("CH 11").tag(11)
                }
                TextField("DMX start address", value: $draft.address, format: .number.grouping(.never))
            case .plug:
                TextField("Relay output", value: $draft.address, format: .number.grouping(.never))
            case .rgb:
                TextField("Red output", value: $draft.address, format: .number.grouping(.never))
                TextField("Green output", value: $draft.green, format: .number.grouping(.never))
                TextField("Blue output", value: $draft.blue, format: .number.grouping(.never))
            }
            if let message = session.lightingMessage { Text(message).foregroundStyle(.orange) }
            HStack {
                Button("Cancel") { dismiss() }.keyboardShortcut(.cancelAction)
                Spacer()
                Button("Apply Patch") {
                    if session.editLighting({ lighting in
                        if let index = lighting.fixtures.firstIndex(where: { $0.id == draft.id }) { lighting.fixtures[index] = draft }
                        else { lighting.fixtures.append(draft) }
                    }) { dismiss() }
                }.keyboardShortcut(.defaultAction)
            }
        }.formStyle(.grouped).frame(width: 460, height: 360)
        .onAppear { session.lightingMessage = nil }
    }
}

private struct FixtureTestControls: View {
    let session: EditorSession
    let fixture: PatchedFixture
    private var simulation: LightingSimulation { session.lightingSimulation }
    private var intended: FixtureState {
        simulation.reports[fixture.controllerID]?.fixtures.first { $0.id == fixture.id }?.intended ?? fixture.kind.dark
    }

    var body: some View {
        VStack(alignment: .leading) {
            switch intended {
            case .head(let head):
                HStack {
                    headSlider("Pan", \.pan)
                    headSlider("Tilt", \.tilt)
                    headSlider("Dimmer", \.dimmer)
                }
                HStack {
                    Picker("Color", selection: headBinding(\.color, fallback: head.color)) {
                        ForEach(HeadLook.colors.indices, id: \.self) { Text(HeadLook.colors[$0]).tag($0) }
                    }
                    Picker("Gobo", selection: headBinding(\.gobo, fallback: head.gobo)) {
                        ForEach(0...7, id: \.self) { Text($0 == 0 ? "Open" : "Gobo \($0)").tag($0) }
                    }
                }
            case .plug:
                Toggle("On", isOn: Binding(get: {
                    if case .plug(let on) = intended { return on }
                    return false
                }, set: { apply(.plug($0)) }))
            case .rgb:
                Picker("RGB", selection: Binding(get: {
                    if case .rgb(let color) = intended { return color }
                    return .off
                }, set: { apply(.rgb($0)) })) {
                    ForEach(RelayColor.allCases) { Text($0.label).tag($0) }
                }.pickerStyle(.segmented)
            }
            if simulation.overrides[fixture.id] != nil {
                Button("Clear Manual Override") {
                    simulation.override(nil, for: fixture)
                    session.refreshLighting()
                }
            }
        }.disabled(simulation.isStopped)
    }

    private func apply(_ state: FixtureState) {
        simulation.override(state, for: fixture)
        session.refreshLighting()
    }

    private func headBinding<T>(_ key: WritableKeyPath<HeadLook, T>, fallback: T) -> Binding<T> {
        Binding(get: {
            if case .head(let head) = intended { return head[keyPath: key] }
            return fallback
        }, set: { value in
            guard case .head(var head) = intended else { return }
            head[keyPath: key] = value
            apply(.head(head))
        })
    }

    private func headSlider(_ label: String, _ key: WritableKeyPath<HeadLook, Double>) -> some View {
        Slider(value: headBinding(key, fallback: 0), in: 0...1) { Text(label) }
    }
}

struct FixturePreview: View {
    let session: EditorSession
    var allowsPlacement = true
    var usesLightingSelection = false
    @State private var editing = false
    @State private var draft: PlacementEdit?
    @State private var selectedFixtureID: UUID?
    @State private var showsPositionPath = true

    private struct PlacementEdit {
        var id: UUID
        var placement: FixturePreviewPlacement
    }

    private let colors: [Color] = [
        .white, .red, .green, .blue, .yellow, .orange, .cyan, .pink,
        .purple, .orange, .mint, .teal, .red
    ]

    var body: some View {
        let fixtures = session.project.lighting.fixtures.filter { !usesLightingSelection || !session.lightingHiddenFixtureIDs.contains($0.id) }
        let reports = session.lightingSimulation.reports
        let outputs = Dictionary(uniqueKeysWithValues: reports.values.flatMap { report in
            report.fixtures.map { ($0.id, $0) }
        })
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("Fixture Preview").font(.headline)
                Text("Simulated output · schematic").font(.caption).foregroundStyle(.secondary)
                Spacer()
                if usesLightingSelection, session.positionPathFixture != nil {
                    Toggle("Path", isOn: $showsPositionPath).toggleStyle(.switch).controlSize(.small)
                }
                if allowsPlacement {
                    Toggle("Edit Placement", isOn: $editing).toggleStyle(.switch).controlSize(.small)
                        .disabled(fixtures.isEmpty)
                }
            }
            GeometryReader { geometry in
                let size = geometry.size
                ZStack(alignment: .topLeading) {
                    RoundedRectangle(cornerRadius: 8).fill(Color(white: 0.09))
                    Canvas { context, _ in
                        drawGrid(in: context, size: size)
                        for (index, fixture) in fixtures.enumerated() {
                            let status = reports[fixture.controllerID]?.status
                            let active = status == .sent || status == .ready
                            let output = outputs[fixture.id]?.effective ?? fixture.kind.dark
                            draw(output: active ? output : output.darkened,
                                 placement: placement(for: fixture, index: index), in: context, size: size)
                        }
                    }.accessibilityHidden(true)

                    ForEach(Array(fixtures.enumerated()), id: \.element.id) { index, fixture in
                        let location = placement(for: fixture, index: index)
                        let state = outputs[fixture.id]?.effective ?? fixture.kind.dark
                        let status = reports[fixture.controllerID]?.status
                        let active = status == .sent || status == .ready
                        let effect = outputs[fixture.id]?.activeEffect
                        let detail = active ? [effect, state.label].compactMap { $0 }.joined(separator: " · ") : (status?.rawValue ?? "No output")
                        marker(fixture.name, icon: icon(for: fixture.kind), detail: detail,
                               fixture: fixture, placement: location, endpoint: false, size: size,
                               effectColor: effect == nil ? nil : previewColor(state))
                        if editing, location.stripEnd != nil {
                            marker("Strip end", icon: "circle", detail: fixture.name,
                                   fixture: fixture, placement: location, endpoint: true, size: size)
                        }
                    }
                    if usesLightingSelection, showsPositionPath, let fixture = session.positionPathFixture {
                        VStack {
                            Spacer()
                            HStack {
                                Spacer()
                                HeadPositionPathEditor(session: session, fixture: fixture)
                                    .frame(width: min(280, max(180, size.width - 24)), height: 184)
                                    .background(Color(nsColor: .controlBackgroundColor).opacity(0.98), in: RoundedRectangle(cornerRadius: 8))
                                    .padding(8)
                            }
                        }
                    }
                    if fixtures.isEmpty {
                        Text(usesLightingSelection && !session.project.lighting.fixtures.isEmpty ? "Use the eye buttons to show fixtures in this schematic." : "Add fixtures in Setup & Monitor to see them here.")
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                }
                .coordinateSpace(name: "fixturePreview")
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            if allowsPlacement, !usesLightingSelection, let selected = fixtures.first(where: { $0.id == selectedFixtureID }) {
                GroupBox(selected.name) { FixtureTestControls(session: session, fixture: selected) }
            }
            if editing {
                Text("Drag the fixture markers to position them. Drag either strip marker to shape the line.")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
        .onChange(of: session.project.id) { _, _ in draft = nil }
        .onChange(of: editing) { _, _ in draft = nil }
    }

    private func placement(for fixture: PatchedFixture, index: Int) -> FixturePreviewPlacement {
        if let draft, draft.id == fixture.id { return draft.placement }
        return fixture.previewPlacement ?? .initial(index: session.project.lighting.fixtures.firstIndex(where: { $0.id == fixture.id }) ?? index, kind: fixture.kind)
    }

    private func point(_ position: FixturePreviewPoint, in size: CGSize) -> CGPoint {
        CGPoint(x: size.width * position.x, y: size.height * position.y)
    }

    private func icon(for kind: FixtureKind) -> String {
        switch kind {
        case .movingHead: "light.beacon.max"
        case .plug: "powerplug"
        case .rgb: "line.diagonal"
        }
    }

    private func marker(_ label: String, icon: String, detail: String, fixture: PatchedFixture,
                        placement: FixturePreviewPlacement, endpoint: Bool, size: CGSize, effectColor: Color? = nil) -> some View {
        let anchor = point(endpoint ? placement.stripEnd ?? placement.origin : placement.origin, in: size)
        return Image(systemName: icon)
            .font(.system(size: 12, weight: .semibold))
            .frame(width: 26, height: 26)
            .foregroundStyle(.white)
            .background(.black.opacity(0.8), in: Circle())
            .overlay {
                if let effectColor {
                    Circle().strokeBorder(effectColor, lineWidth: 3).padding(-4).allowsHitTesting(false)
                }
            }
            .overlay { Circle().strokeBorder(selectedFixtureID == fixture.id ? Color.accentColor : .white.opacity(editing ? 0.75 : 0.3), lineWidth: selectedFixtureID == fixture.id ? 2 : 1) }
            .overlay(alignment: .bottom) {
                if !endpoint {
                    Text(label).font(.caption2).lineLimit(1).fixedSize()
                        .padding(.horizontal, 4).background(.black.opacity(0.65), in: Capsule())
                        .offset(y: 12).allowsHitTesting(false).accessibilityHidden(true)
                }
            }
            .onTapGesture { if allowsPlacement {
                if usesLightingSelection { session.selectLighting(.fixture(fixture.id)) }
                else { selectedFixtureID = fixture.id }
            } }
            .overlay {
                if usesLightingSelection && session.selectedLightingFixtureIDs.contains(fixture.id) {
                    Circle().stroke(Color.orange, lineWidth: 2).allowsHitTesting(false)
                }
            }
            .position(anchor)
            .accessibilityLabel("\(label), \(detail)")
            .help("\(label) · \(detail)")
            .gesture(DragGesture(minimumDistance: 1, coordinateSpace: .named("fixturePreview"))
                .onChanged { value in
                    guard editing, size.width > 0, size.height > 0 else { return }
                    if usesLightingSelection { session.selectLighting(.fixture(fixture.id)) }
                    var updated = placement
                    let position = FixturePreviewPoint(
                        x: min(0.96, max(0.04, value.location.x / size.width)),
                        y: min(0.90, max(0.07, value.location.y / size.height))
                    )
                    if endpoint { updated.stripEnd = position }
                    else { updated.origin = position }
                    draft = PlacementEdit(id: fixture.id, placement: updated)
                }
                .onEnded { _ in
                    guard let edit = draft, edit.id == fixture.id else { return }
                    draft = nil
                    session.editLighting { lighting in
                        guard let index = lighting.fixtures.firstIndex(where: { $0.id == edit.id }) else { return }
                        lighting.fixtures[index].previewPlacement = edit.placement
                    }
                }, including: editing ? .all : .none)
    }

    private func previewColor(_ state: FixtureState) -> Color {
        switch state {
        case .head(let head): head.dimmer > 0 ? colors[head.color] : .gray
        case .plug(let isOn): isOn ? .yellow : .gray
        case .rgb(let color):
            color == .off ? .gray : Color(red: color.outputs[0] ? 1 : 0, green: color.outputs[1] ? 1 : 0, blue: color.outputs[2] ? 1 : 0)
        }
    }

    private func drawGrid(in context: GraphicsContext, size: CGSize) {
        var grid = Path()
        for step in 1..<12 {
            let x = size.width * Double(step) / 12
            grid.move(to: CGPoint(x: x, y: 0))
            grid.addLine(to: CGPoint(x: x, y: size.height))
        }
        for step in 1..<6 {
            let y = size.height * Double(step) / 6
            grid.move(to: CGPoint(x: 0, y: y))
            grid.addLine(to: CGPoint(x: size.width, y: y))
        }
        context.stroke(grid, with: .color(.white.opacity(0.07)), lineWidth: 1)
    }

    private func draw(output: FixtureState, placement: FixturePreviewPlacement,
                      in context: GraphicsContext, size: CGSize) {
        let start = point(placement.origin, in: size)
        switch output {
        case .head(let head):
            let angle = (head.pan - 0.5) * 2 * Double.pi + .pi / 2
            let length = min(size.width, size.height) * (0.22 + 0.65 * head.tilt)
            let target = CGPoint(x: start.x + cos(angle) * length, y: start.y + sin(angle) * length)
            var axis = Path()
            axis.move(to: start)
            axis.addLine(to: target)
            context.stroke(axis, with: .color(.white.opacity(0.25)), style: StrokeStyle(lineWidth: 1, dash: [3, 4]))
            guard head.dimmer > 0 else { return }
            let width = length * 0.20
            let tint = colors[head.color]
            var beam = Path()
            beam.move(to: start)
            beam.addLine(to: CGPoint(x: target.x - sin(angle) * width, y: target.y + cos(angle) * width))
            beam.addLine(to: CGPoint(x: target.x + sin(angle) * width, y: target.y - cos(angle) * width))
            beam.closeSubpath()
            context.fill(beam, with: .linearGradient(
                Gradient(colors: [tint.opacity(head.dimmer * 0.95), tint.opacity(head.dimmer * 0.22)]),
                startPoint: start, endPoint: target))
        case .plug(let on):
            let circle = Path(ellipseIn: CGRect(x: start.x - 21, y: start.y - 21, width: 42, height: 42))
            context.fill(circle, with: .color(on ? .yellow.opacity(0.65) : .white.opacity(0.09)))
        case .rgb(let color):
            guard let end = placement.stripEnd else { return }
            let channels = color.outputs
            let tint = Color(red: channels[0] ? 1 : 0, green: channels[1] ? 1 : 0, blue: channels[2] ? 1 : 0)
            var strip = Path()
            strip.move(to: start)
            strip.addLine(to: point(end, in: size))
            context.stroke(strip, with: .color(color == .off ? .white.opacity(0.16) : tint.opacity(0.25)),
                           style: StrokeStyle(lineWidth: 15, lineCap: .round))
            context.stroke(strip, with: .color(color == .off ? .gray : tint),
                           style: StrokeStyle(lineWidth: 5, lineCap: .round))
        }
    }
}


/// Authoring workspace sharing the same project, renderer clock and simulation as Edit/Show.
struct DedicatedLightingWorkspace: View {
    @Bindable var session: EditorSession
    let refreshDisplays: () -> Void
    let openOutput: () -> Void
    @State private var showsSetup = false
    @State private var patch: PatchedFixture?
    @State private var showsCueReview = false
    private var simulation: LightingSimulation { session.lightingSimulation }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView(.horizontal) {
                HStack(spacing: 12) {
                    Button("Setup & Monitor", systemImage: "slider.horizontal.3") { showsSetup = true }
                    Text("SIMULATION").font(.caption.bold()).foregroundStyle(.orange)
                    if session.isRecordingCues {
                        Button("Stop Recording", systemImage: "stop.circle") { session.setPlaying(false) }
                            .buttonStyle(.borderedProminent).tint(.red)
                    } else if !session.recordedCues.isEmpty {
                        Button("Review Take", systemImage: "list.bullet.rectangle") { showsCueReview = true }
                    } else {
                        Button("Record Cues", systemImage: "record.circle") { session.startCueRecording() }
                            .disabled(!session.canStartCueRecording)
                            .help("Play the soundtrack and record saved cues and looks. Add a soundtrack and at least one cue or look to get started.")
                    }
                    Button(simulation.isStopped ? "Resume Fixtures" : "Stop Fixtures") {
                        if simulation.isStopped { simulation.resume(); session.refreshLighting() }
                        else { session.stopManualFixtures() }
                    }
                    Toggle("Fixture Blackout", isOn: Binding(get: { simulation.blackout }, set: {
                        simulation.blackout = $0; session.refreshLighting()
                    })).toggleStyle(.checkbox)
                    Toggle("Projection References", isOn: $session.lightingProjectionReferences).toggleStyle(.checkbox)
                    Spacer()
                }.padding(.horizontal, 12).frame(height: 46)
            }.scrollIndicators(.hidden)
            if session.isRecordingCues {
                Divider()
                CueRecordingControls(session: session)
            }
            if let message = session.cueRecordingMessage, !showsCueReview {
                Text(message).font(.caption).foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading).padding(.horizontal, 12).padding(.bottom, 6)
            }
            Divider()
            VSplitView {
                HSplitView {
                    sidebar.frame(minWidth: 180, idealWidth: session.lightingSidebarWidth, maxWidth: 340)
                        .onGeometryChange(for: Double.self) { $0.size.width } action: { if NSEvent.pressedMouseButtons != 0 { session.lightingSidebarWidth = $0 } }
                    FixturePreview(session: session, usesLightingSelection: true)
                        .padding(12).frame(minWidth: 260, maxWidth: .infinity, maxHeight: .infinity)
                        .background(SplitInitialPositionView(vertical: true, leading: session.lightingSidebarWidth, trailing: session.lightingInspectorWidth))
                    Group {
                        if session.inspectorTab == .edit {
                            VStack(spacing: 0) {
                                Picker("Inspector section", selection: $session.inspectorTab) {
                                    Text("Selection").tag(InspectorTab.edit)
                                    Text("Output").tag(InspectorTab.show)
                                    Text("Project").tag(InspectorTab.project)
                                }.pickerStyle(.segmented).labelsHidden().padding(12)
                                Divider()
                                ScrollView {
                                    LightingSelectionInspector(session: session, editPatch: { patch = $0 })
                                        .padding(14).frame(maxWidth: .infinity, alignment: .leading)
                                }.id(session.selectedHeadPositionKeyID?.uuidString ?? session.selectedLightingCueID?.uuidString ?? String(describing: session.lightingSelection))
                            }
                        } else {
                            ProjectInspectorView(session: session, refreshDisplays: refreshDisplays, openOutput: openOutput)
                        }
                    }.frame(minWidth: 270, idealWidth: session.lightingInspectorWidth, maxWidth: 440)
                        .background(Color(nsColor: .controlBackgroundColor).opacity(0.45))
                        .onGeometryChange(for: Double.self) { $0.size.width } action: { if NSEvent.pressedMouseButtons != 0 { session.lightingInspectorWidth = $0 } }
                }.frame(minHeight: 220)
                PlaybackTimelineView(session: session, lightingFocus: true)
                    .frame(minHeight: 184, idealHeight: session.lightingTimelineHeight, maxHeight: 440)
                    .background(SplitInitialPositionView(vertical: false, leading: nil, trailing: session.lightingTimelineHeight))
                    .onGeometryChange(for: Double.self) { $0.size.height } action: { if NSEvent.pressedMouseButtons != 0 { session.lightingTimelineHeight = $0 } }
            }.id(session.layoutRevision)
        }
        .onChange(of: session.isRecordingCues) { wasRecording, recording in
            if wasRecording, !recording, !session.recordedCues.isEmpty, !showsSetup, patch == nil {
                showsCueReview = true
            }
        }
        .sheet(isPresented: $showsCueReview) {
            CueTakeReview(session: session)
        }
        .sheet(isPresented: $showsSetup) {
            LightingWorkspace(session: session) { showsSetup = false }.frame(width: 850, height: 550)
        }
        .sheet(item: $patch) { fixture in
            FixturePatchEditor(session: session, draft: fixture)
                .onDisappear {
                    if session.project.lighting.fixtures.contains(where: { $0.id == fixture.id }) { session.selectLighting(.fixture(fixture.id)) }
                }
        }
    }
    private var sidebar: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Lighting").font(.headline)
                Spacer()
                Menu {
                    ForEach(FixtureKind.allCases) { kind in
                        Button(kind.rawValue) {
                            if let fixture = session.newLightingFixture(kind: kind) { patch = fixture }
                            else { session.lightingMessage = "Add a compatible controller with free outputs in Setup & Monitor." }
                        }
                    }
                } label: { Image(systemName: "plus") }.menuIndicator(.hidden).fixedSize().help("Add fixture")
            }.padding(12)
            Divider()
            List {
                if !session.lightingGroups.isEmpty {
                    Section("Groups") {
                        ForEach(session.lightingGroups, id: \.self) { group in
                            selectionRow(group, icon: "folder", selection: .group(group))
                        }
                    }
                }
                Section("Fixtures") {
                    ForEach(session.project.lighting.fixtures) { fixture in
                        HStack(spacing: 4) {
                            selectionRow(fixture.name, icon: fixture.kind == .movingHead ? "light.beacon.max" : fixture.kind == .plug ? "powerplug" : "line.diagonal", selection: .fixture(fixture.id))
                            Button {
                                if !session.lightingHiddenFixtureIDs.insert(fixture.id).inserted { session.lightingHiddenFixtureIDs.remove(fixture.id) }
                            } label: { Image(systemName: session.lightingHiddenFixtureIDs.contains(fixture.id) ? "eye.slash" : "eye") }
                                .buttonStyle(.plain).foregroundStyle(.secondary)
                                .help("Show or hide in this schematic only; output is unchanged")
                        }
                    }
                    if session.project.lighting.fixtures.isEmpty {
                        Button("Add controllers and fixtures…") { showsSetup = true }
                    }
                }
                Section("Looks") {
                    ForEach(session.project.lighting.looks) { look in
                        selectionRow(look.name, icon: "sparkles", selection: .look(look.id))
                    }
                    if session.project.lighting.looks.isEmpty { Text("Capture a look from the selection").font(.caption).foregroundStyle(.secondary) }
                }
            }.listStyle(.sidebar)
        }
    }
    private func selectionRow(_ name: String, icon: String, selection: LightingSelection) -> some View {
        Button { session.selectLighting(selection) } label: {
            Label(name, systemImage: icon).lineLimit(1).frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 5).padding(.horizontal, 4)
                .background(session.lightingSelection == selection ? Color.accentColor.opacity(0.22) : .clear, in: RoundedRectangle(cornerRadius: 4))
        }.buttonStyle(.plain).accessibilityAddTraits(session.lightingSelection == selection ? .isSelected : [])
    }
}

private struct CueRecordingControls: View {
    @Bindable var session: EditorSession
    @State private var lookID: UUID?

    var body: some View {
        let cues = session.manualCueList
        let looks = session.project.lighting.looks
        ScrollView(.horizontal) {
            HStack(spacing: 10) {
                Label("\(session.recordedCues.count) recorded", systemImage: "record.circle.fill")
                    .foregroundStyle(.red).monospacedDigit()
                if !cues.isEmpty {
                    Picker("Next cue", selection: $session.nextManualCueID) {
                        Text(session.lastManualCueID == nil ? "First Cue" : "End of List").tag(UUID?.none)
                        ForEach(cues) { Text($0.name).tag(Optional($0.id)) }
                    }.frame(width: 230)
                    Button("GO") { session.goManualCue() }
                        .disabled(session.nextManualCueID == nil && session.lastManualCueID != nil)
                }
                if !looks.isEmpty {
                    Picker("Look", selection: $lookID) {
                        Text("Select a look").tag(UUID?.none)
                        ForEach(looks) { Text($0.name).tag(Optional($0.id)) }
                    }.frame(width: 180)
                    Button("Trigger Look") {
                        if let lookID { session.triggerRecordedLook(lookID) }
                    }.disabled(!looks.contains { $0.id == lookID })
                }
            }.padding(.horizontal, 12).padding(.vertical, 8)
        }.scrollIndicators(.hidden)
    }
}

private struct CueTakeReview: View {
    let session: EditorSession
    @Environment(\.dismiss) private var dismiss
    @State private var times: [UUID: Double] = [:]
    @State private var included: Set<UUID> = []

    private var beatTimes: [Double] {
        let duration = session.project.song?.duration ?? 0
        return session.project.showMarkers.filter { $0.kind == .beat && $0.time <= duration }.map(\.time).sorted()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Review Cue Take").font(.title2.bold())
            Text("Choose which cues to add. Adjust their song times in seconds, or snap the selected cues to the nearest beat marker.")
                .foregroundStyle(.secondary)
            List(session.recordedCues) { cue in
                HStack {
                    Toggle(isOn: Binding(get: { included.contains(cue.id) }, set: { include in
                        if include { included.insert(cue.id) } else { included.remove(cue.id) }
                    })) {
                        Text(cue.name).lineLimit(1)
                    }.toggleStyle(.checkbox)
                    Spacer()
                    TextField("Song time for \(cue.name)", value: Binding(
                        get: { times[cue.id] ?? cue.time }, set: { times[cue.id] = $0 }
                    ), format: .number.precision(.fractionLength(3...6)))
                        .labelsHidden().multilineTextAlignment(.trailing).frame(width: 100)
                        .disabled(!included.contains(cue.id))
                    Text("s").foregroundStyle(.secondary)
                }
            }.frame(minHeight: 220)
            HStack {
                Button("Snap Selected to Beats") {
                    let beats = beatTimes
                    for cue in session.recordedCues where included.contains(cue.id) {
                        let time = times[cue.id] ?? cue.time
                        times[cue.id] = beats.min { abs($0 - time) < abs($1 - time) }
                    }
                }.disabled(beatTimes.isEmpty || included.isEmpty)
                Button("Restore Recorded Times") { times.removeAll() }.disabled(times.isEmpty)
            }
            if let message = session.cueRecordingMessage {
                Text(message).foregroundStyle(.orange)
            }
            HStack {
                Button("Discard Take", role: .destructive) {
                    session.discardRecordedCues()
                    dismiss()
                }
                Spacer()
                Button("Close") { dismiss() }.keyboardShortcut(.cancelAction)
                Button("Add Selected to Timeline") {
                    let chosen = session.recordedCues.filter { included.contains($0.id) }
                    let selectedTimes = Dictionary(uniqueKeysWithValues: chosen.map { ($0.id, times[$0.id] ?? $0.time) })
                    if session.addRecordedCues(times: selectedTimes) { dismiss() }
                }.keyboardShortcut(.defaultAction)
                    .disabled(included.isEmpty || session.playbackRequested)
            }
        }.padding(18).frame(width: 560)
            .onAppear { included = Set(session.recordedCues.map(\.id)) }
            .onChange(of: session.recordedCues.isEmpty) { _, empty in if empty { dismiss() } }
    }
}

private struct LightingSelectionInspector: View {
    @Bindable var session: EditorSession
    let editPatch: (PatchedFixture) -> Void
    @State private var lookName = ""
    private var fixtures: [PatchedFixture] { session.selectedLightingFixtures }
    private var head: HeadLook {
        if let fixture = fixtures.first(where: { $0.kind == .movingHead }), case .head(let value) = session.intendedLightingState(fixture) { return value }
        return HeadLook()
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            if let key = session.selectedHeadPositionKey {
                HeadPositionKeyInspector(session: session, key: key)
            } else if let cue = session.selectedLightingCue {
                SelectedCueInspector(session: session, cue: cue)
            } else if !fixtures.isEmpty {
                Text(title).font(.headline)
                if case .fixture = session.lightingSelection, let fixture = fixtures.first {
                    Text(fixture.kind.rawValue).foregroundStyle(.secondary)
                    LabeledContent("Patch", value: fixture.slots.map(String.init).joined(separator: ", "))
                    Text(session.lightingSimulation.reports[fixture.controllerID]?.status.rawValue ?? "Simulation stopped").font(.caption).foregroundStyle(.secondary)
                    Button("Edit Fixture Patch…") { editPatch(fixture) }
                } else { Text("\(fixtures.count) fixtures").foregroundStyle(.secondary) }
                if case .look = session.lightingSelection {
                    Button("Audition Look") { session.auditionSelectedLightingLook() }.disabled(session.lightingSimulation.isStopped)
                }
                if session.lightingSimulation.isStopped { Text("Resume Fixtures to audition controls.").font(.caption).foregroundStyle(.secondary) }
                VStack(alignment: .leading, spacing: 12) {
                    if fixtures.contains(where: { $0.kind == .movingHead }) {
                        Text("Moving Heads").font(.subheadline.bold())
                        headValue("Pan", \.pan)
                        headValue("Tilt", \.tilt)
                        headValue("Dimmer", \.dimmer)
                        Picker("Color", selection: headBinding(\.color)) {
                            ForEach(HeadLook.colors.indices, id: \.self) { Text(HeadLook.colors[$0]).tag($0) }
                        }
                        Picker("Gobo", selection: headBinding(\.gobo)) {
                            ForEach(0...7, id: \.self) { Text($0 == 0 ? "Open" : "Gobo \($0)").tag($0) }
                        }
                    }
                    if fixtures.contains(where: { $0.kind == .plug }) {
                        Toggle("Plugs On", isOn: Binding(get: {
                            guard let fixture = fixtures.first(where: { $0.kind == .plug }), case .plug(let on) = session.intendedLightingState(fixture) else { return false }
                            return on
                        }, set: { value in session.auditionLighting { fixture, state in fixture.kind == .plug ? .plug(value) : state } }))
                    }
                    if fixtures.contains(where: { $0.kind == .rgb }) {
                        Picker("RGB Strips", selection: Binding(get: {
                            guard let fixture = fixtures.first(where: { $0.kind == .rgb }), case .rgb(let color) = session.intendedLightingState(fixture) else { return RelayColor.off }
                            return color
                        }, set: { value in session.auditionLighting { fixture, state in fixture.kind == .rgb ? .rgb(value) : state } })) {
                            ForEach(RelayColor.allCases) { Text($0.label).tag($0) }
                        }
                    }
                    if fixtures.count > 1 { Text("Controls show the first fixture of each type. Changes apply to selected fixtures of that type.").font(.caption).foregroundStyle(.secondary) }
                    Button("Clear Manual Overrides") { session.clearSelectedLightingOverrides() }
                }.disabled(session.lightingSimulation.isStopped)
                if fixtures.contains(where: { $0.kind == .movingHead }) {
                    Button("Capture Position at Playhead") {
                        session.captureHeadPositions(at: session.transport.elapsed(at: ProcessInfo.processInfo.systemUptime))
                    }
                }
                Divider()
                TextField("New look name", text: $lookName)
                Button("Capture Look") { _ = session.captureLightingSelection(name: lookName) }
                    .disabled(lookName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                if session.selectedFixtureLook != nil {
                    Button("Place Selected Look at Playhead") {
                        session.placeSelectedLightingLook(at: session.transport.elapsed(at: ProcessInfo.processInfo.systemUptime), fixtureIDs: session.selectedLightingFixtureIDs)
                    }
                }
            } else {
                Text("Select a fixture, group, look or timeline cue.").foregroundStyle(.secondary)
            }
            if let message = session.lightingMessage { Text(message).font(.caption).foregroundStyle(.orange) }
        }.textFieldStyle(.roundedBorder)
    }
    private var title: String {
        switch session.lightingSelection {
        case .fixture: return fixtures.first?.name ?? "Fixture"
        case .group(let name): return name
        case .look(let id): return session.project.lighting.looks.first { $0.id == id }?.name ?? "Look"
        case nil: return "Selection"
        }
    }
    private func headBinding<T>(_ key: WritableKeyPath<HeadLook, T>) -> Binding<T> {
        Binding(get: { head[keyPath: key] }, set: { value in
            session.auditionLighting { _, state in
                guard case .head(var head) = state else { return state }
                head[keyPath: key] = value
                return .head(head)
            }
        })
    }
    private func headValue(_ label: String, _ key: WritableKeyPath<HeadLook, Double>) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            LabeledContent(label) { TextField(label, value: headBinding(key), format: .number.precision(.fractionLength(3))).frame(width: 66) }
            Slider(value: headBinding(key), in: 0...1).accessibilityLabel(label)
        }
    }
}


private struct HeadPositionPathEditor: View {
    let session: EditorSession
    let fixture: PatchedFixture
    @State private var draft: HeadPositionKey?
    @State private var baseline: MappingProject?
    private var keys: [HeadPositionKey] {
        session.headPositionKeys(for: fixture.id).map { key in draft?.id == key.id ? draft! : key }
    }
    var body: some View {
        let intended = session.intendedLightingState(fixture)
        VStack(spacing: 4) {
            HStack {
                Text("\(fixture.name) · Pan/Tilt").font(.caption.bold()).lineLimit(1)
                Spacer(minLength: 0)
                Button { session.captureHeadPositions(at: session.transport.elapsed(at: ProcessInfo.processInfo.systemUptime)) } label: {
                    Image(systemName: "plus.diamond")
                }.buttonStyle(.plain).help("Capture position at the playhead")
            }.padding(.horizontal, 10).padding(.top, 8)
            GeometryReader { geometry in
                let size = geometry.size
                ZStack(alignment: .topLeading) {
                    Canvas { context, _ in
                        let rect = CGRect(x: 16, y: 16, width: max(1, size.width - 32), height: max(1, size.height - 32))
                        context.stroke(Path(rect), with: .color(.secondary.opacity(0.4)), lineWidth: 1)
                        for (a, b) in zip(keys, keys.dropFirst()) {
                            var segment = Path()
                            segment.move(to: HeadPathGeometry.point(pan: a.pan, tilt: a.tilt, size: size))
                            segment.addLine(to: HeadPathGeometry.point(pan: b.pan, tilt: b.tilt, size: size))
                            context.stroke(segment, with: .color(.cyan.opacity(0.8)), style: StrokeStyle(lineWidth: 2, dash: b.curve == .snap ? [3, 3] : []))
                        }
                        if case .head(let current) = intended {
                            let point = HeadPathGeometry.point(pan: current.pan, tilt: current.tilt, size: size)
                            context.stroke(Path(ellipseIn: CGRect(x: point.x - 7, y: point.y - 7, width: 14, height: 14)), with: .color(.orange), lineWidth: 2)
                        }
                    }.allowsHitTesting(false).accessibilityHidden(true)
                    ForEach(keys) { key in
                        Image(systemName: session.selectedHeadPositionKeyID == key.id ? "diamond.fill" : "diamond")
                            .foregroundStyle(.cyan).frame(width: 20, height: 20).contentShape(Rectangle())
                            .onTapGesture { session.selectHeadPositionKey(key.id) }
                            .gesture(DragGesture(minimumDistance: 1, coordinateSpace: .named("headPositionPad"))
                                .onChanged { value in
                                    guard let position = HeadPathGeometry.position(at: value.location, size: size) else { return }
                                    if draft == nil { baseline = session.project; session.selectHeadPositionKey(key.id) }
                                    var next = key; next.pan = position.pan; next.tilt = position.tilt
                                    draft = next
                                }.onEnded { _ in
                                    defer { draft = nil; baseline = nil }
                                    guard let draft, baseline == session.project else { return }
                                    session.updateHeadPosition(draft)
                                })
                            .position(HeadPathGeometry.point(pan: key.pan, tilt: key.tilt, size: size))
                            .help("\(TimelinePresentation.timecode(key.time)) · pan \(key.pan.formatted(.number.precision(.fractionLength(3)))) · tilt \(key.tilt.formatted(.number.precision(.fractionLength(3))))")
                            .accessibilityLabel("Position key at \(TimelinePresentation.timecode(key.time))")
                    }
                    if keys.isEmpty { Text("Capture positions at two song times").font(.caption).foregroundStyle(.secondary).frame(width: size.width, height: size.height) }
                }.coordinateSpace(name: "headPositionPad")
            }
            Text("Pan →  ·  Tilt ↑  ·  orange = intended position").font(.system(size: 9)).foregroundStyle(.secondary).padding(.bottom, 6)
        }.onChange(of: session.project.id) { _, _ in draft = nil; baseline = nil }
    }
}

private struct HeadPositionKeyInspector: View {
    let session: EditorSession
    let key: HeadPositionKey
    private func binding<Value>(_ path: WritableKeyPath<HeadPositionKey, Value>) -> Binding<Value> {
        Binding(get: { key[keyPath: path] }, set: { value in var next = key; next[keyPath: path] = value; session.updateHeadPosition(next) })
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Position Key").font(.headline)
            Text(session.project.lighting.fixtures.first { $0.id == key.fixtureID }?.name ?? "Moving head").foregroundStyle(.secondary)
            LabeledContent("Time (s)") { TextField("Time", value: binding(\.time), format: .number.precision(.fractionLength(3))) }
            LabeledContent("Pan") { TextField("Pan", value: binding(\.pan), format: .number.precision(.fractionLength(3))) }
            LabeledContent("Tilt") { TextField("Tilt", value: binding(\.tilt), format: .number.precision(.fractionLength(3))) }
            Picker("Arrive using", selection: binding(\.curve)) {
                ForEach(CueCurve.allCases) { Text($0.rawValue).tag($0) }
            }
            Text("The curve controls travel from the previous key. Snap holds the previous position until this key. Brightness and color use existing cues.")
                .font(.caption).foregroundStyle(.secondary)
            HStack {
                Button("Seek") { session.seekPlayback(to: key.time) }
                Button("Duplicate") { session.duplicateHeadPosition(at: session.transport.elapsed(at: ProcessInfo.processInfo.systemUptime)) }
                Button("Delete", role: .destructive) { session.deleteHeadPosition(key.id) }
            }
            if session.lightingSimulation.overrides[key.fixtureID] != nil {
                Text("A manual override is active.").font(.caption).foregroundStyle(.orange)
                Button("Release Manual Override") { session.clearSelectedLightingOverrides() }
            }
            Button("Capture Position at Playhead") { session.captureHeadPositions(at: session.transport.elapsed(at: ProcessInfo.processInfo.systemUptime)) }
        }
    }
}
