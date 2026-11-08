import SwiftUI

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
                Button("Stop Fixtures") { simulation.stop(); session.refreshLighting() }
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
                Text("This controller will show intended values without sending them.").foregroundStyle(.secondary)
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

private struct FixturePatchEditor: View {
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

private struct FixturePreview: View {
    let session: EditorSession
    @State private var editing = false
    @State private var draft: PlacementEdit?

    private struct PlacementEdit {
        var id: UUID
        var placement: FixturePreviewPlacement
    }

    private let colors: [Color] = [
        .white, .red, .green, .blue, .yellow, .orange, .cyan, .pink,
        .purple, .orange, .mint, .teal, .red
    ]

    var body: some View {
        let fixtures = session.project.lighting.fixtures
        let reports = session.lightingSimulation.reports
        let outputs = Dictionary(uniqueKeysWithValues: reports.values.flatMap { report in
            report.fixtures.map { ($0.id, $0.effective) }
        })
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("Fixture Preview").font(.headline)
                Text("Simulated output · schematic").font(.caption).foregroundStyle(.secondary)
                Spacer()
                Toggle("Edit Placement", isOn: $editing).toggleStyle(.switch).controlSize(.small)
                    .disabled(fixtures.isEmpty)
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
                            let output = outputs[fixture.id] ?? fixture.kind.dark
                            draw(output: active ? output : output.darkened,
                                 placement: placement(for: fixture, index: index), in: context, size: size)
                        }
                    }.accessibilityHidden(true)

                    ForEach(Array(fixtures.enumerated()), id: \.element.id) { index, fixture in
                        let location = placement(for: fixture, index: index)
                        let state = outputs[fixture.id] ?? fixture.kind.dark
                        let status = reports[fixture.controllerID]?.status
                        let active = status == .sent || status == .ready
                        marker(fixture.name, icon: icon(for: fixture.kind),
                               detail: active ? state.label : (status?.rawValue ?? "No output"),
                               fixture: fixture, placement: location, endpoint: false, size: size)
                        if editing, location.stripEnd != nil {
                            marker("Strip end", icon: "circle", detail: fixture.name,
                                   fixture: fixture, placement: location, endpoint: true, size: size)
                        }
                    }
                    if fixtures.isEmpty {
                        Text("Add fixtures in Setup & Monitor to see them here.")
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                }
                .coordinateSpace(name: "fixturePreview")
                .clipShape(RoundedRectangle(cornerRadius: 8))
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
        return fixture.previewPlacement ?? .initial(index: index, kind: fixture.kind)
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
                        placement: FixturePreviewPlacement, endpoint: Bool, size: CGSize) -> some View {
        let anchor = point(endpoint ? placement.stripEnd ?? placement.origin : placement.origin, in: size)
        return Image(systemName: icon)
            .font(.system(size: 12, weight: .semibold))
            .frame(width: 26, height: 26)
            .foregroundStyle(.white)
            .background(.black.opacity(0.8), in: Circle())
            .overlay { Circle().strokeBorder(.white.opacity(editing ? 0.75 : 0.3)) }
            .overlay(alignment: .bottom) {
                if !endpoint {
                    Text(label).font(.caption2).lineLimit(1).fixedSize()
                        .padding(.horizontal, 4).background(.black.opacity(0.65), in: Capsule())
                        .offset(y: 12).allowsHitTesting(false).accessibilityHidden(true)
                }
            }
            .position(anchor)
            .accessibilityLabel("\(label), \(detail)")
            .help("\(label) · \(detail)")
            .gesture(DragGesture(minimumDistance: 1, coordinateSpace: .named("fixturePreview"))
                .onChanged { value in
                    guard editing, size.width > 0, size.height > 0 else { return }
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
