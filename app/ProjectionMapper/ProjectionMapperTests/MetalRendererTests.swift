import AppKit
import MetalKit
import SwiftUI
import Testing

@MainActor
@Suite(.serialized)
struct MetalRendererTests {
    @Test func renderingAvailabilityCoversSuspensionAndResume() {
        func available(attached: Bool = true, visible: Bool = true, minimized: Bool = false,
                       occluded: Bool = false, hidden: Bool = false, size: CGSize = CGSize(width: 640, height: 360)) -> Bool {
            MetalSceneView.canRender(attached: attached, visible: visible, minimized: minimized,
                                     occluded: occluded, hidden: hidden, size: size)
        }
        #expect(available())
        #expect(!available(attached: false))
        #expect(!available(visible: false))
        #expect(!available(minimized: true))
        #expect(!available(occluded: true))
        #expect(!available(hidden: true))
        #expect(!available(size: .zero))
        #expect(!available(size: CGSize(width: CGFloat.infinity, height: 10)))
        #expect(available()) // Returning to a visible nonzero surface permits a new frame.
    }

    @Test func unavailableDrawableSkipsFrameAndLaterEncodingStillWorks() throws {
        let renderer = try MetalRenderer()
        let view = UnavailableDrawableView(frame: CGRect(x: 0, y: 0, width: 16, height: 16), device: renderer.device)
        view.drawableSize = CGSize(width: 16, height: 16)
        renderer.draw(in: view)
        #expect(view.descriptorRequests == 1)
        #expect(try centerPixel(renderer) == [0, 64, 255, 255])
    }

    @Test func detachedAndHiddenViewsStayPausedWithoutDrawables() throws {
        _ = NSApplication.shared
        let view = MetalSceneView(frame: CGRect(x: 0, y: 0, width: 640, height: 360))
        view.layoutSubtreeIfNeeded()
        let metal = try #require(view.metalView)
        let renderer = try #require(metal.delegate as? MetalRenderer)
        #expect(!view.isRenderingActive && !renderer.isDrawingEnabled)
        #expect(metal.isPaused && !metal.enableSetNeedsDisplay)
        view.isHidden = true
        view.isHidden = false
        view.setFrameSize(.zero)
        view.layoutSubtreeIfNeeded()
        renderer.draw(in: metal) // No drawable requested for a suspended/zero-sized surface.
        renderer.mtkView(metal, drawableSizeWillChange: .zero)
        #expect(!view.isRenderingActive)
        view.stopRendering(); view.stopRendering()
        #expect(metal.isPaused && !metal.enableSetNeedsDisplay)
    }

    @Test func repeatedOutputCloseReleasesViewsAndRenderers() throws {
        _ = NSApplication.shared
        let suite = "ProjectionMapper.LifecycleTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let output = TestOutputCoordinator(presentWindow: { _ in }, preferences: OutputPreferences(defaults: defaults))
        for _ in 0..<20 {
            weak var view: TestOutputView?
            weak var renderer: MetalRenderer?
            try autoreleasepool {
                #expect(output.open(for: .testWindow))
                let window = try #require(output.window)
                view = window.contentView as? TestOutputView
                renderer = view?.metalView?.delegate as? MetalRenderer
                #expect(renderer != nil && !window.isVisible)
                for preset in TestResolution.allCases { output.setResolution(preset) }
                output.close()
                #expect(window.contentView == nil && window.delegate == nil)
                #expect(!output.isOpen)
            }
            #expect(view == nil && renderer == nil)
        }
    }

    @Test func closingOutputDoesNotSuspendIndependentEditorRenderer() throws {
        _ = NSApplication.shared
        let preview = MetalSceneView(frame: CGRect(x: 0, y: 0, width: 600, height: 400))
        let renderer = try #require(preview.metalView?.delegate as? MetalRenderer)
        let output = TestOutputCoordinator(presentWindow: { _ in })
        output.open(for: .testWindow)
        #expect(output.window?.contentView !== preview)
        output.close()
        #expect(preview.metalView?.delegate === renderer)
        #expect(try centerPixel(renderer) == [0, 64, 255, 255])
    }

    @Test func movingBetweenUnpresentedWindowsAndDetachingRemovesOwnership() throws {
        _ = NSApplication.shared
        let first = NSWindow(contentRect: CGRect(x: 0, y: 0, width: 600, height: 400),
                             styleMask: [.titled], backing: .buffered, defer: false)
        let second = NSWindow(contentRect: first.frame, styleMask: [.titled], backing: .buffered, defer: false)
        first.isReleasedWhenClosed = false; second.isReleasedWhenClosed = false
        weak var renderer: MetalRenderer?
        weak var released: MetalSceneView?
        try autoreleasepool {
            let view = MetalSceneView(frame: first.contentLayoutRect)
            renderer = try #require(view.metalView?.delegate as? MetalRenderer)
            released = view
            first.contentView = view
            second.contentView = view
            NotificationCenter.default.post(name: NSWindow.willCloseNotification, object: first)
            #expect(view.window === second && !view.isRenderingActive)
            second.contentView = nil
        }
        #expect(released == nil && renderer == nil)
        first.close(); second.close()
    }

    @Test func sharedPreviewAndOutputUseSessionSceneAcrossPresets() throws {
        _ = NSApplication.shared
        let scene = RenderScene(geometry: .diagnostic, color: SIMD4(0, 1, 0, 1))
        let session = EditorSession(presentOutput: { _ in }, project: MappingProject(surface: MappingSurface(color: scene.color, content: .solid)))
        let host = NSHostingView(rootView: MetalScenePreview(scene: session.scene, aspectRatio: 16.0 / 9.0,
                                                           outputDescription: "HD"))
        let editor = NSWindow(contentRect: CGRect(x: 0, y: 0, width: 600, height: 400),
                              styleMask: [.titled, .resizable], backing: .buffered, defer: false)
        editor.isReleasedWhenClosed = false
        editor.contentView = host
        // Hosted layout is exercised without presenting the test window.
        defer { editor.close(); session.testOutput.close() }
        for resolution in TestResolution.allCases {
            session.setTestResolution(resolution)
            host.rootView = MetalScenePreview(scene: session.scene, aspectRatio: resolution.aspectRatio,
                                             outputDescription: resolution.dimensions)
            host.layoutSubtreeIfNeeded()
            RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.03))
            let preview = try #require(findSceneView(in: host))
            let previewRenderer = try #require(preview.metalView?.delegate as? MetalRenderer)
            #expect(session.testOutput.open(for: .testWindow, resolution: resolution))
            let output = try #require(session.testOutput.window?.contentView as? TestOutputView)
            let outputRenderer = try #require(output.metalView?.delegate as? MetalRenderer)
            #expect(previewRenderer !== outputRenderer)
            #expect(previewRenderer.scene == session.scene && outputRenderer.scene == session.scene)
            #expect(abs(preview.outputFrame.width / preview.outputFrame.height - resolution.aspectRatio) < 0.001)
            #expect(abs(output.outputFrame.width / output.outputFrame.height - resolution.aspectRatio) < 0.001)
            #expect(try centerPixel(previewRenderer) == [0, 255, 0, 255])
            #expect(try centerPixel(outputRenderer) == [0, 255, 0, 255])
            session.testOutput.close()
            #expect(previewRenderer.scene == scene && !session.testOutput.isOpen)
        }
        session.isSidebarVisible = false
        session.isInspectorVisible = false
        session.renameProject("House")
        session.resetProject()
        #expect(session.scene == .diagnosticGrid && !session.hasUserChanges)
        #expect(findSceneView(in: host)?.metalView != nil)
    }

    private func findSceneView(in view: NSView) -> MetalSceneView? {
        if let scene = view as? MetalSceneView { return scene }
        return view.subviews.lazy.compactMap { findSceneView(in: $0) }.first
    }

    private func centerPixel(_ renderer: MetalRenderer) throws -> [UInt8] {
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: MetalRenderer.pixelFormat,
                                                                  width: 16, height: 16, mipmapped: false)
        descriptor.storageMode = .shared
        descriptor.usage = .renderTarget
        let texture = try #require(renderer.device.makeTexture(descriptor: descriptor))
        let pass = MTLRenderPassDescriptor()
        pass.colorAttachments[0].texture = texture
        let command = try #require(renderer.encodeScene(to: pass))
        command.commit()
        command.waitUntilCompleted()
        #expect(command.status == .completed && command.error == nil)
        var pixel = [UInt8](repeating: 0, count: 4)
        pixel.withUnsafeMutableBytes {
            texture.getBytes($0.baseAddress!, bytesPerRow: 4,
                             from: MTLRegionMake2D(8, 8, 1, 1), mipmapLevel: 0)
        }
        return pixel
    }

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
        var contentKind: UInt32 = 0
        var appearance = SIMD2<Float>(1,1)
        var masterGain: Float = 1
        encoder.setFragmentBytes(&contentKind,length: MemoryLayout<UInt32>.stride,index: 2)
        encoder.setFragmentBytes(&appearance,length: MemoryLayout<SIMD2<Float>>.stride,index: 9)
        encoder.setFragmentBytes(&masterGain,length: MemoryLayout<Float>.stride,index: 10)
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
        let renderer = try MetalRenderer(scene: RenderScene(geometry: geometry, color: RenderScene.diagnostic.color))
        try verifyScenePixels(renderer, xRange: 2..<6, yRange: 1..<5)
        #expect(renderer.geometry == geometry)
    }

    @Test func gpuRectanglePreservesFractionalCoverageAcrossOutputShapes() throws {
        let renderer = try MetalRenderer()
        for (width, height) in [(64, 36), (32, 24), (36, 64)] {
            try verifyScenePixels(renderer, xRange: width/4..<width*3/4, yRange: height/4..<height*3/4,
                                  width: width, height: height)
        }
    }

    private func verifyScenePixels(_ renderer: MetalRenderer, xRange: Range<Int>, yRange: Range<Int>,
                                   width: Int = 16, height: Int = 16) throws {
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .bgra8Unorm,
                                                                  width: width, height: height, mipmapped: false)
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
        var pixels = [UInt8](repeating: 0, count: width * height * 4)
        pixels.withUnsafeMutableBytes {
            texture.getBytes($0.baseAddress!, bytesPerRow: width * 4,
                             from: MTLRegionMake2D(0, 0, width, height), mipmapLevel: 0)
        }
        // Verify every pixel, including the seam and the black exterior.
        for y in 0..<height {
            for x in 0..<width {
                let offset = (y * width + x) * 4
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
        for size in [CGSize(width: 800, height: 450), CGSize(width: 400, height: 600), CGSize(width: 600, height: 600)] {
            #expect(output.open(for: .testWindow))
            let window = try #require(output.window)
            let content = try #require(window.contentView as? TestOutputView)
            // AppKit can report these windows as occluded; that must suspend invalidation.
            RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.03))
            content.layoutSubtreeIfNeeded()
            let expectedActive = MetalSceneView.canRender(attached: content.window === window,
                visible: window.isVisible, minimized: window.isMiniaturized,
                occluded: !window.occlusionState.contains(.visible), hidden: content.isHiddenOrHasHiddenAncestor,
                size: content.outputFrame.size)
            #expect(content.isRenderingActive == expectedActive)
            let metal = try #require(content.metalView)
            let renderer = try #require(metal.delegate as? MetalRenderer)
            let originalGeometry = renderer.geometry
            #expect(content.renderingError == nil)
            #expect(metal.device != nil && metal.delegate != nil)
            #expect(metal.isPaused && metal.enableSetNeedsDisplay == expectedActive)
            #expect(renderer.isDrawingEnabled == expectedActive)
            #expect(metal.autoResizeDrawable)
            window.setContentSize(size)
            let originalFrame = window.frame
            var landscapeDrawableSize: CGSize?
            for resolution in TestResolution.allCases {
                output.setResolution(resolution)
                content.layoutSubtreeIfNeeded()
                #expect(output.window === window && content.metalView === metal)
                #expect(window.frame == originalFrame)
                #expect(content.outputFrame == resolution.fittedRect(in: content.bounds))
                #expect(abs(content.outputFrame.midX - content.bounds.midX) < 0.001)
                #expect(abs(content.outputFrame.midY - content.bounds.midY) < 0.001)
                #expect(abs(content.outputFrame.width / content.outputFrame.height - resolution.aspectRatio) < 0.001)
                #expect(content.resolution == resolution)
                #expect(renderer.geometry == originalGeometry && originalGeometry == .diagnostic)
                metal.draw()
                let drawable = try #require(metal.currentDrawable)
                let pixels = CGSize(width: drawable.texture.width, height: drawable.texture.height)
                let nativeSize = metal.convertToBacking(metal.bounds).size
                #expect(abs(pixels.width - nativeSize.width) <= 1)
                #expect(abs(pixels.height - nativeSize.height) <= 1)
                if [.hd, .fullHD, .ultraHD].contains(resolution) {
                    if let landscapeDrawableSize { #expect(pixels == landscapeDrawableSize) }
                    else { landscapeDrawableSize = pixels }
                }
            }
            output.close()
            #expect(!output.isOpen)
        }
    }
}


/// No layer/drawable is acquired, so this probe never presents a window.
@MainActor
private final class UnavailableDrawableView: MTKView {
    var descriptorRequests = 0
    override var currentRenderPassDescriptor: MTLRenderPassDescriptor? {
        descriptorRequests += 1
        return nil
    }
}
