import AppKit
import MetalKit
import CoreVideo
import Testing

@MainActor
@Suite(.serialized)
struct ProjectorOutputTests {
    private func display(_ id: UInt32 = 2, uuid: String? = "projector") -> DisplayDescriptor {
        DisplayDescriptor(id: id, uuid: uuid, name: "Projector", desktopFrame: CGRect(x: -1920,y: -400,width: 1920,height: 1080), renderWidth: 1920, renderHeight: 1080, scale: 1, refreshRate: 60)
    }
    private func coordinator() -> ProjectorOutputCoordinator {
        _ = NSApplication.shared
        return ProjectorOutputCoordinator(createWindow: { target, scene in
            let window = NSWindow(contentRect: target.desktopFrame!,styleMask: [.borderless],backing: .buffered,defer: false)
            window.isReleasedWhenClosed = false
            window.contentView = MetalSceneView(frame: CGRect(origin: .zero,size: target.desktopFrame!.size),scene: scene)
            return window
        }, present: { _ in }, validatePresentation: { _ in true })
    }
    private func withSession(_ body: (EditorSession, OutputPreferences) throws -> Void) throws {
        let name = "ProjectionMapper.Projector.\(UUID())"
        // Use the same named domain for deterministic cleanup.
        let settings = UserDefaults(suiteName: name)!
        defer { settings.removePersistentDomain(forName: name) }
        let preferences = OutputPreferences(defaults: settings)
        let session = EditorSession(presentOutput: { _ in }, output: OutputSelectionState(preferences: preferences),projectorOutput: coordinator())
        defer { session.releaseRuntimeResources() }
        try body(session, preferences)
    }
    @Test func selectionDoesNotOpenOrChangePlaybackAndExplicitOpenIsSingleDestination() throws {
        try withSession { session, _ in
            let original = session.project, transport = session.transport
            session.output.update([display()]); session.output.select(.display(2))
            #expect(!session.isOutputOpen && session.canOpenOutput)
            session.openOutput()
            #expect(session.projectorOutput.isOpen && !session.testOutput.isOpen)
            #expect(session.project == original && session.transport == transport && !session.videoAudioEnabled)
            let window = session.projectorOutput.window
            session.openOutput(); #expect(session.projectorOutput.window === window)
            #expect(window?.isVisible == false)
            session.output.select(.testWindow)
            #expect(!session.projectorOutput.isOpen && !session.testOutput.isOpen)
            session.openOutput(); #expect(session.testOutput.isOpen && !session.projectorOutput.isOpen)
        }
    }
    @Test func unplugReconnectAndRuntimeIDReplacementNeverResumeOrRelocate() throws {
        try withSession { session, prefs in
            session.output.update([display()]); session.output.select(.display(2)); session.openOutput()
            let original = session.project
            session.output.update([])
            #expect(!session.isOutputOpen && session.projectorOutput.state == .unavailable)
            #expect(session.projectorOutput.message?.contains("Playback may still") == true)
            #expect(prefs.load().displayUUID == "projector" && session.project == original)
            session.output.update([display(99)]); #expect(!session.isOutputOpen)
            session.output.select(.display(99)); session.openOutput(); #expect(session.projectorOutput.isOpen)
            session.output.update([display(99,uuid: "replacement")]); #expect(!session.isOutputOpen)
        }
    }
    @Test func modeScaleOriginAndEligibilityChangesCloseAndNeedExplicitOpen() throws {
        for index in 0..<8 {
            try withSession { session, _ in
                session.output.update([display()]); session.output.select(.display(2)); session.openOutput()
                var changed = display()
                switch index {
                case 0: changed.renderWidth = 1280
                case 1: changed.scale = 2
                case 2: changed.desktopFrame?.origin.x = 100
                case 3: changed.refreshRate = 59.94
                case 4: changed.isMirrored = true
                case 5: changed.isEditorDisplay = true
                case 6: changed.isBuiltIn = true
                default: changed.hasIndependentScreen = false
                }
                session.output.update([changed]); #expect(!session.isOutputOpen)
                session.output.update([display()]); #expect(!session.isOutputOpen)
            }
        }
    }
    @Test func duplicateUUIDInvalidDimensionsAndWrongSnapshotCannotOpen() {
        let output = coordinator(), d = display()
        var invalid = d; invalid.desktopFrame?.origin.x = .nan
        var builtIn = d; builtIn.isBuiltIn = true
        for (target,snapshot) in [(d,[d,display(3)]),(invalid,[invalid]),(builtIn,[builtIn]),(d,[display(99)])] {
            #expect(!output.open(target,snapshot: snapshot,scene: .diagnostic))
            #expect(output.window == nil)
        }
        var noPixels = d; noPixels.renderWidth = 0
        #expect(!output.open(noPixels,snapshot: [noPixels],scene: .diagnostic))
    }
    @Test func discoveryFailureSleepAndRapidCloseAreIdempotent() throws {
        try withSession { session, _ in
            session.output.update([display()]); session.output.select(.display(2)); session.openOutput()
            NSWorkspace.shared.notificationCenter.post(name: NSWorkspace.willSleepNotification, object: nil)
            #expect(!session.isOutputOpen)
            session.openOutput(); #expect(session.projectorOutput.isOpen)
            session.output.update([],error: "Scan failed"); #expect(!session.isOutputOpen)
            session.closeOutput(); session.closeOutput(); #expect(session.projectorOutput.state == .closed)
        }
    }
    @Test func staleOpenCannotPresentAfterInvalidationAndRendererErrorsStayInEditor() {
        var presentations = 0
        final class Holder { var output: ProjectorOutputCoordinator? }
        let holder = Holder()
        let output = ProjectorOutputCoordinator(createWindow: { target, _ in
            holder.output?.invalidate("Changed during creation")
            let window = NSWindow(contentRect: target.desktopFrame!,styleMask: [.borderless],backing: .buffered,defer: false)
            window.isReleasedWhenClosed = false
            return window
        },present: { _ in presentations += 1 },validatePresentation: { _ in true })
        holder.output = output
        #expect(!output.open(display(),snapshot: [display()],scene: .diagnostic) && presentations == 0)
        let failed = ProjectorOutputCoordinator(createWindow: { _,_ in throw ProjectorOutputCoordinator.OutputError.renderer("Fixture failure") },present: { _ in presentations += 1 },validatePresentation: { _ in true })
        #expect(!failed.open(display(),snapshot: [display()],scene: .diagnostic))
        #expect(failed.state == .failed && failed.message?.contains("Fixture failure") == true && presentations == 0)
    }
    @Test func projectLoadResetAndRelaunchLeavePhysicalOutputClosed() throws {
        try withSession { session, prefs in
            session.output.update([display()]); session.output.select(.display(2)); session.openOutput()
            let document = session.document
            try session.load(document,from: URL(fileURLWithPath: "/private/tmp/output-fixture.projectionmap"))
            #expect(!session.isOutputOpen && !session.transport.isPlaying)
            session.openOutput(); #expect(session.isOutputOpen)
            session.resetProject(); #expect(!session.isOutputOpen)
            let next = EditorSession(output: OutputSelectionState(preferences: prefs),projectorOutput: coordinator())
            next.output.update([display()]); #expect(next.output.destination == .display(2) && !next.isOutputOpen)
            next.releaseRuntimeResources()
        }
    }
    @Test func displayChangeDuringCreationLeavesOutputUnavailableAndCanRetry() {
        var validations = 0, presentations = 0
        weak var rejectedView: MetalSceneView?
        let output = ProjectorOutputCoordinator(createWindow: { target, scene in
            let window = NSWindow(contentRect: target.desktopFrame!, styleMask: [.borderless], backing: .buffered, defer: false)
            window.isReleasedWhenClosed = false
            let view = MetalSceneView(frame: CGRect(origin: .zero, size: target.desktopFrame!.size), scene: scene)
            rejectedView = view
            window.contentView = view
            return window
        }, present: { _ in presentations += 1 }, validatePresentation: { _ in
            validations += 1
            return validations != 2
        })
        autoreleasepool {
            #expect(!output.open(display(), snapshot: [display()], scene: .diagnostic))
        }
        #expect(output.state == .unavailable && output.window == nil && output.activeDisplay == nil)
        #expect(output.message?.contains("changed before output opened") == true)
        #expect(presentations == 0 && rejectedView == nil)
        #expect(output.open(display(), snapshot: [display()], scene: .diagnostic))
        #expect(output.state == .open && presentations == 1)
        output.close()
    }
    @Test func profileRoundTripModeMismatchInvalidValuesAndNoPortableLeak() throws {
        try withSession { session, prefs in
            session.output.update([display()]); session.output.select(.display(2))
            var profile = try #require(OutputCalibrationProfile(display: display()))
            profile.measuredDelayMilliseconds = 87; profile.compensationMilliseconds = 87; profile.notes = "High speed reference camera"
            session.output.saveCalibration(profile)
            #expect(prefs.loadCalibration(for: display()) == profile)
            var mode = display(); mode.renderWidth = 1280
            #expect(prefs.loadCalibration(for: mode)?.matches(mode) == false)
            #expect(prefs.loadCalibration(for: display(uuid: "other")) == nil)
            let original = profile
            for value in [Double.nan,.infinity,-501,501] {
                profile.compensationMilliseconds = value; prefs.saveCalibration(profile)
                #expect(prefs.loadCalibration(for: display()) == original)
            }
            profile = original; profile.notes = String(repeating: "x",count: 2001); #expect(!profile.isValid)
            let json = String(decoding: try ProjectCodec.encode(session.document),as: UTF8.self)
            #expect(!json.contains("measuredDelay") && !json.contains("compensationMilliseconds") && !json.contains("High speed"))
            #expect(!session.hasUserChanges)
        }
    }
    @Test func malformedProfilesAndUnknownVersionFallBackSafely() {
        let name = "ProjectionMapper.Profile.\(UUID())"
        let settings = UserDefaults(suiteName: name)!; defer { settings.removePersistentDomain(forName: name) }
        let prefs = OutputPreferences(defaults: settings)
        settings.set(Data("bad".utf8),forKey: "output.calibration.v1"); #expect(prefs.loadCalibration(for: display()) == nil)
        var p = OutputCalibrationProfile(display: display())!; p.version = 2
        prefs.saveCalibration(p); #expect(prefs.loadCalibration(for: display()) == nil)
    }
    @Test func cadenceIsBoundedAndRejectsBackwardAndInvalidSamples() {
        var cadence = OutputCadence()
        for i in 0..<1000 { cadence.record(at: Double(i) / 60) }
        #expect(cadence.frames == 1000 && cadence.intervals.count == 240)
        let original = cadence.summary
        for t in [Double.nan,.infinity,0,Double(999)/60] { cadence.record(at: t) }
        #expect(cadence.summary == original)
        #expect(cadence.summary.contains("60.0 submissions/s"))
        #expect(OutputDiagnostic.frame(at: .nan) == 0 && OutputDiagnostic.frame(at: -1) == 0)
        #expect(OutputDiagnostic.frame(at: 1) == 60)
    }
    @Test func boundaryAndFlashUseFullOutputAndBlackoutWhileNormalSceneIsUnchanged() throws {
        var original = RenderScene.diagnostic
        for diagnostic in [OutputDiagnostic.boundary,.timing] {
            let fixture = diagnostic.scene(from: original,elapsed: 0)
            #expect(fixture.geometry == OutputDiagnostic.full && original.geometry == .diagnostic)
            let bright = try pixels(fixture)
            #expect(bright.contains(255))
            original.showOutput.blackout()
            let black = try pixels(diagnostic.scene(from: original,elapsed: 0))
            #expect(stride(from: 0,to: black.count,by: 4).allSatisfy { black[$0] == 0 && black[$0+1] == 0 && black[$0+2] == 0 })
            original.showOutput = ShowOutputState()
        }
        #expect(OutputDiagnostic.normal.scene(from: original,elapsed: 100) == original)
        let flash = try pixels(OutputDiagnostic.timing.scene(from: original,elapsed: 0))
        let dim = try pixels(OutputDiagnostic.timing.scene(from: original,elapsed: 0.5))
        #expect(flash[0] == 255 && dim[0] < 20)
    }
    @Test func physicalSceneMatchesSharedSessionPixelsAndFinishRestoresScene() throws {
        try withSession { session, _ in
            session.output.update([display()]); session.output.select(.display(2)); session.openOutput()
            session.seekPlayback(to: 3)
            #expect(session.projectorOutput.scene == session.scene && session.testOutput.scene == session.scene)
            #expect(try pixels(session.projectorOutput.scene) == pixels(session.scene))
            session.projectorOutput.setDiagnostic(.boundary)
            session.projectorOutput.setDiagnostic(.normal)
            let view = try #require(session.projectorOutput.window?.contentView as? MetalSceneView)
            let renderer = try #require(view.metalView?.delegate as? MetalRenderer)
            #expect(renderer.scene == session.scene)
            session.blackoutOutput(); #expect(session.projectorOutput.scene.showOutput.isBlackout)
        }
    }
    @Test func repeatedHiddenOutputCloseReleasesViewsRenderersAndDiagnosticTimers() throws {
        let output = coordinator()
        for _ in 0..<20 {
            weak var view: MetalSceneView?, renderer: MetalRenderer?
            try autoreleasepool {
                #expect(output.open(display(),snapshot: [display()],scene: .diagnostic))
                let window = try #require(output.window)
                view = window.contentView as? MetalSceneView; renderer = view?.metalView?.delegate as? MetalRenderer
                output.setDiagnostic(.timing); output.close(); output.close()
                #expect(window.contentView == nil && window.delegate == nil && !output.isOpen && output.diagnostic == .normal)
            }
            #expect(view == nil && renderer == nil)
        }
    }
    @Test func connectedMasksEffectsImagesAndSharedVideoMatchOutputGPU() throws {
        let output = coordinator(), owner = UUID(), assetID = UUID()
        defer { output.close() }
        let asset = VideoAsset(id: assetID,name: "fixture",fileExtension: "mp4",byteCount: 4096,duration: 4,width: 16,height: 16,frameRate: 60,hasAudio: false,codec: "H.264",transform: [1,0,0,1,0,0])
        var buffer: CVPixelBuffer?
        #expect(CVPixelBufferCreate(kCFAllocatorDefault,16,16,kCVPixelFormatType_32BGRA,[kCVPixelBufferIOSurfacePropertiesKey:[:]] as CFDictionary,&buffer) == kCVReturnSuccess)
        let videoBuffer = try #require(buffer)
        CVPixelBufferLockBaseAddress(videoBuffer,[])
        let base = try #require(CVPixelBufferGetBaseAddress(videoBuffer)).assumingMemoryBound(to: UInt8.self)
        for y in 0..<16 { for x in 0..<16 {
            let i = y * CVPixelBufferGetBytesPerRow(videoBuffer) + x * 4
            base[i] = UInt8(x*12); base[i+1] = UInt8(y*12); base[i+2] = 200; base[i+3] = 255
        } }
        CVPixelBufferUnlockBaseAddress(videoBuffer,[])
        let frame = VideoFrame(buffer: videoBuffer,asset: asset,clipID: nil,sourceTime: 0.375)
        let image = ImagePixels(width: 2,height: 2,bytes: Data([0,0,255,255,0,255,0,255,255,0,0,255,255,255,255,255]))
        for repeatContent in [false,true] {
            for content in [SurfaceContent.solid,.diagnosticGrid,.gradient,.movingLines,.movingCheckers,.plasma,.noise,.particles,.image,.video] {
                var left = RenderSurface(geometry: NormalizedRectangle(topLeft: SIMD2(0,0),topRight: SIMD2(0.5,0),bottomRight: SIMD2(0.5,1),bottomLeft: SIMD2(0,1)),color: SIMD4(1,0.2,0.1,1),content: content)
                left.sourceID = owner; left.inputMap = FaceInputMap(origin: SIMD2(0,0),size: SIMD2(repeatContent ? 1 : 0.5,1))
                left.mask = FaceMask(holes: [MaskPolygon(points: [SIMD2(0.2,0.2),SIMD2(0.4,0.2),SIMD2(0.4,0.4),SIMD2(0.2,0.4)])])
                left.image = ImageContent(assetID: assetID,placement: .stretch,canvasAspect: 1)
                left.video = VideoContent(assetID: assetID,outPoint: 4,placement: .stretch,canvasAspect: 1)
                var right = left
                right = RenderSurface(geometry: NormalizedRectangle(topLeft: SIMD2(0.5,0),topRight: SIMD2(1,0),bottomRight: SIMD2(1,1),bottomLeft: SIMD2(0.5,1)),color: left.color,content: content,inputMap: FaceInputMap(origin: SIMD2(repeatContent ? 0 : 0.5,0),size: SIMD2(repeatContent ? 1 : 0.5,1)),sourceID: owner,mask: left.mask,image: left.image,video: left.video)
                var scene = RenderScene(surfaces: [left,right],masterBrightness: 0.75)
                scene.images = [assetID:image]; scene.videoFrames = [owner:frame]
                #expect(output.open(display(),snapshot: [display()],scene: scene))
                let view = try #require(output.window?.contentView as? MetalSceneView)
                let renderer = try #require(view.metalView?.delegate as? MetalRenderer)
                let reference = try pixels(scene)
                #expect(try pixels(renderer.scene) == reference)
                #expect(reference.contains { $0 > 0 && $0 < 255 })
                #expect(output.scene.videoFrames[owner] === frame)
                output.close()
            }
        }
    }
    @Test func runtimeRendererFailureClosesOutputAndDoesNotProjectErrorUI() throws {
        let output = coordinator()
        #expect(output.open(display(),snapshot: [display()],scene: .diagnostic))
        let window = try #require(output.window)
        let view = try #require(window.contentView as? MetalSceneView)
        view.renderingFailed?("Simulated command failure")
        #expect(output.state == .failed && output.window == nil && window.contentView == nil)
        #expect(output.message?.contains("Simulated command failure") == true)
    }
    private func pixels(_ scene: RenderScene) throws -> [UInt8] {
        let renderer = try MetalRenderer(scene: scene)
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .bgra8Unorm,width: 128,height: 128,mipmapped: false)
        descriptor.storageMode = .shared; descriptor.usage = .renderTarget
        let texture = try #require(renderer.device.makeTexture(descriptor: descriptor))
        let pass = MTLRenderPassDescriptor(); pass.colorAttachments[0].texture = texture
        let command = try #require(renderer.encodeScene(to: pass,evaluationTime: 0.375,evaluationUptime: 100))
        command.commit(); command.waitUntilCompleted(); #expect(command.status == .completed && command.error == nil)
        var bytes = [UInt8](repeating: 0,count: 128*128*4)
        bytes.withUnsafeMutableBytes { texture.getBytes($0.baseAddress!,bytesPerRow: 128*4,from: MTLRegionMake2D(0,0,128,128),mipmapLevel: 0) }
        return bytes
    }
}
