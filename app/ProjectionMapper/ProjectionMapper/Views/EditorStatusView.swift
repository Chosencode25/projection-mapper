import SwiftUI

struct EditorStatusView: View {
    let session: EditorSession

    var body: some View {
        HStack(spacing: 8) {
            Circle().fill(Color.purple).frame(width: 5, height: 5)
            Text(session.outputStatusText)
                .foregroundStyle(.secondary).lineLimit(1)
                .help(session.output.statusText + " · " + session.testOutput.statusText)
            if session.hasUserChanges { Text("· Unsaved changes").foregroundStyle(.secondary) }
            if let message = session.fileMessage { Text("· " + message).foregroundStyle(.secondary).lineLimit(1).help(message) }
            if session.isSavingMedia {
                ProgressView().controlSize(.small)
                Text("Saving media…")
                Button("Cancel") { session.cancelMediaSave() }.buttonStyle(.borderless)
            }
            if session.identifyingSourceID != nil {
                Text("Identifying object").foregroundStyle(.orange)
                Button("Finish") { session.finishIdentification() }.buttonStyle(.borderless)
            }
            Spacer()
            Text(session.output.destination == .testWindow ? "Test Mode" : "Projector Mode").foregroundStyle(.tertiary)
            Text("v\(AppVersion.version)").foregroundStyle(.secondary)
        }
        .font(.caption).padding(.horizontal, 18).frame(height: 30)
    }
}
