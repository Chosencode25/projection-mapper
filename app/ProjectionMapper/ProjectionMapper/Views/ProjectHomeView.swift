import SwiftUI

struct ProjectHomeView: View {
    let library: ShowLibrary
    let recent: [URL]
    let drafts: [URL]
    let canRecover: Bool
    let open: (URL) -> Void
    let browse: () -> Void
    let new: () -> Void
    let playground: () -> Void
    let demo: () -> Void
    let recover: () -> Void
    @State private var tab = "Projects"
    @State private var selected: URL?
    @State private var filter = ""
    @State private var projectCards: [ProjectCard] = []
    @State private var playlist: ShowPlaylist?
    @State private var schedule: ShowSchedule?

    private struct ProjectCard: Identifiable {
        let url: URL
        let project: MappingProject?
        let isDraft: Bool
        var id: URL { url }
        var name: String { project?.name ?? url.deletingPathExtension().lastPathComponent }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Projection Mapper").font(.largeTitle.bold())
                    Text("Project Home").foregroundStyle(.secondary)
                }
                Spacer()
                Picker("Library section", selection: $tab) {
                    ForEach(["Projects", "Playlists", "Schedules"], id: \.self) { Text($0).tag($0) }
                }.pickerStyle(.segmented).labelsHidden().fixedSize()
            }.padding(24)
            Divider()
            if library.running {
                HStack {
                    Label(library.status, systemImage: "play.rectangle").lineLimit(2)
                    Spacer()
                    Button("Finish Current") { library.finishCurrent() }.disabled(library.stoppingAfterCurrent)
                    Button("Stop Now", role: .destructive) { library.stopNow() }
                }.padding(.horizontal, 24).padding(.vertical, 10)
                Divider()
            }
            switch tab {
            case "Playlists": playlistPage
            case "Schedules": schedulePage
            default: projectsPage
            }
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .onAppear {
            var visited = Set<String>()
            let store = ProjectPackageStore()
            projectCards = (recent + drafts).map(\.standardizedFileURL).filter { visited.insert($0.path).inserted }.map { url in
                ProjectCard(url: url, project: try? store.read(url).project,
                            isDraft: drafts.contains { $0.standardizedFileURL.path == url.path })
            }
            selected = projectCards.first { $0.project != nil }?.url
        }
        .sheet(item: $playlist) { item in
            PlaylistEditor(draft: item, projects: projectCards.filter { $0.project != nil }.map { ($0.url, $0.name) },
                           save: library.put)
        }
        .sheet(item: $schedule) { item in ScheduleEditor(draft: item, playlists: library.playlists, save: library.put) }
    }

    private var projectsPage: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                Button("New Project", systemImage: "plus", action: new).buttonStyle(.borderedProminent)
                Button("Open File…", systemImage: "folder", action: browse)
                Button("From Playground…", action: playground)
                Button("Open Demo", action: demo)
                if canRecover { Button("Recover…", action: recover) }
                Spacer()
                TextField("Find a project", text: $filter).textFieldStyle(.roundedBorder).frame(width: 150)
            }.padding(.horizontal, 24).disabled(library.running)
            ScrollView {
                let cards = projectCards.filter { filter.isEmpty || $0.name.localizedCaseInsensitiveContains(filter) }
                if cards.isEmpty {
                    ContentUnavailableView(filter.isEmpty ? "No recent projects" : "No matching projects",
                                           systemImage: "rectangle.on.rectangle",
                                           description: Text(filter.isEmpty ? "Create a project or open a saved show." : "Try another project name."))
                        .frame(maxWidth: .infinity, minHeight: 280)
                } else {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 178, maximum: 260), spacing: 16)], spacing: 16) {
                        ForEach(cards) { card in projectCard(card) }
                    }.padding(.horizontal, 24).padding(.vertical, 4)
                }
            }
            Divider()
            HStack {
                Text(projectCards.first { $0.id == selected }?.name ?? "Select a project").lineLimit(1).foregroundStyle(.secondary)
                Spacer()
                Button("Open Project") { if let selected { open(selected) } }
                    .buttonStyle(.borderedProminent).keyboardShortcut(.defaultAction)
                    .disabled(library.running || !projectCards.contains { $0.id == selected && $0.project != nil })
            }.padding(.horizontal, 24).padding(.bottom, 16)
        }.padding(.top, 14)
    }

    private func projectCard(_ card: ProjectCard) -> some View {
        let active = selected == card.url
        return VStack(alignment: .leading, spacing: 7) {
            Canvas { context, size in
                let content = CGRect(origin: .zero, size: size).insetBy(dx: 16, dy: 12)
                let scene = card.project?.renderScene
                for (index, surface) in (scene?.surfaces ?? []).prefix(60).enumerated() {
                    let corners = surface.geometry
                    var path = Path()
                    for (pointIndex, value) in [corners.topLeft, corners.topRight, corners.bottomRight, corners.bottomLeft].enumerated() {
                        let point = CGPoint(x: content.minX + CGFloat(value.x) * content.width,
                                            y: content.minY + CGFloat(value.y) * content.height)
                        if pointIndex == 0 { path.move(to: point) } else { path.addLine(to: point) }
                    }
                    path.closeSubpath()
                    let tint = Color(hue: 0.54 + Double(index % 8) * 0.047, saturation: 0.66, brightness: 0.86)
                    context.fill(path, with: .color(tint.opacity(0.34)))
                    context.stroke(path, with: .color(tint), lineWidth: 1)
                }
            }.frame(height: 100)
                .background(LinearGradient(colors: [Color(red: 0.09, green: 0.17, blue: 0.26), Color(red: 0.06, green: 0.10, blue: 0.18)],
                                           startPoint: .topLeading, endPoint: .bottomTrailing))
                .overlay {
                    if card.project?.surfaces.isEmpty != false {
                        Image(systemName: card.project == nil ? "exclamationmark.triangle" : "light.beacon.max")
                            .font(.title).foregroundStyle(.white.opacity(0.65))
                    }
                }.clipShape(RoundedRectangle(cornerRadius: 8))
                .accessibilityHidden(true)
            Text(card.name).font(.headline).lineLimit(1)
            Text(card.project.map { project in
                (card.isDraft ? "Draft · " : "") + (project.song?.name ?? "\(project.surfaces.count) surfaces · \(project.lighting.fixtures.count) fixtures")
            } ?? "File missing or unreadable").font(.caption).foregroundStyle(.secondary).lineLimit(1)
        }.padding(9).background(active ? Color.accentColor.opacity(0.12) : Color.secondary.opacity(0.07), in: RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(active ? Color.accentColor : .clear, lineWidth: 2))
            .contentShape(Rectangle())
            .onTapGesture(count: 2) { if !library.running, card.project != nil { open(card.url) } }
            .onTapGesture { selected = card.url }
            .accessibilityElement(children: .combine)
            .accessibilityAddTraits(.isButton)
            .accessibilityAction { if !library.running, card.project != nil { open(card.url) } }
    }

    private var playlistPage: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Playlists").font(.title2.bold())
                Spacer()
                Button("New Playlist", systemImage: "plus") { playlist = ShowPlaylist() }
                    .disabled(library.running || library.scheduled || !library.storageAvailable)
            }
            if library.playlists.isEmpty {
                ContentUnavailableView("No playlists", systemImage: "list.number",
                                       description: Text("Add saved projects and arrange the order they should play."))
            }
            List(library.playlists) { item in
                HStack {
                    VStack(alignment: .leading) {
                        Text(item.name).font(.headline)
                        Text("\(item.entries.count) items · \(item.repeats) passes").foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button("Edit") { playlist = item }.disabled(library.running || library.scheduled)
                    Button("Play") { library.start(item) }.buttonStyle(.borderedProminent).disabled(library.running)
                    Button("Remove", role: .destructive) { library.removePlaylist(item.id) }
                        .disabled(library.running || library.scheduled || library.schedules.contains { $0.playlistID == item.id })
                }.padding(.vertical, 5)
            }.listStyle(.inset)
            Text(library.status).foregroundStyle(.secondary)
        }.padding(24)
    }

    private var schedulePage: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Schedules").font(.title2.bold())
                Spacer()
                if library.scheduled { Button("Disarm") { library.disarmSchedules() } }
                else {
                    Button("Arm Schedules") { library.armSchedules() }.buttonStyle(.borderedProminent)
                        .disabled(library.running || !library.schedules.contains(where: \.enabled))
                }
                Button("New Schedule", systemImage: "plus") {
                    if let id = library.playlists.first?.id { schedule = ShowSchedule(playlistID: id) }
                }.disabled(library.running || library.scheduled || library.playlists.isEmpty)
            }
            Text("Keep the app open and the Mac awake. For simultaneous starts, higher priority wins. A running show keeps its slot.")
                .font(.callout).foregroundStyle(.secondary)
            List(library.schedules) { rule in
                HStack {
                    VStack(alignment: .leading) {
                        Text(rule.name).font(.headline)
                        let next = rule.occurrences(around: .now, days: 0...7).first { $0.starts > .now }
                        let overlap = library.schedules.contains { $0.id != rule.id && rule.conflicts(with: $0, around: .now) }
                        Text([rule.enabled ? "Enabled" : "Disabled", rule.timeZoneID, "Priority \(rule.priority)",
                              overlap ? "Overlaps another schedule this week" : nil,
                              next.map { "Next: \($0.starts.formatted(date: .abbreviated, time: .shortened))" }].compactMap { $0 }.joined(separator: " · "))
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button("Edit") { schedule = rule }.disabled(library.scheduled || library.running)
                    Button("Remove", role: .destructive) { library.removeSchedule(rule.id) }.disabled(library.scheduled || library.running)
                }.padding(.vertical, 5)
            }.listStyle(.inset)
            Text(library.status).foregroundStyle(.secondary)
        }.padding(24)
    }
}

private struct PlaylistEditor: View {
    @State var draft: ShowPlaylist
    let projects: [(URL, String)]
    let save: (ShowPlaylist) -> Void
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Playlist").font(.title2.bold())
            TextField("Name", text: $draft.name)
            HStack {
                Stepper("Passes: \(draft.repeats)", value: $draft.repeats, in: 1...20)
                Toggle("Shuffle shows", isOn: $draft.shuffle)
                Spacer()
                Menu("Add Project") {
                    ForEach(projects, id: \.0) { url, name in Button(name) { append(url) } }
                    Button("Choose File…") {
                        let panel = NSOpenPanel()
                        panel.allowedContentTypes = [ProjectPackageStore.contentType]
                        if panel.runModal() == .OK, let url = panel.url { append(url) }
                    }
                }.disabled(draft.entries.count >= 100)
            }
            Text("Intros play first and outros last. Enter 0 seconds to use the show length. A still intermission defaults to 10 seconds.")
                .foregroundStyle(.secondary).font(.caption)
            List {
                ForEach($draft.entries) { $entry in
                    HStack {
                        Text(projects.first { $0.0.path == entry.path }?.1 ?? entry.url.deletingPathExtension().lastPathComponent)
                            .lineLimit(1).frame(maxWidth: .infinity, alignment: .leading)
                        Picker("Role", selection: $entry.role) {
                            ForEach(ShowPlaylist.Entry.Role.allCases) { Text($0.rawValue).tag($0) }
                        }.labelsHidden().frame(width: 115)
                        TextField("Seconds", value: $entry.seconds, format: .number.grouping(.never)).frame(width: 62)
                        Button { move(entry.id, by: -1) } label: { Image(systemName: "arrow.up") }.accessibilityLabel("Move earlier")
                        Button { move(entry.id, by: 1) } label: { Image(systemName: "arrow.down") }.accessibilityLabel("Move later")
                        Button(role: .destructive) { draft.entries.removeAll { $0.id == entry.id } } label: { Image(systemName: "minus.circle") }
                    }.buttonStyle(.borderless)
                }
            }
            HStack {
                Spacer()
                Button("Cancel") { dismiss() }.keyboardShortcut(.cancelAction)
                Button("Save Playlist") { save(draft); dismiss() }.keyboardShortcut(.defaultAction).disabled(!draft.isValid)
            }
        }.padding(22).frame(width: 680, height: 410).textFieldStyle(.roundedBorder)
    }
    func append(_ url: URL) { if draft.entries.count < 100 { draft.entries.append(.init(path: url.path)) } }
    func move(_ id: UUID, by offset: Int) {
        guard let index = draft.entries.firstIndex(where: { $0.id == id }), draft.entries.indices.contains(index + offset) else { return }
        draft.entries.swapAt(index, index + offset)
    }
}

private struct ScheduleEditor: View {
    @State var draft: ShowSchedule
    let playlists: [ShowPlaylist]
    let save: (ShowSchedule) -> Void
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Schedule").font(.title2.bold())
            Form {
                TextField("Name", text: $draft.name)
                Picker("Playlist", selection: $draft.playlistID) { ForEach(playlists) { Text($0.name).tag($0.id) } }
                Toggle("Enabled", isOn: $draft.enabled)
                Picker("Time zone", selection: $draft.timeZoneID) {
                    ForEach(Array(Set(TimeZone.knownTimeZoneIdentifiers + [draft.timeZoneID])).sorted(), id: \.self) { Text($0).tag($0) }
                }
                HStack {
                    timeFields("Start", minute: $draft.startMinute)
                    timeFields("End", minute: $draft.endMinute)
                }
                HStack {
                    ForEach(1...7, id: \.self) { day in
                        Toggle(Calendar.current.shortWeekdaySymbols[day - 1], isOn: Binding(
                            get: { draft.weekdays.contains(day) },
                            set: { if $0 { draft.weekdays.insert(day) } else { draft.weekdays.remove(day) } }
                        )).toggleStyle(.checkbox)
                    }
                }
                TextField("First date (YYYY-MM-DD)", text: $draft.firstDate)
                TextField("Last date (YYYY-MM-DD)", text: $draft.lastDate)
                TextField("Skip dates (comma separated)", text: $draft.excludedDates)
                Stepper("Priority: \(draft.priority)", value: $draft.priority, in: -100...100)
                Toggle("Finish the current item at cutoff", isOn: $draft.finishCurrent)
            }
            if !draft.isValid { Text("Check times, dates, and selected weekdays.").foregroundStyle(.orange).font(.caption) }
            HStack {
                Spacer()
                Button("Cancel") { dismiss() }.keyboardShortcut(.cancelAction)
                Button("Save Schedule") { save(draft); dismiss() }.keyboardShortcut(.defaultAction).disabled(!draft.isValid)
            }
        }.padding(22).frame(width: 580)
    }

    private func timeFields(_ title: String, minute: Binding<Int>) -> some View {
        HStack {
            Text(title)
            Picker("Hour", selection: Binding(get: { minute.wrappedValue / 60 },
                set: { minute.wrappedValue = $0 * 60 + minute.wrappedValue % 60 })) {
                ForEach(0..<24, id: \.self) { Text(String(format: "%02d", $0)).tag($0) }
            }.labelsHidden()
            Text(":")
            Picker("Minute", selection: Binding(get: { minute.wrappedValue % 60 },
                set: { minute.wrappedValue = (minute.wrappedValue / 60) * 60 + $0 })) {
                ForEach(0..<60, id: \.self) { Text(String(format: "%02d", $0)).tag($0) }
            }.labelsHidden()
        }
    }
}
