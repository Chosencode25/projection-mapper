import SwiftUI

struct EditorCanvasView: View {
    var body: some View {
        GeometryReader { geometry in
            let availableWidth = max(0, geometry.size.width - 56)
            let availableHeight = max(0, geometry.size.height - 100)
            let width = min(availableWidth, availableHeight * 16 / 9)
            VStack(spacing: 16) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color(red: 0.055, green: 0.06, blue: 0.075))
                    RoundedRectangle(cornerRadius: 8)
                        .strokeBorder(Color.white.opacity(0.13), lineWidth: 1)
                    VStack(spacing: 14) {
                        Image(systemName: "viewfinder").font(.system(size: 36, weight: .light))
                            .foregroundStyle(.purple.opacity(0.8))
                        Text("Mapping Preview").font(.title3.weight(.medium))
                        Text("Your mapped content will appear here.")
                            .font(.caption).foregroundStyle(.secondary).multilineTextAlignment(.center)
                    }
                    .padding(20)
                }
                .frame(width: width, height: width * 9 / 16)
                Text("16:9 · Editor preview").font(.caption).foregroundStyle(.secondary)
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
        }
        .background(Color(red: 0.085, green: 0.09, blue: 0.105))
    }
}
