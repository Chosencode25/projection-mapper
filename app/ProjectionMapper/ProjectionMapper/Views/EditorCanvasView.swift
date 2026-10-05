import SwiftUI

struct EditorCanvasView: View {
    let output: OutputSelectionState
    var body: some View {
        GeometryReader { geometry in
            let availableWidth = max(0, geometry.size.width - 56)
            let availableHeight = max(0, geometry.size.height - 100)
            let ratio = output.aspectRatio
            let width = min(availableWidth, availableHeight * ratio)
            let height = width / ratio
            VStack(spacing: 16) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color(red: 0.055, green: 0.06, blue: 0.075))
                    RoundedRectangle(cornerRadius: 8)
                        .strokeBorder(Color.white.opacity(0.13), lineWidth: 1)
                    VStack(spacing: 14) {
                        Image(systemName: "viewfinder").font(.system(size: width < 220 ? 22 : 36, weight: .light))
                            .foregroundStyle(.purple.opacity(0.8))
                        if width >= 160 && height >= 130 {
                            Text("Mapping Preview").font(.title3.weight(.medium))
                            Text("Your mapped content will appear here.")
                                .font(.caption).foregroundStyle(.secondary).multilineTextAlignment(.center)
                        }
                    }
                    .padding(12)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .clipped()
                }
                .frame(width: width, height: height)
                Text("\(output.selectedName) · \(output.renderSizeText) · Editor preview").font(.caption).foregroundStyle(.secondary)
                    .lineLimit(2).multilineTextAlignment(.center)
                    .frame(maxWidth: max(0, availableWidth))
                    .help("\(output.selectedName) · \(output.renderSizeText)")
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
        }
        .background(Color(red: 0.085, green: 0.09, blue: 0.105))
    }
}
