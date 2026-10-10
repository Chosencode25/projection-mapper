import AppKit
import ImageIO
import UniformTypeIdentifiers
import MetalKit
import Testing

@MainActor
@Suite(.serialized)
struct ImageImportTests {
    private func fixture(width: Int = 16,height: Int = 8,alpha: UInt8 = 255,quadrants: Bool = false) throws -> ImportedImage {
        var data = Data(count: width*height*4)
        for y in 0..<height { for x in 0..<width {
            let i = (y*width+x)*4
            let color: [UInt8] = quadrants && y >= height/2 ? (x < width/2 ? [alpha,0,0,alpha] : [alpha,alpha,alpha,alpha]) : (x < width/2 ? [0,0,alpha,alpha] : [0,alpha,0,alpha])
            data.replaceSubrange(i..<i+4,with: color)
        } }
        let pixels = ImagePixels(width: width,height: height,bytes: data)
        let out = NSMutableData(), image = try #require(pixels.cgImage)
        let dst = try #require(CGImageDestinationCreateWithData(out,UTType.png.identifier as CFString,1,nil))
        CGImageDestinationAddImage(dst,image,nil); #expect(CGImageDestinationFinalize(dst))
        return try ImageImportService.decode(out as Data,name: "House.png")
    }
    private func full() -> NormalizedRectangle {
        NormalizedRectangle(topLeft: SIMD2(0,0),topRight: SIMD2(1,0),bottomRight: SIMD2(1,1),bottomLeft: SIMD2(0,1))
    }
    private func render(_ scene: RenderScene,width: Int = 128,height: Int = 64) throws -> (Data,MetalRenderer) {
        let r = try MetalRenderer(scene: scene)
        let desc = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .bgra8Unorm,width: width,height: height,mipmapped: false)
        desc.storageMode = .shared; desc.usage = .renderTarget
        let texture = try #require(r.device.makeTexture(descriptor: desc))
        let pass = MTLRenderPassDescriptor(); pass.colorAttachments[0].texture = texture
        let command = try #require(r.encodeScene(to: pass,evaluationTime: 0,evaluationUptime: 100))
        command.commit(); command.waitUntilCompleted(); #expect(command.status == .completed && command.error == nil)
        var bytes = Data(count: width*height*4)
        bytes.withUnsafeMutableBytes { texture.getBytes($0.baseAddress!,bytesPerRow: width*4,from: MTLRegionMake2D(0,0,width,height),mipmapLevel: 0) }
        return (bytes,r)
    }
    private func rgb(_ data: Data,_ x: Int,_ y: Int,width: Int = 128) -> [UInt8] { let i = (y*width+x)*4; return [data[i+2],data[i+1],data[i]] }
    private func scene(_ image: ImportedImage,placement: ImagePlacement = .stretch,aspect: Float = 2,alpha: Float = 1) -> RenderScene {
        var face = RenderSurface(geometry: full(),color: SIMD4(1,1,1,1),content: .image,image: ImageContent(assetID: image.asset.id,placement: placement,canvasAspect: aspect))
        face.appearance.opacity = alpha
        var scene = RenderScene(surfaces: [face]); scene.images[image.asset.id] = image.pixels; return scene
    }
    private func temp() throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: url,withIntermediateDirectories: true); return url
    }
    @Test func normalizationPreservesPNGOrientationColorAndTransparency() throws {
        let image = try fixture(quadrants: true)
        #expect(image.pixels.width == 16 && image.pixels.height == 8)
        let i = 4*(1*16+1)
        #expect(Array(image.pixels.bytes[i..<i+4]) == [0,0,255,255])
        let normalized = try ImageImportService.decode(image.png,name: "normalized.png")
        #expect(normalized.pixels == image.pixels)
        let bytes = try render(scene(image)).0
        #expect(rgb(bytes,16,12) == [255,0,0])
        #expect(rgb(bytes,110,12) == [0,255,0])
        #expect(rgb(bytes,16,52) == [0,0,255])
        #expect(rgb(bytes,110,52) == [255,255,255])
    }
    @Test func JPEGOrientationIsNormalizedAndLargeImagesAreBounded() throws {
        let image = try fixture(width: 32,height: 16,quadrants: true)
        let output = NSMutableData(), dst = try #require(CGImageDestinationCreateWithData(output,UTType.jpeg.identifier as CFString,1,nil))
        CGImageDestinationAddImage(dst,try #require(image.pixels.cgImage),[kCGImagePropertyOrientation: 6] as CFDictionary)
        #expect(CGImageDestinationFinalize(dst))
        let jpeg = try ImageImportService.decode(output as Data,name: "Rotated.jpg")
        #expect(jpeg.pixels.width == 16 && jpeg.pixels.height == 32)
        let large = try fixture(width: 5000,height: 2)
        #expect(large.pixels.width <= 4096 && large.pixels.height > 0)
        #expect(throws: ImageImportError.self) { try ImageImportService.decode(Data([1,2,3]),name: "bad.png") }
    }
    @Test func fitFillStretchAndAlphaRevealLowerFaces() throws {
        let image = try fixture(alpha: 128)
        var s = scene(image,placement: .fit,aspect: 1)
        s = RenderScene(surfaces: [RenderSurface(geometry: full(),color: SIMD4(0,0,1,1))]+s.surfaces)
        s.images[image.asset.id] = image.pixels
        let fitted = try render(s).0
        #expect(rgb(fitted,16,3) == [0,0,255])
        let center = rgb(fitted,16,32); #expect(abs(Int(center[0])-128) <= 2 && abs(Int(center[2])-127) <= 2)
        let filled = try render(scene(try fixture(),placement: .fill,aspect: 1)).0
        #expect(rgb(filled,20,3)[0] > 250)
        let stretched = try render(scene(try fixture(),placement: .stretch,aspect: 1)).0
        #expect(rgb(stretched,20,3)[0] > 250)
        #expect(ImagePlacement.fit.scale(imageAspect: 2,canvasAspect: 1) == SIMD2(1,2))
        #expect(ImagePlacement.fill.scale(imageAspect: 2,canvasAspect: 1) == SIMD2(0.5,1))
    }
    @Test func sharedImageSpansJoinedFacesRepeatChangesSamplingAndCacheReleases() throws {
        let image = try fixture()
        var left = RenderSurface(geometry: NormalizedRectangle(topLeft: SIMD2(0,0),topRight: SIMD2(0.5,0),bottomRight: SIMD2(0.5,1),bottomLeft: SIMD2(0,1)),color: SIMD4(1,1,1,1),content: .image,image: ImageContent(assetID: image.asset.id,placement: .stretch))
        var right = left; right = RenderSurface(geometry: NormalizedRectangle(topLeft: SIMD2(0.5,0),topRight: SIMD2(1,0),bottomRight: SIMD2(1,1),bottomLeft: SIMD2(0.5,1)),color: left.color,content: .image,image: left.image)
        left.inputMap = FaceInputMap(origin: .zero,size: SIMD2(0.5,1)); right.inputMap = FaceInputMap(origin: SIMD2(0.5,0),size: SIMD2(0.5,1))
        var s = RenderScene(surfaces: [left,right]); s.images[image.asset.id] = image.pixels
        let (continuous,r) = try render(s)
        #expect(rgb(continuous,24,32) == [255,0,0] && rgb(continuous,104,32) == [0,255,0])
        #expect(r.cachedImageTextureCount == 1)
        left.inputMap = .full; right.inputMap = .full
        var repeated = RenderScene(surfaces: [left,right]); repeated.images = s.images
        let bytes = try render(repeated).0
        #expect(rgb(bytes,16,32) == [255,0,0] && rgb(bytes,80,32) == [255,0,0])
        r.setScene(RenderScene(surfaces: [])); #expect(r.cachedImageTextureCount == 0)
    }
    @Test func imageWarpCropFlipMaskAndCalibrationShareOutputPath() throws {
        let image = try fixture()
        var s = scene(image)
        var face = s.surfaces[0]
        face.appearance.flipHorizontal = true
        face.mask = FaceMask(boundary: MaskPolygon(points: [SIMD2(0.1,0.1),SIMD2(0.9,0.1),SIMD2(0.9,0.9),SIMD2(0.1,0.9)]))
        s = RenderScene(surfaces: [face]); s.images[image.asset.id] = image.pixels
        let flipped = try render(s).0
        #expect(rgb(flipped,24,32) == [0,255,0] && rgb(flipped,104,32) == [255,0,0])
        #expect(rgb(flipped,2,32) == [0,0,0])
        s.calibration = CalibrationState(pattern: .white)
        let white = try render(s).0
        #expect(rgb(white,24,32) == [255,255,255] && rgb(white,2,32) == [0,0,0])
        s.calibration = CalibrationState(); s.images = [:]
        #expect(try rgb(render(s).0,24,32) == [0,0,0])
        face.appearance.crop = ContentCrop(origin: .zero,size: SIMD2(0.4,1))
        let shape = NormalizedRectangle(topLeft: SIMD2(0.1,0.1),topRight: SIMD2(0.9,0.15),bottomRight: SIMD2(0.75,0.9),bottomLeft: SIMD2(0.2,0.85))
        let warped = RenderSurface(geometry: shape,color: face.color,content: .image,appearance: face.appearance,mask: face.mask,image: face.image)
        var warpedScene = RenderScene(surfaces: [warped]); warpedScene.images[image.asset.id] = image.pixels
        let center = try #require(PerspectiveTransform(shape)).project(SIMD2(0.5,0.5))
        #expect(try rgb(render(warpedScene).0,Int(center.x*128),Int(center.y*64)) == [255,0,0])
        face.appearance = .defaults; face.mask = nil; face.inputMap.quarterTurns = 2
        var rotated = RenderScene(surfaces: [face]); rotated.images[image.asset.id] = image.pixels
        #expect(try rgb(render(rotated).0,24,32) == [0,255,0])

    }
    @Test func ownershipDetachDuplicationAndReplacePreserveGeometryAndMasks() throws {
        let s = EditorSession(presentOutput: { _ in })
        let faceID = s.project.surfaces[0].id, corners = s.project.surfaces[0].corners
        let a = try fixture(); try s.installImage(a,target: .owner(s.selectedSource!.id))
        s.createMask(faceID: faceID); let mask = s.selectedSurface?.mask
        s.duplicateSurface(faceID)
        #expect(s.project.imageAssets.count == 1 && s.imagePixels.count == 1)
        let second = s.selectedSurfaceID!
        s.toggleGrouping(faceID); s.toggleGrouping(second); s.createObject()
        let object = try #require(s.selectedObject)
        let b = try fixture(width: 8,height: 8)
        try s.installImage(b,target: .owner(object.source.id))
        #expect(s.project.surfaces.allSatisfy { s.project.source(for: $0).image?.assetID == b.asset.id })
        s.selectSurface(faceID); try s.installImage(a,target: .detach(faceID))
        #expect(s.selectedSurface?.layout.objectID == nil && s.selectedSurface?.corners == corners && s.selectedSurface?.mask == mask)
        #expect(s.project.objects[0].source.image?.assetID == b.asset.id)
        s.removeSelectedImage(); #expect(s.selectedSource?.content == .diagnosticGrid)
        #expect(s.imagePixels[b.asset.id] != nil)
    }
    @Test func portablePackagesRecoveryMovedAssetsAndMissingRelink() throws {
        let dir = try temp(); defer { try? FileManager.default.removeItem(at: dir) }
        let s = EditorSession(presentOutput: { _ in }); let image = try fixture()
        try s.installImage(image,target: .owner(s.selectedSource!.id))
        try s.installImage(try fixture(width: 8,height: 8),target: .reference)
        let corners = s.project.surfaces[0].corners
        let a = dir.appendingPathComponent("A.projectionmap"), b = dir.appendingPathComponent("Moved.projectionmap")
        try s.save(to: a); try FileManager.default.moveItem(at: a,to: b)
        let loaded = EditorSession(presentOutput: { _ in })
        try loaded.load(ProjectPackageStore().read(b),from: b)
        #expect(loaded.imagePixels.count == 2 && !loaded.hasUserChanges && loaded.project.surfaces[0].corners == corners)
        let photo = loaded.project.referencePhoto!
        loaded.referencePhotoVisible = false; #expect(!loaded.hasUserChanges)
        loaded.referencePhotoVisible = true
        #expect(loaded.editorScene.editorTransparentBackground && !loaded.scene.editorTransparentBackground)
        #expect(!loaded.scene.surfaces.contains { $0.image?.assetID == photo.assetID })
        try FileManager.default.removeItem(at: b.appendingPathComponent("assets/\(image.asset.fileName)"))
        let missing = EditorSession(presentOutput: { _ in }); try missing.load(ProjectPackageStore().read(b),from: b)
        #expect(missing.imageProblems[image.asset.id] != nil && missing.project.surfaces[0].source.image?.assetID == image.asset.id)
        #expect(throws: (any Error).self) { try missing.save(to: dir.appendingPathComponent("Bad.projectionmap")) }
        try missing.installImage(image,target: .relink(image.asset.id)); try missing.save(to: b)
        #expect(missing.imageProblems.isEmpty)
        missing.configureRecovery(ProjectRecoveryStore(directory: dir.appendingPathComponent("Recovery")))
        missing.renameProject("Recovered"); try missing.flushRecovery()
        let entry = try #require(ProjectRecoveryStore(directory: dir.appendingPathComponent("Recovery")).entries().first)
        let restored = EditorSession(presentOutput: { _ in }); try restored.load(entry.document,from: entry.url,recovering: true)
        #expect(restored.imagePixels.count == 2 && restored.hasUserChanges)
    }
    @Test func failuresStaleTargetsAndAtomicSaveLeaveLastGoodState() async throws {
        let dir = try temp(); defer { try? FileManager.default.removeItem(at: dir) }
        let s = EditorSession(presentOutput: { _ in }); let image = try fixture()
        let original = s.project
        #expect(throws: ImageImportError.self) { try s.installImage(image,target: .owner(UUID())) }
        #expect(s.project == original)
        let bad = dir.appendingPathComponent("bad.png"); try Data([1,2,3]).write(to: bad)
        await s.importImage(from: bad,target: .owner(s.selectedSource!.id)); #expect(s.project == original && s.editMessage != nil)
        try s.installImage(image,target: .owner(s.selectedSource!.id))
        let url = dir.appendingPathComponent("Saved.projectionmap"); try s.save(to: url)
        let good = s.document; s.renameProject("Changed")
        let store = ProjectPackageStore(); store.beforeCommit = { _ in throw ProjectFileError.io("disk failed") }
        #expect(throws: ProjectFileError.self) { try s.save(to: url,store: store) }
        #expect(try ProjectPackageStore().read(url) == good && s.hasUserChanges)
    }
    @Test func asyncCompletionCannotReplaceANewProjectOrDeletedOwner() async throws {
        let dir = try temp(); defer { try? FileManager.default.removeItem(at: dir) }
        let image = try fixture(width: 128,height: 64)
        let url = dir.appendingPathComponent("Imported.png"); try image.png.write(to: url)
        let session = EditorSession(presentOutput: { _ in })
        let originalOwner = session.selectedSource!.id
        let gate = ImageDecodeGate()
        let task = Task { await session.importImage(from: url,target: .owner(originalOwner),decode: { _ in await gate.wait() }) }
        while !(await gate.started) { await Task.yield() }
        session.resetProject(); let newID = session.project.id
        await gate.finish(image)
        await task.value
        #expect(session.project.id == newID && session.project.hasDefaultContent && session.imagePixels.isEmpty)
    }
    @Test func looksKeepAssetsAliveAndFinalRemovalCollectsResources() throws {
        let s = EditorSession(presentOutput: { _ in }), image = try fixture()
        try s.installImage(image,target: .owner(s.selectedSource!.id))
        _ = s.saveLook(name: "Image look")
        s.removeSelectedImage()
        #expect(s.project.imageAssets.contains { $0.id == image.asset.id } && s.imagePixels[image.asset.id] != nil)
        if let look = s.project.looks.first { s.deleteLook(look.id) }
        #expect(s.imagePixels.isEmpty && s.project.imageAssets.isEmpty)
    }
    @Test func photoAlignmentIsSavedVisibilityIsTemporaryAndCleanOutputStaysUnchanged() throws {
        let s = EditorSession(presentOutput: { _ in }), image = try fixture()
        let original = try render(s.scene).0, geometry = s.project.surfaces.map(\.corners)
        try s.installImage(image,target: .reference)
        var photo = s.project.referencePhoto!; photo.isLocked = false; photo.center = SIMD2(0.2,0.7); photo.scale = 2; photo.opacity = 0.3
        s.setReferencePhoto(photo)
        #expect(s.project.surfaces.map(\.corners) == geometry && s.project.referencePhoto == photo)
        #expect(try render(s.scene).0 == original)
        let encoded = try ProjectCodec.encode(s.document)
        s.referencePhotoVisible = false
        #expect(try ProjectCodec.encode(s.document) == encoded && !s.editorScene.editorTransparentBackground)
        s.referencePhotoVisible = true
        let alpha = try render(s.editorScene).0
        #expect(alpha[3] == 0 && original[3] == 255)
        photo.scale = .nan; s.setReferencePhoto(photo)
        #expect(s.project.referencePhoto?.scale == 2)
    }
    @Test func symlinkedMediaAndMemoryOverflowAreRejected() throws {
        let dir = try temp(); defer { try? FileManager.default.removeItem(at: dir) }
        let image = try fixture(), file = dir.appendingPathComponent("Image.png"), link = dir.appendingPathComponent("Link.png")
        try image.png.write(to: file)
        try FileManager.default.createSymbolicLink(at: link,withDestinationURL: file)
        #expect(throws: ImageImportError.self) { try ImageImportService.read(link) }
        var doc = ProjectDocument(project: MappingProject())
        doc.project.imageAssets = (0..<5).map { _ in ImageAsset(name: "Large",width: 4096,height: 4096) }
        #expect(throws: ProjectFileError.self) { try ProjectCodec.validate(doc) }
    }
    @Test func versionSixMigratesAndAssetIdentitiesAreValidated() throws {
        let doc = ProjectDocument(project: MappingProject())
        var json = try #require(JSONSerialization.jsonObject(with: ProjectCodec.encode(doc)) as? [String:Any])
        json["formatVersion"] = 6
        var project = json["project"] as! [String:Any]; project.removeValue(forKey: "imageAssets"); json["project"] = project
        let migrated = try ProjectCodec.decode(JSONSerialization.data(withJSONObject: json))
        #expect(migrated.formatVersion == ProjectDocument.currentVersion && migrated.project.imageAssets.isEmpty && migrated.project.referencePhoto == nil)
        var bad = migrated; bad.project.surfaces[0].source.image = ImageContent(assetID: UUID()); bad.project.surfaces[0].source.content = .image
        #expect(throws: ProjectFileError.self) { try ProjectCodec.validate(bad) }
    }
}

private actor ImageDecodeGate {
    private(set) var started = false
    private var continuation: CheckedContinuation<ImportedImage,Never>?
    func wait() async -> ImportedImage {
        await withCheckedContinuation { continuation = $0; started = true }
    }
    func finish(_ image: ImportedImage) { continuation?.resume(returning: image); continuation = nil }
}
