import SwiftUI

struct SurfaceSidebarView: View {
    let session: EditorSession
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("SURFACES · FRONT FIRST").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                Spacer()
                Button { session.addSurface() } label: { Image(systemName: "plus") }
                    .help("Add Surface").accessibilityLabel("Add Surface")
            }.padding(.horizontal, 12).padding(.top, 16)
            ScrollView {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(session.project.surfaces) { face in
                        HStack(spacing: 6) {
                            Toggle("Group \(face.name)", isOn: Binding(get: { session.groupingSelection.contains(face.id) },
                                set: { _ in session.toggleGrouping(face.id) }))
                                .labelsHidden().toggleStyle(.checkbox).help("Select for grouping")
                            Button { session.selectSurface(face.id) } label: {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(face.name).lineLimit(1)
                                    if let object = session.project.object(for: face) {
                                        Text(object.name).font(.caption2).foregroundStyle(.secondary).lineLimit(1)
                                    }
                                }.frame(maxWidth: .infinity, alignment: .leading).contentShape(Rectangle())
                            }.buttonStyle(.plain)
                            Button { session.setVisible(!face.layout.isVisible, faceID: face.id) } label: {
                                Image(systemName: face.layout.isVisible ? "eye" : "eye.slash")
                            }.buttonStyle(.plain).accessibilityLabel("Toggle visibility of \(face.name)")
                        }
                        .padding(8).background(session.selectedSurfaceID == face.id ? Color.purple.opacity(0.25) : Color.clear)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                    }
                    if session.project.surfaces.isEmpty { Text("No surfaces. Add one to begin.").font(.caption).foregroundStyle(.secondary) }
                    if !session.project.objects.isEmpty {
                        Divider().padding(.vertical, 8)
                        Text("OBJECTS").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                        ForEach(session.project.objects) { object in
                            HStack {
                                Button { session.selectObject(object.id) } label: {
                                    Label(object.name, systemImage: "cube").frame(maxWidth: .infinity, alignment: .leading)
                                }.buttonStyle(.plain)
                                Button { session.setVisible(!object.isVisible, objectID: object.id) } label: {
                                    Image(systemName: object.isVisible ? "eye" : "eye.slash")
                                }.buttonStyle(.plain).accessibilityLabel("Toggle visibility of \(object.name)")
                            }.padding(8).background(session.selectedObjectID == object.id ? Color.purple.opacity(0.25) : Color.clear)
                                .clipShape(RoundedRectangle(cornerRadius: 6))
                        }
                    }
                }.padding(.horizontal, 10)
            }
            VStack(alignment: .leading, spacing: 8) {
                Button("Group checked faces (\(session.groupingSelection.count))") { session.createObject() }
                    .disabled(session.groupingSelection.isEmpty)
                Menu("Select by tag") {
                    ForEach(Array(Set(session.project.surfaces.flatMap(\.tags) + session.project.objects.flatMap(\.tags))).sorted(), id: \.self) { tag in
                        Button(tag) { session.selectTag(tag) }
                    }
                }
                Button("Deselect") { session.selectSurface(nil) }
                    .disabled(session.selectedSurface == nil && session.selectedObject == nil)
            }.font(.caption).padding(12)
        }
        .frame(maxHeight: .infinity).background(Color(nsColor: .controlBackgroundColor).opacity(0.45))
    }
}
