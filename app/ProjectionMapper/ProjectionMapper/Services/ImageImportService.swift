import Foundation
import ImageIO
import UniformTypeIdentifiers
import CoreGraphics

enum ImageImportError: LocalizedError {
    case invalid(String)
    var errorDescription: String? { switch self { case .invalid(let message): message } }
}
enum ImageImportService {
    static let maximumFileBytes = 128 * 1024 * 1024
    static let maximumDecodedBytes = 256 * 1024 * 1024
    static let maximumEncodedBytes = 256 * 1024 * 1024
    static func read(_ url: URL) throws -> ImportedImage {
        let access = url.startAccessingSecurityScopedResource()
        defer { if access { url.stopAccessingSecurityScopedResource() } }
        let values = try url.resourceValues(forKeys: [.isRegularFileKey,.isSymbolicLinkKey,.fileSizeKey])
        guard values.isRegularFile == true, values.isSymbolicLink != true,
              let size = values.fileSize, size > 0, size <= maximumFileBytes else {
            throw ImageImportError.invalid("Choose a readable PNG or JPEG smaller than 128 MB.")
        }
        return try decode(Data(contentsOf: url), name: url.lastPathComponent)
    }
    static func decode(_ data: Data, name: String) throws -> ImportedImage {
        guard !data.isEmpty, data.count <= maximumFileBytes,
              let source = CGImageSourceCreateWithData(data as CFData, [kCGImageSourceShouldCache: false] as CFDictionary),
              let type = CGImageSourceGetType(source) as String?, [UTType.png.identifier,UTType.jpeg.identifier].contains(type),
              CGImageSourceGetCount(source) == 1,
              let properties = CGImageSourceCopyPropertiesAtIndex(source,0,nil) as? [CFString:Any],
              let w = properties[kCGImagePropertyPixelWidth] as? Int,
              let h = properties[kCGImagePropertyPixelHeight] as? Int,
              w > 0, h > 0, w <= 100000, h <= 100000, Int64(w)*Int64(h) <= 100_000_000 else {
            throw ImageImportError.invalid("This file is not a valid single-image PNG or JPEG.")
        }
        let options = [kCGImageSourceCreateThumbnailFromImageAlways: true,
                       kCGImageSourceCreateThumbnailWithTransform: true,
                       kCGImageSourceThumbnailMaxPixelSize: 4096,
                       kCGImageSourceShouldCacheImmediately: true] as CFDictionary
        guard let image = CGImageSourceCreateThumbnailAtIndex(source,0,options) else {
            throw ImageImportError.invalid("The image could not be decoded.")
        }
        let width = image.width, height = image.height
        guard width > 0, height > 0, width <= 4096, height <= 4096 else { throw ImageImportError.invalid("Image dimensions exceed the decoding limit.") }
        var bytes = Data(count: width*height*4)
        let succeeded = bytes.withUnsafeMutableBytes { buffer -> Bool in
            guard let context = CGContext(data: buffer.baseAddress,width: width,height: height,bitsPerComponent: 8,bytesPerRow: width*4,
                                          space: CGColorSpace(name: CGColorSpace.sRGB)!,
                                          bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue) else { return false }
            context.interpolationQuality = .high
            context.draw(image,in: CGRect(x: 0,y: 0,width: width,height: height))
            return true
        }
        let pixels = ImagePixels(width: width,height: height,bytes: bytes)
        guard succeeded, let normalized = pixels.cgImage else { throw ImageImportError.invalid("Image color conversion failed.") }
        let png = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(png,UTType.png.identifier as CFString,1,nil) else {
            throw ImageImportError.invalid("Could not prepare the portable image.")
        }
        CGImageDestinationAddImage(destination,normalized,nil)
        guard CGImageDestinationFinalize(destination), png.length <= maximumFileBytes else { throw ImageImportError.invalid("Could not package this image.") }
        return ImportedImage(asset: ImageAsset(name: String(name.prefix(255)),width: width,height: height),pixels: pixels,png: png as Data)
    }
    static func loadAssets(_ project: MappingProject, package: URL) -> (pixels: [UUID:ImagePixels], files: [UUID:Data], problems: [UUID:String]) {
        loadAssets(project.imageAssets,package: package)
    }
    static func loadAssets(_ assets: [ImageAsset], package: URL) -> (pixels: [UUID:ImagePixels], files: [UUID:Data], problems: [UUID:String]) {
        var pixels: [UUID:ImagePixels] = [:], files: [UUID:Data] = [:], problems: [UUID:String] = [:]
        var decoded = 0, encoded = 0
        for asset in assets {
            do {
                let folder = package.appendingPathComponent("assets")
                let info = try folder.resourceValues(forKeys: [.isDirectoryKey,.isSymbolicLinkKey])
                guard info.isDirectory == true, info.isSymbolicLink != true else { throw ImageImportError.invalid("Unsafe asset folder") }
                let image = try read(folder.appendingPathComponent(asset.fileName))
                guard image.pixels.width == asset.width, image.pixels.height == asset.height,
                      decoded + image.pixels.bytes.count <= maximumDecodedBytes,
                      encoded + image.png.count <= maximumEncodedBytes else { throw ImageImportError.invalid("Image dimensions or project memory limit mismatch") }
                pixels[asset.id] = image.pixels; files[asset.id] = image.png
                decoded += image.pixels.bytes.count; encoded += image.png.count
            } catch { problems[asset.id] = "\(asset.name): missing or damaged image. Relink or replace it." }
        }
        return (pixels,files,problems)
    }
}
