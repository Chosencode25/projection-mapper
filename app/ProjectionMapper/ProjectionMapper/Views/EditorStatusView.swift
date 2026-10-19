import SwiftUI

struct EditorStatusView: View {
    let session: EditorSession
    private var outputWarning: Bool { session.projectorOutput.state == .failed || session.projectorOutput.state == .unavailable }
    private var outputColor: Color {
        if session.showOutput.isBlackout || session.showOutput.targetGain == 0 || outputWarning { return .orange }
        return session.isOutputOpen ? .green : .secondary
    }
    private var notice: String? { session.editMessage ?? session.historyNotice ?? session.fileMessage }

    var body: some View {
        HStack(spacing: 9) {
            Circle().fill(outputColor).frame(width: 6, height: 6)
            Text(session.showOutput.isBlackout ? "Output blacked out" : session.outputStatusText)
                .foregroundStyle(outputWarning || session.showOutput.isBlackout ? Color.orange : Color.secondary)
                .lineLimit(1).frame(maxWidth: 270, alignment: .leading)
                .help(session.outputStatusText + " · " + session.output.statusText)
            if session.showOutput.isBlackout || session.showOutput.targetGain == 0 {
                Button("Restore") { session.restoreOutput() }.buttonStyle(.borderless).foregroundStyle(.orange)
                    .help("Restore brightness (Command-Shift-R)")
            }
            Divider().frame(height: 12)
            if session.isSavingMedia || session.isImportingImage || session.isImportingVideo {
                ProgressView().controlSize(.mini)
                Text(session.isSavingMedia ? "Saving media…" : session.isImportingVideo ? "Preparing video…" : "Preparing image…")
                    .foregroundStyle(.secondary)
                if session.isSavingMedia { Button("Cancel") { session.cancelMediaSave() }.buttonStyle(.borderless) }
            } else if let notice {
                Label(notice, systemImage: session.editMessage != nil ? "exclamationmark.triangle" : "info.circle")
                    .foregroundStyle(session.editMessage != nil ? Color.orange : Color.secondary)
                    .lineLimit(1).help(notice).layoutPriority(1)
            } else {
                Text(session.hasUserChanges ? "Unsaved changes" : "No unsaved changes").foregroundStyle(.secondary).lineLimit(1)
            }
            if session.identifyingSourceID != nil {
                Button("Finish Identification") { session.finishIdentification() }.buttonStyle(.borderless).foregroundStyle(.orange)
            }
            Spacer(minLength: 0)
            if session.hasUserChanges { Circle().fill(Color.accentColor).frame(width: 5, height: 5).help("Unsaved project changes") }
            Text("v\(AppVersion.version)").foregroundStyle(.tertiary)
        }
        .font(.system(size: 10)).padding(.horizontal, 14).frame(height: 30)
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.65))
    }
}
