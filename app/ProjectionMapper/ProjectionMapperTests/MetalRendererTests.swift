import AppKit
import MetalKit
import Testing

@MainActor
@Suite(.serialized)
struct MetalRendererTests {
    @Test func initializationFailuresShowReadableOutputError() throws {
        _ = NSApplication.shared
        let missingDevice = TestOutputView(frame: CGRect(x: 0, y: 0, width: 640, height: 360)) {
            try MetalRenderer(deviceProvider: { nil })
        }
        #expect(missingDevice.metalView == nil)
        #expect(missingDevice.renderingError == MetalInitializationError.deviceUnavailable.localizedDescription)
        let device = try #require(MTLCreateSystemDefaultDevice())
        let missingQueue = TestOutputView(frame: missingDevice.frame) {
            try MetalRenderer(deviceProvider: { device }, queueProvider: { _ in nil })
        }
        #expect(missingQueue.metalView == nil)
        #expect(missingQueue.renderingError == MetalInitializationError.commandQueueUnavailable.localizedDescription)
        let messages = missingQueue.subviews.flatMap(\.subviews).compactMap { $0 as? NSTextField }
        #expect(messages.first?.stringValue == missingQueue.renderingError)
        missingQueue.resolution = .portrait
        #expect(missingQueue.outputFrame == TestResolution.portrait.fittedRect(in: missingQueue.bounds))
    }

    @Test func gpuClearWritesDiagnosticPixels() throws {
        let renderer = try MetalRenderer()
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .bgra8Unorm,
                                                                  width: 16, height: 16, mipmapped: false)
        descriptor.storageMode = .shared
        descriptor.usage = .renderTarget
        let texture = try #require(renderer.device.makeTexture(descriptor: descriptor))
        let pass = MTLRenderPassDescriptor()
        pass.colorAttachments[0].texture = texture
        let command = try #require(renderer.encodeClear(to: pass))
        command.commit()
        command.waitUntilCompleted()
        #expect(command.status == .completed)
        #expect(command.error == nil)
        var pixels = [UInt8](repeating: 0, count: 16 * 16 * 4)
        pixels.withUnsafeMutableBytes {
            texture.getBytes($0.baseAddress!, bytesPerRow: 16 * 4,
                             from: MTLRegionMake2D(0, 0, 16, 16), mipmapLevel: 0)
        }
        // BGRA bytes read from GPU memory, including opposite corners.
        for offset in [0, pixels.count - 4] {
            #expect(abs(Int(pixels[offset]) - 140) <= 1)
            #expect(abs(Int(pixels[offset + 1]) - 89) <= 1)
            #expect(abs(Int(pixels[offset + 2]) - 13) <= 1)
            #expect(pixels[offset + 3] == 255)
        }
    }

    @Test func nativeMetalOutputSurvivesPresetsResizeAndReopen() throws {
        _ = NSApplication.shared
        let suite = "ProjectionMapper.MetalWindowTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let output = TestOutputCoordinator(preferences: OutputPreferences(defaults: defaults))
        defer { output.close() }
        for resolution in TestResolution.allCases {
            #expect(output.open(for: .testWindow, resolution: resolution))
            let window = try #require(output.window)
            let content = try #require(window.contentView as? TestOutputView)
            let metal = try #require(content.metalView)
            #expect(content.renderingError == nil)
            #expect(metal.device != nil && metal.delegate != nil)
            #expect(metal.isPaused && metal.enableSetNeedsDisplay)
            for size in [CGSize(width: 800, height: 450), CGSize(width: 400, height: 600)] {
                window.setContentSize(size)
                content.layoutSubtreeIfNeeded()
                #expect(content.outputFrame == resolution.fittedRect(in: content.bounds))
                #expect(content.resolution == resolution)
                metal.draw()
                #expect(metal.currentDrawable != nil)
            }
            output.close()
            #expect(!output.isOpen)
        }
    }
}
