import MetalKit
import CoreVideo
import simd

enum MetalInitializationError: LocalizedError {
    case diagnosticTextureUnavailable
    case deviceUnavailable
    case commandQueueUnavailable
    case shaderLibraryUnavailable(String)
    case shaderFunctionUnavailable(String)
    case renderPipelineUnavailable(String)

    var errorDescription: String? {
        switch self {
        case .diagnosticTextureUnavailable: "Metal could not create the diagnostic texture. Close and reopen the window to try again."
        case .deviceUnavailable: "Metal is unavailable on this Mac. Test Output cannot render."
        case .commandQueueUnavailable: "Metal could not create a command queue. Close and reopen Test Output to try again."
        case .shaderLibraryUnavailable(let reason): "Metal could not load the output shaders: \(reason)"
        case .shaderFunctionUnavailable(let name): "Metal output shader is missing: \(name)."
        case .renderPipelineUnavailable(let reason): "Metal could not create the output pipeline: \(reason)"
        }
    }
}

/// Immutable GPU submission leases keep Core Video textures and buffers alive until completion.
private final class VideoSubmissionLease: @unchecked Sendable {
    let frames: [VideoFrame]
    let textures: [CVMetalTexture]
    init(frames: [VideoFrame],textures: [CVMetalTexture]) { self.frames = frames; self.textures = textures }
}

/// Rendering is independent of output-window ownership and simulated resolution.
@MainActor
final class MetalRenderer: NSObject, MTKViewDelegate {
    let device: any MTLDevice
    let commandQueue: any MTLCommandQueue
    let rectanglePipeline: any MTLRenderPipelineState
    let diagnosticTexture: any MTLTexture
    private var prepared: [(RenderSurface, PerspectiveTransform, [SIMD2<UInt32>], [SIMD2<Float>])] = []
    private static func prepare(_ scene: RenderScene) -> [(RenderSurface, PerspectiveTransform, [SIMD2<UInt32>], [SIMD2<Float>])] {
        scene.effectiveSurfaces.compactMap { item in
            guard let perspective = item.perspective else { return nil }
            let mask = item.mask ?? FaceMask(isEnabled: false)
            return (item,perspective,mask.shaderRings,mask.isEnabled ? mask.shaderPoints : [.zero])
        }
    }
    private var videoCache: CVMetalTextureCache?
    private var videoTextures: [UUID:(VideoFrame,CVMetalTexture)] = [:]
    private func videoTexture(_ owner: UUID, frame: VideoFrame) -> (any MTLTexture)? {
        if let cached = videoTextures[owner], cached.0 == frame { return CVMetalTextureGetTexture(cached.1) }
        if videoCache == nil { CVMetalTextureCacheCreate(nil,nil,device,nil,&videoCache) }
        guard let videoCache else { return nil }
        var wrapped: CVMetalTexture?
        let buffer = frame.pixelBuffer
        guard CVMetalTextureCacheCreateTextureFromImage(nil,videoCache,buffer,nil,.bgra8Unorm,
            CVPixelBufferGetWidth(buffer),CVPixelBufferGetHeight(buffer),0,&wrapped) == kCVReturnSuccess, let wrapped else { return nil }
        videoTextures[owner] = (frame,wrapped)
        return CVMetalTextureGetTexture(wrapped)
    }
    private var imageTextures: [UUID:any MTLTexture] = [:]
    private var loadedImages: [UUID:ImagePixels] = [:]
    private var hasVisibleSurface = false
    private var hasRunningAnimation = false
    static let pixelFormat: MTLPixelFormat = .bgra8Unorm
    static let backgroundColor = MTLClearColorMake(0, 0, 0, 1)
    let diagnostics: RenderDiagnostics?
    private var requestedAt: TimeInterval?
    private var lastContinuousDemand: Bool?
    /// The view uses this after a submitted frame, including the completed fade's final frame.
    var renderDemandDidChange: ((Bool) -> Void)?
    var isDrawingEnabled = true { didSet { if !isDrawingEnabled { requestedAt = nil } } }
    private(set) var scene: RenderScene
    var geometry: NormalizedRectangle { scene.geometry }

    init(scene: RenderScene = .diagnostic, diagnostics: RenderDiagnostics? = nil,
         deviceProvider: () -> (any MTLDevice)? = { MTLCreateSystemDefaultDevice() },
         queueProvider: (any MTLDevice) -> (any MTLCommandQueue)? = { $0.makeCommandQueue() },
         libraryProvider: (any MTLDevice) throws -> any MTLLibrary = {
             try $0.makeDefaultLibrary(bundle: Bundle(for: MetalRenderer.self))
         },
         pipelineProvider: (any MTLDevice, MTLRenderPipelineDescriptor) throws -> any MTLRenderPipelineState = {
             try $0.makeRenderPipelineState(descriptor: $1)
         }) throws {
        guard let device = deviceProvider() else { throw MetalInitializationError.deviceUnavailable }
        guard let queue = queueProvider(device) else { throw MetalInitializationError.commandQueueUnavailable }
        self.diagnostics = diagnostics
        self.device = device
        self.scene = scene
        prepared = Self.prepare(scene)
        hasVisibleSurface = prepared.contains { $0.0.appearance.opacity > 0 }
        hasRunningAnimation = prepared.contains { $0.0.appearance.opacity > 0 && $0.0.content.isAnimated && !$0.0.playback.isPaused }
        guard let texture = DiagnosticTexture.make(device: device) else {
            throw MetalInitializationError.diagnosticTextureUnavailable
        }
        diagnosticTexture = texture
        commandQueue = queue
        let library: any MTLLibrary
        do { library = try libraryProvider(device) }
        catch { throw MetalInitializationError.shaderLibraryUnavailable(error.localizedDescription) }
        guard let vertex = library.makeFunction(name: "rectangleVertex") else {
            throw MetalInitializationError.shaderFunctionUnavailable("rectangleVertex")
        }
        guard let fragment = library.makeFunction(name: "rectangleFragment") else {
            throw MetalInitializationError.shaderFunctionUnavailable("rectangleFragment")
        }
        let descriptor = MTLRenderPipelineDescriptor()
        descriptor.label = "Rectangle output pipeline"
        descriptor.vertexFunction = vertex
        descriptor.fragmentFunction = fragment
        descriptor.colorAttachments[0].pixelFormat = Self.pixelFormat
        descriptor.colorAttachments[0].isBlendingEnabled = true
        descriptor.colorAttachments[0].sourceRGBBlendFactor = .sourceAlpha
        descriptor.colorAttachments[0].destinationRGBBlendFactor = .oneMinusSourceAlpha
        descriptor.colorAttachments[0].sourceAlphaBlendFactor = .one
        descriptor.colorAttachments[0].destinationAlphaBlendFactor = .oneMinusSourceAlpha
        do { rectanglePipeline = try pipelineProvider(device, descriptor) }
        catch { throw MetalInitializationError.renderPipelineUnavailable(error.localizedDescription) }
        super.init()
        updateImageTextures()
    }

    /// Shared by drawable presentation and offscreen GPU verification.
    func encodeScene(to descriptor: MTLRenderPassDescriptor, viewIdentifier: String = "offscreen",
                     requestTime: TimeInterval? = nil, evaluationTime: Double? = nil,
                     evaluationUptime: TimeInterval? = nil) -> (any MTLCommandBuffer)? {
        let encodeStart = diagnostics == nil ? nil : ProcessInfo.processInfo.systemUptime
        descriptor.colorAttachments[0].loadAction = .clear
        descriptor.colorAttachments[0].storeAction = .store
        descriptor.colorAttachments[0].clearColor = scene.editorTransparentBackground ? MTLClearColorMake(0,0,0,0) : Self.backgroundColor
        guard let command = commandQueue.makeCommandBuffer(),
              let encoder = command.makeRenderCommandEncoder(descriptor: descriptor) else {
            diagnostics?.skipped("encoding-unavailable")
            return nil
        }
        command.label = "Mapped surface output"
        // All faces in this frame evaluate one explicit global time; no per-view frame counter.
        let uptime = evaluationUptime ?? ProcessInfo.processInfo.systemUptime
        let seconds = evaluationTime ?? scene.transport.elapsed(at: uptime)
        var masterGain = scene.effectiveGain(at: uptime)
        encoder.setFragmentBytes(&masterGain, length: MemoryLayout<Float>.stride, index: 10)
        var calibration = scene.calibration.shaderParameters
        encoder.setFragmentBytes(&calibration, length: MemoryLayout<SIMD4<Float>>.stride, index: 11)
        var frameLeases: [VideoFrame] = []
        var textureLeases: [CVMetalTexture] = []
        for (original, perspective, rings, points) in prepared {
            let item = original.evaluated(at: seconds, calibrationActive: scene.calibration.pattern.isActive)
            guard masterGain > 0, item.appearance.opacity > 0 else { continue }
            encoder.setRenderPipelineState(rectanglePipeline)
            let positions = item.geometry.trianglePositions
            positions.withUnsafeBytes {
                encoder.setVertexBytes($0.baseAddress!, length: $0.count, index: 0)
            }
            var color = item.color
            var inverse = perspective.shaderInverse
            var textured = item.content.shaderKind
            encoder.setFragmentBytes(&color, length: MemoryLayout<SIMD4<Float>>.stride, index: 0)
            encoder.setFragmentBytes(&inverse, length: MemoryLayout<simd_float3x3>.stride, index: 1)
            encoder.setFragmentBytes(&textured, length: MemoryLayout<UInt32>.stride, index: 2)
            var inputMap = item.appearance.matrix * item.inputMap.matrix
            encoder.setFragmentBytes(&inputMap, length: MemoryLayout<simd_float3x3>.stride, index: 3)
            let settings = item.generator.isValid ? item.generator : .defaults
            var phaseValue = Float((item.playback.elapsed(at: seconds.isFinite ? seconds : 0) * Double(settings.rate)).truncatingRemainder(dividingBy: 8) / 8)
            var parameters = SIMD4(settings.scale, settings.intensity, Float(settings.density), settings.particleSize)
            var motion = settings.motion
            var seed = settings.seed
            encoder.setFragmentBytes(&parameters, length: MemoryLayout<SIMD4<Float>>.stride, index: 6)
            encoder.setFragmentBytes(&motion, length: MemoryLayout<SIMD2<Float>>.stride, index: 7)
            encoder.setFragmentBytes(&seed, length: MemoryLayout<UInt32>.stride, index: 8)
            var secondary = settings.secondaryColor
            encoder.setFragmentBytes(&phaseValue, length: MemoryLayout<Float>.stride, index: 4)
            encoder.setFragmentBytes(&secondary, length: MemoryLayout<SIMD4<Float>>.stride, index: 5)
            var appearance = SIMD2(item.appearance.opacity,item.appearance.brightness)
            encoder.setFragmentBytes(&appearance,length: MemoryLayout<SIMD2<Float>>.stride,index: 9)
            rings.withUnsafeBytes { encoder.setFragmentBytes($0.baseAddress!, length: $0.count, index: 12) }
            points.withUnsafeBytes { encoder.setFragmentBytes($0.baseAddress!, length: $0.count, index: 13) }
            var imageScale = SIMD2<Float>(1,1)
            var videoUV = matrix_identity_float3x3
            if item.content == .video, !scene.calibration.pattern.isActive {
                guard let content = item.video, let owner = item.sourceID, let frame = scene.videoFrames[owner],
                      frame.assetID == content.assetID,
                      frame.clipID == original.timelineClips.first(where: { $0.contains(seconds) })?.id,
                      let texture = videoTexture(owner,frame: frame) else { continue }
                let size = frame.asset.displaySize
                imageScale = content.placement.scale(imageAspect: Float(size.width/size.height),canvasAspect: content.canvasAspect)
                videoUV = frame.asset.textureMatrix
                frameLeases.append(frame)
                if let lease = videoTextures[owner]?.1 { textureLeases.append(lease) }
                encoder.setFragmentTexture(texture,index: 0)
            } else if item.content == .image, !scene.calibration.pattern.isActive {
                guard let content = item.image, let pixels = scene.images[content.assetID], let texture = imageTextures[content.assetID] else { continue }
                imageScale = content.placement.scale(imageAspect: Float(pixels.width)/Float(pixels.height),canvasAspect: content.canvasAspect)
                encoder.setFragmentTexture(texture,index: 0)
            } else { encoder.setFragmentTexture(diagnosticTexture,index: 0) }
            encoder.setFragmentBytes(&imageScale,length: MemoryLayout<SIMD2<Float>>.stride,index: 14)
            encoder.setFragmentBytes(&videoUV,length: MemoryLayout<simd_float3x3>.stride,index: 15)
            encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: positions.count)
        }
        encoder.endEncoding()
        if !frameLeases.isEmpty {
            let lease = VideoSubmissionLease(frames: frameLeases,textures: textureLeases)
            command.addCompletedHandler { _ in _ = lease }
        }
        if let diagnostics, let encodeStart {
            let encodeMilliseconds = (ProcessInfo.processInfo.systemUptime - encodeStart) * 1_000
            let started = requestTime ?? encodeStart
            let width = descriptor.colorAttachments[0].texture?.width ?? 0
            let height = descriptor.colorAttachments[0].texture?.height ?? 0
            command.addScheduledHandler { _ in diagnostics.submitted() }
            command.addCompletedHandler { buffer in
                diagnostics.completed(RenderTimingSample(view: viewIdentifier, width: width, height: height,
                    encodeMilliseconds: encodeMilliseconds,
                    completionMilliseconds: (ProcessInfo.processInfo.systemUptime - started) * 1_000,
                    gpuMilliseconds: RenderTimingSample.gpuDuration(start: buffer.gpuStartTime, end: buffer.gpuEndTime),
                    succeeded: buffer.status == .completed && buffer.error == nil))
            }
        }
        return command
    }

    func setScene(_ scene: RenderScene) {
        self.scene = scene
        updateImageTextures()
        videoTextures = videoTextures.filter { scene.videoFrames[$0.key] != nil }
        lastContinuousDemand = nil
        prepared = Self.prepare(scene)
        hasVisibleSurface = prepared.contains { $0.0.appearance.opacity > 0 }
        hasRunningAnimation = prepared.contains { $0.0.appearance.opacity > 0 && $0.0.content.isAnimated && !$0.0.playback.isPaused }
    }

    private func updateImageTextures() {
        let ids = Set(scene.surfaces.compactMap { $0.image?.assetID } + scene.surfaces.flatMap { $0.timelineClips.compactMap { $0.source.image?.assetID } })
        imageTextures = imageTextures.filter { ids.contains($0.key) && scene.images[$0.key] != nil }
        loadedImages = loadedImages.filter { ids.contains($0.key) && scene.images[$0.key] != nil }
        var changed: [any MTLTexture] = []
        for id in ids {
            guard let pixels = scene.images[id], loadedImages[id] != pixels else { continue }
            let descriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .bgra8Unorm,width: pixels.width,height: pixels.height,mipmapped: true)
            descriptor.storageMode = .shared; descriptor.usage = .shaderRead
            guard let texture = device.makeTexture(descriptor: descriptor) else { imageTextures.removeValue(forKey: id); loadedImages.removeValue(forKey: id); continue }
            pixels.bytes.withUnsafeBytes { buffer in
                texture.replace(region: MTLRegionMake2D(0,0,pixels.width,pixels.height),mipmapLevel: 0,withBytes: buffer.baseAddress!,bytesPerRow: pixels.width*4)
            }
            imageTextures[id] = texture; loadedImages[id] = pixels; changed.append(texture)
        }
        if !changed.isEmpty, let command = commandQueue.makeCommandBuffer(), let blit = command.makeBlitCommandEncoder() {
            for texture in changed { blit.generateMipmaps(for: texture) }
            blit.endEncoding(); command.commit()
        }
    }
    var cachedImageTextureCount: Int { imageTextures.count }

    func updateRenderingDemand(at uptime: TimeInterval) {
        let continuous = isDrawingEnabled && scene.needsContinuousRendering(at: uptime,
            hasVisibleSurface: hasVisibleSurface, hasRunningAnimation: hasRunningAnimation)
        guard lastContinuousDemand != continuous else { return }
        lastContinuousDemand = continuous
        renderDemandDidChange?(continuous)
    }

    func requestDraw(in view: MTKView) {
        guard isDrawingEnabled else { return }
        if diagnostics != nil && requestedAt == nil { requestedAt = ProcessInfo.processInfo.systemUptime }
        view.needsDisplay = true
    }

    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) { requestDraw(in: view) }

    func draw(in view: MTKView) {
        guard isDrawingEnabled else { diagnostics?.skipped("suspended"); return }
        guard view.drawableSize.width > 0, view.drawableSize.height > 0 else {
            diagnostics?.skipped("empty-drawable"); return
        }
        guard let descriptor = view.currentRenderPassDescriptor, let drawable = view.currentDrawable else {
            diagnostics?.skipped("drawable-unavailable"); return
        }
        let requestTime = requestedAt
        requestedAt = nil
        let uptime = ProcessInfo.processInfo.systemUptime
        guard let command = encodeScene(to: descriptor, viewIdentifier: String(describing: ObjectIdentifier(view)),
                                        requestTime: requestTime, evaluationUptime: uptime) else { return }
        command.present(drawable)
        command.commit()
        updateRenderingDemand(at: uptime)
    }
}
