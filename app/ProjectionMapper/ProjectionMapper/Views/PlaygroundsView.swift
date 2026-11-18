import SwiftUI
import AppKit

struct PlaygroundsView: View {
    enum Mode { case save, choose, manage }
    let mode: Mode
    let current: ProjectDocument
    let currentImages: [UUID: Data]
    let library: PlaygroundLibrary
    let cancel: () -> Void
    let beginShow: (ProjectDocument, [UUID: Data], String, Bool) -> Void
    let saved: (String) -> Void
    @State private var entries: [PlaygroundLibrary.Entry] = []
    @State private var selection: UUID?
    @State private var name = ""
    @State private var note = ""
    @State private var showName = "New Show"
    @State private var chooseSong = true
    @State private var error: String?
    @State private var confirmsUpdate = false
    private var selected: PlaygroundLibrary.Entry? { entries.first { $0.id == selection } }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(mode == .save ? "Save Playground" : mode == .choose ? "New Show from Playground" : "Manage Playgrounds")
                .font(.title2)
            if mode == .save {
                Text("Keep your house mapping and fixture setup for another song.").foregroundStyle(.secondary)
                details
            } else {
                HStack(alignment: .top, spacing: 18) {
                    List(entries, selection: $selection) { entry in
                        VStack(alignment: .leading) {
                            Text(entry.info.name)
                            if !entry.info.note.isEmpty { Text(entry.info.note).font(.caption).foregroundStyle(.secondary).lineLimit(2) }
                        }.tag(entry.id)
                    }.frame(width: 240, height: 230)
                    VStack(alignment: .leading, spacing: 12) {
                        if mode == .choose {
                            TextField("Show name", text: $showName)
                            Toggle("Choose a song after opening", isOn: $chooseSong)
                            Text("An independent show with empty programming. Your saved playground stays unchanged.")
                                .font(.caption).foregroundStyle(.secondary)
                        } else {
                            details
                            HStack {
                                Button("Save Name & Note") { attempt {
                                    guard let selected else { return }
                                    try library.rename(selected.url, name: name, note: note); reload()
                                } }.disabled(selected == nil || !validName(name))
                                Button("Duplicate") { attempt {
                                    guard let selected else { return }
                                    let url = try library.copy(selected.url, name: String(selected.info.name.prefix(75)) + " Copy")
                                    reload(select: try library.read(url).info.id)
                                } }.disabled(selected == nil)
                            }
                            Button("Update from Current Setup…") { confirmsUpdate = true }.disabled(selected == nil)
                            Button("Export Playground…", action: exportSelected).disabled(selected == nil)
                        }
                        Spacer()
                    }.frame(maxWidth: .infinity)
                }
                HStack {
                    Button("Import Playground…", action: importPlayground)
                    if mode == .choose { Button("From Project File…", action: fromProject) }
                }
            }
            if let error { Text(error).font(.caption).foregroundStyle(.red).textSelection(.enabled) }
            HStack {
                Spacer()
                Button(mode == .manage ? "Done" : "Cancel", action: cancel).keyboardShortcut(.cancelAction)
                if mode == .save {
                    Button("Save Playground") { attempt {
                        let document = try PlaygroundExtraction.extract(current, name: name)
                        try library.save(document, info: PlaygroundInfo(name: name, note: note), images: currentImages)
                        saved(name)
                    } }.keyboardShortcut(.defaultAction).disabled(!validName(name) || note.count > 500)
                } else if mode == .choose {
                    Button("Create Show") { attempt {
                        guard let selected else { return }
                        let data = try library.read(selected.url)
                        beginShow(data.document, data.images, showName, chooseSong)
                    } }.keyboardShortcut(.defaultAction).disabled(selected == nil || !validName(showName))
                }
            }
        }.padding(20).frame(width: 680)
        .onAppear { name = String(current.project.name.prefix(80)); reload() }
        .onChange(of: selection) { _, _ in guard mode != .save else { return }; name = selected?.info.name ?? ""; note = selected?.info.note ?? "" }
        .confirmationDialog("Replace this playground's setup?", isPresented: $confirmsUpdate, titleVisibility: .visible) {
            Button("Update Playground") { attempt {
                guard let selected else { return }
                var info = selected.info; info.modifiedAt = .now
                let document = try PlaygroundExtraction.extract(current, name: info.name)
                try library.save(document, info: info, images: currentImages, to: selected.url)
                reload()
            } }
            Button("Cancel", role: .cancel) {}
        } message: { Text("Use the current house mapping and fixture configuration. Existing shows keep their own setup.") }
    }
    private var details: some View {
        VStack(alignment: .leading, spacing: 10) {
            TextField("Playground name", text: $name)
            TextField("Note (optional)", text: $note, axis: .vertical).lineLimit(2...3)
        }
    }
    private func validName(_ value: String) -> Bool {
        !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && value.count <= 80
    }
    private func attempt(_ work: () throws -> Void) {
        do { error = nil; try work() } catch { self.error = error.localizedDescription }
    }
    private func reload(select id: UUID? = nil) {
        attempt {
            entries = try library.entries()
            selection = id ?? selection ?? entries.first?.id
            if !entries.contains(where: { $0.id == selection }) { selection = entries.first?.id }
        }
    }
    private func importPlayground() {
        let panel = NSOpenPanel(); panel.allowedContentTypes = [PlaygroundLibrary.contentType]
        panel.allowsMultipleSelection = false
        panel.begin { response in
            guard response == .OK, let url = panel.url else { return }
            attempt {
                let imported = try library.copy(url)
                reload(select: try library.read(imported).info.id)
            }
        }
    }
    private func fromProject() {
        let panel = NSOpenPanel(); panel.allowedContentTypes = [ProjectPackageStore.contentType]
        panel.allowsMultipleSelection = false
        panel.begin { response in
            guard response == .OK, let url = panel.url else { return }
            attempt {
                let source = try ProjectPackageStore().read(url)
                let document = try PlaygroundExtraction.extract(source, name: showName)
                let images = ImageImportService.loadAssets(document.project, package: url)
                guard images.problems.isEmpty else { throw ProjectFileError.invalid("The reference photo is missing or damaged.") }
                beginShow(document, images.files, showName, chooseSong)
            }
        }
    }
    private func exportSelected() {
        guard let selected else { return }
        let panel = NSSavePanel(); panel.allowedContentTypes = [PlaygroundLibrary.contentType]
        panel.nameFieldStringValue = selected.info.name.replacingOccurrences(of: "/", with: "-") + "." + PlaygroundLibrary.fileExtension
        panel.canCreateDirectories = true
        panel.begin { response in
            guard response == .OK, let url = panel.url else { return }
            attempt { _ = try library.copy(selected.url, to: url) }
        }
    }
}
