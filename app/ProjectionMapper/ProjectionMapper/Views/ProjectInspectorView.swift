import SwiftUI

struct ProjectInspectorView: View {
    @Bindable var session: EditorSession
    let refreshDisplays: () -> Void
    let openOutput: () -> Void
    @FocusState private var nameIsFocused: Bool

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("PROJECT").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                VStack(alignment: .leading, spacing: 8) {
                    Text("Name").font(.caption).foregroundStyle(.secondary)
                    TextField("Project name", text: Binding(
                        get: { session.project.name },
                        set: { session.renameProject($0) }
                    ))
                    .textFieldStyle(.roundedBorder)
                    .accessibilityLabel("Project name")
                    .focused($nameIsFocused)
                    .onSubmit { session.finishNameEditing(); nameIsFocused = false }
                    .onChange(of: nameIsFocused) { _, focused in
                        if !focused { session.finishNameEditing() }
                    }
                }
                Divider()
                LabeledContent("Surfaces", value: "0")
                Divider()
                OutputDetailsView(session: session, refreshDisplays: refreshDisplays, openOutput: openOutput)
                Spacer()
                Label("Projects stay in memory. Saving arrives in v1.14.", systemImage: "info.circle")
                    .font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            }
            .font(.subheadline)
            .padding(20)
        }
        .frame(maxHeight: .infinity)
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.45))
    }
}
