import AppKit
import SwiftUI

struct EffectPackView: View {
    let session: EditorSession
    let action: EffectPackAction
    @Environment(\.dismiss) private var dismiss
    @State private var name: String
    @State private var pack: EffectPack?
    @State private var selected: Set<EffectPackItem.ID>
    @State private var replacements: [EffectPackItem.ID: EffectPack.ImportChoice] = [:]
    @State private var choosing = false
    @State private var failure: String?
    @State private var result: String?

    init(session: EditorSession, action: EffectPackAction) {
        self.session = session
        self.action = action
        _name = State(initialValue: String("\(session.project.name) Effects".prefix(80)))
        _selected = State(initialValue: action == .export ? Set(session.project.effectPackItems.map(\.id)) : [])
    }

    private var catalog: [EffectPackItem] { session.project.effectPackItems }
    private var items: [EffectPackItem] { action == .export ? catalog : (pack?.items ?? []) }
    private var hasSelected: Bool { items.contains { selected.contains($0.id) } }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label(action.title, systemImage: "swatchpalette").font(.title2.weight(.semibold))
            if let result {
                Label(result, systemImage: "checkmark.circle")
            } else {
                content.disabled(choosing)
            }
            if let failure {
                Text(failure).foregroundStyle(.orange).fixedSize(horizontal: false, vertical: true)
            }
            Divider()
            buttons
        }
        .padding(22).frame(width: 620)
        .interactiveDismissDisabled(choosing)
    }

    private var content: some View {
        VStack(alignment: .leading, spacing: 10) {
            if action == .export {
                TextField("Pack name", text: $name)
                if items.isEmpty {
                    Text("Save a palette or effect preset in this show first.").foregroundStyle(.secondary)
                }
            } else {
                HStack {
                    Text(pack?.name ?? "Choose a pack to review.").lineLimit(1)
                    Spacer()
                    Button(pack == nil ? "Choose Pack…" : "Choose Another…", action: choosePack)
                }
                if pack != nil {
                    Text("Matching names start with Keep Both. Replacing a palette updates colors linked to matching slots.")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
            if !items.isEmpty {
                HStack {
                    Text("\(selected.intersection(Set(items.map(\.id))).count) selected").foregroundStyle(.secondary)
                    Spacer()
                    Button("Select All") { selected = Set(items.map(\.id)); failure = nil }
                    Button("Select None") { selected = []; failure = nil }
                }.font(.caption)
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 12) {
                        ForEach(EffectPackItem.Kind.allCases) { kind in
                            let group = items.filter { $0.id.kind == kind }
                            if !group.isEmpty {
                                Text(kind.rawValue).font(.headline)
                                ForEach(group) { row($0) }
                            }
                        }
                    }.padding(.vertical, 3)
                }.frame(height: min(310, 78 + CGFloat(items.count) * 36))
            }
        }
    }

    private func row(_ item: EffectPackItem) -> some View {
        let matches = pack?.matches(for: item, in: catalog) ?? []
        return HStack(spacing: 12) {
            Toggle(isOn: Binding(get: { selected.contains(item.id) }, set: { value in
                if value { selected.insert(item.id) } else { selected.remove(item.id) }
                failure = nil
            })) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(item.name).lineLimit(1)
                    Text(item.detail).font(.caption).foregroundStyle(.secondary)
                }
            }.toggleStyle(.checkbox)
            Spacer()
            if !matches.isEmpty {
                Picker("Name conflict for \(item.name)", selection: Binding(get: { replacements[item.id] ?? .keepBoth },
                    set: { replacements[item.id] = $0; failure = nil })) {
                    Text("Keep Both").tag(EffectPack.ImportChoice.keepBoth)
                    ForEach(Array(matches.enumerated()), id: \.element.id) { index, match in
                        let suffix = matches.count > 1 ? " (\(index + 1))" : ""
                        Text("Replace \(match.name)\(suffix)").tag(EffectPack.ImportChoice.replace(match.id))
                    }
                }.labelsHidden().frame(maxWidth: 230).disabled(!selected.contains(item.id))
            }
        }
    }

    private var buttons: some View {
        HStack {
            Spacer()
            if result != nil {
                Button("Done") { dismiss() }.keyboardShortcut(.defaultAction)
            } else {
                Button("Cancel") { dismiss() }.keyboardShortcut(.cancelAction)
                if action == .export {
                    Button("Export Pack…", action: exportPack).keyboardShortcut(.defaultAction)
                        .disabled(choosing || !hasSelected || EffectPack.nameKey(name).isEmpty || name.count > 80)
                } else {
                    Button("Import Selected", action: importSelected).keyboardShortcut(.defaultAction)
                        .disabled(choosing || !hasSelected)
                }
            }
        }
    }

    private func exportPack() {
        let title = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let snapshot = EffectPack(name: title, items: catalog.filter { selected.contains($0.id) })
        let panel = NSSavePanel()
        panel.title = action.title
        panel.allowedContentTypes = [EffectPackStore.contentType]
        panel.nameFieldStringValue = title.replacingOccurrences(of: "/", with: "-") + ".projectionpack"
        panel.directoryURL = session.documentURL?.deletingLastPathComponent()
        failure = nil
        choosing = true
        panel.begin { response in
            choosing = false
            guard response == .OK, let url = panel.url else { return }
            do {
                try EffectPackStore.write(snapshot, to: url)
                result = "Saved \(url.lastPathComponent)"
            } catch { failure = error.localizedDescription }
        }
    }

    private func choosePack() {
        let panel = NSOpenPanel()
        panel.title = "Choose an Effect & Palette Pack"
        panel.allowedContentTypes = [EffectPackStore.contentType]
        panel.allowsMultipleSelection = false
        failure = nil
        choosing = true
        panel.begin { response in
            choosing = false
            guard response == .OK, let url = panel.url else { return }
            do {
                let loaded = try EffectPackStore.read(url)
                pack = loaded
                selected = Set(loaded.items.map(\.id))
                replacements = [:]
            } catch { failure = error.localizedDescription }
        }
    }

    private func importSelected() {
        guard let pack else { return }
        let choices = Dictionary(uniqueKeysWithValues: pack.items.filter { selected.contains($0.id) }.map {
            ($0.id, replacements[$0.id] ?? .keepBoth)
        })
        do {
            try session.importEffectPack(pack, choices: choices)
            failure = nil
            result = "Imported \(choices.count) \(choices.count == 1 ? "item" : "items")."
        } catch { failure = error.localizedDescription }
    }
}
