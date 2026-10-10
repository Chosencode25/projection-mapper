import Foundation
import CoreVideo
import simd

struct VideoAsset: Codable, Equatable, Identifiable, Sendable {
    var id = UUID()
    var name: String
    var fileExtension: String
    var byteCount: Int64
    var duration: Double
    var width: Int
    var height: Int
    var frameRate: Double
    var hasAudio: Bool
    var codec: String
    /// Affine transform a,b,c,d,tx,ty supplied by the inspected track.
    var transform: [Double]
    var fileName: String { id.uuidString + "." + fileExtension }
    var isValid: Bool {
        !name.isEmpty && name.count <= 255 && ["mp4","mov"].contains(fileExtension) && byteCount > 0 && byteCount <= VideoImportService.maximumFileBytes &&
        duration.isFinite && (0.1...86400).contains(duration) && width > 0 && height > 0 && max(width,height) <= 4096 &&
        Int64(width)*Int64(height) <= 8_847_360 && frameRate.isFinite && frameRate > 0 && frameRate <= 120 &&
        ["H.264","HEVC"].contains(codec) && transform.count == 6 && transform.allSatisfy(\.isFinite) && abs(transform[0]*transform[3]-transform[1]*transform[2]) > 0.0001 && validDisplayTransform
    }
    private var validDisplayTransform: Bool {
        guard transform.count == 6 else { return false }
        let size = displaySize
        return size.width.isFinite && size.height.isFinite && size.width > 0 && size.height > 0 &&
            size.width <= 8192 && size.height <= 8192 && transform.allSatisfy { abs($0) <= 16384 }
    }
    var affine: CGAffineTransform { CGAffineTransform(a: transform[0],b: transform[1],c: transform[2],d: transform[3],tx: transform[4],ty: transform[5]) }
    var displaySize: CGSize { CGRect(x: 0,y: 0,width: width,height: height).applying(affine).standardized.size }
    /// Display-normalized UV -> raw decoded pixel-buffer UV, retaining track orientation.
    var textureMatrix: simd_float3x3 {
        let bounds = CGRect(x: 0,y: 0,width: width,height: height).applying(affine).standardized
        let inverse = affine.inverted()
        func point(_ x: Double,_ y: Double) -> SIMD2<Float> {
            let raw = CGPoint(x: bounds.minX+x*bounds.width,y: bounds.minY+y*bounds.height).applying(inverse)
            return SIMD2(Float(raw.x/Double(width)),Float(raw.y/Double(height)))
        }
        let zero = point(0,0), x = point(1,0)-zero, y = point(0,1)-zero
        return simd_float3x3(columns: (SIMD3(x.x,x.y,0),SIMD3(y.x,y.y,0),SIMD3(zero.x,zero.y,1)))
    }
}
struct VideoContent: Codable, Equatable, Sendable {
    var assetID: UUID
    var inPoint: Double = 0
    var outPoint: Double
    var rate: Double = 1
    var loops = false
    var loopOffset: Double?
    var isMuted = true
    var placement: ImagePlacement = .fit
    var canvasAspect: Float = 16/9
    var rangeDuration: Double { outPoint-inPoint }
    var timelineDuration: Double { rangeDuration/rate }
    var isValid: Bool {
        inPoint.isFinite && outPoint.isFinite && inPoint >= 0 && rangeDuration >= 0.1 && outPoint <= 86400 &&
        [0.25,0.5,1,2,4].contains(rate) && (loopOffset.map { $0.isFinite && $0 >= 0 && $0 < rangeDuration } ?? true) && canvasAspect.isFinite && (0.01...100).contains(canvasAspect)
    }
    func requestedTime(elapsed: Double) -> Double {
        let delta = max(0,elapsed)*rate
        if loops { return inPoint + (delta+(loopOffset ?? 0)).truncatingRemainder(dividingBy: rangeDuration) }
        return min(outPoint-0.000001,inPoint+delta)
    }
}
struct VideoAudioSettings: Codable, Equatable, Sendable {
    var volume: Float = 1
    var deviceUID: String?
    var isValid: Bool { volume.isFinite && (0...1).contains(volume) && (deviceUID.map { !$0.isEmpty && $0.count <= 512 } ?? true) }
}
/// Producer owns the buffer until publication; published buffers are never mutated.
final class VideoFrame: @unchecked Sendable, Equatable {
    let id = UUID()
    let pixelBuffer: CVPixelBuffer
    let assetID: UUID
    let clipID: UUID?
    let sourceTime: Double
    let asset: VideoAsset
    init(buffer: CVPixelBuffer, asset: VideoAsset, clipID: UUID?, sourceTime: Double) {
        pixelBuffer = buffer; assetID = asset.id; self.asset = asset; self.clipID = clipID; self.sourceTime = sourceTime
    }
    static func == (lhs: VideoFrame,rhs: VideoFrame) -> Bool { lhs === rhs }
    var byteCount: Int { CVPixelBufferGetBytesPerRow(pixelBuffer)*CVPixelBufferGetHeight(pixelBuffer) }
}
extension MappingProject {
    var referencedVideoIDs: Set<UUID> {
        var ids = Set((surfaces.map(\.source)+objects.map(\.source)).compactMap { $0.video?.assetID })
        ids.formUnion(timelineClips.compactMap { $0.source.video?.assetID })
        ids.formUnion(looks.flatMap(\.entries).compactMap { $0.source?.video?.assetID })
        return ids
    }
    func videoProblem(_ content: VideoContent?) -> Bool {
        guard let content else { return false }
        guard content.isValid, let asset = videoAssets.first(where: { $0.id == content.assetID }) else { return true }
        return content.outPoint > asset.duration + 0.00001
    }
}
