import Metal

/// Generated once per renderer; no image import, disk access or per-frame upload.
enum DiagnosticTexture {
    static let size = 512
    static func make(device: any MTLDevice) -> (any MTLTexture)? {
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .rgba8Unorm,
            width: size, height: size, mipmapped: true)
        descriptor.storageMode = .shared
        descriptor.usage = .shaderRead
        guard let texture = device.makeTexture(descriptor: descriptor) else { return nil }
        texture.label = "Perspective diagnostic grid"
        var pixels = [UInt8](repeating: 255, count: size * size * 4)
        for y in 0..<size {
            for x in 0..<size {
                let shade: UInt8 = (x / 64 + y / 64).isMultiple(of: 2) ? 220 : 30
                var rgb = SIMD3<UInt8>(shade, shade, shade)
                if x % 64 < 2 || y % 64 < 2 { rgb = SIMD3(255, 128, 0) }
                if x < 4 || y < 4 || x >= size - 4 || y >= size - 4 { rgb = SIMD3(0, 220, 220) }
                if x < 40 && y < 40 { rgb = SIMD3(255, 0, 0) }
                if x >= size - 40 && y < 40 { rgb = SIMD3(0, 255, 0) }
                if x >= size - 40 && y >= size - 40 { rgb = SIMD3(0, 0, 255) }
                if x < 40 && y >= size - 40 { rgb = SIMD3(255, 255, 0) }
                let offset = (y * size + x) * 4
                pixels[offset] = rgb[0]; pixels[offset + 1] = rgb[1]; pixels[offset + 2] = rgb[2]
            }
        }
        // Box-filter all levels on CPU at initialization, including colored orientation markers.
        var width = size, level = 0
        while true {
            pixels.withUnsafeBytes { texture.replace(region: MTLRegionMake2D(0, 0, width, width),
                mipmapLevel: level, withBytes: $0.baseAddress!, bytesPerRow: width * 4) }
            guard width > 1 else { break }
            let nextWidth = width / 2
            var next = [UInt8](repeating: 0, count: nextWidth * nextWidth * 4)
            for y in 0..<nextWidth { for x in 0..<nextWidth { for channel in 0..<4 {
                let top = (2*y*width+2*x)*4+channel, bottom = top+width*4
                let sum = Int(pixels[top]) + Int(pixels[top + 4]) + Int(pixels[bottom]) + Int(pixels[bottom + 4])
                next[(y*nextWidth+x)*4+channel] = UInt8(sum / 4)
            } } }
            pixels = next; width = nextWidth; level += 1
        }
        return texture
    }
}
