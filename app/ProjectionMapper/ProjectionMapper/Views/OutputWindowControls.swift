import SwiftUI

struct OutputWindowControls: View {
    let session: EditorSession
    let openOutput: () -> Void
    var compact = false

    var body: some View {
        HStack(spacing: 6) {
            Button(action: openOutput) {
                if compact {
                    Image(systemName: session.isOutputOpen ? "macwindow" : "play.rectangle")
                } else {
                    Label(session.isOutputOpen ? "Show Output" : "Open Output", systemImage: "play.rectangle")
                }
            }
            .buttonStyle(.bordered).controlSize(.small)
            .disabled(!session.canOpenOutput)
            .accessibilityLabel("Show Output")
            .help(session.output.destination == .testWindow
                  ? "Show the Test Window (Control–Command–O), restoring it if minimized"
                  : "Open clean fullscreen output on the selected external display")
            Button(action: { session.closeOutput() }) {
                if compact {
                    Image(systemName: "xmark.rectangle")
                } else {
                    Image(systemName: "xmark.rectangle")
                }
            }
            .disabled(!session.isOutputOpen)
            .accessibilityLabel("Close Output")
            .help("Close output and keep the editor and playback controls available")
        }
    }
}
