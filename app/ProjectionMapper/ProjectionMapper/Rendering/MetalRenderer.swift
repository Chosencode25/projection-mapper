import MetalKit

enum MetalInitializationError: LocalizedError {
    case deviceUnavailable
    case commandQueueUnavailable
    case shaderLibraryUnavailable(String)
    case shaderFunctionUnavailable(String)
    case renderPipelineUnavailable(String)

    var errorDescription: String? {
        switch self {
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
    static let pixelFormat: MTLPixelFormat = .bgra8Unorm
    static let backgroundColor = MTLClearColorMake(0, 0, 0, 1)
    var isDrawingEnabled = true
    let scene: RenderScene
    var geometry: NormalizedRectangle { scene.geometry }

    init(scene: RenderScene = .diagnostic,
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
        self.device = device
        self.scene = scene
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
        do { rectanglePipeline = try pipelineProvider(device, descriptor) }
        catch { throw MetalInitializationError.renderPipelineUnavailable(error.localizedDescription) }
        super.init()
    }

    /// Shared by drawable presentation and offscreen GPU verification.
    func encodeScene(to descriptor: MTLRenderPassDescriptor) -> (any MTLCommandBuffer)? {
        descriptor.colorAttachments[0].loadAction = .clear
        descriptor.colorAttachments[0].storeAction = .store
        descriptor.colorAttachments[0].clearColor = Self.backgroundColor
        guard let command = commandQueue.makeCommandBuffer(),
              let encoder = command.makeRenderCommandEncoder(descriptor: descriptor) else { return nil }
        command.label = "Temporary rectangle output"
        encoder.setRenderPipelineState(rectanglePipeline)
        let rectanglePositions = geometry.trianglePositions
        rectanglePositions.withUnsafeBytes {
            encoder.setVertexBytes($0.baseAddress!, length: $0.count, index: 0)
        }
        var color = scene.color
        encoder.setFragmentBytes(&color, length: MemoryLayout<SIMD4<Float>>.stride, index: 0)
        encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: rectanglePositions.count)
        encoder.endEncoding()
        return command
    }

    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
        if isDrawingEnabled { view.needsDisplay = true }
    }

    func draw(in view: MTKView) {
        guard isDrawingEnabled, view.drawableSize.width > 0, view.drawableSize.height > 0,
              let descriptor = view.currentRenderPassDescriptor,
              let drawable = view.currentDrawable,
              let command = encodeScene(to: descriptor) else { return }
        command.present(drawable)
        command.commit()
    }
}
