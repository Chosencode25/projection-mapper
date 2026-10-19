import AppKit
import CoreVideo
import Darwin
import MetalKit
import Testing

@MainActor
@Suite(.serialized)
struct RenderPerformanceTests {
    @Test func diagnosticsBoundSamplesButPreserveTotals() {
        let diagnostics = RenderDiagnostics(capacity: 2)
        for index in 0..<5 {
            diagnostics.submitted()
            diagnostics.completed(RenderTimingSample(view: "\(index)", width: 16, height: 16,
                encodeMilliseconds: 1, completionMilliseconds: 2, gpuMilliseconds: nil, succeeded: true))
        }
        diagnostics.skipped("suspended"); diagnostics.skipped("suspended")
        let snapshot = diagnostics.snapshot()
        #expect(snapshot.submissions == 5 && snapshot.completions == 5)
        #expect(snapshot.samples.map(\.view) == ["3", "4"])
        #expect(snapshot.skips["suspended"] == 2)
        let countersOnly = RenderDiagnostics(capacity: 0)
        countersOnly.submitted()
        #expect(countersOnly.snapshot().samples.isEmpty && countersOnly.snapshot().submissions == 1)
    }

    @Test func unavailableGPUTimestampsAreNotReportedAsZero() {
        #expect(RenderTimingSample.gpuDuration(start: 0, end: 0) == nil)
        #expect(RenderTimingSample.gpuDuration(start: 2, end: 1) == nil)
        #expect(RenderTimingSample.gpuDuration(start: .nan, end: 1) == nil)
        #expect(RenderTimingSample.gpuDuration(start: 1, end: 1.002)! > 1.99)
    }

    @Test func optionalDiagnosticsCaptureCompletedGPUWorkAndRelease() throws {
        weak var released: RenderDiagnostics?
        try autoreleasepool {
            let diagnostics = RenderDiagnostics(capacity: 2)
            released = diagnostics
            let renderer = try MetalRenderer(diagnostics: diagnostics)
            let texture = try makeTexture(renderer, width: 16, height: 16)
            let command = try #require(renderer.encodeScene(to: pass(texture), viewIdentifier: "probe"))
            command.commit(); command.waitUntilCompleted()
            let deadline = Date(timeIntervalSinceNow: 1)
            while diagnostics.snapshot().completions == 0 && Date() < deadline { Thread.sleep(forTimeInterval: 0.001) }
            let sample = try #require(diagnostics.snapshot().samples.first)
            #expect(sample.view == "probe" && sample.width == 16 && sample.height == 16 && sample.succeeded)
            #expect(sample.encodeMilliseconds >= 0 && sample.completionMilliseconds >= sample.encodeMilliseconds)
            #expect(diagnostics.snapshot().submissions == 1)
        }
        #expect(released == nil)
        #expect(try MetalRenderer().diagnostics == nil)
    }

    @Test func suspendedDrawsAreCountedWithoutSubmission() throws {
        let diagnostics = RenderDiagnostics()
        let renderer = try MetalRenderer(diagnostics: diagnostics)
        renderer.isDrawingEnabled = false
        let view = MTKView(frame: .zero, device: renderer.device)
        renderer.draw(in: view)
        #expect(diagnostics.snapshot().submissions == 0)
        #expect(diagnostics.snapshot().skips["suspended"] == 1)
    }

    @Test func runtimeUpdatesReuseGeometryAndStillRenderNewVideoFrames() throws {
        let owner = UUID(), asset = videoAsset()
        let red = try videoFrame(asset, color: SIMD4(0,0,255,255))
        let green = try videoFrame(asset, color: SIMD4(0,255,0,255))
        var face = RenderSurface(geometry: .diagnostic, color: SIMD4(1,1,1,1), content: .video,
            sourceID: owner, video: VideoContent(assetID: asset.id,outPoint: 4,placement: .stretch,canvasAspect: 1))
        face.mask = FaceMask(holes: [MaskPolygon(points: [SIMD2(0.1,0.1),SIMD2(0.3,0.1),SIMD2(0.3,0.3),SIMD2(0.1,0.3)])])
        var scene = RenderScene(surfaces: [face])
        scene.videoFrames = [owner:red]
        let renderer = try MetalRenderer(scene: scene)
        let before = try pixels(renderer)
        // Decoder/transport snapshots should not rerun mask validation or matrix/vertex
        // preparation, while each newly published video texture still reaches output.
        for index in 0..<120 {
            scene.transport.seek(to: Double(index)/60,at: 100)
            scene.videoFrames = [owner:index.isMultiple(of: 2) ? red : green]
            scene.masterBrightness = index.isMultiple(of: 2) ? 1 : 0.75
            scene.outputTimingFixtureActive = index.isMultiple(of: 2)
            renderer.setScene(scene)
        }
        #expect(renderer.surfacePreparationCount == 1)
        let after = try pixels(renderer)
        #expect(before != after)
        #expect(try pixels(MetalRenderer(scene: scene)) == after)
        scene.showOutput.blackout(); renderer.setScene(scene)
        #expect(renderer.surfacePreparationCount == 1)
        let black = try pixels(renderer)
        #expect(stride(from: 0,to: black.count,by: 4).allSatisfy { black[$0] == 0 && black[$0+1] == 0 && black[$0+2] == 0 })
    }

    @Test func cachedPayloadsFollowSurfaceAndCalibrationEdits() throws {
        var face = RenderSurface(geometry: .diagnostic,color: SIMD4(1,0.3,0.1,1),content: .gradient)
        face.mask = FaceMask()
        let renderer = try MetalRenderer(scene: RenderScene(surfaces: [face]))
        func verify(_ scene: RenderScene) throws {
            renderer.setScene(scene)
            #expect(try pixels(renderer) == pixels(MetalRenderer(scene: scene)))
        }
        face.inputMap.quarterTurns = 1
        try verify(RenderScene(surfaces: [face]))
        face.appearance.flipHorizontal = true
        face.appearance.crop = ContentCrop(origin: SIMD2(0.1,0.1),size: SIMD2(0.7,0.8))
        try verify(RenderScene(surfaces: [face]))
        face.mask?.holes = [MaskPolygon(points: [SIMD2(0.25,0.25),SIMD2(0.75,0.25),SIMD2(0.75,0.75),SIMD2(0.25,0.75)])]
        try verify(RenderScene(surfaces: [face]))
        face = RenderSurface(geometry: NormalizedRectangle(topLeft: SIMD2(0.1,0.1),topRight: SIMD2(0.85,0.2),bottomRight: SIMD2(0.9,0.8),bottomLeft: SIMD2(0.2,0.9)),
            color: face.color, content: face.content, inputMap: face.inputMap, appearance: face.appearance, mask: face.mask)
        try verify(RenderScene(surfaces: [face]))
        face.appearance.opacity = 0
        var scene = RenderScene(surfaces: [face])
        try verify(scene)
        let normalCount = renderer.surfacePreparationCount
        scene.calibration.pattern = .white
        try verify(scene)
        #expect(renderer.surfacePreparationCount == normalCount+1)
        scene.calibration.pattern = .grid; scene.calibration.columns = 12
        try verify(scene)
        #expect(renderer.surfacePreparationCount == normalCount+1)
        scene.calibration.columns = 0
        try verify(scene)
        #expect(renderer.surfacePreparationCount == normalCount+2)
        scene.calibration.columns = 8; scene.calibration.pattern = .normal
        try verify(scene)
        #expect(renderer.surfacePreparationCount == normalCount+3)
        try verify(RenderScene(surfaces: []))
    }

    @Test func sequencedVideoOwnerChangeDoesNotReuseThePreviousOwner() throws {
        let firstOwner = UUID(), secondOwner = UUID(), asset = videoAsset()
        let red = try videoFrame(asset,color: SIMD4(0,0,255,255))
        let green = try videoFrame(asset,color: SIMD4(0,255,0,255))
        let source = SurfaceSource(content: .video,video: VideoContent(assetID: asset.id,outPoint: 4,placement: .stretch,canvasAspect: 1))
        let clip = EffectClip(sourceID: firstOwner,start: 0,duration: 4,source: SourceLook(source: source))
        var first = RenderSurface(geometry: .diagnostic,color: SIMD4(1,1,1,1),content: .solid,sourceID: firstOwner,timelineClips: [clip])
        var scene = RenderScene(surfaces: [first])
        scene.videoFrames = [firstOwner:VideoFrame(buffer: red.pixelBuffer,asset: asset,clipID: clip.id,sourceTime: 0),
                             secondOwner:VideoFrame(buffer: green.pixelBuffer,asset: asset,clipID: clip.id,sourceTime: 0)]
        let renderer = try MetalRenderer(scene: scene), before = try pixels(renderer)
        first.sourceID = secondOwner
        var changed = RenderScene(surfaces: [first]); changed.videoFrames = scene.videoFrames
        #expect(changed.surfaces == scene.surfaces) // Procedural source equality omits owner identity.
        renderer.setScene(changed)
        #expect(renderer.surfacePreparationCount == 2)
        let after = try pixels(renderer)
        #expect(before != after)
        #expect(try pixels(MetalRenderer(scene: changed)) == after)
    }

    private func videoAsset() -> VideoAsset {
        VideoAsset(name: "preparation fixture",fileExtension: "mp4",byteCount: 4096,duration: 4,width: 16,height: 16,
            frameRate: 60,hasAudio: false,codec: "H.264",transform: [1,0,0,1,0,0])
    }
    private func videoFrame(_ asset: VideoAsset,color: SIMD4<UInt8>) throws -> VideoFrame {
        var buffer: CVPixelBuffer?
        #expect(CVPixelBufferCreate(kCFAllocatorDefault,16,16,kCVPixelFormatType_32BGRA,
            [kCVPixelBufferIOSurfacePropertiesKey:[:]] as CFDictionary,&buffer) == kCVReturnSuccess)
        let pixels = try #require(buffer)
        CVPixelBufferLockBaseAddress(pixels,[])
        defer { CVPixelBufferUnlockBaseAddress(pixels,[]) }
        let base = try #require(CVPixelBufferGetBaseAddress(pixels)).assumingMemoryBound(to: UInt8.self)
        for y in 0..<16 { for x in 0..<16 {
            let offset = y*CVPixelBufferGetBytesPerRow(pixels)+x*4
            for component in 0..<4 { base[offset+component] = color[component] }
        } }
        return VideoFrame(buffer: pixels,asset: asset,clipID: nil,sourceTime: 0)
    }
    private func pixels(_ renderer: MetalRenderer) throws -> [UInt8] {
        let texture = try makeTexture(renderer,width: 32,height: 32)
        let command = try #require(renderer.encodeScene(to: pass(texture),evaluationTime: 0.375,evaluationUptime: 100))
        command.commit(); command.waitUntilCompleted()
        #expect(command.status == .completed && command.error == nil)
        var bytes = [UInt8](repeating: 0,count: 32*32*4)
        bytes.withUnsafeMutableBytes { texture.getBytes($0.baseAddress!,bytesPerRow: 32*4,
            from: MTLRegionMake2D(0,0,32,32),mipmapLevel: 0) }
        return bytes
    }

    @Test(.enabled(if: ProcessInfo.processInfo.environment["PROJECTION_MAPPER_PERFORMANCE_OUTPUT"] != nil))
    func offscreenPerformanceMatrix() throws {
        let directory = try #require(ProcessInfo.processInfo.environment["PROJECTION_MAPPER_PERFORMANCE_OUTPUT"])
        var samples: [BenchmarkSample] = []
        let device = try #require(MTLCreateSystemDefaultDevice())
        let metadata: [String: Any] = ["device": device.name, "memoryBytes": ProcessInfo.processInfo.physicalMemory,
            "cpuCount": ProcessInfo.processInfo.processorCount, "os": ProcessInfo.processInfo.operatingSystemVersionString,
            "thermalState": ProcessInfo.processInfo.thermalState.rawValue,
            "lowPowerMode": ProcessInfo.processInfo.isLowPowerModeEnabled,
            "method": "Release; 30 warmup + 300 samples, 3 repeats; sequential single/two-queue pair; validation disabled"]
        for (preset, width, height) in dimensions {
            for count in [1, 2] {
                let renderers = try (0..<count).map { _ in try MetalRenderer() }
                let textures = try renderers.map { try makeTexture($0, width: width, height: height) }
                for repeatIndex in 0..<3 {
                    for index in -30..<300 {
                        try autoreleasepool {
                            let start = ProcessInfo.processInfo.systemUptime
                            let commands = try zip(renderers, textures).map { renderer, texture in
                                try #require(renderer.encodeScene(to: pass(texture)))
                            }
                            let encoded = ProcessInfo.processInfo.systemUptime
                            commands.forEach { $0.commit() }
                            commands.forEach { $0.waitUntilCompleted() }
                            let completed = ProcessInfo.processInfo.systemUptime
                            #expect(commands.allSatisfy { $0.status == .completed && $0.error == nil })
                            if index >= 0 {
                                let times = commands.compactMap { RenderTimingSample.gpuDuration(start: $0.gpuStartTime, end: $0.gpuEndTime) }
                                let starts = commands.map(\.gpuStartTime), ends = commands.map(\.gpuEndTime)
                                samples.append(BenchmarkSample(preset: preset, width: width, height: height, views: count,
                                    repetition: repeatIndex, index: index,
                                    cpuMilliseconds: (encoded - start) * 1_000,
                                    gpuMilliseconds: times.count == count ? times.reduce(0, +) : nil,
                                    gpuSpanMilliseconds: starts.allSatisfy { $0 > 0 } ? (ends.max()! - starts.min()!) * 1_000 : nil,
                                    completionMilliseconds: (completed - start) * 1_000))
                            }
                        }
                    }
                    for texture in textures { try verifyPixels(texture) }
                }
            }
        }
        try write(samples, to: directory + "/offscreen-samples.json")
        try JSONSerialization.data(withJSONObject: metadata, options: [.prettyPrinted, .sortedKeys])
            .write(to: URL(fileURLWithPath: directory + "/machine.json"))
        #expect(samples.count == 9_000)
    }

    @Test(.enabled(if: ProcessInfo.processInfo.environment["PROJECTION_MAPPER_REDRAW_OUTPUT"] != nil))
    func syntheticRedrawLatency() throws {
        _ = NSApplication.shared
        let directory = try #require(ProcessInfo.processInfo.environment["PROJECTION_MAPPER_REDRAW_OUTPUT"])
        let diagnostics = RenderDiagnostics(capacity: 500)
        let window = makeWindow(width: 640, height: 360, diagnostics: diagnostics)
        defer { window.contentView = nil; window.close() }
        let view = try #require(window.contentView as? MetalSceneView)
        let metal = try #require(view.metalView)
        let renderer = try #require(metal.delegate as? MetalRenderer)
        for index in 0..<100 {
            view.outputAspectRatio = TestResolution.allCases[index % 5].aspectRatio
            view.layoutSubtreeIfNeeded()
            // Deliberately exercise invalidation-to-GPU completion in an unpresented harness.
            // This measures a synthetic request, not an OS visibility event or display latency.
            renderer.isDrawingEnabled = true
            renderer.requestDraw(in: metal)
            renderer.draw(in: metal)
            let deadline = Date(timeIntervalSinceNow: 2)
            while diagnostics.snapshot().completions <= index && Date() < deadline {
                Thread.sleep(forTimeInterval: 0.001)
            }
            #expect(diagnostics.snapshot().completions == index + 1)
            view.updateRenderingAvailability()
        }
        try write(diagnostics.snapshot().samples, to: directory + "/synthetic-redraw-timings.json")
        #expect(diagnostics.snapshot().samples.allSatisfy { $0.succeeded })
    }

    @Test(.enabled(if: ProcessInfo.processInfo.environment["PROJECTION_MAPPER_NATIVE_OUTPUT"] != nil))
    func nativeMatrixIdleAndLifecycle() throws {
        _ = NSApplication.shared
        let directory = try #require(ProcessInfo.processInfo.environment["PROJECTION_MAPPER_NATIVE_OUTPUT"])
        let diagnostics = RenderDiagnostics(capacity: 2_048)
        var native: [NativeSample] = [], idle: [IdleSample] = []
        let editor = makeWindow(width: 800, height: 450, diagnostics: diagnostics)
        let output = makeWindow(width: 640, height: 360, diagnostics: diagnostics)
        defer { editor.close(); output.close() }
        editor.orderFront(nil); output.orderFront(nil)
        for size in [CGSize(width: 800, height: 450), CGSize(width: 400, height: 600), CGSize(width: 600, height: 600)] {
            output.setContentSize(size)
            for preset in TestResolution.allCases {
                for window in [editor, output] {
                    let view = try #require(window.contentView as? MetalSceneView)
                    view.outputAspectRatio = preset.aspectRatio
                    view.layoutSubtreeIfNeeded()
                    RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.03))
                    let metal = try #require(view.metalView)
                    // Refresh MTKView's cached drawable after fitting changes, even when occluded.
                    metal.draw()
                    let drawable = try #require(metal.currentDrawable)
                    let backing = metal.convertToBacking(metal.bounds).size
                    #expect(abs(CGFloat(drawable.texture.width) - backing.width) <= 1)
                    #expect(abs(CGFloat(drawable.texture.height) - backing.height) <= 1)
                    native.append(NativeSample(view: window === editor ? "editor" : "output", preset: preset.rawValue,
                        windowWidth: window.contentView!.bounds.width, windowHeight: window.contentView!.bounds.height,
                        fittedWidth: view.outputFrame.width, fittedHeight: view.outputFrame.height,
                        pixelWidth: drawable.texture.width, pixelHeight: drawable.texture.height,
                        scale: window.backingScaleFactor, visible: window.isVisible,
                        occluded: !window.occlusionState.contains(.visible), active: view.isRenderingActive))
                }
            }
        }
        for state in ["editor-only", "both", "minimized-output", "hidden-both", "closed-output"] {
            switch state {
            case "editor-only": output.orderOut(nil)
            case "both": output.orderFront(nil)
            case "minimized-output": output.miniaturize(nil)
            case "hidden-both": output.deminiaturize(nil); output.orderOut(nil); editor.orderOut(nil)
            default: output.close(); editor.orderFront(nil)
            }
            RunLoop.main.run(until: Date(timeIntervalSinceNow: 2))
            let before = diagnostics.snapshot(), cpuBefore = cpuSeconds(), wall = ProcessInfo.processInfo.systemUptime
            RunLoop.main.run(until: Date(timeIntervalSinceNow: 10))
            let after = diagnostics.snapshot(), elapsed = ProcessInfo.processInfo.systemUptime - wall
            let editorActive = (editor.contentView as? MetalSceneView)?.isRenderingActive ?? false
            let outputActive = (output.contentView as? MetalSceneView)?.isRenderingActive ?? false
            idle.append(IdleSample(state: state, wallSeconds: elapsed,
                cpuPercent: (cpuSeconds() - cpuBefore) / elapsed * 100,
                newSubmissions: after.submissions - before.submissions,
                editorActive: editorActive, outputActive: outputActive, peakResidentBytes: peakResidentBytes()))
            #expect(after.submissions == before.submissions)
        }
        var memory: [Int64] = []
        for _ in 0..<3 {
            for _ in 0..<50 {
                weak var renderer: MetalRenderer?
                weak var view: MetalSceneView?
                autoreleasepool {
                    let window = makeWindow(width: 640, height: 360, diagnostics: diagnostics)
                    view = window.contentView as? MetalSceneView
                    renderer = view?.metalView?.delegate as? MetalRenderer
                    window.orderFront(nil)
                    for index in 0..<100 { view?.outputAspectRatio = TestResolution.allCases[index % 5].aspectRatio }
                    (window.contentView as? MetalSceneView)?.stopRendering()
                    window.contentView = nil
                    window.close()
                }
                #expect(view == nil && renderer == nil)
            }
            memory.append(peakResidentBytes())
        }
        try write(native, to: directory + "/native-matrix.json")
        try write(idle, to: directory + "/idle.json")
        try write(memory, to: directory + "/stress-peak-memory.json")
        try write(diagnostics.snapshot().samples, to: directory + "/native-timings.json")
        #expect(diagnostics.snapshot().samples.allSatisfy { $0.succeeded })
    }

    private let dimensions: [(String, Int, Int)] = [("HD",1280,720),("Full HD",1920,1080),
        ("4:3",1024,768),("Portrait",1080,1920),("4K",3840,2160)]
    private func makeTexture(_ renderer: MetalRenderer, width: Int, height: Int) throws -> any MTLTexture {
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .bgra8Unorm, width: width, height: height, mipmapped: false)
        descriptor.storageMode = .shared; descriptor.usage = .renderTarget
        return try #require(renderer.device.makeTexture(descriptor: descriptor))
    }
    private func pass(_ texture: any MTLTexture) -> MTLRenderPassDescriptor {
        let descriptor = MTLRenderPassDescriptor(); descriptor.colorAttachments[0].texture = texture; return descriptor
    }
    private func verifyPixels(_ texture: any MTLTexture) throws {
        for (x, y, expected) in [(0, 0, [UInt8](arrayLiteral: 0,0,0,255)),
                                 (texture.width / 2, texture.height / 2, [UInt8](arrayLiteral: 0,64,255,255))] {
            var pixel = [UInt8](repeating: 0, count: 4)
            pixel.withUnsafeMutableBytes { texture.getBytes($0.baseAddress!, bytesPerRow: 4,
                from: MTLRegionMake2D(x,y,1,1), mipmapLevel: 0) }
            #expect(pixel == expected)
        }
    }
    private func makeWindow(width: CGFloat, height: CGFloat, diagnostics: RenderDiagnostics) -> NSWindow {
        let window = NSWindow(contentRect: CGRect(x: 0, y: 0, width: width, height: height),
            styleMask: [.titled,.closable,.miniaturizable,.resizable], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        window.contentView = MetalSceneView(frame: CGRect(x: 0,y: 0,width: width,height: height),
                                           rendererFactory: { try MetalRenderer(diagnostics: diagnostics) })
        return window
    }
    private func cpuSeconds() -> Double {
        var usage = rusage(); getrusage(RUSAGE_SELF, &usage)
        return Double(usage.ru_utime.tv_sec + usage.ru_stime.tv_sec) + Double(usage.ru_utime.tv_usec + usage.ru_stime.tv_usec) / 1_000_000
    }
    private func peakResidentBytes() -> Int64 { var usage = rusage(); getrusage(RUSAGE_SELF, &usage); return Int64(usage.ru_maxrss) }
    private func write<T: Encodable>(_ value: T, to path: String) throws {
        let encoder = JSONEncoder(); encoder.outputFormatting = [.prettyPrinted,.sortedKeys]
        try encoder.encode(value).write(to: URL(fileURLWithPath: path))
    }
}

private struct BenchmarkSample: Codable {
    let preset: String; let width: Int; let height: Int; let views: Int; let repetition: Int; let index: Int
    let cpuMilliseconds: Double; let gpuMilliseconds: Double?; let gpuSpanMilliseconds: Double?; let completionMilliseconds: Double
}
private struct NativeSample: Codable {
    let view: String; let preset: String; let windowWidth: Double; let windowHeight: Double
    let fittedWidth: Double; let fittedHeight: Double; let pixelWidth: Int; let pixelHeight: Int; let scale: Double
    let visible: Bool; let occluded: Bool; let active: Bool
}
private struct IdleSample: Codable {
    let state: String; let wallSeconds: Double; let cpuPercent: Double; let newSubmissions: Int
    let editorActive: Bool; let outputActive: Bool; let peakResidentBytes: Int64
}
