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
                    Text("Show Output")
                }
            }
            .disabled(session.output.destination != .testWindow)
            .accessibilityLabel("Show Output")
            .help(session.output.destination == .testWindow
                  ? "Show the Test Window (Control–Command–O), restoring it if minimized"
                  : "Select Test Window to open output. Projector output is deferred.")
            Button(action: { session.testOutput.close() }) {
                if compact {
                    Image(systemName: "xmark.rectangle")
                } else {
                    Text("Close Output")
                }
            }
            .disabled(!session.testOutput.isOpen)
            .accessibilityLabel("Close Output")
            .help("Close test output and keep the editor open")
        }
    }
}
