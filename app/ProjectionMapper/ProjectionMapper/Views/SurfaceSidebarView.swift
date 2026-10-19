import SwiftUI

struct SurfaceSidebarView: View {
    let session: EditorSession
    @State private var search = ""
    private var query: String { search.trimmingCharacters(in: .whitespacesAndNewlines) }
    private func matches(_ values: [String]) -> Bool { query.isEmpty || values.contains { $0.localizedCaseInsensitiveContains(query) } }
    private var tags: [String] { Array(Set(session.project.surfaces.flatMap(\.tags) + session.project.objects.flatMap(\.tags))).sorted() }

    var body: some View {
        let faces = session.project.surfaces.filter { face in
            matches([face.name, session.project.object(for: face)?.name ?? ""] + face.tags)
        }
        let objects = session.project.objects.filter { matches([$0.name] + $0.tags) }
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Surfaces").font(.headline)
                Text("\(session.project.surfaces.count)").font(.caption.monospacedDigit()).foregroundStyle(.secondary)
                Spacer()
                Button { session.addSurface() } label: { Image(systemName: "plus") }
                    .buttonStyle(.borderless).help("Add a surface").accessibilityLabel("Add Surface")
            }.padding(.horizontal, 14).padding(.top, 14)
            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass").foregroundStyle(.tertiary)
                TextField("Find a surface…", text: $search).textFieldStyle(.plain).font(.caption)
                    .accessibilityLabel("Find surfaces and objects")
                if !search.isEmpty {
                    Button { search = "" } label: { Image(systemName: "xmark.circle.fill") }
                        .buttonStyle(.plain).foregroundStyle(.secondary).accessibilityLabel("Clear surface search")
                }
            }.padding(8).background(.black.opacity(0.15), in: RoundedRectangle(cornerRadius: 7)).padding(.horizontal, 12)
            HStack {
                Text(session.isGroupingFaces ? "CHECK FACES TO GROUP" : "FRONT FIRST")
                Spacer()
                if !query.isEmpty { Text("\(faces.count) matches") }
            }.font(.system(size: 9, weight: .semibold)).foregroundStyle(.tertiary).padding(.horizontal, 14)
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 4) {
                    ForEach(faces) { face in faceRow(face) }
                    if faces.isEmpty {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(query.isEmpty ? "Your canvas starts here" : "No matching surfaces").font(.subheadline.weight(.medium))
                            Text(query.isEmpty ? "Add a surface or import media using Add in the top bar." : "Try a different name, object or tag.")
                                .font(.caption).foregroundStyle(.secondary)
                        }.padding(10)
                    }
                    if !objects.isEmpty {
                        Text("OBJECTS · SHARED CONTENT").font(.system(size: 9, weight: .semibold)).foregroundStyle(.tertiary)
                            .padding(.horizontal, 10).padding(.top, 14).padding(.bottom, 4)
                        ForEach(objects) { object in objectRow(object) }
                    }
                }.padding(.horizontal, 8).padding(.bottom, 10)
            }
            Divider()
            VStack(alignment: .leading, spacing: 8) {
                if session.isGroupingFaces {
                    Text("Choose the faces that should share one content canvas.").font(.caption).foregroundStyle(.secondary)
                    HStack {
                        Button("Create object (\(session.groupingSelection.count))") { session.createObject() }
                            .buttonStyle(.borderedProminent).disabled(session.groupingSelection.isEmpty)
                        Button("Cancel") { session.cancelGroupingFaces() }.buttonStyle(.borderless)
                    }
                } else {
                    HStack {
                        Button("Group faces…", systemImage: "square.stack.3d.up") { session.beginGroupingFaces() }
                            .disabled(session.project.surfaces.isEmpty)
                        Spacer()
                        Button { session.selectSurface(nil) } label: { Image(systemName: "xmark.circle") }
                            .disabled(session.selectedSurface == nil && session.selectedObject == nil)
                            .help("Deselect surface or object").accessibilityLabel("Deselect")
                        Menu { ForEach(tags, id: \.self) { tag in Button(tag) { session.selectTag(tag) } } }
                            label: { Image(systemName: "tag") }
                            .disabled(tags.isEmpty).help("Select faces by tag").accessibilityLabel("Select by tag")
                    }.buttonStyle(.borderless)
                }
            }.font(.caption).padding(.horizontal, 12).padding(.bottom, 12)
        }
        .frame(maxHeight: .infinity).background(Color(nsColor: .controlBackgroundColor).opacity(0.55))
        .onChange(of: session.project.id) { _, _ in search = "" }
    }

    private func faceRow(_ face: MappingSurface) -> some View {
        let selected = session.selectedSurfaceID == face.id
        let object = session.project.object(for: face)
        return HStack(spacing: 7) {
            if session.isGroupingFaces {
                Toggle("Group \(face.name)", isOn: Binding(get: { session.groupingSelection.contains(face.id) }, set: { _ in session.toggleGrouping(face.id) }))
                    .labelsHidden().toggleStyle(.checkbox)
            }
            Button { session.selectSurface(face.id) } label: {
                HStack(spacing: 8) {
                    Image(systemName: object == nil ? "rectangle.on.rectangle" : "cube")
                        .font(.system(size: 12)).foregroundStyle(selected ? Color.accentColor : Color.secondary)
                        .frame(width: 16)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(face.name).font(.system(size: 12, weight: selected ? .semibold : .medium)).lineLimit(1)
                        Text(object?.name ?? session.project.source(for: face).content.title)
                            .font(.system(size: 10)).foregroundStyle(.secondary).lineLimit(1)
                    }.frame(maxWidth: .infinity, alignment: .leading)
                }.contentShape(Rectangle())
            }.buttonStyle(.plain).help(face.name + (object.map { " · " + $0.name } ?? ""))
            Button {
                if let object, object.isGeometryLocked { session.selectObject(object.id) }
                else { session.setGeometryLocked(!face.layout.isGeometryLocked, faceID: face.id) }
            } label: { Image(systemName: session.project.isGeometryLocked(face) ? "lock.fill" : "lock.open") }
                .buttonStyle(.plain).font(.system(size: 10)).foregroundStyle(.secondary)
                .help(object?.isGeometryLocked == true ? "Inspect the locking object" : "Lock or unlock output corners")
                .accessibilityLabel("Geometry lock for " + face.name)
            Button { session.setVisible(!face.layout.isVisible, faceID: face.id) } label: {
                Image(systemName: face.layout.isVisible ? "eye" : "eye.slash")
            }.buttonStyle(.plain).font(.system(size: 11)).foregroundStyle(.secondary)
                .help(face.layout.isVisible ? "Hide \(face.name)" : "Show \(face.name)")
                .accessibilityLabel("Toggle visibility of \(face.name)")
        }
        .padding(.horizontal, 9).padding(.vertical, 10)
        .background(selected ? Color.accentColor.opacity(0.16) : Color.clear, in: RoundedRectangle(cornerRadius: 8))
        .overlay(alignment: .leading) { if selected { RoundedRectangle(cornerRadius: 2).fill(Color.accentColor).frame(width: 3).padding(.vertical, 8) } }
        .opacity(face.layout.isVisible ? 1 : 0.55)
    }

    private func objectRow(_ object: MappingObject) -> some View {
        let selected = session.selectedObjectID == object.id
        return HStack(spacing: 6) {
            Button { session.selectObject(object.id) } label: {
                VStack(alignment: .leading, spacing: 3) {
                    Label(object.name, systemImage: "cube.fill").font(.system(size: 12, weight: .medium)).lineLimit(1)
                    Text("\(session.project.surfaces.filter { $0.layout.objectID == object.id }.count) connected faces")
                        .font(.system(size: 10)).foregroundStyle(.secondary)
                }.frame(maxWidth: .infinity, alignment: .leading).contentShape(Rectangle())
            }.buttonStyle(.plain).help(object.name)
            Button { session.setGeometryLocked(!object.isGeometryLocked, objectID: object.id) } label: {
                Image(systemName: object.isGeometryLocked ? "lock.fill" : "lock.open")
            }.buttonStyle(.plain).foregroundStyle(.secondary).accessibilityLabel("Geometry lock for " + object.name)
            Button { session.setVisible(!object.isVisible, objectID: object.id) } label: {
                Image(systemName: object.isVisible ? "eye" : "eye.slash")
            }.buttonStyle(.plain).foregroundStyle(.secondary).accessibilityLabel("Toggle visibility of " + object.name)
        }.font(.caption).padding(10)
            .background(selected ? Color.accentColor.opacity(0.16) : Color.white.opacity(0.025), in: RoundedRectangle(cornerRadius: 8))
    }
}
