import SwiftUI

struct OutputWindowControls: View {
    let session: EditorSession
    let openOutput: () -> Void
    var compact = false

    var body: some View {
        HStack(spacing: 10) {
            Button(action: openOutput) {
                if compact {
                    Image(systemName: "macwindow.badge.plus")
                } else {
                    Text(session.output.destination == .testWindow ? "Show Test Output" : "Open Projector Output")
                }
            }
            .disabled(!session.canOpenOutput)
            .accessibilityLabel("Show Output")
            .help(session.output.destination == .testWindow
                  ? "Show the Test Window (Control–Command–O), restoring it if minimized"
                  : "Open clean fullscreen output on the selected external display")
            Button(action: { session.closeOutput() }) {
                if compact {
                    Image(systemName: "xmark.rectangle")
                } else {
                    Text("Close Output")
                }
            }
            .disabled(!session.isOutputOpen)
            .accessibilityLabel("Close Output")
            .help("Close output and keep the editor and playback controls available")
        }
    }
}
