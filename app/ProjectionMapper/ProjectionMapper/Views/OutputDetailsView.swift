import SwiftUI

struct OutputDetailsView: View {
    let session: EditorSession
    var output: OutputSelectionState { session.output }
    let refreshDisplays: () -> Void
    let openOutput: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("OUTPUT TARGET").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
            OutputSelectorView(output: output)
            Text(output.selectedName).font(.subheadline.weight(.medium)).textSelection(.enabled)
            detail("Render size", output.renderSizeText)
            if let display = output.selectedDisplay {
                detail("Desktop size", display.desktopSizeText)
                detail("Scale", display.scaleText)
                detail("Reported refresh", display.refreshText)
            } else {
                Picker("Test resolution", selection: Binding(
                    get: { output.testResolution },
                    set: { session.setTestResolution($0) }
                )) {
                    ForEach(TestResolution.allCases) { resolution in
                        Text(resolution.label).tag(resolution)
                    }
                }
                .pickerStyle(.menu)
                .labelsHidden()
                .accessibilityLabel("Test resolution")
                .help("Simulated output resolution; independent of the window size")
                detail("Reported refresh", "Not applicable")
            }
            Text(output.statusText).font(.caption).foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            Button("Refresh Displays", action: refreshDisplays)
            OutputWindowControls(session: session, openOutput: openOutput)
            Text(session.testOutput.statusText).font(.caption).foregroundStyle(.secondary)
            Text(output.destination == .testWindow
                 ? "Rectangle test output. Mapping surfaces arrive in v1.05."
                 : "Projector output is deferred. Select Test Window to open output.")
                .font(.caption).foregroundStyle(.secondary)
        }
    }
    private func detail(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(label).foregroundStyle(.secondary)
            Text(value).textSelection(.enabled)
        }.font(.caption)
    }
}
