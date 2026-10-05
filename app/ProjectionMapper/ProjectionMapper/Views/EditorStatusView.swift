import SwiftUI

struct EditorStatusView: View {
    let session: EditorSession

    var body: some View {
        HStack(spacing: 8) {
            Circle().fill(Color.purple).frame(width: 5, height: 5)
            Text("Ready").foregroundStyle(.secondary)
            if session.hasUserChanges { Text("· Unsaved changes").foregroundStyle(.secondary) }
            Spacer()
            Text("App skeleton").foregroundStyle(.tertiary)
            Text("v1.01").foregroundStyle(.secondary)
        }
        .font(.caption).padding(.horizontal, 18).frame(height: 30)
    }
}
