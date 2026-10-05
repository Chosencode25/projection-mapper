import SwiftUI

struct ProjectInspectorView: View {
    @Bindable var session: EditorSession
    @FocusState private var nameIsFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
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
            LabeledContent("Output", value: "Not configured")
            Spacer()
            Label("Projects stay in memory in v1.01.", systemImage: "info.circle")
                .font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
        }
        .font(.subheadline)
        .padding(20)
        .frame(maxHeight: .infinity)
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.45))
    }
}
