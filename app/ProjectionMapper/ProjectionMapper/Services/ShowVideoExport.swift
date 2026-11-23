@preconcurrency import AVFoundation
import CoreVideo
import Foundation
import Metal

enum VideoExportMode: String, CaseIterable, Identifiable, Sendable {
    case mapped, canvas
    var id: Self { self }
    var title: String { self == .mapped ? "Mapped Projector Output" : "Unmapped Content Canvas" }
}

struct VideoExportOptions: Sendable {
    static let clock: CMTimeScale = 60_000
    static let frameRates = [24, 25, 30, 50, 60]
    var mode = VideoExportMode.mapped
    var owner: UUID?
    var width = 1920
    var height = 1080
    var framesPerSecond = 30
    var start = 0.0
    var end = 10.0
    var includeSong = false

    var startTick: Int64 { tick(start) }
    var endTick: Int64 { tick(end) }
    var frameTicks: Int64 { Int64(Self.clock) / Int64(max(1, framesPerSecond)) }
    var frameCount: Int {
        guard Self.frameRates.contains(framesPerSecond), endTick > startTick else { return 0 }
        return Int((endTick - startTick + frameTicks - 1) / frameTicks)
    }
    var outputDuration: CMTime { CMTime(value: Int64(frameCount) * frameTicks, timescale: Self.clock) }
    var bitRate: Int {
        guard (16...4096).contains(width), (16...4096).contains(height), Self.frameRates.contains(framesPerSecond) else { return 0 }
        return max(1_000_000, Int(Double(width * height * framesPerSecond) * 0.14))
    }
    var estimatedBytes: Int64 {
        Int64(outputDuration.seconds * Double(bitRate + (includeSong ? 256_000 : 0)) / 8)
    }
    var issue: String? {
        guard (16...4096).contains(width), (16...4096).contains(height), width.isMultiple(of: 2), height.isMultiple(of: 2),
              width * height <= 8_847_360 else {
            return "Use even dimensions within 16–4096 pixels and a maximum of 8.85 megapixels."
        }
        guard Self.frameRates.contains(framesPerSecond), (0...3600).contains(start), (0...3600).contains(end), frameCount > 0 else {
            return "Enter a start and end between 0 and 3,600 seconds, with the end after the start."
        }
        if mode == .canvas && owner == nil { return "Choose a face or object to export." }
        return nil
    }

    func presentationTime(_ frame: Int) -> CMTime {
        CMTime(value: Int64(frame) * frameTicks, timescale: Self.clock)
    }

    func showTime(_ frame: Int) -> Double {
        CMTime(value: startTick + Int64(frame) * frameTicks, timescale: Self.clock).seconds
    }

    private func tick(_ value: Double) -> Int64 {
        guard (0...3600).contains(value) else { return 0 }
        return Int64((value * Double(Self.clock)).rounded())
    }
}

struct VideoExportOwner: Identifiable {
    let id: UUID
    let name: String
}

extension MappingProject {
    var exportOwners: [VideoExportOwner] {
        let objectOwners = objects.filter { object in surfaces.contains { $0.layout.objectID == object.id } }
            .map { VideoExportOwner(id: $0.source.id, name: $0.name) }
        return objectOwners + surfaces.filter { $0.layout.objectID == nil }.map { VideoExportOwner(id: $0.source.id, name: $0.name) }
    }

    func deliveryScene(_ options: VideoExportOptions) throws -> RenderScene {
        if options.mode == .mapped {
            let mapped = renderScene
            guard !mapped.surfaces.isEmpty, mapped.invalidCount == 0 else {
                throw DeliveryError.invalid("Show at least one mapped surface and fix invalid geometry or masks before exporting.")
            }
            return mapped
        }
        guard let owner = options.owner, let face = surfaces.first(where: { source(for: $0).id == owner }) else {
            throw DeliveryError.invalid("The selected content canvas is no longer available.")
        }
        let source = resolvedSource(source(for: face))
        let full = NormalizedRectangle(topLeft: .zero, topRight: SIMD2(1, 0), bottomRight: SIMD2(1, 1), bottomLeft: SIMD2(0, 1))
        let surface = RenderSurface(geometry: full, color: source.color, content: source.content,
            generator: source.generator, sourceID: owner, image: source.image, video: source.video,
            timelineClips: timelineClips.filter { $0.sourceID == owner }.sorted { $0.start < $1.start },
            choreography: choreographyClips.filter { $0.kind == .projection && $0.targets.contains { $0.id == owner } },
            visuals: renderVisuals(owner: owner, face: face.id).filter { $0.region == nil })
        return RenderScene(surfaces: [surface], masterBrightness: masterOutput.brightness)
    }
}

@MainActor
enum ShowVideoExport {
    private struct Media {
        var videoAssets: [VideoAsset] = []
        var urls: [UUID: URL] = [:]
    }

    private struct DecodedFrame {
        let assetID: UUID
        let clipID: UUID?
        let requested: Double
        let frame: VideoFrame
    }

    static func write(snapshot: DeliverySnapshot, options: VideoExportOptions, to destination: URL,
                      progress: @MainActor (Double, String) -> Void) async throws {
        if let issue = options.issue { throw DeliveryError.invalid(issue) }
        try DeliveryFile.requireVacant(destination)
        let project = try ProjectCodec.decode(snapshot.document).project
        var scene = try project.deliveryScene(options)
        scene.images = snapshot.imagePixels
        let resources = try await validateMedia(in: scene, snapshot: snapshot, assets: project.videoAssets, options: options)
        let parent = destination.deletingLastPathComponent()
        let work = parent.appendingPathComponent(".projection-export-\(UUID().uuidString)", isDirectory: true)
        let fileManager = FileManager.default
        try fileManager.createDirectory(at: work, withIntermediateDirectories: false)
        defer { try? fileManager.removeItem(at: work) }
        let movie = work.appendingPathComponent("video.mp4")
        let audio: SoundtrackExport?
        if options.includeSong, let song = project.song, options.start < song.duration {
            guard let bytes = snapshot.songBytes, bytes.count == song.byteCount else {
                throw DeliveryError.invalid("Replace the missing soundtrack or export without it.")
            }
            progress(0.03, "Preparing the soundtrack…")
            let original = work.appendingPathComponent(song.fileName)
            try bytes.write(to: original)
            audio = try await SoundtrackExport.prepare(from: original, options: options)
        } else { audio = nil }
        let title = AVMutableMetadataItem()
        title.identifier = .commonIdentifierTitle
        title.value = project.name as NSString
        let description = AVMutableMetadataItem()
        description.identifier = .commonIdentifierDescription
        let source = options.mode == .mapped ? "mapped" : "canvas \(options.owner?.uuidString ?? "")"
        description.value = """
            Projection Mapper \(AppVersion.version) (\(AppVersion.build))
            Project \(project.id.uuidString), revised \(ISO8601DateFormatter().string(from: project.modifiedAt))
            \(source); \(options.width)x\(options.height); \(options.framesPerSecond) fps; \(options.frameCount) frames
            Show range \(options.startTick)/60000 to \(options.endTick)/60000 seconds; \(audio != nil ? "project song" : "silent")
            """ as NSString
        let metadata: [AVMetadataItem] = [title, description]
        try await render(scene: scene, resources: resources, options: options, audio: audio,
                         to: movie, metadata: metadata, progress: progress)
        try DeliveryFile.publish(movie, to: destination)
    }

    private static func validateMedia(in scene: RenderScene, snapshot: DeliverySnapshot,
                                      assets: [VideoAsset], options: VideoExportOptions) async throws -> Media {
        var images = Set<UUID>()
        var videos = Set<UUID>()
        func collect(_ image: ImageContent?, _ video: VideoContent?) {
            if let image { images.insert(image.assetID) }
            if let video { videos.insert(video.assetID) }
        }
        func collectClips(_ clips: [EffectClip]) {
            for clip in clips where clip.start < options.end && clip.end > options.start {
                collect(clip.source.image, clip.source.video)
            }
        }
        for surface in scene.surfaces where surface.appearance.opacity > 0 {
            if surface.timelineClips.isEmpty { collect(surface.image, surface.video) }
            collectClips(surface.timelineClips)
            for visual in surface.visuals where visual.track.isVisible && visual.track.opacity > 0 {
                if visual.clips.isEmpty { collect(visual.track.source.image, visual.track.source.video) }
                collectClips(visual.clips)
            }
        }
        guard images.allSatisfy({ snapshot.imagePixels[$0] != nil }) else {
            throw DeliveryError.invalid("Relink the missing images in the selected export before continuing.")
        }
        var media = Media(videoAssets: assets.filter { videos.contains($0.id) })
        guard media.videoAssets.count == videos.count else { throw DeliveryError.invalid("A video in the export is missing.") }
        for asset in media.videoAssets {
            try Task.checkCancellation()
            media.urls[asset.id] = try await snapshot.validateVideo(asset)
        }
        return media
    }

    private static func render(scene base: RenderScene, resources: Media, options: VideoExportOptions,
                               audio: SoundtrackExport?, to url: URL,
                               metadata: [AVMetadataItem], progress: @MainActor (Double, String) -> Void) async throws {
        var scene = base
        let renderer = try MetalRenderer(scene: scene)
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: MetalRenderer.pixelFormat,
                        width: options.width, height: options.height, mipmapped: false)
        descriptor.storageMode = .shared
        descriptor.usage = .renderTarget
        guard let texture = renderer.device.makeTexture(descriptor: descriptor) else {
            throw DeliveryError.writing("Could not allocate an export frame at this resolution.")
        }
        let pass = MTLRenderPassDescriptor()
        pass.colorAttachments[0].texture = texture
        let writer = try AVAssetWriter(outputURL: url, fileType: .mp4)
        writer.metadata = metadata
        writer.shouldOptimizeForNetworkUse = true
        let settings: [String: Any] = [
            AVVideoCodecKey: AVVideoCodecType.h264, AVVideoWidthKey: options.width, AVVideoHeightKey: options.height,
            AVVideoColorPropertiesKey: [AVVideoColorPrimariesKey: AVVideoColorPrimaries_ITU_R_709_2,
                                        AVVideoTransferFunctionKey: AVVideoTransferFunction_ITU_R_709_2,
                                        AVVideoYCbCrMatrixKey: AVVideoYCbCrMatrix_ITU_R_709_2],
            AVVideoCompressionPropertiesKey: [AVVideoAverageBitRateKey: options.bitRate,
                                             AVVideoExpectedSourceFrameRateKey: options.framesPerSecond,
                                             AVVideoAllowFrameReorderingKey: false]
        ]
        guard writer.canApply(outputSettings: settings, forMediaType: .video) else {
            throw DeliveryError.writing("The Mac’s H.264 encoder cannot write these settings.")
        }
        let input = AVAssetWriterInput(mediaType: .video, outputSettings: settings)
        guard writer.canAdd(input) else { throw DeliveryError.writing("Could not add the movie track.") }
        let adapter = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: input, sourcePixelBufferAttributes: [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
            kCVPixelBufferWidthKey as String: options.width, kCVPixelBufferHeightKey as String: options.height,
            kCVPixelBufferIOSurfacePropertiesKey as String: [:]
        ])
        writer.add(input)
        if let audio {
            guard writer.canAdd(audio.input) else { throw DeliveryError.writing("Could not add the soundtrack track.") }
            writer.add(audio.input)
        }
        guard writer.startWriting() else { throw writer.error ?? DeliveryError.writing("The movie encoder could not start.") }
        writer.startSession(atSourceTime: .zero)
        let soundtrack = audio.map { audio in
            Task { @MainActor in try await audio.appendSamples(to: writer) }
        }
        defer {
            soundtrack?.cancel()
            if writer.status == .writing { writer.cancelWriting() }
        }
        guard let pool = adapter.pixelBufferPool else { throw DeliveryError.writing("The video frame pool is unavailable.") }
        var generators: [UUID: AVAssetImageGenerator] = [:]
        var decoded: [UUID: DecodedFrame] = [:]

        for frame in 0..<options.frameCount {
            try Task.checkCancellation()
            if let failure = audio?.failure { throw failure }
            if frame == 0 || frame.isMultiple(of: max(1, options.framesPerSecond / 4)) {
                progress(0.05 + 0.85 * Double(frame) / Double(options.frameCount), "Rendering frame \(frame + 1) of \(options.frameCount)…")
            }
            let time = options.showTime(frame)
            scene.transport.sampleSong(time, playing: false)
            let requests = VideoPlaybackRequest.requests(scene: scene, assets: resources.videoAssets, audioEnabled: false, at: 0)
            let requestIDs = Set(requests.map(\.ownerID))
            decoded = decoded.filter { requestIDs.contains($0.key) }
            var remainingBytes = VideoPlaybackCoordinator.maximumFrameBytes
            for request in requests {
                try Task.checkCancellation()
                let bytes = request.asset.width * request.asset.height * 4
                guard remainingBytes >= bytes else { throw DeliveryError.invalid("Too many simultaneous video frames. The export limit is 256 MiB of decoded frames.") }
                remainingBytes -= bytes
                let current = decoded[request.ownerID]
                if current?.assetID == request.asset.id && current?.clipID == request.clipID && current?.requested == request.sourceTime { continue }
                guard let url = resources.urls[request.asset.id] else { throw DeliveryError.invalid("A video in the export is missing.") }
                let generator: AVAssetImageGenerator
                if let existing = generators[request.asset.id] { generator = existing }
                else {
                    generator = AVAssetImageGenerator(asset: AVURLAsset(url: url))
                    generator.appliesPreferredTrackTransform = false
                    generator.requestedTimeToleranceBefore = CMTime(seconds: 1 / request.asset.frameRate, preferredTimescale: VideoExportOptions.clock)
                    generator.requestedTimeToleranceAfter = .zero
                    generators[request.asset.id] = generator
                }
                let sourceTime = CMTime(seconds: request.sourceTime, preferredTimescale: 1_000_000)
                let result = try await generator.image(at: sourceTime)
                try Task.checkCancellation()
                let pixels = try VideoImportService.pixelBuffer(result.image)
                decoded[request.ownerID] = DecodedFrame(assetID: request.asset.id, clipID: request.clipID, requested: request.sourceTime,
                    frame: VideoFrame(buffer: pixels, asset: request.asset, clipID: request.clipID, sourceTime: result.actualTime.seconds))
            }
            scene.videoFrames = decoded.mapValues(\.frame)
            renderer.setScene(scene)
            guard let command = renderer.encodeScene(to: pass, viewIdentifier: "video export", evaluationTime: time, evaluationUptime: 0) else {
                throw DeliveryError.writing("The Metal renderer could not encode frame \(frame + 1).")
            }
            let completed = await withCheckedContinuation { continuation in
                command.addCompletedHandler { continuation.resume(returning: $0.status == .completed) }
                command.commit()
            }
            guard completed else { throw DeliveryError.writing("Metal failed while rendering frame \(frame + 1).") }
            try await append(texture, at: options.presentationTime(frame), pool: pool, input: input, adapter: adapter, writer: writer)
            // Resume other main-actor work between static frames and encoder submissions.
            if frame.isMultiple(of: 4) { await Task.yield() }
        }
        try Task.checkCancellation()
        progress(0.94, "Finishing the video file…")
        input.markAsFinished()
        try await withTaskCancellationHandler {
            try await soundtrack?.value
        } onCancel: {
            soundtrack?.cancel()
        }
        writer.endSession(atSourceTime: options.outputDuration)
        await writer.finishWriting()
        guard writer.status == .completed else { throw writer.error ?? DeliveryError.writing("Could not finish the movie file.") }
    }

    private static func append(_ texture: any MTLTexture, at time: CMTime, pool: CVPixelBufferPool,
                               input: AVAssetWriterInput, adapter: AVAssetWriterInputPixelBufferAdaptor,
                               writer: AVAssetWriter) async throws {
        let deadline = ContinuousClock.now.advanced(by: .seconds(30))
        while true {
            try Task.checkCancellation()
            guard writer.status == .writing else { throw writer.error ?? DeliveryError.writing("The movie encoder stopped.") }
            var buffer: CVPixelBuffer?
            if input.isReadyForMoreMediaData {
                let attributes = [kCVPixelBufferPoolAllocationThresholdKey: 6] as CFDictionary
                let result = CVPixelBufferPoolCreatePixelBufferWithAuxAttributes(nil, pool, attributes, &buffer)
                if result == kCVReturnSuccess, let buffer {
                    let status = CVPixelBufferLockBaseAddress(buffer, [])
                    guard status == kCVReturnSuccess else { throw DeliveryError.writing("Could not access a video frame.") }
                    if let address = CVPixelBufferGetBaseAddress(buffer) {
                        texture.getBytes(address, bytesPerRow: CVPixelBufferGetBytesPerRow(buffer),
                                         from: MTLRegionMake2D(0, 0, texture.width, texture.height), mipmapLevel: 0)
                    } else {
                        CVPixelBufferUnlockBaseAddress(buffer, [])
                        throw DeliveryError.writing("Could not access a video frame.")
                    }
                    CVPixelBufferUnlockBaseAddress(buffer, [])
                    guard adapter.append(buffer, withPresentationTime: time) else {
                        throw writer.error ?? DeliveryError.writing("Could not write a video frame.")
                    }
                    return
                }
                guard result == kCVReturnWouldExceedAllocationThreshold else {
                    throw DeliveryError.writing("The encoder could not allocate a video frame.")
                }
            }
            guard ContinuousClock.now < deadline else { throw DeliveryError.writing("The movie encoder stopped accepting frames.") }
            try await Task.sleep(for: .milliseconds(5))
        }
    }

}

/// Encode AAC in the same writing session as video so the container preserves encoder priming.
@MainActor
private final class SoundtrackExport {
    let input: AVAssetWriterInput
    private let reader: AVAssetReader
    private let samples: AVAssetReaderAudioMixOutput
    private(set) var failure: (any Error)?

    private init(input: AVAssetWriterInput, reader: AVAssetReader, samples: AVAssetReaderAudioMixOutput) {
        self.input = input
        self.reader = reader
        self.samples = samples
    }

    static func prepare(from source: URL, options: VideoExportOptions) async throws -> SoundtrackExport? {
        let song = AVURLAsset(url: source)
        guard let audio = try await song.loadTracks(withMediaType: .audio).first else {
            throw DeliveryError.invalid("The selected soundtrack could not be decoded.")
        }
        let start = CMTime(value: options.startTick, timescale: VideoExportOptions.clock)
        let end = CMTime(value: options.endTick, timescale: VideoExportOptions.clock)
        let available = try await audio.load(.timeRange)
        let trimmed = CMTimeRange(start: start, end: end).intersection(available)
        guard trimmed.isValid, trimmed.duration > .zero else { return nil }
        let composition = AVMutableComposition()
        guard let track = composition.addMutableTrack(withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid) else {
            throw DeliveryError.writing("Could not prepare the soundtrack range.")
        }
        try track.insertTimeRange(trimmed, of: audio, at: trimmed.start - start)
        let reader = try AVAssetReader(asset: composition)
        let samples = AVAssetReaderAudioMixOutput(audioTracks: [track], audioSettings: [
            AVFormatIDKey: kAudioFormatLinearPCM, AVSampleRateKey: 48_000, AVNumberOfChannelsKey: 2,
            AVLinearPCMBitDepthKey: 16, AVLinearPCMIsFloatKey: false, AVLinearPCMIsNonInterleaved: false
        ])
        guard reader.canAdd(samples) else { throw DeliveryError.writing("Could not read the soundtrack as PCM.") }
        reader.add(samples)
        let input = AVAssetWriterInput(mediaType: .audio, outputSettings: [
            AVFormatIDKey: kAudioFormatMPEG4AAC, AVSampleRateKey: 48_000, AVNumberOfChannelsKey: 2, AVEncoderBitRateKey: 192_000
        ])
        return SoundtrackExport(input: input, reader: reader, samples: samples)
    }

    func appendSamples(to writer: AVAssetWriter) async throws {
        defer {
            if reader.status == .reading { reader.cancelReading() }
            if writer.status == .writing { input.markAsFinished() }
        }
        do {
            guard reader.startReading() else { throw reader.error ?? DeliveryError.writing("Could not start reading the soundtrack.") }
            var appended = false
            while let sample = samples.copyNextSampleBuffer() {
                try Task.checkCancellation()
                guard sample.numSamples > 0 else { continue }
                let deadline = ContinuousClock.now.advanced(by: .seconds(30))
                while !input.isReadyForMoreMediaData {
                    guard writer.status == .writing, ContinuousClock.now < deadline else {
                        throw writer.error ?? DeliveryError.writing("The soundtrack encoder stopped accepting audio.")
                    }
                    try await Task.sleep(for: .milliseconds(5))
                }
                guard input.append(sample) else {
                    throw writer.error ?? DeliveryError.writing("Could not write soundtrack samples.")
                }
                appended = true
                await Task.yield()
            }
            guard reader.status == .completed, appended else {
                throw reader.error ?? DeliveryError.writing("The soundtrack ended before audio could be written.")
            }
        } catch {
            failure = error
            throw error
        }
    }
}
