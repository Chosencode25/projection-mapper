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
                    Text("Open Output")
                }
            }
            .disabled(session.output.destination != .testWindow)
            .accessibilityLabel("Open Output")
            .help(session.output.destination == .testWindow
                  ? "Open the Test Window, or bring it forward if already open"
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
