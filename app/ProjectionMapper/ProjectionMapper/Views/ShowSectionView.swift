import AppKit
import SwiftUI

struct ShowSectionView: View {
    let session: EditorSession
    let action: ShowSectionAction
    @Environment(\.dismiss) private var dismiss
    @State private var name = "Show Section"
    @State private var start: Double
    @State private var end: Double
    @State private var insertionTime: Double
    @State private var labels: [UUID: String] = [:]
    @State private var assignments: [UUID: UUID] = [:]
    @State private var source: URL?
    @State private var section: ShowSection?
    @State private var job: Task<Void, Never>?
    @State private var choosing = false
    @State private var message: String?
    @State private var complete = false

    init(session: EditorSession, action: ShowSectionAction) {
        self.session = session
        self.action = action
        let playhead = session.transport.elapsed(at: ProcessInfo.processInfo.systemUptime)
        _start = State(initialValue: playhead)
        _end = State(initialValue: min(3600, playhead + 20))
        _insertionTime = State(initialValue: playhead)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label(action.title, systemImage: action == .save ? "film.stack" : "plus.rectangle.on.rectangle")
                .font(.title2.weight(.semibold))
            if complete {
                Label(action == .save ? "Section saved." : "Section inserted. You can undo it in one step.",
                      systemImage: "checkmark.circle")
            } else if job != nil {
                ProgressView(action == .save ? "Saving section…" : "Preparing section media…")
            } else if action == .save {
                saveForm
            } else {
                insertForm
            }
            if let message {
                Text(message).foregroundStyle(.orange).fixedSize(horizontal: false, vertical: true)
            }
            Divider()
            buttons
        }
        .padding(22).frame(width: 570)
        .interactiveDismissDisabled(job != nil || choosing)
        .onDisappear { job?.cancel() }
    }

    private var capture: Result<ShowSection, any Error> {
        Result { try ShowSection.capture(session.project, name: name, start: start, end: end) }
    }

    private var saveForm: some View {
        VStack(alignment: .leading, spacing: 10) {
            TextField("Section name", text: $name)
            HStack {
                TextField("Start (sec)", value: $start, format: .number.precision(.fractionLength(0...4)))
                Text("to")
                TextField("End (sec)", value: $end, format: .number.precision(.fractionLength(0...4)))
                Text("seconds").foregroundStyle(.secondary)
            }
            switch capture {
            case .success(let draft):
                Text("\(draft.clips.count) clips · \(draft.cues.count) lighting cues")
                    .font(.subheadline)
                Text("Name each role for the job it does, such as Roof or Windows.")
                    .font(.caption).foregroundStyle(.secondary)
                rows(draft.roles) { role in
                    TextField(role.name, text: Binding(get: { labels[role.id] ?? role.name },
                                                       set: { labels[role.id] = $0 }))
                        .accessibilityLabel("Role for \(role.name)")
                }
            case .failure(let error):
                Text(error.localizedDescription).font(.caption).foregroundStyle(.secondary)
            }
        }.disabled(choosing)
    }

    private var insertForm: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(section?.name ?? "Choose a saved show section.").lineLimit(1)
                Spacer()
                Button(section == nil ? "Choose Section…" : "Choose Another…", action: chooseSection)
            }
            if let section {
                HStack {
                    TextField("Insert at (sec)", value: $insertionTime, format: .number.precision(.fractionLength(0...4)))
                    Text("· \(section.duration.formatted(.number.precision(.fractionLength(0...2)))) seconds")
                        .foregroundStyle(.secondary)
                }
                Text("Review the destination for each role. The receiving layout stays in place.")
                    .font(.caption).foregroundStyle(.secondary)
                rows(section.roles) { role in
                    Picker("Destination for \(role.name)", selection: Binding(get: { assignments[role.id] },
                        set: { assignments[role.id] = $0; message = nil })) {
                        Text("Choose a destination").tag(nil as UUID?)
                        ForEach(session.project.sectionTargets.filter { $0.kind == role.kind }) { target in
                            Text(target.displayName).tag(Optional(target.id))
                        }
                    }.labelsHidden().accessibilityLabel("Destination for \(role.name)")
                }
                if let issue = insertionIssue(section) {
                    Text(issue).font(.caption).foregroundStyle(.secondary)
                }
            }
        }.disabled(choosing)
    }

    private func rows<Control: View>(_ targets: [SectionTarget], @ViewBuilder control: @escaping (SectionTarget) -> Control) -> some View {
        ScrollView {
            LazyVStack(spacing: 7) {
                ForEach(targets) { target in
                    HStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(target.name).lineLimit(1)
                            Text([target.kind.label, target.context].compactMap { $0 }.joined(separator: " · "))
                                .font(.caption).lineLimit(1).foregroundStyle(.secondary)
                        }
                        .frame(width: 196, alignment: .leading)
                        control(target)
                    }
                }
            }.padding(.vertical, 2)
        }.frame(height: min(235, CGFloat(targets.count) * 42))
    }

    private var buttons: some View {
        HStack {
            Spacer()
            if complete {
                Button("Done") { dismiss() }.keyboardShortcut(.defaultAction)
            } else if let job {
                Button("Cancel") { job.cancel() }
            } else {
                Button("Cancel") { dismiss() }.keyboardShortcut(.cancelAction)
                if action == .save {
                    Button("Save Section…", action: save).keyboardShortcut(.defaultAction)
                        .disabled(choosing || !validCapture)
                } else {
                    Button("Insert Section", action: insert).keyboardShortcut(.defaultAction)
                        .disabled(choosing || section.map { insertionIssue($0) != nil } != false)
                }
            }
        }
    }

    private var validCapture: Bool {
        guard case .success(let proposed) = capture else { return false }
        return proposed.roles.allSatisfy {
            let label = (labels[$0.id] ?? $0.name).trimmingCharacters(in: .whitespacesAndNewlines)
            return !label.isEmpty && label.count <= 80
        }
    }

    private func insertionIssue(_ section: ShowSection) -> String? {
        guard assignments.count == section.roles.count else { return "Choose a destination for every role." }
        do { _ = try section.insertion(into: session.project, matching: assignments, at: insertionTime); return nil }
        catch { return error.localizedDescription }
    }

    private func save() {
        guard !choosing, validCapture, case .success(var draft) = capture else { return }
        for index in draft.roles.indices {
            if let label = labels[draft.roles[index].id] {
                draft.roles[index].name = label.trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }
        let manifest: Data
        do { manifest = try JSONEncoder().encode(draft) }
        catch { message = error.localizedDescription; return }
        let initial = session.project
        let clipsVideoAssets = draft.videos
        let panel = NSSavePanel()
        panel.title = "Save Show Section"
        panel.allowedContentTypes = [ShowSectionStore.contentType]
        panel.nameFieldStringValue = draft.name.replacingOccurrences(of: "/", with: "-") + ".projectionsection"
        panel.directoryURL = session.documentURL?.deletingLastPathComponent()
        choosing = true
        panel.begin { response in
            choosing = false
            guard response == .OK, let url = panel.url else { return }
            perform {
                guard session.project == initial, session.canEditShowSection else {
                    throw DeliveryError.invalid("The show changed before saving. Review the range and try again.")
                }
                try await session.withDeliverySnapshot { snapshot in
                    for video in clipsVideoAssets {
                        try Task.checkCancellation()
                        _ = try await snapshot.validateVideo(video)
                    }
                    let worker = Task.detached(priority: .userInitiated) {
                        try ShowSectionStore.write(manifest, to: url, images: snapshot.imageFiles, videos: snapshot.videoFiles)
                    }
                    try await withTaskCancellationHandler { try await worker.value } onCancel: { worker.cancel() }
                }
            }
        }
    }

    private func chooseSection() {
        guard !choosing else { return }
        let panel = NSOpenPanel()
        panel.title = "Choose a Show Section"
        panel.allowedContentTypes = [ShowSectionStore.contentType]
        panel.allowsMultipleSelection = false
        choosing = true
        panel.begin { response in
            choosing = false
            guard response == .OK, let url = panel.url else { return }
            do {
                let loaded = try ShowSectionStore.read(url)
                source = url
                section = loaded
                assignments = [:]
                for role in loaded.roles {
                    let possible = session.project.sectionTargets.filter { $0.kind == role.kind }
                    let byID = possible.first { $0.id == role.id }
                    let byName = possible.filter { $0.name.localizedCaseInsensitiveCompare(role.name) == .orderedSame }
                    if let match = byID ?? (byName.count == 1 ? byName.first : nil), !assignments.values.contains(match.id) {
                        assignments[role.id] = match.id
                    }
                }
                message = nil
            } catch { message = error.localizedDescription }
        }
    }

    private func insert() {
        guard let section, let source, insertionIssue(section) == nil else { return }
        let matching = assignments
        let time = insertionTime
        perform { try await session.insertShowSection(section, from: source, matching: matching, at: time) }
    }

    private func perform(_ operation: @escaping @MainActor () async throws -> Void) {
        guard job == nil else { return }
        message = nil
        job = Task { @MainActor in
            defer { job = nil }
            do { try await operation(); complete = true }
            catch where Task.isCancelled { }
            catch { message = error.localizedDescription }
        }
    }
}
