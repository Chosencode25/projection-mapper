import SwiftUI

struct EditorStatusView: View {
    let session: EditorSession

    var body: some View {
        HStack(spacing: 8) {
            Circle().fill(Color.purple).frame(width: 5, height: 5)
            Text(session.output.statusText).foregroundStyle(.secondary).lineLimit(1)
                .help(session.output.statusText)
            if session.hasUserChanges { Text("· Unsaved changes").foregroundStyle(.secondary) }
            Spacer()
            Text("Output selection").foregroundStyle(.tertiary)
            Text("v\(AppVersion.version)").foregroundStyle(.secondary)
        }
        .font(.caption).padding(.horizontal, 18).frame(height: 30)
    }
}
