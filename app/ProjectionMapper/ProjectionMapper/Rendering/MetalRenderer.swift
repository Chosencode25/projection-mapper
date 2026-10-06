import MetalKit
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

/// Rendering is independent of output-window ownership and simulated resolution.
@MainActor
final class MetalRenderer: NSObject, MTKViewDelegate {
    let device: any MTLDevice
    let commandQueue: any MTLCommandQueue
    let rectanglePipeline: any MTLRenderPipelineState
    let diagnosticTexture: any MTLTexture
    private var prepared: [(RenderSurface, PerspectiveTransform)] = []
    static let pixelFormat: MTLPixelFormat = .bgra8Unorm
    static let backgroundColor = MTLClearColorMake(0, 0, 0, 1)
    let diagnostics: RenderDiagnostics?
    private var requestedAt: TimeInterval?
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
        prepared = scene.surfaces.compactMap { item in item.perspective.map { (item, $0) } }
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
    }

    /// Shared by drawable presentation and offscreen GPU verification.
    func encodeScene(to descriptor: MTLRenderPassDescriptor, viewIdentifier: String = "offscreen",
                     requestTime: TimeInterval? = nil, evaluationTime: Double? = nil) -> (any MTLCommandBuffer)? {
        let encodeStart = diagnostics == nil ? nil : ProcessInfo.processInfo.systemUptime
        descriptor.colorAttachments[0].loadAction = .clear
        descriptor.colorAttachments[0].storeAction = .store
        descriptor.colorAttachments[0].clearColor = Self.backgroundColor
        guard let command = commandQueue.makeCommandBuffer(),
              let encoder = command.makeRenderCommandEncoder(descriptor: descriptor) else {
            diagnostics?.skipped("encoding-unavailable")
            return nil
        }
        command.label = "Mapped surface output"
        // All faces in this frame evaluate one explicit global time; no per-view frame counter.
        let seconds = evaluationTime ?? scene.transport.elapsed(at: ProcessInfo.processInfo.systemUptime)
        for (item, perspective) in prepared {
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
            var inputMap = item.inputMap.matrix
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
            encoder.setFragmentTexture(diagnosticTexture, index: 0)
            encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: positions.count)
        }
        encoder.endEncoding()
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
        prepared = scene.surfaces.compactMap { item in item.perspective.map { (item, $0) } }
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
        guard let command = encodeScene(to: descriptor, viewIdentifier: String(describing: ObjectIdentifier(view)),
                                        requestTime: requestTime) else { return }
        command.present(drawable)
        command.commit()
    }
}
