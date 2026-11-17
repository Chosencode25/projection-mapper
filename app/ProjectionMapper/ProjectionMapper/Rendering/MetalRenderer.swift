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
    /// Geometry and mask payloads are immutable until the surface definition changes.
    /// Cache their arrays and matrices so playback does not rebuild them for every frame.
    private struct PreparedSurface {
        let surface: RenderSurface
        let positions: [SIMD2<Float>]
        let inverse: simd_float3x3
        let inputMap: simd_float3x3
        let rings: [SIMD2<UInt32>]
        let points: [SIMD2<Float>]
    }
    private var prepared: [PreparedSurface] = []
    /// Lightweight diagnostic counter for checking preparation work independently of frame rate.
    private(set) var surfacePreparationCount = 1
    private static func prepare(_ scene: RenderScene) -> [PreparedSurface] {
        scene.effectiveSurfaces.compactMap { item in
            guard let perspective = item.perspective else { return nil }
            let mask = item.mask ?? FaceMask(isEnabled: false)
            return PreparedSurface(surface: item, positions: item.geometry.trianglePositions,
                inverse: perspective.shaderInverse, inputMap: item.appearance.matrix * item.inputMap.matrix,
                rings: mask.shaderRings, points: mask.isEnabled ? mask.shaderPoints : [.zero])
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
    private let artwork = ProjectionArtwork()
    private struct VisualShaderSource {
        var color = SIMD4<Float>.zero
        var secondary = SIMD4<Float>.zero
        var parameters = SIMD4<Float>.zero
        var motionPhaseKind = SIMD4<Float>.zero
        var seedScale = SIMD4<Float>(0, 1, 1, 0)
        var videoU = SIMD4<Float>(1, 0, 0, 0)
        var videoV = SIMD4<Float>(0, 1, 0, 0)
        var videoW = SIMD4<Float>(0, 0, 1, 0)
    }

    private struct VisualShaderLayer {
        var first = VisualShaderSource()
        var second = VisualShaderSource()
        var transform = SIMD4<Float>.zero
        var style = SIMD4<Float>.zero
        var bounds = SIMD4<Float>.zero
        var region = SIMD4<Float>(0, 0, 0, -1)
        var metric = SIMD4<Float>(1, 1, 0, 0)
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
    var renderingFailed: ((String) -> Void)?
    var frameSubmitted: ((TimeInterval) -> Void)?
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
        hasVisibleSurface = prepared.contains { $0.surface.appearance.opacity > 0 }
        hasRunningAnimation = prepared.contains { $0.surface.appearance.opacity > 0 && $0.surface.hasAnimatedContent }
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
        encoder.setRenderPipelineState(rectanglePipeline)
        var boundSecondSource = false
        let textureSlots = (MappingProject.maximumLayersPerOwner + MappingProject.maximumRegionsPerFace) * 2
        let blankTextures: [(any MTLTexture)?] = Array(repeating: diagnosticTexture, count: textureSlots)
        encoder.setFragmentTextures(blankTextures, range: 2..<(2 + textureSlots))
        var emptyLayer = VisualShaderLayer()
        var emptyPoint = SIMD2<Float>.zero
        encoder.setFragmentBytes(&emptyLayer, length: MemoryLayout<VisualShaderLayer>.stride, index: 26)
        encoder.setFragmentBytes(&emptyPoint, length: MemoryLayout<SIMD2<Float>>.stride, index: 27)
        for payload in prepared {
            let original = payload.surface
            let transition = scene.calibration.pattern.isActive ? nil : original.transition(at: seconds)
            var item = transition.map { original.applying($0.outgoing) }
                ?? original.evaluated(at: seconds, calibrationActive: scene.calibration.pattern.isActive)
            let visuals = scene.calibration.pattern.isActive ? [] : original.visuals.compactMap { visual in
                visual.evaluate(at: seconds).map { (visual, $0) }
            }
            guard masterGain > 0, item.appearance.opacity > 0 || (!visuals.isEmpty && original.appearance.opacity > 0) else { continue }
            if item.appearance.opacity == 0 {
                item.content = .solid
                item.color = .zero
                item.appearance = original.appearance
            }
            let positions = payload.positions
            positions.withUnsafeBytes {
                encoder.setVertexBytes($0.baseAddress!, length: $0.count, index: 0)
            }
            var inverse = payload.inverse
            var inputMap = payload.inputMap
            var appearance = SIMD2(item.appearance.opacity,item.appearance.brightness)
            encoder.setFragmentBytes(&inverse, length: MemoryLayout<simd_float3x3>.stride, index: 1)
            encoder.setFragmentBytes(&inputMap, length: MemoryLayout<simd_float3x3>.stride, index: 3)
            encoder.setFragmentBytes(&appearance,length: MemoryLayout<SIMD2<Float>>.stride,index: 9)
            payload.rings.withUnsafeBytes { encoder.setFragmentBytes($0.baseAddress!, length: $0.count, index: 12) }
            payload.points.withUnsafeBytes { encoder.setFragmentBytes($0.baseAddress!, length: $0.count, index: 13) }

            func bind(_ surface: RenderSurface, clipID: UUID?, second: Bool) -> Bool {
                var color = surface.color
                var kind = surface.content.shaderKind
                let settings = surface.generator.isValid ? surface.generator : .defaults
                var phase = Float((surface.playback.elapsed(at: seconds.isFinite ? seconds : 0) * Double(settings.rate))
                    .truncatingRemainder(dividingBy: 8) / 8)
                var parameters = SIMD4(settings.scale, settings.intensity, Float(settings.density), settings.particleSize)
                var motion = settings.motion
                var seed = settings.seed
                var secondary = settings.secondaryColor
                var scale = SIMD2<Float>(1,1)
                var uv = matrix_identity_float3x3
                var texture: any MTLTexture = diagnosticTexture
                if !scene.calibration.pattern.isActive {
                    switch surface.content {
                    case .video:
                        if let content = surface.video, let owner = original.videoFrameKey(for: clipID), let frame = scene.videoFrames[owner],
                           frame.assetID == content.assetID, frame.clipID == clipID, let decoded = videoTexture(owner, frame: frame) {
                            let size = frame.asset.displaySize
                            scale = content.placement.scale(imageAspect: Float(size.width/size.height), canvasAspect: content.canvasAspect)
                            uv = frame.asset.textureMatrix
                            texture = decoded
                            frameLeases.append(frame)
                            if let lease = videoTextures[owner]?.1 { textureLeases.append(lease) }
                        } else if transition != nil { kind = 0; color = .zero }
                        else { return false }
                    case .image:
                        if let content = surface.image, let pixels = scene.images[content.assetID],
                           let image = imageTextures[content.assetID] {
                            scale = content.placement.scale(imageAspect: Float(pixels.width)/Float(pixels.height), canvasAspect: content.canvasAspect)
                            texture = image
                        } else if transition != nil { kind = 0; color = .zero }
                        else { return false }
                    default: break
                    }
                }
                if second {
                    var flags = SIMD2(kind, seed)
                    encoder.setFragmentBytes(&flags, length: MemoryLayout<SIMD2<UInt32>>.stride, index: 18)
                } else {
                    encoder.setFragmentBytes(&kind, length: MemoryLayout<UInt32>.stride, index: 2)
                    encoder.setFragmentBytes(&seed, length: MemoryLayout<UInt32>.stride, index: 8)
                }
                encoder.setFragmentBytes(&color, length: MemoryLayout<SIMD4<Float>>.stride, index: second ? 17 : 0)
                encoder.setFragmentBytes(&phase, length: MemoryLayout<Float>.stride, index: second ? 19 : 4)
                encoder.setFragmentBytes(&secondary, length: MemoryLayout<SIMD4<Float>>.stride, index: second ? 20 : 5)
                encoder.setFragmentBytes(&parameters, length: MemoryLayout<SIMD4<Float>>.stride, index: second ? 21 : 6)
                encoder.setFragmentBytes(&motion, length: MemoryLayout<SIMD2<Float>>.stride, index: second ? 22 : 7)
                encoder.setFragmentBytes(&scale, length: MemoryLayout<SIMD2<Float>>.stride, index: second ? 23 : 14)
                encoder.setFragmentBytes(&uv, length: MemoryLayout<simd_float3x3>.stride, index: second ? 24 : 15)
                encoder.setFragmentTexture(texture, index: second ? 1 : 0)
                return true
            }

            let activeID = transition?.outgoing.id ?? original.timelineClips.last(where: { $0.contains(seconds) })?.id
            if !bind(item, clipID: activeID, second: false) {
                guard !visuals.isEmpty else { continue }
                _ = bind(RenderSurface(geometry: original.geometry, color: .zero), clipID: nil, second: false)
            }
            var layerCount = UInt32(visuals.count)
            encoder.setFragmentBytes(&layerCount, length: MemoryLayout<UInt32>.stride, index: 25)
            if !visuals.isEmpty {
                var uniforms: [VisualShaderLayer] = []
                var points: [SIMD2<Float>] = []
                var textures: [(any MTLTexture)?] = []
                let geometry = original.geometry
                let reference = SIMD2<Float>(16 / 9, 1)
                let width = simd_length((geometry.topRight - geometry.topLeft) * reference)
                let height = simd_length((geometry.bottomLeft - geometry.topLeft) * reference)
                let shorter = max(1e-5, min(width, height))
                for (visual, evaluation) in visuals {
                    let track = visual.track
                    var layer = VisualShaderLayer()
                    let angle = track.rotation * .pi / 180
                    layer.transform = SIMD4(track.center.x, track.center.y, 1 / track.size.x, 1 / track.size.y)
                    layer.style = SIMD4(sin(angle), cos(angle), track.opacity, track.blend == .add ? 1 : 0)
                    layer.region.w = evaluation.fraction
                    if let region = visual.region {
                        let vertices = region.shape.points
                        let origin = vertices.reduce(SIMD2<Float>(repeating: 1), simd_min)
                        let end = vertices.reduce(SIMD2<Float>.zero, simd_max)
                        layer.bounds = SIMD4(origin.x, origin.y, end.x - origin.x, end.y - origin.y)
                        layer.region.x = Float(points.count)
                        layer.region.y = Float(vertices.count)
                        layer.region.z = region.outline ?? 0
                        layer.metric = SIMD4(width / shorter, height / shorter, 0, 0)
                        points += vertices
                    }
                    func pack(_ sample: RenderVisual.Sample) -> (VisualShaderSource, any MTLTexture) {
                        if track.kind == .media, sample.source.content == .video,
                           let content = sample.source.video,
                           let frame = scene.videoFrames[sample.frameID], frame.assetID == content.assetID,
                           frame.clipID == sample.clipID, let texture = videoTexture(sample.frameID, frame: frame) {
                            frameLeases.append(frame)
                            if let lease = videoTextures[sample.frameID]?.1 { textureLeases.append(lease) }
                            let size = frame.asset.displaySize
                            let scale = content.placement.scale(imageAspect: Float(size.width / size.height), canvasAspect: content.canvasAspect)
                            return (texturedVisual(scale: scale, uv: frame.asset.textureMatrix), texture)
                        }
                        return packVisual(sample, visual: visual, time: seconds)
                    }
                    let first = pack(evaluation.first)
                    layer.first = first.0
                    textures.append(first.1)
                    if let sample = evaluation.second {
                        let second = pack(sample)
                        layer.second = second.0
                        textures.append(second.1)
                    } else {
                        textures.append(diagnosticTexture)
                    }
                    uniforms.append(layer)
                }
                uniforms.withUnsafeBytes { encoder.setFragmentBytes($0.baseAddress!, length: $0.count, index: 26) }
                if !points.isEmpty {
                    points.withUnsafeBytes { encoder.setFragmentBytes($0.baseAddress!, length: $0.count, index: 27) }
                }
                encoder.setFragmentTextures(textures, range: 2..<(2 + textures.count))
            }
            var blend = transition?.amount ?? -1
            encoder.setFragmentBytes(&blend, length: MemoryLayout<Float>.stride, index: 16)
            if let transition {
                _ = bind(original.applying(transition.incoming), clipID: transition.incoming.id, second: true)
                boundSecondSource = true
            } else if !boundSecondSource {
                _ = bind(RenderSurface(geometry: original.geometry, color: .zero), clipID: nil, second: true)
                boundSecondSource = true
            }
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

    private func texturedVisual(scale: SIMD2<Float> = SIMD2(1, 1),
                                uv: simd_float3x3 = matrix_identity_float3x3) -> VisualShaderSource {
        var source = VisualShaderSource()
        source.motionPhaseKind.w = 8
        source.seedScale = SIMD4(0, scale.x, scale.y, 0)
        source.videoU = SIMD4(uv.columns.0, 0)
        source.videoV = SIMD4(uv.columns.1, 0)
        source.videoW = SIMD4(uv.columns.2, 0)
        return source
    }

    private func packVisual(_ sample: RenderVisual.Sample, visual: RenderVisual,
                            time: Double) -> (VisualShaderSource, any MTLTexture) {
        let track = visual.track
        switch track.kind {
        case .text:
            var style = track.text
            if let target = visual.countdownMarkerTime { style.countdownEnd = target }
            let title = style.displayedText(at: time, songTitle: visual.songTitle, markers: [])
            if let texture = artwork.text(title, style: style, device: device) { return (texturedVisual(), texture) }
        case .singingFace:
            if let texture = artwork.face(track.mouth(at: time, since: sample.start), device: device) {
                return (texturedVisual(), texture)
            }
        case .media:
            let source = sample.source
            if source.content == .image {
                if let image = source.image, let pixels = scene.images[image.assetID], let texture = imageTextures[image.assetID] {
                    let scale = image.placement.scale(imageAspect: Float(pixels.width) / Float(pixels.height), canvasAspect: image.canvasAspect)
                    return (texturedVisual(scale: scale), texture)
                }
            } else if source.content != .video {
                let settings = source.generator
                let phase = Float((sample.elapsed * Double(settings.rate)).truncatingRemainder(dividingBy: 8) / 8)
                var uniforms = VisualShaderSource()
                uniforms.color = source.color
                uniforms.secondary = settings.secondaryColor
                uniforms.parameters = SIMD4(settings.scale, settings.intensity, Float(settings.density), settings.particleSize)
                uniforms.motionPhaseKind = SIMD4(settings.motion.x, settings.motion.y, phase, Float(source.content.shaderKind))
                uniforms.seedScale.x = Float(bitPattern: settings.seed)
                return (uniforms, diagnosticTexture)
            }
        }
        return (VisualShaderSource(), diagnosticTexture)
    }

    func setScene(_ scene: RenderScene) {
        // Decoder frames, transport, master fades and fixture updates do not change geometry.
        // RenderSurface equality intentionally ignores procedural owner IDs, but timeline
        // clips may later evaluate to video, so preserve owner changes explicitly here.
        let needsPreparation = scene.surfaces != self.scene.surfaces ||
            !scene.surfaces.elementsEqual(self.scene.surfaces, by: { $0.sourceID == $1.sourceID }) ||
            scene.calibration.isValid != self.scene.calibration.isValid ||
            scene.calibration.pattern.isActive != self.scene.calibration.pattern.isActive
        self.scene = scene
        updateImageTextures()
        videoTextures = videoTextures.filter { scene.videoFrames[$0.key] != nil }
        lastContinuousDemand = nil
        if needsPreparation {
            prepared = Self.prepare(scene)
            surfacePreparationCount += 1
            hasVisibleSurface = prepared.contains { $0.surface.appearance.opacity > 0 }
            hasRunningAnimation = prepared.contains { $0.surface.appearance.opacity > 0 && $0.surface.hasAnimatedContent }
        }
    }

    private func updateImageTextures() {
        let visuals = scene.surfaces.flatMap(\.visuals)
        let base = scene.surfaces.compactMap { $0.image?.assetID } +
            scene.surfaces.flatMap { $0.timelineClips.compactMap { $0.source.image?.assetID } }
        let overlays = visuals.compactMap { $0.track.source.image?.assetID } +
            visuals.flatMap { $0.clips.compactMap { $0.source.image?.assetID } }
        let ids = Set(base + overlays)
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
                                        requestTime: requestTime, evaluationUptime: uptime) else { renderingFailed?("Metal could not encode output."); return }
        command.addCompletedHandler { [weak self] buffer in
            guard buffer.status == .error else { return }
            let reason = buffer.error?.localizedDescription ?? "Metal output command failed."
            Task { @MainActor [weak self] in self?.renderingFailed?(reason) }
        }
        command.present(drawable)
        command.commit()
        frameSubmitted?(uptime)
        updateRenderingDemand(at: uptime)
    }
}
