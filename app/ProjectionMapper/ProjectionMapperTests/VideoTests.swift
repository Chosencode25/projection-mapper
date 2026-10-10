import AppKit
import AVFoundation
import CoreVideo
import MetalKit
import Testing
import Darwin

@MainActor @Suite(.serialized) struct VideoTests {
    private func directory() throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString,isDirectory: true)
        try FileManager.default.createDirectory(at: url,withIntermediateDirectories: true); return url
    }
    private func movie(in folder: URL,rotated: Bool = false,codec: AVVideoCodecType = .h264,width: Int = 128,height: Int = 64) async throws -> URL {
        let url = folder.appendingPathComponent(UUID().uuidString+".mp4")
        let writer = try AVAssetWriter(outputURL: url,fileType: .mp4)
        let input = AVAssetWriterInput(mediaType: .video,outputSettings: [AVVideoCodecKey:codec,AVVideoWidthKey:width,AVVideoHeightKey:height,
            AVVideoCompressionPropertiesKey:[AVVideoAverageBitRateKey:200000,AVVideoMaxKeyFrameIntervalKey:1]])
        if rotated { input.transform = CGAffineTransform(a: 0,b: 1,c: -1,d: 0,tx: 64,ty: 0) }
        let adaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: input,sourcePixelBufferAttributes: [kCVPixelBufferPixelFormatTypeKey as String:kCVPixelFormatType_32BGRA,
            kCVPixelBufferWidthKey as String:width,kCVPixelBufferHeightKey as String:height,kCVPixelBufferIOSurfacePropertiesKey as String:[:]])
        writer.add(input); #expect(writer.startWriting()); writer.startSession(atSourceTime: .zero)
        for i in 0..<120 {
            while !input.isReadyForMoreMediaData { try await Task.sleep(for: .milliseconds(1)); if writer.status == .failed { throw writer.error! } }
            var buffer: CVPixelBuffer?
            #expect(CVPixelBufferCreate(kCFAllocatorDefault,width,height,kCVPixelFormatType_32BGRA,[kCVPixelBufferIOSurfacePropertiesKey:[:]] as CFDictionary,&buffer) == kCVReturnSuccess)
            let pixels = try #require(buffer)
            CVPixelBufferLockBaseAddress(pixels,[])
            let base = try #require(CVPixelBufferGetBaseAddress(pixels)).assumingMemoryBound(to: UInt8.self)
            let stride = CVPixelBufferGetBytesPerRow(pixels)
            var row = [UInt8](repeating: 0,count: width*4)
            for x in 0..<width {
                let rgb: [UInt8] = i < 60 ? (x < width/2 ? [0,0,255] : [255,0,0]) : (x < width/2 ? [0,255,0] : [255,255,255])
                row[x*4] = rgb[0]; row[x*4+1] = rgb[1]; row[x*4+2] = rgb[2]; row[x*4+3] = 255
            }
            row.withUnsafeBytes { bytes in for y in 0..<height { memcpy(base.advanced(by: y*stride),bytes.baseAddress!,width*4) } }
            CVPixelBufferUnlockBaseAddress(pixels,[])
            #expect(adaptor.append(pixels,withPresentationTime: CMTime(value: Int64(i),timescale: 30)))
        }
        input.markAsFinished(); await writer.finishWriting()
        #expect(writer.status == .completed)
        return url
    }
    private func audioMovie(_ movie: URL,in folder: URL) async throws -> URL {
        let wav = folder.appendingPathComponent("tone.wav")
        var bytes = Data()
        func str(_ text: String) { bytes.append(contentsOf: text.utf8) }
        func u32(_ value: UInt32) { var le = value.littleEndian; withUnsafeBytes(of: &le) { bytes.append(contentsOf: $0) } }
        func u16(_ value: UInt16) { var le = value.littleEndian; withUnsafeBytes(of: &le) { bytes.append(contentsOf: $0) } }
        let count = 48000*4
        str("RIFF"); u32(UInt32(36+count*2)); str("WAVEfmt "); u32(16); u16(1); u16(1); u32(48000); u32(96000); u16(2); u16(16); str("data"); u32(UInt32(count*2))
        for i in 0..<count { u16(UInt16(bitPattern: Int16(sin(Double(i)*2*Double.pi*440/48000)*3000))) }
        try bytes.write(to: wav)
        let composition = AVMutableComposition()
        let videoAsset = AVURLAsset(url: movie), audioAsset = AVURLAsset(url: wav)
        let video = try #require(try await videoAsset.loadTracks(withMediaType: .video).first)
        let audio = try #require(try await audioAsset.loadTracks(withMediaType: .audio).first)
        let range = CMTimeRange(start: .zero,duration: try await videoAsset.load(.duration))
        try composition.addMutableTrack(withMediaType: .video,preferredTrackID: kCMPersistentTrackID_Invalid)?.insertTimeRange(range,of: video,at: .zero)
        try composition.addMutableTrack(withMediaType: .audio,preferredTrackID: kCMPersistentTrackID_Invalid)?.insertTimeRange(range,of: audio,at: .zero)
        let output = folder.appendingPathComponent("audio.mp4")
        let export = try #require(AVAssetExportSession(asset: composition,presetName: AVAssetExportPresetHighestQuality))
        try await export.export(to: output,as: .mp4)
        return output
    }
    private func scene(_ imported: ImportedVideo, at seconds: Double = 0) -> RenderScene {
        var transport = AnimationTransport(); transport.seek(to: seconds,at: ProcessInfo.processInfo.systemUptime)
        let content = VideoContent(assetID: imported.asset.id,outPoint: imported.asset.duration,canvasAspect: 2)
        return RenderScene(surfaces: [RenderSurface(geometry: NormalizedRectangle(topLeft: SIMD2(0,0),topRight: SIMD2(1,0),bottomRight: SIMD2(1,1),bottomLeft: SIMD2(0,1)),color: SIMD4(1,1,1,1),content: .video,sourceID: UUID(),video: content)],transport: transport)
    }
    private func waitForFrame(_ coordinator: VideoPlaybackCoordinator,owner: UUID) async throws -> VideoFrame {
        for _ in 0..<500 {
            coordinator.tick()
            if let frame = coordinator.frames[owner] { return frame }
            try await Task.sleep(for: .milliseconds(10))
        }
        throw ProjectFileError.io("No decoded frame after five seconds: \(coordinator.problems)")
    }
    private func rendered(_ scene: RenderScene,width: Int = 128,height: Int = 64) throws -> Data {
        let renderer = try MetalRenderer(scene: scene)
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .bgra8Unorm,width: width,height: height,mipmapped: false)
        descriptor.storageMode = .shared; descriptor.usage = .renderTarget
        let target = try #require(renderer.device.makeTexture(descriptor: descriptor))
        let pass = MTLRenderPassDescriptor(); pass.colorAttachments[0].texture = target
        let command = try #require(renderer.encodeScene(to: pass)); command.commit(); command.waitUntilCompleted()
        #expect(command.status == .completed && command.error == nil)
        var data = Data(count: width*height*4)
        data.withUnsafeMutableBytes { target.getBytes($0.baseAddress!,bytesPerRow: width*4,from: MTLRegionMake2D(0,0,width,height),mipmapLevel: 0) }
        return data
    }
    private func profileGPU(_ renderer: MetalRenderer,target: MTLTexture) throws -> Double {
        let pass = MTLRenderPassDescriptor(); pass.colorAttachments[0].texture = target
        let command = try #require(renderer.encodeScene(to: pass)); command.commit(); command.waitUntilCompleted()
        #expect(command.status == .completed && command.error == nil)
        return max(0,(command.gpuEndTime-command.gpuStartTime)*1000)
    }
    private func rgb(_ bytes: Data,_ x: Int,_ y: Int,width: Int = 128) -> [Int] { let i = (y*width+x)*4; return [Int(bytes[i+2]),Int(bytes[i+1]),Int(bytes[i])] }

    @Test func importInspectionOrientationCodecsAndInvalidFiles() async throws {
        let folder = try directory(); defer { try? FileManager.default.removeItem(at: folder) }
        let video = try await movie(in: folder,rotated: true)
        let imported = try await VideoImportService.read(video); defer { try? FileManager.default.removeItem(at: imported.url) }
        #expect(imported.asset.isValid && imported.asset.codec == "H.264")
        #expect(abs(imported.asset.duration-4) < 0.01 && imported.asset.displaySize.width == 64 && imported.asset.displaySize.height == 128)
        #expect(imported.poster.width > 0 && imported.poster.height > imported.poster.width)
        #expect(try Data(contentsOf: imported.url) == Data(contentsOf: video))
        let audio = try await audioMovie(video,in: folder)
        #expect(try await VideoImportService.inspect(audio).0.hasAudio)
        let hevc = try await movie(in: folder,codec: .hevc)
        #expect(try await VideoImportService.inspect(hevc).0.codec == "HEVC")
        let invalid = folder.appendingPathComponent("invalid.mp4"); try Data([1,2,3]).write(to: invalid)
        await #expect(throws: (any Error).self) { try await VideoImportService.inspect(invalid) }
        let link = folder.appendingPathComponent("link.mp4"); try FileManager.default.createSymbolicLink(at: link,withDestinationURL: video)
        #expect(throws: ProjectFileError.self) { try VideoImportService.safeFile(link) }
    }
    @Test func videoRangesTrimMoveLoopRateAndMigration() throws {
        let asset = VideoAsset(name: "fixture.mp4",fileExtension: "mp4",byteCount: 20,duration: 30,width: 128,height: 64,frameRate: 30,hasAudio: true,codec: "H.264",transform: [1,0,0,1,0,0])
        var project = MappingProject(); project.videoAssets = [asset]
        var source = project.surfaces[0].source; source.content = .video; source.video = VideoContent(assetID: asset.id,inPoint: 3,outPoint: 13)
        let clip = EffectClip(sourceID: source.id,start: 10,duration: 10,source: SourceLook(source: source))
        let trim = clip.trimming(start: 12,duration: 8)
        #expect(trim.source.video?.inPoint == 5 && trim.source.video?.outPoint == 13 && trim.end == 20)
        var move = clip; move.start = 20; #expect(move.source.video == clip.source.video)
        var short = clip; short.duration = 2
        var settings = source.video!; settings.isMuted = false; settings.placement = .fill
        #expect(short.replacingVideo(settings).duration == 2)
        settings.rate = 2; #expect(short.replacingVideo(settings).duration == 1)
        settings = source.video!; settings.inPoint = 5; #expect(short.replacingVideo(settings).duration == 8)
        #expect(clip.source.video?.requestedTime(elapsed: 4) == 7)
        var loop = source.video!; loop.loops = true; loop.rate = 2
        #expect(loop.requestedTime(elapsed: 6) == 5)
        var loopingClip = clip; loopingClip.source.video = loop
        let loopTrim = loopingClip.trimming(start: 12,duration: 8)
        #expect(loopTrim.source.video?.inPoint == 3 && loopTrim.source.video?.outPoint == 13)
        #expect(loopTrim.source.video?.requestedTime(elapsed: 0) == loop.requestedTime(elapsed: 2))
        project.timelineClips = [clip]
        let doc = ProjectDocument(project: project)
        #expect(try ProjectCodec.decode(ProjectCodec.encode(doc)) == doc)
        var json = try #require(JSONSerialization.jsonObject(with: ProjectCodec.encode(ProjectDocument(project: MappingProject()))) as? [String:Any])
        json["formatVersion"] = 8
        var old = try #require(json["project"] as? [String:Any]); old.removeValue(forKey: "videoAssets"); old.removeValue(forKey: "videoAudio"); json["project"] = old
        #expect(try ProjectCodec.decode(JSONSerialization.data(withJSONObject: json)).project.videoAssets.isEmpty)
        var invalid = clip; invalid.duration = 20; #expect(!invalid.isValid)
        invalid = clip.trimming(start: 1,duration: 19); #expect(!invalid.isValid)
    }
    private actor ImportGate {
        var started = false
        var continuation: CheckedContinuation<Void,Never>?
        func wait() async { started = true; await withCheckedContinuation { continuation = $0 } }
        func release() { continuation?.resume(); continuation = nil }
    }
    @Test func staleAndCancelledImportsDoNotReplaceMapping() async throws {
        let folder = try directory(); defer { try? FileManager.default.removeItem(at: folder) }
        let file = try await movie(in: folder)
        for cancel in [false,true] {
            let imported = try await VideoImportService.read(file)
            let gate = ImportGate(), session = EditorSession(presentOutput: { _ in })
            let owner = try #require(session.selectedSource?.id)
            let task = Task { await session.importVideo(from: file,target: .owner(owner),read: { _ in await gate.wait(); return imported }) }
            while !(await gate.started) { await Task.yield() }
            if cancel { task.cancel() } else { session.resetProject() }
            let baseline = session.project
            await gate.release(); await task.value
            #expect(session.project == baseline && session.project.videoAssets.isEmpty && !session.isImportingVideo)
            #expect(!FileManager.default.fileExists(atPath: imported.url.path))
        }
    }
    @Test func adjacentSameAssetAndRapidBackwardSeeksSelectCurrentClip() async throws {
        let folder = try directory(); defer { try? FileManager.default.removeItem(at: folder) }
        let file = try await movie(in: folder), imported = try await VideoImportService.read(file)
        defer { try? FileManager.default.removeItem(at: imported.url) }
        let original = scene(imported)
        var surface = original.surfaces[0]
        let owner = try #require(surface.sourceID)
        let first = EffectClip(sourceID: owner,start: 0,duration: 1,source: SourceLook(source: SurfaceSource(content: .video,video: VideoContent(assetID: imported.asset.id,outPoint: 1))))
        let second = EffectClip(sourceID: owner,start: 1,duration: 1,source: SourceLook(source: SurfaceSource(content: .video,video: VideoContent(assetID: imported.asset.id,inPoint: 3,outPoint: 4))))
        surface.timelineClips = [first,second]
        var snapshot = RenderScene(surfaces: [surface],transport: original.transport)
        let coordinator = VideoPlaybackCoordinator(); coordinator.visualOverride = true
        defer { coordinator.reset() }
        for time in [0.2,1.2,0.3,1.3,0.4] {
            snapshot.transport.seek(to: time,at: ProcessInfo.processInfo.systemUptime)
            coordinator.configure(scene: snapshot,assets: [imported.asset],urls: [imported.asset.id:imported.url],audio: VideoAudioSettings(),enabled: false)
            let frame = try await waitForFrame(coordinator,owner: owner)
            #expect(frame.clipID == (time < 1 ? first.id : second.id))
            #expect(abs(frame.sourceTime-(time < 1 ? time : time+2)) < 0.04)
            var output = snapshot; output.videoFrames = coordinator.frames
            let color = rgb(try rendered(output),20,32)
            #expect(time < 1 ? color[0] > 200 && color[1] < 80 : color[1] > 200 && color[0] < 100)
        }
        snapshot.transport.seek(to: 2.2,at: ProcessInfo.processInfo.systemUptime)
        coordinator.configure(scene: snapshot,assets: [imported.asset],urls: [imported.asset.id:imported.url],audio: VideoAudioSettings(),enabled: false)
        #expect(coordinator.frames.isEmpty && coordinator.activeOwnerCount == 0)
    }
    @Test func ownerRequestsAudioSafetyGapsAndSharedTime() throws {
        var project = MappingProject(); var second = MappingSurface(); second.source = project.surfaces[0].source.independentCopy(); project.surfaces.append(second)
        let asset = VideoAsset(name: "fixture.mp4",fileExtension: "mp4",byteCount: 20,duration: 4,width: 128,height: 64,frameRate: 30,hasAudio: true,codec: "H.264",transform: [1,0,0,1,0,0])
        let session = EditorSession(presentOutput: { _ in },project: project)
        session.createObject(faceIDs: Set(project.surfaces.map(\.id)))
        let owner = try #require(session.selectedObject?.source.id)
        var scene = session.scene
        let source = SurfaceSource(content: .video,video: VideoContent(assetID: asset.id,outPoint: 4,isMuted: false))
        let clip = EffectClip(sourceID: owner,start: 5,duration: 4,source: SourceLook(source: source))
        let surfaces = scene.surfaces.map { original in var face = original; face.content = .video; face.video = source.video; face.timelineClips = [clip]; return face }
        scene = RenderScene(surfaces: surfaces)
        scene.transport.seek(to: 6,at: 100); scene.transport.setPlaying(true,at: 100)
        let requests = VideoPlaybackRequest.requests(scene: scene,assets: [asset],audioEnabled: true,at: 100)
        #expect(requests.count == 1 && requests[0].sourceTime == 1 && requests[0].audible)
        var hiddenFirst = surfaces[0]; hiddenFirst.appearance.opacity = 0
        let partlyVisible = RenderScene(surfaces: [hiddenFirst]+surfaces,transport: scene.transport)
        #expect(VideoPlaybackRequest.requests(scene: partlyVisible,assets: [asset],audioEnabled: true,at: 100).count == 1)
        #expect(!VideoPlaybackRequest.requests(scene: scene,assets: [asset],audioEnabled: false,at: 100)[0].audible)
        #expect(VideoPlaybackRequest.requests(scene: scene,assets: [asset],audioEnabled: true,at: 104).isEmpty)
        scene.transport.setPlaying(false,at: 100)
        #expect(!VideoPlaybackRequest.requests(scene: scene,assets: [asset],audioEnabled: true,at: 100)[0].audible)
    }
    @Test func audioCommandsShareOwnerPauseRatesAndDeviceLossWithoutSound() async throws {
        let folder = try directory(); defer { try? FileManager.default.removeItem(at: folder) }
        let video = try await movie(in: folder), file = try await audioMovie(video,in: folder)
        let imported = try await VideoImportService.read(file)
        defer { try? FileManager.default.removeItem(at: imported.url) }
        let base = scene(imported)
        var face = base.surfaces[0]; face.video?.isMuted = false; face.video?.loops = true
        let owner = try #require(face.sourceID)
        var snapshot = RenderScene(surfaces: [face,face,face])
        let coordinator = VideoPlaybackCoordinator(); coordinator.visualOverride = true
        defer { coordinator.reset() }
        let device = VideoAudioDevices.outputs().first
        var connected = true
        coordinator.availableAudioDevices = { connected ? device.map { [$0] } ?? [] : [] }
        // Zero master volume lets us verify actual AVPlayer commands without audible output.
        let settings = VideoAudioSettings(volume: 0,deviceUID: device?.id)
        func configure(_ enabled: Bool = true) {
            coordinator.configure(scene: snapshot,assets: [imported.asset],urls: [imported.asset.id:imported.url],audio: settings,enabled: enabled)
        }
        configure(); _ = try await waitForFrame(coordinator,owner: owner)
        #expect(coordinator.activeOwnerCount == 1 && coordinator.audioPlaybackStates[owner]?.isMuted == true)
        snapshot.transport.setPlaying(true,at: ProcessInfo.processInfo.systemUptime); configure()
        for _ in 0..<300 {
            coordinator.tick()
            if coordinator.audibleOwnerCount == 1 { break }
            try await Task.sleep(for: .milliseconds(10))
        }
        #expect(coordinator.audibleOwnerCount == 1 && coordinator.audioPlaybackStates[owner]?.volume == 0)
        snapshot.transport.setSpeed(4,at: ProcessInfo.processInfo.systemUptime); configure()
        #expect(coordinator.audioPlaybackStates[owner]?.isMuted == true && coordinator.problems[owner]?.contains("speed") == true)
        snapshot.transport.setSpeed(1,at: ProcessInfo.processInfo.systemUptime); configure(false)
        #expect(coordinator.audioPlaybackStates[owner]?.isMuted == true)
        snapshot.transport.setPlaying(false,at: ProcessInfo.processInfo.systemUptime); configure()
        #expect(coordinator.audioPlaybackStates[owner]?.rate == 0 && coordinator.audioPlaybackStates[owner]?.isMuted == true)
        if device != nil {
            snapshot.transport.setPlaying(true,at: ProcessInfo.processInfo.systemUptime); configure()
            connected = false; coordinator.tick(at: ProcessInfo.processInfo.systemUptime+2)
            #expect(coordinator.audioPlaybackStates[owner]?.isMuted == true)
            connected = true; coordinator.tick(at: ProcessInfo.processInfo.systemUptime+4)
            #expect(coordinator.audioPlaybackStates[owner]?.isMuted == true)
            coordinator.rearmAudio(); configure()
            #expect(coordinator.audioPlaybackStates[owner]?.isMuted == false)
        }
        coordinator.reset(); #expect(coordinator.audioPlaybackStates.isEmpty)
    }
    @Test func pausedDecoderGpuSeekingAndOrientation() async throws {
        let folder = try directory(); defer { try? FileManager.default.removeItem(at: folder) }
        let imported = try await VideoImportService.read(movie(in: folder)); defer { try? FileManager.default.removeItem(at: imported.url) }
        let coordinator = VideoPlaybackCoordinator(); coordinator.visualOverride = true; defer { coordinator.reset() }
        var snapshot = scene(imported,at: 1)
        let owner = try #require(snapshot.surfaces[0].sourceID)
        coordinator.configure(scene: snapshot,assets: [imported.asset],urls: [imported.asset.id:imported.url],audio: VideoAudioSettings(),enabled: false)
        let first = try await waitForFrame(coordinator,owner: owner)
        snapshot.videoFrames = [owner:first]
        let red = rgb(try rendered(snapshot),24,32); #expect(red[0] > 200 && red[1] < 80 && red[2] < 80)
        snapshot.transport.seek(to: 3,at: ProcessInfo.processInfo.systemUptime)
        coordinator.configure(scene: snapshot,assets: [imported.asset],urls: [imported.asset.id:imported.url],audio: VideoAudioSettings(),enabled: false)
        let next = try await waitForFrame(coordinator,owner: owner); snapshot.videoFrames = [owner:next]
        let green = rgb(try rendered(snapshot),24,32); #expect(green[1] > 200 && green[0] < 100)
        #expect(coordinator.activeOwnerCount == 1 && coordinator.audibleOwnerCount == 0)
        let rotated = try await VideoImportService.read(movie(in: folder,rotated: true)); defer { try? FileManager.default.removeItem(at: rotated.url) }
        var rotatedScene = scene(rotated,at: 1); let rotatedOwner = try #require(rotatedScene.surfaces[0].sourceID)
        coordinator.configure(scene: rotatedScene,assets: [rotated.asset],urls: [rotated.asset.id:rotated.url],audio: VideoAudioSettings(),enabled: false)
        rotatedScene.videoFrames = [rotatedOwner:try await waitForFrame(coordinator,owner: rotatedOwner)]
        let frame = try rendered(rotatedScene)
        #expect(rgb(frame,64,12)[0] > 200 && rgb(frame,64,52)[2] > 200)
        coordinator.visualOverride = false; coordinator.tick(); #expect(coordinator.activeOwnerCount == 0 && coordinator.frames.isEmpty)
        coordinator.visualOverride = true
        rotatedScene.calibration.pattern = .grid
        coordinator.configure(scene: rotatedScene,assets: [rotated.asset],urls: [rotated.asset.id:rotated.url],audio: VideoAudioSettings(),enabled: false)
        #expect(coordinator.activeOwnerCount == 0 && coordinator.frames.isEmpty)
        rotatedScene.calibration.pattern = .normal; rotatedScene.showOutput.blackout()
        coordinator.configure(scene: rotatedScene,assets: [rotated.asset],urls: [rotated.asset.id:rotated.url],audio: VideoAudioSettings(),enabled: false)
        #expect(coordinator.activeOwnerCount == 0 && coordinator.frames.isEmpty)
        rotatedScene.showOutput = ShowOutputState(); rotatedScene.transport.seek(to: 3,at: ProcessInfo.processInfo.systemUptime)
        coordinator.configure(scene: rotatedScene,assets: [rotated.asset],urls: [rotated.asset.id:rotated.url],audio: VideoAudioSettings(),enabled: false)
        let resumed = try await waitForFrame(coordinator,owner: rotatedOwner)
        #expect(abs(resumed.sourceTime-3) < 0.04)
    }
    @Test func portableClipOnlyAssetsRecoveryFailedSaveAndShortRelink() async throws {
        let folder = try directory(); defer { try? FileManager.default.removeItem(at: folder) }
        let imported = try await VideoImportService.read(movie(in: folder)); defer { try? FileManager.default.removeItem(at: imported.url) }
        let session = EditorSession(presentOutput: { _ in })
        let owner = session.project.timelineTracks[0].id
        try session.installVideo(imported,target: .owner(owner))
        let id = try #require(session.addTimelineClip(sourceID: owner,at: 5))
        #expect(session.project.timelineClips[0].duration == imported.asset.duration)
        session.removeSelectedVideo(); #expect(session.project.referencedVideoIDs == [imported.asset.id])
        let package = folder.appendingPathComponent("test.projectionmap")
        try await session.saveMedia(to: package)
        let moved = folder.appendingPathComponent("moved.projectionmap"); try FileManager.default.copyItem(at: package,to: moved)
        let doc = try ProjectPackageStore().read(moved)
        let media = await VideoImportService.loadAssets(doc.project.videoAssets,package: moved)
        #expect(media.problems.isEmpty && media.urls.count == 1)
        let restored = EditorSession(presentOutput: { _ in }); try restored.load(doc,from: moved,loadedVideos: media)
        #expect(!restored.videoAudioEnabled && !restored.transport.isPlaying && restored.project.timelineClips.first?.id == id)
        var short = ImportedVideo(asset: imported.asset,url: package.appendingPathComponent("assets").appendingPathComponent(imported.asset.fileName),poster: imported.poster); short.asset.duration = 1
        #expect(throws: ProjectFileError.self) { try restored.installVideo(short,target: .relink(imported.asset.id)) }
        let before = try Data(contentsOf: moved.appendingPathComponent("manifest.json"))
        let failing = ProjectPackageStore(); failing.beforeCommit = { _ in throw ProjectFileError.io("injected") }
        #expect(throws: ProjectFileError.self) { try restored.save(to: moved,store: failing) }
        #expect(try Data(contentsOf: moved.appendingPathComponent("manifest.json")) == before)
        let recovery = ProjectRecoveryStore(directory: folder.appendingPathComponent("Recovery")); restored.configureRecovery(recovery)
        restored.renameProject("Changed"); try restored.flushRecovery()
        #expect(recovery.entries().count == 1)
        try FileManager.default.removeItem(at: moved.appendingPathComponent("assets").appendingPathComponent(imported.asset.fileName))
        let missing = await VideoImportService.loadAssets(doc.project.videoAssets,package: moved)
        #expect(missing.problems.count == 1 && missing.urls.isEmpty)
        restored.clearRecovery()
    }
    @Test func sharedMappedFramesRepeatCropAndStaleClipSuppression() async throws {
        let folder = try directory(); defer { try? FileManager.default.removeItem(at: folder) }
        let imported = try await VideoImportService.read(movie(in: folder)); defer { try? FileManager.default.removeItem(at: imported.url) }
        let coordinator = VideoPlaybackCoordinator(); coordinator.visualOverride = true; defer { coordinator.reset() }
        var base = scene(imported,at: 1); let owner = try #require(base.surfaces[0].sourceID)
        coordinator.configure(scene: base,assets: [imported.asset],urls: [imported.asset.id:imported.url],audio: VideoAudioSettings(),enabled: false)
        let frame = try await waitForFrame(coordinator,owner: owner)
        var surfaces: [RenderSurface] = []
        for i in 0..<3 {
            var face = base.surfaces[0]
            let a = Float(i)/3, b = Float(i+1)/3
            face = RenderSurface(geometry: NormalizedRectangle(topLeft: SIMD2(a,0),topRight: SIMD2(b,0),bottomRight: SIMD2(b,1),bottomLeft: SIMD2(a,1)),
                color: face.color,content: .video,inputMap: FaceInputMap(origin: SIMD2(a,0),size: SIMD2(1.0/3,1)),sourceID: owner,video: face.video)
            surfaces.append(face)
        }
        var joined = RenderScene(surfaces: surfaces,transport: base.transport); joined.videoFrames = [owner:frame]
        #expect(try rendered(joined) == rendered(joined))
        let continuous = try rendered(joined)
        #expect(rgb(continuous,18,32)[0] > 200 && rgb(continuous,110,32)[2] > 200)
        let repeated = surfaces.map { face in var face = face; face.inputMap = .full; return face }
        joined = RenderScene(surfaces: repeated,transport: base.transport); joined.videoFrames = [owner:frame]
        let pixels = try rendered(joined)
        #expect(rgb(pixels,8,32)[0] > 200 && rgb(pixels,36,32)[2] > 200 && rgb(pixels,51,32)[0] > 200)
        var cropped = base.surfaces[0]; cropped.appearance.crop = ContentCrop(origin: SIMD2(0.5,0),size: SIMD2(0.5,1))
        base = RenderScene(surfaces: [cropped],transport: base.transport); base.videoFrames = [owner:frame]
        #expect(rgb(try rendered(base),24,32)[2] > 200)
        var source = SurfaceSource(); source.content = .video; source.video = cropped.video
        let clip = EffectClip(sourceID: owner,start: 0,duration: 4,source: SourceLook(source: source))
        cropped.timelineClips = [clip]
        var pending = RenderScene(surfaces: [cropped],transport: base.transport); pending.videoFrames = [owner:frame] // wrong clip identity
        #expect(rgb(try rendered(pending),24,32) == [0,0,0])
        pending.calibration.pattern = .white
        #expect(rgb(try rendered(pending),24,32) == [255,255,255])
    }
    @Test func videoOwnerLifecycleCaptureAssetsAndAudioOnOpen() async throws {
        let folder = try directory(); defer { try? FileManager.default.removeItem(at: folder) }
        let imported = try await VideoImportService.read(movie(in: folder)); defer { try? FileManager.default.removeItem(at: imported.url) }
        let session = EditorSession(presentOutput: { _ in })
        session.addSurface(); session.createObject(faceIDs: Set(session.project.surfaces.map(\.id)))
        let object = try #require(session.selectedObject)
        try session.installVideo(imported,target: .owner(object.source.id))
        let clip = try #require(session.addTimelineClip(sourceID: object.source.id,at: 0))
        session.duplicateObject(object.id)
        #expect(session.project.timelineClips.count == 2 && session.project.videoAssets.count == 1)
        let face = try #require(session.project.surfaces.first { $0.layout.objectID == object.id })
        session.detachSurface(face.id)
        #expect(session.project.timelineClips.count == 3)
        session.deleteTimelineClip(clip)
        try ProjectCodec.validate(session.document)
        let look = try #require(session.saveLook(name: "video"))
        session.removeSelectedVideo(); #expect(session.project.referencedVideoIDs.contains(imported.asset.id))
        session.deleteLook(look)
        let package = folder.appendingPathComponent("owners.projectionmap"); try await session.saveMedia(to: package)
        let doc = try ProjectPackageStore().read(package)
        let media = await VideoImportService.loadAssets(doc.project.videoAssets,package: package)
        let loaded = EditorSession(presentOutput: { _ in }); try loaded.load(doc,from: package,loadedVideos: media)
        #expect(!loaded.videoAudioEnabled && !loaded.transport.isPlaying)
        loaded.resetProject(); #expect(loaded.videoFiles.isEmpty && loaded.project.videoAssets.isEmpty && loaded.videoPlayback.activeOwnerCount == 0)
    }
    @Test func cancellationLeavesLastGoodPackageAndInvalidRangesFail() async throws {
        let folder = try directory(); defer { try? FileManager.default.removeItem(at: folder) }
        let imported = try await VideoImportService.read(movie(in: folder)); defer { try? FileManager.default.removeItem(at: imported.url) }
        let session = EditorSession(presentOutput: { _ in })
        try session.installVideo(imported,target: .owner(session.project.timelineTracks[0].id))
        let package = folder.appendingPathComponent("last.projectionmap"); try await session.saveMedia(to: package)
        let original = try Data(contentsOf: package.appendingPathComponent("manifest.json"))
        session.renameProject("unsaved")
        let data = try ProjectCodec.encode(session.document), videoURL = try #require(session.videoFiles[imported.asset.id]), assetID = imported.asset.id
        let task = Task.detached {
            try Task.checkCancellation()
            try ProjectPackageStore().write(ProjectCodec.decode(data),to: package,assetsFrom: package,videoFiles: [assetID:videoURL])
        }
        task.cancel()
        do { try await task.value; Issue.record("Cancelled save unexpectedly committed") } catch { }
        #expect(try Data(contentsOf: package.appendingPathComponent("manifest.json")) == original && session.hasUserChanges)
        var invalid = try #require(session.selectedSource?.video); invalid.outPoint = 20
        session.setSelectedVideo(invalid)
        #expect(session.selectedSource?.video?.outPoint == 4)
    }
    @Test func runtimeSourceRatesAndRapidChangesStayOnTransport() async throws {
        let folder = try directory(); defer { try? FileManager.default.removeItem(at: folder) }
        let file = try await movie(in: folder), imported = try await VideoImportService.read(file)
        defer { try? FileManager.default.removeItem(at: imported.url) }
        let base = scene(imported), owner = try #require(base.surfaces[0].sourceID)
        let coordinator = VideoPlaybackCoordinator(); coordinator.visualOverride = true
        defer { coordinator.reset() }
        for rate in [0.25,0.5,2.0,4.0,1.0] {
            var face = base.surfaces[0]; face.video?.rate = rate; face.video?.loops = true
            var snapshot = RenderScene(surfaces: [face])
            snapshot.transport.seek(to: 0.2,at: ProcessInfo.processInfo.systemUptime)
            snapshot.transport.setPlaying(true,at: ProcessInfo.processInfo.systemUptime)
            coordinator.configure(scene: snapshot,assets: [imported.asset],urls: [imported.asset.id:imported.url],audio: VideoAudioSettings(),enabled: false)
            _ = try await waitForFrame(coordinator,owner: owner)
            let start = ProcessInfo.processInfo.systemUptime
            var observed = 0
            while ProcessInfo.processInfo.systemUptime-start < 0.8 {
                coordinator.tick()
                if let frame = coordinator.frames[owner] {
                    let requested = try #require(VideoPlaybackRequest.requests(scene: snapshot,assets: [imported.asset],audioEnabled: false,at: ProcessInfo.processInfo.systemUptime).first)
                    let difference = abs(frame.sourceTime-requested.sourceTime)
                    #expect(min(difference,4-difference) < 0.25)
                    observed += 1
                }
                try await Task.sleep(for: .milliseconds(20))
            }
            #expect(observed > 5 && coordinator.audibleOwnerCount == 0)
        }
    }
    @Test func runningLoopStressProfileAndPortableDemo() async throws {
        let folder = try directory(); defer { try? FileManager.default.removeItem(at: folder) }
        let hd = ProcessInfo.processInfo.environment["PROJECTION_MAPPER_VIDEO_PROFILE_HD"] == "1"
        let seconds = Double(ProcessInfo.processInfo.environment["PROJECTION_MAPPER_VIDEO_PROFILE_SECONDS"] ?? "6") ?? 6
        let original = try await movie(in: folder,width: hd ? 1920 : 128,height: hd ? 1080 : 64)
        let audibleMovie = try await audioMovie(original,in: folder)
        let imported = try await VideoImportService.read(audibleMovie); defer { try? FileManager.default.removeItem(at: imported.url) }
        var evidence: [[String:Double]] = []
        for count in [1,3] {
            let coordinator = VideoPlaybackCoordinator(); coordinator.visualOverride = true
            var prototype = scene(imported).surfaces[0]; prototype.video?.loops = true
            let owner = try #require(prototype.sourceID)
            let faces = (0..<3).map { i in var face = prototype; if count == 3 { face.sourceID = UUID() }; return face }
            var snapshot = RenderScene(surfaces: faces)
            snapshot.transport.setPlaying(true,at: ProcessInfo.processInfo.systemUptime)
            coordinator.configure(scene: snapshot,assets: [imported.asset],urls: [imported.asset.id:imported.url],audio: VideoAudioSettings(),enabled: false)
            let started = ProcessInfo.processInfo.systemUptime
            var observed = 0, maxFrames = 0, maxError = 0.0, decodedBytes = 0
            var peakResident: UInt64 = 0
            let cpuStart = clock()
            var gpuTimes: [Double] = []
            let renderer = try MetalRenderer(scene: snapshot)
            let targetDescriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .bgra8Unorm,width: 640,height: 360,mipmapped: false)
            targetDescriptor.usage = .renderTarget
            let renderTarget = try #require(renderer.device.makeTexture(descriptor: targetDescriptor))
            while ProcessInfo.processInfo.systemUptime-started < seconds {
                coordinator.tick()
                let now = ProcessInfo.processInfo.systemUptime
                let requests = VideoPlaybackRequest.requests(scene: snapshot,assets: [imported.asset],audioEnabled: false,at: now)
                for request in requests {
                    if let frame = coordinator.frames[request.ownerID] {
                        observed += 1
                        let distance = abs(frame.sourceTime-request.sourceTime)
                        if distance < 2 { maxError = max(maxError,distance) }
                    }
                }
                maxFrames = max(maxFrames,coordinator.frames.count)
                decodedBytes = max(decodedBytes,coordinator.frames.values.reduce(0) { $0+$1.byteCount })
                if observed % 12 == 0, !coordinator.frames.isEmpty {
                    var renderScene = snapshot; renderScene.videoFrames = coordinator.frames; renderer.setScene(renderScene)
                    let milliseconds = try profileGPU(renderer,target: renderTarget)
                    if milliseconds > 0 { gpuTimes.append(milliseconds) }
                }
                var info = mach_task_basic_info_data_t()
                var infoCount = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info_data_t>.size/MemoryLayout<integer_t>.size)
                let infoCapacity = Int(infoCount)
                let result = withUnsafeMutablePointer(to: &info) { pointer in pointer.withMemoryRebound(to: integer_t.self,capacity: infoCapacity) { task_info(mach_task_self_,task_flavor_t(MACH_TASK_BASIC_INFO),$0,&infoCount) } }
                if result == KERN_SUCCESS { peakResident = max(peakResident,info.resident_size) }
                #expect(coordinator.audibleOwnerCount == 0)
                try await Task.sleep(for: .milliseconds(20))
            }
            #expect(maxFrames == count && observed > 30)
            #expect(decodedBytes <= VideoPlaybackCoordinator.maximumFrameBytes)
            #expect(maxError < 0.25)
            var sample: [String:Double] = [:]
            sample["sourceWidth"] = Double(imported.asset.width); sample["sourceHeight"] = Double(imported.asset.height)
            sample["peakProcessResidentMiB"] = Double(peakResident)/1048576
            sample["processCPUSeconds"] = Double(clock()-cpuStart)/Double(CLOCKS_PER_SEC)
            sample["meanGPUEncodeMilliseconds"] = gpuTimes.reduce(0,+)/Double(max(1,gpuTimes.count))
            sample["owners"] = Double(count); sample["faces"] = 3
            sample["seconds"] = ProcessInfo.processInfo.systemUptime-started
            sample["observedFrames"] = Double(observed); sample["peakPublishedBytes"] = Double(decodedBytes)
            sample["maxObservedSourceErrorSeconds"] = maxError
            evidence.append(sample)
            coordinator.reset(); #expect(coordinator.activeOwnerCount == 0 && coordinator.frames.isEmpty)
            _ = owner
        }
        if let output = ProcessInfo.processInfo.environment["PROJECTION_MAPPER_VIDEO_EVIDENCE_OUTPUT"] {
            let directory = URL(fileURLWithPath: output,isDirectory: true)
            try FileManager.default.createDirectory(at: directory,withIntermediateDirectories: true)
            try JSONSerialization.data(withJSONObject: evidence,options: [.prettyPrinted,.sortedKeys]).write(to: directory.appendingPathComponent("playback-profile.json"))
            let session = EditorSession(presentOutput: { _ in })
            session.addSurface(); session.addSurface()
            let boxFaces = session.project.surfaces.map(\.id)
            for (n,id) in boxFaces.enumerated() {
                session.selectSurface(id); session.renameSurface(id,["Box front","Box side","Box top"][n])
                let x = Float(n)*0.28+0.06
                let corners: [SIMD2<Float>] = [SIMD2(x,0.12),SIMD2(x+0.28,0.12),SIMD2(x+0.28,0.55),SIMD2(x,0.55)]
                for (corner,point) in zip([SurfaceCorner.topLeft,.topRight,.bottomRight,.bottomLeft],corners) {
                    session.selectCorner(corner); session.moveSelectedCorner(to: point,surfaceID: id)
                }
            }
            session.createObject(faceIDs: Set(boxFaces))
            let object = try #require(session.selectedObject); session.renameObject(object.id,"Connected box")
            try session.installVideo(imported,target: .owner(object.source.id))
            _ = session.addTimelineClip(sourceID: object.source.id,at: 0)
            session.setSurfaceContent(.movingLines); _ = session.addTimelineClip(sourceID: object.source.id,at: 4,duration: 4)
            var imageBytes = Data(count: 64*64*4)
            for y in 0..<64 { for x in 0..<64 {
                let i = (y*64+x)*4, bright: UInt8 = ((x/8+y/8)%2 == 0) ? 210 : 55
                imageBytes[i] = bright; imageBytes[i+1] = bright; imageBytes[i+2] = bright; imageBytes[i+3] = 255
            } }
            let image = try #require(ImagePixels(width: 64,height: 64,bytes: imageBytes).cgImage)
            let png = try #require(NSBitmapImageRep(cgImage: image).representation(using: .png,properties: [:]))
            let still = try ImageImportService.decode(png,name: "Rehearsal checker.png")
            try session.installImage(still,target: .owner(object.source.id))
            _ = session.addTimelineClip(sourceID: object.source.id,at: 8,duration: 2)
            try session.installImage(still,target: .reference)
            session.setMask(FaceMask(holes: [MaskPolygon(points: [SIMD2(0.4,0.4),SIMD2(0.6,0.4),SIMD2(0.5,0.6)])]),faceID: boxFaces[0])
            session.addSurface()
            let independentFace = try #require(session.selectedSurface)
            session.renameSurface(independentFace.id,"Independent looping video")
            let corners: [SIMD2<Float>] = [SIMD2(0.3,0.65),SIMD2(0.7,0.65),SIMD2(0.7,0.92),SIMD2(0.3,0.92)]
            for (corner,point) in zip([SurfaceCorner.topLeft,.topRight,.bottomRight,.bottomLeft],corners) {
                session.selectCorner(corner); session.moveSelectedCorner(to: point,surfaceID: independentFace.id)
            }
            try session.installVideo(imported,target: .owner(independentFace.source.id))
            var content = try #require(session.selectedSource?.video); content.inPoint = 1; content.outPoint = 3; content.loops = true
            session.setSelectedVideo(content); _ = session.addTimelineClip(sourceID: independentFace.source.id,at: 1,duration: 6)
            session.renameProject("Video timeline rehearsal")
            try await session.saveMedia(to: directory.appendingPathComponent("Video-demo.projectionmap"))
            let reopened = try ProjectPackageStore().read(directory.appendingPathComponent("Video-demo.projectionmap"))
            #expect(reopened.project.timelineClips.count == 4 && reopened.project.referencePhoto != nil && reopened.project.surfaces.contains { $0.mask != nil })
        }
    }

}
