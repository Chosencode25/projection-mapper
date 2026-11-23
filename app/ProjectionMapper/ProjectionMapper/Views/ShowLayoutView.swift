import AppKit
import SwiftUI

struct LayoutRolesView: View {
    let session: EditorSession
    @Environment(\.dismiss) private var dismiss
    @State private var roles: [LayoutRole]
    @State private var selected: UUID?
    @State private var message: String?
    private let targets: [LayoutTarget]

    init(session: EditorSession) {
        self.session = session
        let initial = session.project.savedLayoutRoles
        _roles = State(initialValue: initial)
        _selected = State(initialValue: initial.first?.id)
        targets = session.project.layoutTargets
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Layout Roles").font(.title2.bold())
            Text("Name and order the surfaces, objects, and fixtures that serve the same role. A target can belong to several roles.")
                .foregroundStyle(.secondary)
            HStack(spacing: 14) {
                VStack(alignment: .leading) {
                    List(roles, selection: $selected) { role in
                        Text(role.name.isEmpty ? "Untitled Role" : role.name).tag(role.id)
                    }
                    HStack {
                        Button("Add Role", systemImage: "plus") {
                            let role = LayoutRole(name: "")
                            roles.append(role)
                            selected = role.id
                        }.disabled(roles.count >= 128)
                        Button("Remove", role: .destructive) {
                            roles.removeAll { $0.id == selected }
                            selected = roles.first?.id
                        }.disabled(selected == nil)
                    }
                }.frame(width: 210)
                Divider()
                if let index = roles.firstIndex(where: { $0.id == selected }) {
                    editor(index)
                } else {
                    ContentUnavailableView("Select a Role", systemImage: "tag")
                }
            }.frame(minHeight: 300)
            if let message { Text(message).foregroundStyle(.orange) }
            HStack {
                Spacer()
                Button("Cancel") { dismiss() }.keyboardShortcut(.cancelAction)
                Button("Save Roles") {
                    do { try session.saveLayoutRoles(roles, basedOn: targets); dismiss() }
                    catch { message = error.localizedDescription }
                }.keyboardShortcut(.defaultAction)
            }
        }.padding(20).frame(width: 740, height: 500)
    }

    private func editor(_ index: Int) -> some View {
        let members = roles[index].targets
        let available = targets.filter { !members.contains($0.id) }
        let groups = Set(available.map(\.group).filter { !$0.isEmpty }).sorted()
        return VStack(alignment: .leading, spacing: 8) {
            TextField("Role name", text: $roles[index].name, prompt: Text("Roof, Windows, Front Lights…"))
            List(Array(members.enumerated()), id: \.element) { offset, id in
                HStack {
                    Text(targets.first { $0.id == id }?.displayName ?? "Unavailable Target").lineLimit(1)
                    Spacer()
                    Button("Move Up", systemImage: "arrow.up") { roles[index].targets.swapAt(offset, offset - 1) }
                        .disabled(offset == 0)
                    Button("Move Down", systemImage: "arrow.down") { roles[index].targets.swapAt(offset, offset + 1) }
                        .disabled(offset + 1 == members.count)
                    Button("Remove Target", systemImage: "minus.circle") { roles[index].targets.remove(at: offset) }
                }.labelStyle(.iconOnly).buttonStyle(.borderless)
            }
            Menu("Add Targets") {
                if !groups.isEmpty {
                    Menu("Fixture Groups") {
                        ForEach(groups, id: \.self) { group in
                            Button(group) { roles[index].targets += available.filter { $0.group == group }.map(\.id) }
                        }
                    }
                    Divider()
                }
                ForEach(available) { target in
                    Button("\(target.displayName) · \(target.kind.label)") { roles[index].targets.append(target.id) }
                }
            }.fixedSize().disabled(available.isEmpty)
        }.textFieldStyle(.roundedBorder)
    }
}

struct ApplyShowLayoutView: View {
    let session: EditorSession
    let openCopy: (URL) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var source: ProjectDocument?
    @State private var sourceURL: URL?
    @State private var plan: ShowLayoutPlan?
    @State private var assignments: ShowLayoutPlan.Assignments = [:]
    @State private var selecting = false
    @State private var job: Task<Void, Never>?
    @State private var message: String?
    @State private var savedURL: URL?
    private let receiving: ProjectDocument

    init(session: EditorSession, openCopy: @escaping (URL) -> Void) {
        self.session = session
        self.openCopy = openCopy
        receiving = session.document
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Apply Show to This Layout").font(.title2.bold())
            HStack {
                LabeledContent("Receiving layout", value: receiving.project.name)
                Spacer()
                Button(source == nil ? "Choose Source Show…" : "Choose Another Show…", action: chooseSource)
                    .disabled(selecting || job != nil || savedURL != nil)
            }
            if let savedURL {
                ContentUnavailableView("Show Copy Saved", systemImage: "checkmark.circle",
                                       description: Text(savedURL.lastPathComponent))
                Spacer(minLength: 0)
            } else if let source, let plan {
                Text("Review destinations for \(source.project.name). Select multiple destinations to repeat programming, or explicitly skip a target.")
                    .foregroundStyle(.secondary)
                List(plan.source) { target in
                    assignmentRow(target, plan: plan)
                }.frame(minHeight: 260)
                HStack {
                    let unresolved = plan.source.filter { assignments[$0.id] == nil }
                    Text(unresolved.isEmpty ? "Every target reviewed" : "\(unresolved.count) awaiting assignment")
                        .foregroundStyle(.secondary)
                    Spacer()
                    if !unresolved.isEmpty {
                        Button("Skip Unassigned") { for target in unresolved { assignments[target.id] = [] } }
                    }
                    Button("Reset Suggestions") { assignments = plan.suggestions }
                }.disabled(job != nil)
                Text("The copy uses this layout’s mapping and fixture patch with the source show’s programming. Chase length can change when the number of targets changes.")
                    .font(.caption).foregroundStyle(.secondary)
            } else {
                ContentUnavailableView("Choose a Saved Show", systemImage: "doc.on.doc",
                                       description: Text("Its song, projection, and lighting will be copied to a new project using this layout."))
            }
            if let message { Text(message).foregroundStyle(.orange) }
            HStack {
                if job != nil { ProgressView().controlSize(.small); Text("Saving a separate show…").foregroundStyle(.secondary) }
                Spacer()
                if let savedURL {
                    Button("Done") { dismiss() }.keyboardShortcut(.cancelAction)
                    Button("Open Copy") { openCopy(savedURL); dismiss() }.keyboardShortcut(.defaultAction)
                } else {
                    Button("Cancel") { if let job { job.cancel() } else { dismiss() } }.keyboardShortcut(.cancelAction)
                    Button("Save Show Copy…", action: chooseDestination).keyboardShortcut(.defaultAction)
                        .disabled(plan == nil || plan?.issue(assignments) != nil || job != nil || selecting)
                }
            }
        }.padding(20).frame(width: 780, height: 540).interactiveDismissDisabled(job != nil)
            .onDisappear { job?.cancel() }
    }

    private func assignmentRow(_ target: LayoutTarget, plan: ShowLayoutPlan) -> some View {
        let roles = plan.sourceRoles.filter { $0.targets.contains(target.id) }.map(\.name).joined(separator: ", ")
        let selected = assignments[target.id]
        let choices = plan.choices(for: target, assignments: assignments)
        let claimed = Set(assignments.filter { $0.key != target.id }.values.flatMap { $0 })
        let labels = (selected ?? []).compactMap { id in choices.first { $0.id == id }?.displayName }
        return HStack {
            VStack(alignment: .leading) {
                Text(target.displayName).lineLimit(1)
                Text([target.kind.label, roles].filter { !$0.isEmpty }.joined(separator: " · "))
                    .font(.caption).foregroundStyle(.secondary).lineLimit(1)
            }.frame(maxWidth: .infinity, alignment: .leading)
            Menu {
                Button("Skip This Target") { assign([], to: target, plan: plan) }
                ForEach(choices) { choice in
                    Button {
                        var updated = assignments[target.id] ?? []
                        if updated.contains(choice.id) { updated.removeAll { $0 == choice.id } }
                        else { updated.append(choice.id) }
                        assign(updated.isEmpty ? nil : updated, to: target, plan: plan)
                    } label: {
                        if selected?.contains(choice.id) == true { Label(choice.displayName, systemImage: "checkmark") }
                        else { Text(choice.displayName) }
                    }.disabled(claimed.contains(choice.id))
                }
            } label: {
                Text(selected?.isEmpty == true ? "Skipped" : labels.isEmpty ? "Choose Destinations" : labels.joined(separator: ", "))
                    .lineLimit(1)
            }.frame(width: 315, alignment: .trailing).disabled(job != nil)
        }
    }

    private func assign(_ targets: [LayoutTargetID]?, to source: LayoutTarget, plan: ShowLayoutPlan) {
        assignments[source.id] = targets
        for child in plan.source where child.parentID == source.id.id && source.kind == .object {
            let valid = Set(plan.choices(for: child, assignments: assignments).map(\.id))
            if let existing = assignments[child.id], !Set(existing).isSubset(of: valid) {
                assignments.removeValue(forKey: child.id)
            }
        }
        message = nil
    }

    private func chooseSource() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [ProjectPackageStore.contentType]
        panel.allowsMultipleSelection = false
        selecting = true
        panel.begin { response in
            selecting = false
            guard response == .OK, let url = panel.url else { return }
            do {
                let document = try ProjectPackageStore().read(url)
                let next = ShowLayoutPlan(show: document.project, layout: receiving.project)
                source = document
                sourceURL = url
                plan = next
                assignments = next.suggestions
                message = nil
            } catch { message = error.localizedDescription }
        }
    }

    private func chooseDestination() {
        guard let source, let sourceURL, let plan, plan.issue(assignments) == nil else { return }
        let panel = NSSavePanel()
        panel.allowedContentTypes = [ProjectPackageStore.contentType]
        panel.nameFieldStringValue = String("\(source.project.name) on \(receiving.project.name)".prefix(80))
        selecting = true
        panel.begin { response in
            selecting = false
            guard response == .OK, let destination = panel.url else { return }
            guard session.document == receiving, session.canEditEffectPack else {
                message = "The receiving project changed. Reopen this screen and review the matches again."
                return
            }
            let chosen = assignments
            let photo = receiving.project.referencePhoto.flatMap { session.playgroundImageFiles[$0.assetID] }
            let name = String(destination.deletingPathExtension().lastPathComponent.prefix(80))
            message = nil
            job = Task { @MainActor in
                defer { job = nil }
                do {
                    let sourceBytes = try ProjectCodec.encode(source)
                    let layoutBytes = try ProjectCodec.encode(receiving)
                    let worker = Task.detached(priority: .userInitiated) {
                        let show = try ProjectCodec.decode(sourceBytes)
                        let layout = try ProjectCodec.decode(layoutBytes)
                        let result = try ShowLayoutCopy.create(show: show, layout: layout, name: name, assignments: chosen)
                        try ShowLayoutCopy.write(result, source: sourceURL, reviewed: show, photo: photo, to: destination)
                    }
                    try await withTaskCancellationHandler { try await worker.value } onCancel: { worker.cancel() }
                    savedURL = destination
                } catch is CancellationError {
                    message = "Save canceled."
                } catch {
                    message = error.localizedDescription
                }
            }
        }
    }
}
