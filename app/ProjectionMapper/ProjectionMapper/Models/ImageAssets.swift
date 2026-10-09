import Foundation
import CoreGraphics

enum ImagePlacement: String, CaseIterable, Codable, Identifiable, Sendable {
    case fit, fill, stretch
    var id: Self { self }
    var title: String { rawValue.capitalized }
    /// Canvas UV -> image UV. Fit's outside area is transparent; Fill crops centrally.
    func scale(imageAspect: Float, canvasAspect: Float) -> SIMD2<Float> {
        let ratio = imageAspect / canvasAspect
        switch self {
        case .stretch: return SIMD2(1,1)
        case .fit: return ratio > 1 ? SIMD2(1,ratio) : SIMD2(1/ratio,1)
        case .fill: return ratio > 1 ? SIMD2(1/ratio,1) : SIMD2(1,ratio)
        }
    }
}
struct ImageContent: Codable, Equatable, Sendable {
    var assetID: UUID
    var placement: ImagePlacement = .fit
    var canvasAspect: Float = 16/9
    var isValid: Bool { canvasAspect.isFinite && (0.01...100).contains(canvasAspect) }
}
struct ImageAsset: Codable, Equatable, Identifiable, Sendable {
    var id = UUID()
    var name: String
    var width: Int
    var height: Int
    var fileName: String { id.uuidString + ".png" }
    var isValid: Bool { !name.isEmpty && name.count <= 255 && (1...4096).contains(width) && (1...4096).contains(height) }
}
struct ReferencePhoto: Codable, Equatable, Sendable {
    var assetID: UUID
    var placement: ImagePlacement = .fit
    var center = SIMD2<Float>(0.5,0.5)
    var scale: Float = 1
    var opacity: Float = 0.5
    var isLocked = true
    var isValid: Bool {
        center.x.isFinite && center.y.isFinite && (-2...3).contains(center.x) && (-2...3).contains(center.y) &&
        scale.isFinite && (0.1...4).contains(scale) && opacity.isFinite && (0...1).contains(opacity)
    }
}
/// BGRA sRGB bytes with premultiplied alpha. Runtime-only, immutable across preview/output.
struct ImagePixels: Equatable, Sendable {
    let width: Int
    let height: Int
    let bytes: Data
    var cgImage: CGImage? {
        guard let provider = CGDataProvider(data: bytes as CFData) else { return nil }
        return CGImage(width: width,height: height,bitsPerComponent: 8,bitsPerPixel: 32,bytesPerRow: width*4,
                       space: CGColorSpace(name: CGColorSpace.sRGB)!,
                       bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedFirst.rawValue).union(.byteOrder32Little),
                       provider: provider,decode: nil,shouldInterpolate: true,intent: .defaultIntent)
    }
}
struct ImportedImage: Sendable {
    var asset: ImageAsset
    let pixels: ImagePixels
    let png: Data
}
extension MappingProject {
    var referencedImageIDs: Set<UUID> {
        var ids = Set((surfaces.map(\.source) + objects.map(\.source)).compactMap { $0.image?.assetID })
        for look in looks { for entry in look.entries { if let id = entry.source?.image?.assetID { ids.insert(id) } } }
        if let id = referencePhoto?.assetID { ids.insert(id) }
        return ids
    }
}
