import AVFoundation
import CoreGraphics
import UniformTypeIdentifiers

struct ImportedVideo: Sendable {
    var asset: VideoAsset
    let url: URL
    let poster: ImagePixels
}
enum VideoImportService {
    static let maximumFileBytes: Int64 = 2*1024*1024*1024
    static let maximumProjectBytes: Int64 = 8*1024*1024*1024
    static var stagingDirectory: URL { FileManager.default.temporaryDirectory.appendingPathComponent("ProjectionMapper-VideoAssets",isDirectory: true) }
    static func safeFile(_ url: URL) throws -> Int64 {
        let info = try url.resourceValues(forKeys: [.isRegularFileKey,.isSymbolicLinkKey,.fileSizeKey])
        guard info.isRegularFile == true, info.isSymbolicLink != true, let count = info.fileSize, count > 0, Int64(count) <= maximumFileBytes else {
            throw ProjectFileError.invalid("Choose a regular MP4/MOV video smaller than 2 GiB.")
        }
        return Int64(count)
    }
    /// Chunked, cancellable copying also used by portable saves; destination is staging only.
    static func copy(_ source: URL,to destination: URL) throws {
        let size = try safeFile(source)
        if let free = try destination.deletingLastPathComponent().resourceValues(forKeys: [.volumeAvailableCapacityKey]).volumeAvailableCapacity,
           Int64(free) < size + 16*1024*1024 { throw ProjectFileError.io("Not enough space to copy the video.") }
        FileManager.default.createFile(atPath: destination.path,contents: nil)
        let input = try FileHandle(forReadingFrom: source), output = try FileHandle(forWritingTo: destination)
        defer { try? input.close(); try? output.close() }
        var total: Int64 = 0
        do {
            while let data = try input.read(upToCount: 1024*1024), !data.isEmpty {
                try Task.checkCancellation(); total += Int64(data.count)
                guard total <= maximumFileBytes else { throw ProjectFileError.invalid("Video grew beyond its size limit.") }
                try output.write(contentsOf: data)
            }
            try output.synchronize()
            guard total == size else { throw ProjectFileError.io("The source changed while copying; import again.") }
        } catch { try? FileManager.default.removeItem(at: destination); throw error }
    }
    static func inspect(_ url: URL, name: String? = nil) async throws -> (VideoAsset,ImagePixels) {
        let size = try safeFile(url), ext = url.pathExtension.lowercased()
        guard ["mp4","mov"].contains(ext) else { throw ProjectFileError.invalid("Use an MP4 or MOV video.") }
        let movie = AVURLAsset(url: url)
        let duration = try await movie.load(.duration).seconds
        let tracks = try await movie.loadTracks(withMediaType: .video)
        guard let track = tracks.first else { throw ProjectFileError.invalid("The file has no readable video track.") }
        let natural = try await track.load(.naturalSize), transform = try await track.load(.preferredTransform)
        guard natural.width.isFinite, natural.height.isFinite, natural.width > 0, natural.height > 0,
              natural.width <= 4096, natural.height <= 4096 else {
            throw ProjectFileError.invalid("Invalid video dimensions; use an SDR video up to 4096 pixels per edge.")
        }
        let fps = try await track.load(.nominalFrameRate)
        let descriptions = try await track.load(.formatDescriptions)
        guard let description = descriptions.first else { throw ProjectFileError.invalid("The video format is unavailable.") }
        let subtype = CMFormatDescriptionGetMediaSubType(description)
        guard subtype == kCMVideoCodecType_H264 || subtype == kCMVideoCodecType_HEVC else { throw ProjectFileError.invalid("Use SDR H.264 or HEVC video.") }
        if let transfer = CMFormatDescriptionGetExtension(description,extensionKey: kCMFormatDescriptionExtension_TransferFunction) {
            let value = String(describing: transfer)
            guard !value.contains("2084") && !value.contains("HLG") && !value.contains("2100") else { throw ProjectFileError.invalid("HDR video is not supported yet; export an SDR copy.") }
        }
        let audio = try await movie.loadTracks(withMediaType: .audio)
        let metadata = VideoAsset(name: String((name ?? url.lastPathComponent).prefix(255)),fileExtension: ext,byteCount: size,duration: duration,
            width: Int(natural.width),height: Int(natural.height),frameRate: Double(fps),hasAudio: !audio.isEmpty,
            codec: subtype == kCMVideoCodecType_H264 ? "H.264" : "HEVC",
            transform: [transform.a,transform.b,transform.c,transform.d,transform.tx,transform.ty])
        guard metadata.isValid else { throw ProjectFileError.invalid("Video must be 0.1 seconds–24 hours, SDR up to 4096 pixels per edge, 8.8 MP and 120 fps.") }
        let generator = AVAssetImageGenerator(asset: movie)
        generator.appliesPreferredTrackTransform = true; generator.maximumSize = CGSize(width: 480,height: 270)
        let result = try await generator.image(at: .zero)
        let image = result.image, width = image.width, height = image.height
        var data = Data(count: width*height*4)
        let drawn = data.withUnsafeMutableBytes { bytes -> Bool in
            guard let context = CGContext(data: bytes.baseAddress,width: width,height: height,bitsPerComponent: 8,bytesPerRow: width*4,
                space: CGColorSpace(name: CGColorSpace.sRGB)!,bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue) else { return false }
            context.draw(image,in: CGRect(x: 0,y: 0,width: width,height: height)); return true
        }
        guard drawn else { throw ProjectFileError.invalid("The video preview could not be decoded.") }
        return (metadata,ImagePixels(width: width,height: height,bytes: data))
    }
    static func pixelBuffer(_ image: CGImage) throws -> CVPixelBuffer {
        var buffer: CVPixelBuffer?
        guard CVPixelBufferCreate(kCFAllocatorDefault,image.width,image.height,kCVPixelFormatType_32BGRA,
            [kCVPixelBufferIOSurfacePropertiesKey:[:],kCVPixelBufferMetalCompatibilityKey:true] as CFDictionary,&buffer) == kCVReturnSuccess,
            let buffer else { throw ProjectFileError.io("Video frame allocation failed.") }
        CVPixelBufferLockBaseAddress(buffer,[]); defer { CVPixelBufferUnlockBaseAddress(buffer,[]) }
        guard let context = CGContext(data: CVPixelBufferGetBaseAddress(buffer),width: image.width,height: image.height,bitsPerComponent: 8,
            bytesPerRow: CVPixelBufferGetBytesPerRow(buffer),space: CGColorSpace(name: CGColorSpace.sRGB)!,
            bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue) else { throw ProjectFileError.io("Video color conversion failed.") }
        context.draw(image,in: CGRect(x: 0,y: 0,width: image.width,height: image.height)); return buffer
    }
    static func read(_ source: URL) async throws -> ImportedVideo {
        try FileManager.default.createDirectory(at: stagingDirectory,withIntermediateDirectories: true)
        let ext = source.pathExtension.lowercased()
        guard ["mp4","mov"].contains(ext) else { throw ProjectFileError.invalid("Use MP4 or MOV video.") }
        let staged = stagingDirectory.appendingPathComponent(UUID().uuidString+"."+ext)
        do {
            try copy(source,to: staged)
            let (asset,poster) = try await inspect(staged,name: source.lastPathComponent)
            return ImportedVideo(asset: asset,url: staged,poster: poster)
        } catch { try? FileManager.default.removeItem(at: staged); throw error }
    }
    static func loadAssets(_ assets: [VideoAsset],package: URL) async -> (urls: [UUID:URL],posters: [UUID:ImagePixels],problems: [UUID:String]) {
        var urls: [UUID:URL] = [:], posters: [UUID:ImagePixels] = [:], problems: [UUID:String] = [:]
        let folder = package.appendingPathComponent("assets",isDirectory: true)
        for asset in assets {
            do {
                let info = try folder.resourceValues(forKeys: [.isDirectoryKey,.isSymbolicLinkKey])
                guard info.isDirectory == true, info.isSymbolicLink != true else { throw ProjectFileError.invalid("Unsafe asset folder.") }
                let url = folder.appendingPathComponent(asset.fileName)
                let (actual,poster) = try await inspect(url)
                guard actual.duration >= asset.duration-0.00001, actual.width == asset.width, actual.height == asset.height,
                      actual.byteCount == asset.byteCount, actual.transform == asset.transform else { throw ProjectFileError.invalid("Video metadata changed; relink the asset.") }
                urls[asset.id] = url; posters[asset.id] = poster
            } catch { problems[asset.id] = error.localizedDescription }
        }
        return (urls,posters,problems)
    }
}
