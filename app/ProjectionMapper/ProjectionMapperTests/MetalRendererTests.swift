import AppKit
import MetalKit
import Testing

@MainActor
@Suite(.serialized)
struct MetalRendererTests {
    @Test func compiledPipelineRendersSuppliedVerticesAndColor() throws {
        let renderer = try MetalRenderer()
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: MetalRenderer.pixelFormat,
                                                                  width: 16, height: 16, mipmapped: false)
        descriptor.storageMode = .shared
        descriptor.usage = .renderTarget
        let texture = try #require(renderer.device.makeTexture(descriptor: descriptor))
        let pass = MTLRenderPassDescriptor()
        pass.colorAttachments[0].texture = texture
        pass.colorAttachments[0].loadAction = .clear
        pass.colorAttachments[0].storeAction = .store
        pass.colorAttachments[0].clearColor = MTLClearColorMake(0, 0, 0, 1)
        let command = try #require(renderer.commandQueue.makeCommandBuffer())
        let encoder = try #require(command.makeRenderCommandEncoder(descriptor: pass))
        encoder.setRenderPipelineState(renderer.rectanglePipeline)
        // A full-target probe triangle checks the shader buffer contract without changing app output.
        let positions: [SIMD2<Float>] = [SIMD2(-1, -1), SIMD2(3, -1), SIMD2(-1, 3)]
        positions.withUnsafeBytes { encoder.setVertexBytes($0.baseAddress!, length: $0.count, index: 0) }
        var color = SIMD4<Float>(1, 0.25, 0, 1)
        encoder.setFragmentBytes(&color, length: MemoryLayout<SIMD4<Float>>.stride, index: 0)
        encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: positions.count)
        encoder.endEncoding()
        command.commit()
        command.waitUntilCompleted()
        #expect(command.status == .completed && command.error == nil)
        var pixel = [UInt8](repeating: 0, count: 4)
        pixel.withUnsafeMutableBytes {
            texture.getBytes($0.baseAddress!, bytesPerRow: 4,
                             from: MTLRegionMake2D(8, 8, 1, 1), mipmapLevel: 0)
        }
        #expect(pixel[0] == 0 && abs(Int(pixel[1]) - 64) <= 1 && pixel[2] == 255 && pixel[3] == 255)
    }

    @Test func shaderAndPipelineFailuresShowOutputError() throws {
        _ = NSApplication.shared
        let frame = CGRect(x: 0, y: 0, width: 640, height: 360)
        let missingLibrary = TestOutputView(frame: frame) {
            try MetalRenderer(libraryProvider: { _ in throw CocoaError(.fileNoSuchFile) })
        }
        #expect(missingLibrary.metalView == nil)
        #expect(missingLibrary.renderingError?.contains("could not load the output shaders") == true)
        let missingFunction = TestOutputView(frame: frame) {
            try MetalRenderer(libraryProvider: {
                try $0.makeLibrary(source: "#include <metal_stdlib>\nusing namespace metal;\nkernel void unused() {}", options: nil)
            })
        }
        #expect(missingFunction.metalView == nil)
        #expect(missingFunction.renderingError?.contains("rectangleVertex") == true)
        let invalidPipeline = TestOutputView(frame: frame) {
            try MetalRenderer(pipelineProvider: { _, _ in throw CocoaError(.coderInvalidValue) })
        }
        #expect(invalidPipeline.metalView == nil)
        #expect(invalidPipeline.renderingError?.contains("could not create the output pipeline") == true)
        let labels = invalidPipeline.subviews.flatMap(\.subviews).compactMap { $0 as? NSTextField }
        #expect(labels.first?.stringValue == invalidPipeline.renderingError)
    }

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

    @Test func gpuSceneDrawsRectangleAndBlackBackground() throws {
        let renderer = try MetalRenderer()
        try verifyScenePixels(renderer, xRange: 4..<12, yRange: 4..<12)
    }

    @Test func normalizedCoordinatesHaveTopLeftOriginAndCorrectAxes() {
        #expect(NormalizedRectangle.clipPosition(SIMD2(0, 0)) == SIMD2(-1, 1))
        #expect(NormalizedRectangle.clipPosition(SIMD2(1, 0)) == SIMD2(1, 1))
        #expect(NormalizedRectangle.clipPosition(SIMD2(1, 1)) == SIMD2(1, -1))
        #expect(NormalizedRectangle.clipPosition(SIMD2(0, 1)) == SIMD2(-1, -1))
        #expect(NormalizedRectangle.clipPosition(SIMD2(0.5, 0.5)) == .zero)
    }

    @Test func offCenterNormalizedGeometryRendersAtExpectedPixels() throws {
        let geometry = NormalizedRectangle(
            topLeft: SIMD2(0.125, 0.0625), topRight: SIMD2(0.375, 0.0625),
            bottomRight: SIMD2(0.375, 0.3125), bottomLeft: SIMD2(0.125, 0.3125)
        )
        let renderer = try MetalRenderer(geometry: geometry)
        try verifyScenePixels(renderer, xRange: 2..<6, yRange: 1..<5)
        #expect(renderer.geometry == geometry)
    }

    private func verifyScenePixels(_ renderer: MetalRenderer, xRange: Range<Int>, yRange: Range<Int>) throws {
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .bgra8Unorm,
                                                                  width: 16, height: 16, mipmapped: false)
        descriptor.storageMode = .shared
        descriptor.usage = .renderTarget
        let texture = try #require(renderer.device.makeTexture(descriptor: descriptor))
        let pass = MTLRenderPassDescriptor()
        pass.colorAttachments[0].texture = texture
        let command = try #require(renderer.encodeScene(to: pass))
        command.commit()
        command.waitUntilCompleted()
        #expect(command.status == .completed)
        #expect(command.error == nil)
        var pixels = [UInt8](repeating: 0, count: 16 * 16 * 4)
        pixels.withUnsafeMutableBytes {
            texture.getBytes($0.baseAddress!, bytesPerRow: 16 * 4,
                             from: MTLRegionMake2D(0, 0, 16, 16), mipmapLevel: 0)
        }
        // Verify every pixel, including the seam and the black exterior.
        for y in 0..<16 {
            for x in 0..<16 {
                let offset = (y * 16 + x) * 4
                let inside = xRange.contains(x) && yRange.contains(y)
                #expect(pixels[offset] == 0)
                #expect(abs(Int(pixels[offset + 1]) - (inside ? 64 : 0)) <= 1)
                #expect(pixels[offset + 2] == (inside ? 255 : 0))
                #expect(pixels[offset + 3] == 255)
            }
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
            let renderer = try #require(metal.delegate as? MetalRenderer)
            let originalGeometry = renderer.geometry
            #expect(content.renderingError == nil)
            #expect(metal.device != nil && metal.delegate != nil)
            #expect(metal.isPaused && metal.enableSetNeedsDisplay)
            for size in [CGSize(width: 800, height: 450), CGSize(width: 400, height: 600)] {
                window.setContentSize(size)
                content.layoutSubtreeIfNeeded()
                #expect(content.outputFrame == resolution.fittedRect(in: content.bounds))
                #expect(content.resolution == resolution)
                #expect(renderer.geometry == originalGeometry && originalGeometry == .diagnostic)
                metal.draw()
                #expect(metal.currentDrawable != nil)
            }
            output.close()
            #expect(!output.isOpen)
        }
    }
}
