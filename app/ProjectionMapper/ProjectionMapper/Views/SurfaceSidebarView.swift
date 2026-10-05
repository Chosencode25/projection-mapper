import SwiftUI

struct SurfaceSidebarView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("SURFACES").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                .padding(20)
            VStack(spacing: 12) {
                Image(systemName: "square.stack.3d.up").font(.system(size: 28)).foregroundStyle(.tertiary)
                Text("No surfaces yet").font(.subheadline.weight(.medium))
                Text("Your mapped surfaces will appear here.")
                    .font(.caption).foregroundStyle(.secondary).multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity).padding(.horizontal, 22).padding(.top, 36)
            Spacer()
        }
        .frame(maxHeight: .infinity)
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.45))
    }
}
