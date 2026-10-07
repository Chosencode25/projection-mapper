import MetalKit
import Testing

@MainActor
@Suite(.serialized)
struct CalibrationRendererTests {
    private func rect(_ x0: Float = 0,_ y0: Float = 0,_ x1: Float = 1,_ y1: Float = 1) -> NormalizedRectangle {
        NormalizedRectangle(topLeft: SIMD2(x0,y0),topRight: SIMD2(x1,y0),bottomRight: SIMD2(x1,y1),bottomLeft: SIMD2(x0,y1))
    }
    private func pixels(_ renderer: MetalRenderer, width: Int = 128,height: Int = 128,at uptime: Double = 100) throws -> [UInt8] {
        let desc = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .bgra8Unorm,width: width,height: height,mipmapped: false)
        desc.storageMode = .shared; desc.usage = .renderTarget
        let texture = try #require(renderer.device.makeTexture(descriptor: desc))
        let pass = MTLRenderPassDescriptor(); pass.colorAttachments[0].texture = texture
        let command = try #require(renderer.encodeScene(to: pass,evaluationTime: 0.375,evaluationUptime: uptime))
        command.commit(); command.waitUntilCompleted()
        #expect(command.status == .completed && command.error == nil)
        var bytes = [UInt8](repeating: 0,count: width*height*4)
        bytes.withUnsafeMutableBytes { texture.getBytes($0.baseAddress!,bytesPerRow: width*4,from: MTLRegionMake2D(0,0,width,height),mipmapLevel: 0) }
        return bytes
    }
    private func channel(_ bytes: [UInt8],_ x: Int,_ y: Int,width: Int = 128) -> Int { Int(bytes[(y*width+x)*4]) }
    @Test func whiteAndBlackCoverOnlyMappedFacesAndOpaquePatternsBypassAppearance() throws {
        var face = RenderSurface(geometry: .diagnostic,color: SIMD4(1,0,0,0),content: .particles)
        face.appearance.opacity = 0; face.appearance.brightness = 0
        var scene = RenderScene(surfaces: [face],calibration: CalibrationState(pattern: .white))
        let renderer = try MetalRenderer(scene: scene)
        let white = try pixels(renderer)
        #expect(channel(white,64,64) == 255 && channel(white,0,0) == 0 && channel(white,31,64) == 0)
        #expect(scene.surfaces[0].appearance.opacity == 0)
        scene.calibration.pattern = .black; renderer.setScene(scene)
        let black = try pixels(renderer)
        #expect(stride(from: 0,to: black.count,by: 4).allSatisfy { black[$0] == 0 && black[$0+1] == 0 && black[$0+2] == 0 && black[$0+3] == 255 })
        scene.calibration.pattern = .normal; renderer.setScene(scene)
        #expect(try pixels(renderer) == black)
    }
    @Test func gridCheckerAndFaceLocalCrosshairHaveKnownSamples() throws {
        let face = RenderSurface(geometry: rect(),color: SIMD4(1,0,0,1),content: .solid)
        var scene = RenderScene(surfaces: [face],calibration: CalibrationState(pattern: .grid,columns: 4,rows: 4,lineWidth: 2))
        let renderer = try MetalRenderer(scene: scene)
        let grid = try pixels(renderer)
        #expect(channel(grid,32,16) > 245 && channel(grid,16,16) == 0)
        scene.calibration = CalibrationState(pattern: .checkerboard,columns: 2,rows: 2)
        renderer.setScene(scene); let checker = try pixels(renderer)
        #expect(channel(checker,32,32) == 255 && channel(checker,96,32) == 0)
        #expect(channel(checker,96,96) == 255 && channel(checker,32,96) == 0)
        var mapped = face; mapped.inputMap = FaceInputMap(origin: SIMD2(0.1,0.2),size: SIMD2(0.3,0.4),quarterTurns: 1,mirrored: true)
        scene = RenderScene(surfaces: [mapped],calibration: CalibrationState(pattern: .crosshair,lineWidth: 2))
        renderer.setScene(scene); let crosshair = try pixels(renderer)
        #expect(channel(crosshair,64,32) > 245 && channel(crosshair,32,64) > 245)
        #expect(channel(crosshair,0,32) > 245 && channel(crosshair,32,32) == 0)
    }
    @Test func sharedCanvasMatchesAcrossContinuousAndReversedFacesRepeatIsDistinct() throws {
        let source = SurfaceSource(content: .particles)
        var object = MappingObject(name: "Box",source: source)
        var left = MappingSurface(name: "Left",corners: rect(0,0,0.5,1))
        var right = MappingSurface(name: "Right",corners: rect(0.5,0,1,1))
        left.layout.objectID = object.id; right.layout.objectID = object.id
        left.layout.inputMap = FaceInputMap(size: SIMD2(0.5,1))
        right.layout.inputMap = FaceInputMap(origin: SIMD2(0.5,0),size: SIMD2(0.5,1))
        var project = MappingProject(surface: left); project.surfaces.append(right); project.objects = [object]
        for pattern in [CalibrationPattern.grid,.checkerboard] {
            let config = CalibrationState(pattern: pattern,columns: 4,rows: 4,lineWidth: 2)
            let whole = try MetalRenderer(scene: RenderScene(surfaces: [RenderSurface(geometry: rect(),color: source.color)],calibration: config))
            var scene = project.renderScene; scene.calibration = config
            let tiled = try MetalRenderer(scene: scene)
            let a = try pixels(whole), b = try pixels(tiled)
            #expect(zip(a,b).allSatisfy { abs(Int($0)-Int($1)) <= 2 })
            // Reverse both output face orientation and its input map, preserving owner coordinates.
            project.surfaces[1].corners = NormalizedRectangle(topLeft: SIMD2(1,1),topRight: SIMD2(0.5,1),bottomRight: SIMD2(0.5,0),bottomLeft: SIMD2(1,0))
            project.surfaces[1].layout.inputMap.quarterTurns = 2
            scene = project.renderScene; scene.calibration = config; tiled.setScene(scene)
            #expect(zip(a,try pixels(tiled)).allSatisfy { abs(Int($0)-Int($1)) <= 2 })
            project.surfaces[1] = right
            object.mode = .repeatContent; project.objects = [object]
            scene = project.renderScene; scene.calibration = config; tiled.setScene(scene)
            #expect(zip(a,try pixels(tiled)).filter { abs(Int($0)-Int($1)) > 30 }.count > 1000)
            object.mode = .continuous; project.objects = [object]
        }
    }
    @Test func cropFlipBypassPreservesInputMapsAndNormalDiagnosticPixels() throws {
        var plain = RenderSurface(geometry: rect(),color: SIMD4(1,0,0,1),content: .diagnosticGrid)
        plain.inputMap = FaceInputMap(origin: SIMD2(0.25,0),size: SIMD2(0.5,1),quarterTurns: 1,mirrored: true)
        var changed = plain
        changed.appearance = SurfaceAppearance(opacity: 0.1,brightness: 0.2,crop: ContentCrop(origin: SIMD2(0.1,0.2),size: SIMD2(0.5,0.5)),flipHorizontal: true,flipVertical: true)
        let renderer = try MetalRenderer(scene: RenderScene(surfaces: [changed]))
        let original = try pixels(renderer)
        for pattern in [CalibrationPattern.grid,.checkerboard,.crosshair] {
            let state = CalibrationState(pattern: pattern,lineWidth: 2)
            renderer.setScene(RenderScene(surfaces: [changed],calibration: state))
            let reference = try MetalRenderer(scene: RenderScene(surfaces: [plain],calibration: state))
            #expect(try pixels(renderer) == pixels(reference))
        }
        renderer.setScene(RenderScene(surfaces: [changed]))
        #expect(try pixels(renderer) == original)
        #expect(try pixels(try MetalRenderer(scene: RenderScene(surfaces: [plain]))) != original)
    }
    @Test func visibilityInvalidGeometryAndOpaqueDrawOrderRemainEffective() throws {
        let back = RenderSurface(geometry: rect(),color: SIMD4(1,0,0,1))
        var front = RenderSurface(geometry: rect(0.125,0.125,0.375,0.375),color: back.color)
        front.appearance.opacity = 0; front.inputMap = FaceInputMap(origin: SIMD2(0.5,0),size: SIMD2(0.5,1))
        let config = CalibrationState(pattern: .checkerboard,columns: 2,rows: 2)
        let renderer = try MetalRenderer(scene: RenderScene(surfaces: [back,front],calibration: config))
        #expect(channel(try pixels(renderer),24,24) == 0)
        renderer.setScene(RenderScene(surfaces: [front,back],calibration: config))
        #expect(channel(try pixels(renderer),24,24) == 255)
        var project = MappingProject(); project.surfaces[0].layout.isVisible = false
        var hidden = project.renderScene; hidden.calibration.pattern = .white; renderer.setScene(hidden)
        #expect(channel(try pixels(renderer),64,64) == 0)
        let invalid = RenderSurface(geometry: rect(0,0,0,0),color: back.color)
        renderer.setScene(RenderScene(surfaces: [invalid],calibration: CalibrationState(pattern: .white)))
        #expect(channel(try pixels(renderer),64,64) == 0 && renderer.scene.invalidCount == 1)
        renderer.setScene(RenderScene(surfaces: [back],calibration: CalibrationState(pattern: .white,rows: 0)))
        #expect(channel(try pixels(renderer),64,64) == 0)
    }
    @Test func masterFadeBlackoutAndPreviewOutputParityUseSharedEvaluation() throws {
        var scene = RenderScene(surfaces: [RenderSurface(geometry: rect(),color: SIMD4(0,0,1,1),content: .noise)],masterBrightness: 0.5,calibration: CalibrationState(pattern: .white))
        scene.showOutput.fade(to: 0,duration: 4,at: 100)
        let preview = try MetalRenderer(scene: scene), output = try MetalRenderer(scene: scene)
        let half = try pixels(preview,at: 102)
        #expect(try half == pixels(output,at: 102))
        #expect(abs(channel(half,64,64)-64) <= 1)
        scene.showOutput.blackout(); preview.setScene(scene)
        #expect(channel(try pixels(preview,at: 102),64,64) == 0)
        scene.showOutput.restore(duration: 2,at: 103); preview.setScene(scene)
        #expect(channel(try pixels(preview,at: 103),64,64) == 0)
        #expect(abs(channel(try pixels(preview,at: 105),64,64)-128) <= 1)
        scene.calibration.pattern = .black; preview.setScene(scene)
        #expect(channel(try pixels(preview,at: 105),64,64) == 0)
        scene.calibration.pattern = .white; scene.masterBrightness = 0; preview.setScene(scene)
        #expect(channel(try pixels(preview,at: 105),64,64) == 0)
    }
    @Test func crosshairLineWidthStaysInDrawablePixelsAcrossOutputShapes() throws {
        let face = RenderSurface(geometry: rect(),color: SIMD4(1,0,0,1))
        for (width,height) in [(128,96),(256,144),(96,160)] {
            for lineWidth: Float in [1,4] {
                let renderer = try MetalRenderer(scene: RenderScene(surfaces: [face],calibration: CalibrationState(pattern: .crosshair,lineWidth: lineWidth)))
                let data = try pixels(renderer,width: width,height: height)
                let energy = (width/2-8..<width/2+8).reduce(0.0) { $0 + Double(channel(data,$1,height/4,width: width))/255 }
                #expect(abs(energy-Double(lineWidth)) < 0.25)
            }
        }
    }
    @Test func productionViewCalibrationIdlesFadesCompleteAndBlackTestStaysIdle() throws {
        _ = NSApplication.shared
        var scene = RenderScene(surfaces: [RenderSurface(geometry: rect(),color: SIMD4(1,0,0,1),content: .particles)],calibration: CalibrationState(pattern: .white))
        scene.transport.setPlaying(true,at: 100)
        let renderer = try MetalRenderer(scene: scene)
        let view = MetalSceneView(frame: CGRect(x: 0,y: 0,width: 640,height: 360),rendererFactory: { renderer })
        defer { view.stopRendering() }
        let metal = try #require(view.metalView)
        view.setRenderingActive(true,at: 100)
        #expect(view.window == nil && metal.isPaused && metal.enableSetNeedsDisplay)
        scene.showOutput.fade(to: 0,duration: 4,at: 100); renderer.setScene(scene); view.setRenderingActive(true,at: 100)
        renderer.updateRenderingDemand(at: 102); #expect(!metal.isPaused)
        #expect(channel(try pixels(renderer,at: 104),64,64) == 0)
        renderer.updateRenderingDemand(at: 104); #expect(metal.isPaused)
        scene.showOutput.restore(duration: 2,at: 105); scene.calibration.pattern = .black
        renderer.setScene(scene); view.setRenderingActive(true,at: 106)
        #expect(metal.isPaused && scene.showOutput.gain(at: 106) == 0.5)
        scene.calibration.pattern = .normal; renderer.setScene(scene); view.setRenderingActive(true,at: 107)
        #expect(!metal.isPaused && scene.transport.elapsed(at: 107) == 7)
        view.stopRendering(); renderer.updateRenderingDemand(at: 108)
        #expect(metal.isPaused && !metal.enableSetNeedsDisplay)
    }
    @Test func outputReopenRetainsCalibrationAndCurrentElapsedFadeWithoutShowingWindows() throws {
        let defaults = UserDefaults(suiteName: "v1121.output." + UUID().uuidString)!
        var scene = RenderScene(surfaces: [RenderSurface(geometry: rect(),color: SIMD4(1,0,0,1))],calibration: CalibrationState(pattern: .white))
        scene.showOutput.fade(to: 0,duration: 4,at: 100)
        let coordinator = TestOutputCoordinator(presentWindow: { _ in },scene: scene,preferences: OutputPreferences(defaults: defaults),visibleFrames: { [CGRect(x: 0,y: 0,width: 1600,height: 1000)] })
        defer { coordinator.close() }
        #expect(coordinator.open(for: .testWindow))
        let first = try #require(coordinator.window)
        #expect(!first.isVisible)
        coordinator.close(); #expect(coordinator.scene == scene)
        #expect(coordinator.open(for: .testWindow))
        let reopened = try #require(coordinator.window?.contentView as? TestOutputView)
        let renderer = try #require(reopened.metalView?.delegate as? MetalRenderer)
        #expect(renderer.scene == scene && renderer.scene.effectiveGain(at: 105) == 0)
        #expect(channel(try pixels(renderer,at: 105),64,64) == 0)
        #expect(!coordinator.window!.isVisible && !reopened.isRenderingActive)
    }
}
