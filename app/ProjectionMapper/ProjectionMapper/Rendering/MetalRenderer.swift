import MetalKit

enum MetalInitializationError: LocalizedError {
    case deviceUnavailable
    case commandQueueUnavailable

    var errorDescription: String? {
        switch self {
        case .deviceUnavailable: "Metal is unavailable on this Mac. Test Output cannot render."
        case .commandQueueUnavailable: "Metal could not create a command queue. Close and reopen Test Output to try again."
        }
    }
}

/// Rendering is independent of output-window ownership and simulated resolution.
@MainActor
final class MetalRenderer: NSObject, MTKViewDelegate {
    let device: any MTLDevice
    let commandQueue: any MTLCommandQueue
    static let diagnosticColor = MTLClearColor(red: 0.05, green: 0.35, blue: 0.55, alpha: 1)

    init(deviceProvider: () -> (any MTLDevice)? = { MTLCreateSystemDefaultDevice() },
         queueProvider: (any MTLDevice) -> (any MTLCommandQueue)? = { $0.makeCommandQueue() }) throws {
        guard let device = deviceProvider() else { throw MetalInitializationError.deviceUnavailable }
        guard let queue = queueProvider(device) else { throw MetalInitializationError.commandQueueUnavailable }
        self.device = device
        commandQueue = queue
        super.init()
    }

    /// Also used by GPU readback checks to verify the actual clear operation.
    func encodeClear(to descriptor: MTLRenderPassDescriptor) -> (any MTLCommandBuffer)? {
        descriptor.colorAttachments[0].loadAction = .clear
        descriptor.colorAttachments[0].storeAction = .store
        descriptor.colorAttachments[0].clearColor = Self.diagnosticColor
        guard let command = commandQueue.makeCommandBuffer(),
              let encoder = command.makeRenderCommandEncoder(descriptor: descriptor) else { return nil }
        command.label = "Diagnostic output clear"
        encoder.endEncoding()
        return command
    }

    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
        view.needsDisplay = true
    }

    func draw(in view: MTKView) {
        guard view.drawableSize.width > 0, view.drawableSize.height > 0,
              let descriptor = view.currentRenderPassDescriptor,
              let drawable = view.currentDrawable,
              let command = encodeClear(to: descriptor) else { return }
        command.present(drawable)
        command.commit()
    }
}
