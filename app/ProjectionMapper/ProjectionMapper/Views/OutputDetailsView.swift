import SwiftUI

struct OutputDetailsView: View {
    let output: OutputSelectionState
    let refreshDisplays: () -> Void

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
                detail("Reported refresh", "Not applicable")
            }
            Text(output.statusText).font(.caption).foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            Button("Refresh Displays", action: refreshDisplays)
            Text("Output window arrives in v1.03.").font(.caption).foregroundStyle(.secondary)
        }
    }
    private func detail(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(label).foregroundStyle(.secondary)
            Text(value).textSelection(.enabled)
        }.font(.caption)
    }
}
