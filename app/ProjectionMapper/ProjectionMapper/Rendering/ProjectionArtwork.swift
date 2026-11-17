import AppKit
import CoreText
import Metal

/// Each state has a reusable, transparent texture shared by linked faces in this renderer.
@MainActor
final class ProjectionArtwork {
    private enum Key: Hashable {
        case text(String, String, Float, ProjectionText.Alignment, SIMD4<Float>)
        case face(MouthShape)
    }
    private var textures: [Key: any MTLTexture] = [:]
    private var insertionOrder: [Key] = []

    static func font(_ name: String, size: CGFloat) -> NSFont {
        NSFont(name: name, size: size) ?? NSFont.systemFont(ofSize: size, weight: .semibold)
    }

    func text(_ content: String, style: ProjectionText, device: any MTLDevice) -> (any MTLTexture)? {
        guard !content.isEmpty else { return nil }
        let key = Key.text(content, style.font, style.size, style.alignment, style.color)
        return texture(key, width: 1024, height: 512, device: device) { context in
            let paragraph = NSMutableParagraphStyle()
            switch style.alignment {
            case .leading: paragraph.alignment = .left
            case .center: paragraph.alignment = .center
            case .trailing: paragraph.alignment = .right
            }
            let color = CGColor(red: CGFloat(style.color.x), green: CGFloat(style.color.y),
                                blue: CGFloat(style.color.z), alpha: CGFloat(style.color.w))
            let attributed = NSAttributedString(string: content, attributes: [
                .font: Self.font(style.font, size: 512 * CGFloat(style.size)),
                .foregroundColor: color, .paragraphStyle: paragraph
            ])
            let setter = CTFramesetterCreateWithAttributedString(attributed)
            let constraint = CGSize(width: 992, height: 480)
            let measured = CTFramesetterSuggestFrameSizeWithConstraints(setter, CFRange(), nil, constraint, nil)
            let height = min(480, ceil(measured.height) + 4)
            let box = CGRect(x: 16, y: (512 - height) / 2, width: constraint.width, height: height)
            let frame = CTFramesetterCreateFrame(setter, CFRange(), CGPath(rect: box, transform: nil), nil)
            CTFrameDraw(frame, context)
        }
    }

    func face(_ mouth: MouthShape, device: any MTLDevice) -> (any MTLTexture)? {
        texture(.face(mouth), width: 512, height: 512, device: device) { ctx in
            func ellipse(_ x: CGFloat, _ y: CGFloat, _ width: CGFloat, _ height: CGFloat,
                         _ r: CGFloat, _ g: CGFloat, _ b: CGFloat) {
                ctx.setFillColor(red: r, green: g, blue: b, alpha: 1)
                ctx.fillEllipse(in: CGRect(x: x, y: y, width: width, height: height))
            }
            ellipse(54, 52, 404, 410, 0.68, 0.19, 0.03)
            ellipse(65, 67, 382, 391, 1, 0.62, 0.12)
            ellipse(117, 188, 70, 45, 0.96, 0.31, 0.19)
            ellipse(325, 188, 70, 45, 0.96, 0.31, 0.19)
            for x: CGFloat in [145, 294] {
                ellipse(x, 269, 74, 105, 1, 0.96, 0.82)
                ellipse(x + 23, 288, 38, 58, 0.14, 0.08, 0.11)
                ellipse(x + 31, 324, 13, 15, 1, 1, 1)
            }
            let dimensions: CGSize
            switch mouth {
            case .rest: dimensions = CGSize(width: 82, height: 18)
            case .open: dimensions = CGSize(width: 135, height: 101)
            case .wide: dimensions = CGSize(width: 162, height: 52)
            case .rounded: dimensions = CGSize(width: 79, height: 87)
            case .closed: dimensions = CGSize(width: 110, height: 12)
            }
            let x = 256 - dimensions.width / 2
            let y = 170 - dimensions.height / 2
            ellipse(x, y, dimensions.width, dimensions.height, 0.23, 0.07, 0.08)
            if mouth == .open || mouth == .rounded {
                ellipse(x + dimensions.width * 0.24, y + 7, dimensions.width * 0.52, 24, 0.98, 0.35, 0.42)
            } else if mouth == .wide {
                ellipse(x + 14, y + 20, dimensions.width - 28, 24, 1, 0.94, 0.82)
            }
        }
    }

    private func texture(_ key: Key, width: Int, height: Int, device: any MTLDevice,
                         draw: (CGContext) -> Void) -> (any MTLTexture)? {
        if let existing = textures[key] { return existing }
        guard let space = CGColorSpace(name: CGColorSpace.sRGB),
              let context = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8,
                                      bytesPerRow: width * 4, space: space,
                                      bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue),
              let data = context.data else { return nil }
        context.clear(CGRect(x: 0, y: 0, width: width, height: height))
        draw(context)
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .bgra8Unorm, width: width, height: height, mipmapped: false)
        descriptor.storageMode = .shared
        descriptor.usage = .shaderRead
        guard let texture = device.makeTexture(descriptor: descriptor) else { return nil }
        texture.replace(region: MTLRegionMake2D(0, 0, width, height), mipmapLevel: 0, withBytes: data, bytesPerRow: width * 4)
        if insertionOrder.count >= 16 { textures.removeValue(forKey: insertionOrder.removeFirst()) }
        insertionOrder.append(key)
        textures[key] = texture
        return texture
    }
}
