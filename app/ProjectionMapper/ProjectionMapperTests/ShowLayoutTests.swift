import Foundation
import ImageIO
import MetalKit
import Testing

@MainActor
struct ShowLayoutTests {
    @Test func rolesPersistOnPlaygroundsAndUndoTargetDeletion() throws {
        var layout = MappingProject(name: "House")
        layout.surfaces.append(MappingSurface(name: "Garage"))
        let roof = LayoutTargetID(domain: .face, id: layout.surfaces[0].id)
        let garage = LayoutTargetID(domain: .face, id: layout.surfaces[1].id)
        let roles = [LayoutRole(name: "Roof", targets: [garage, roof]), LayoutRole(name: "Front", targets: [roof])]
        let session = EditorSession(presentOutput: { _ in }, project: layout)
        defer { session.releaseRuntimeResources() }
        try session.saveLayoutRoles(roles, basedOn: layout.layoutTargets)
        let saved = try ProjectCodec.decode(ProjectCodec.encode(session.document))
        #expect(saved.formatVersion == 17 && saved.project.savedLayoutRoles == roles)
        let setup = try PlaygroundExtraction.extract(saved, name: "Reusable House")
        #expect(setup.project.savedLayoutRoles == roles)
        try PlaygroundExtraction.validateSetup(setup)
        #expect(throws: DeliveryError.self) {
            try session.saveLayoutRoles(roles + [LayoutRole(name: " roof ")], basedOn: layout.layoutTargets)
        }
        session.deleteSurface(garage.id)
        #expect(session.project.savedLayoutRoles.first?.targets == [roof])
        session.undoProjectEdit()
        #expect(session.project.savedLayoutRoles == roles)
        session.undoProjectEdit()
        #expect(session.project == layout)
    }

    @Test func repeatsProjectionAndLightingOntoOrderedDestinations() throws {
        var show = MappingProject(name: "Holiday", surface: MappingSurface(name: "Original window", content: .solid))
        let palette = ColorPalette(name: "Festive", slots: [PaletteSlot(name: "Red", color: SIMD4(1, 0, 0, 1))])
        show.palettes = [palette]
        show.surfaces[0].source.primaryBinding = ColorBinding(paletteID: palette.id, slotID: palette.slots[0].id)
        let window = LayoutTargetID(domain: .face, id: show.surfaces[0].id)
        let owner = show.surfaces[0].source.id
        let controller = LightingController(name: "Relays", kind: .arduino)
        let plug = PatchedFixture(name: "Old Plug", kind: .plug, controllerID: controller.id)
        let fixtureID = LayoutTargetID(domain: .fixture, id: plug.id)
        let entry = FixtureLookEntry(id: plug.id, state: .plug(true))
        show.lighting.controllers = [controller]
        show.lighting.fixtures = [plug]
        show.lighting.cues = [LightingCue(name: "Front On", time: 4, entries: [entry]),
                              LightingCue(name: "Operator Cue", time: 5, manualOnly: true, entries: [entry])]
        show.lighting.looks = [FixtureLook(name: "Front On", entries: [entry])]
        let marker = ShowMarker(time: 8, kind: .beat, name: "Drop")
        show.markers = [marker]
        let track = VisualTrack(name: "Countdown", kind: .text,
                                text: ProjectionText(mode: .countdown, markerID: marker.id))
        show.visualLayers = [VisualLayer(ownerID: owner, track: track)]
        show.faceRegions = [FaceRegion(faceID: window.id, track: VisualTrack(name: "Face Artwork"))]
        var clipLook = SourceLook(source: show.surfaces[0].source)
        clipLook.primaryBinding = nil
        show.timelineClips = [EffectClip(sourceID: owner, start: 2, duration: 3, source: clipLook)]
        show.choreography = [ChoreographyClip(targets: [ChoreographyTarget(id: plug.id, position: .init(x: 0.5, y: 0.5))], start: 6)]
        show.layoutRoles = [LayoutRole(name: "Windows", targets: [window]), LayoutRole(name: "Front Lights", targets: [fixtureID])]

        var layout = MappingProject(name: "Receiving layout", surface: MappingSurface(name: "Bay"))
        layout.surfaces.append(MappingSurface(name: "Side"))
        layout.surfaces[0].layout.inputMap = FaceInputMap(origin: SIMD2(0.25, 0), size: SIMD2(0.75, 1))
        layout.surfaces[0].mask = FaceMask(boundary: .rectangle)
        let windows = layout.surfaces.reversed().map { LayoutTargetID(domain: .face, id: $0.id) }
        let patch = LightingController(name: "New Relays", kind: .arduino)
        var frontA = PatchedFixture(name: "A", kind: .plug, controllerID: patch.id)
        var frontB = PatchedFixture(name: "B", kind: .plug, controllerID: patch.id)
        frontA.address = 2; frontB.address = 3
        layout.lighting.controllers = [patch]
        layout.lighting.fixtures = [frontA, frontB]
        let front = [frontB, frontA].map { LayoutTargetID(domain: .fixture, id: $0.id) }
        layout.layoutRoles = [LayoutRole(name: "windows", targets: windows), LayoutRole(name: "FRONT LIGHTS", targets: front)]

        let plan = ShowLayoutPlan(show: show, layout: layout)
        #expect(plan.suggestions[window] == windows && plan.suggestions[fixtureID] == front)
        #expect(plan.issue([window: windows]) != nil)
        #expect(plan.issue([window: windows, fixtureID: [windows[0]]]) != nil)
        let receiving = ProjectDocument(project: layout, output: ProjectOutputSettings(resolution: .fullHD))
        let copy = try ShowLayoutCopy.create(show: ProjectDocument(project: show), layout: receiving,
                                             name: "Holiday on Receiving", assignments: plan.suggestions).document
        let result = copy.project
        #expect(result.id != layout.id && result.id != show.id)
        #expect(copy.output == receiving.output)
        #expect(result.surfaces.map(\.layout) == layout.surfaces.map(\.layout))
        #expect(result.surfaces.map(\.mask) == layout.surfaces.map(\.mask))
        #expect(result.lighting.fixtures == layout.lighting.fixtures && result.lighting.controllers == [patch])
        #expect(result.savedLayoutRoles == layout.savedLayoutRoles)
        #expect(result.timelineClips.map(\.sourceID) == layout.surfaces.reversed().map(\.source.id))
        #expect(result.timelineClips.allSatisfy { $0.start == 2 && $0.duration == 3 })
        #expect(result.layers.map(\.track.text.markerID) == [marker.id, marker.id] && result.regions.count == 2)
        #expect(result.palettes == [palette] && result.surfaces.allSatisfy { $0.source.primaryBinding == show.surfaces[0].source.primaryBinding })
        #expect(result.lighting.cues.count == 2 && result.lighting.cues[1].isManual)
        #expect(result.lighting.cues[0].entries.map(\.id) == [frontB.id, frontA.id])
        #expect(result.lighting.looks.first?.entries.map(\.id) == [frontB.id, frontA.id])
        #expect(result.choreographyClips.first?.targets.map(\.id) == [frontB.id, frontA.id])
    }

    @Test func savesIndependentCopyWithSourceArtAndReceivingPhoto() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: false)
        defer { try? FileManager.default.removeItem(at: directory) }
        let art = try pixel([0, 0, 255, 255])
        let photo = try pixel([255, 0, 0, 255])
        let sharedID = UUID()
        var show = MappingProject(name: "Source")
        show.surfaces[0].source.content = .image
        show.surfaces[0].source.image = ImageContent(assetID: sharedID)
        show.imageAssets = [ImageAsset(id: sharedID, name: "Show Art", width: 1, height: 1)]
        var layout = MappingProject(name: "Layout")
        layout.imageAssets = [ImageAsset(id: sharedID, name: "House Photo", width: 1, height: 1)]
        layout.referencePhoto = ReferencePhoto(assetID: sharedID)
        let store = ProjectPackageStore()
        let input = directory.appendingPathComponent("Source.projectionmap")
        let output = directory.appendingPathComponent("Copy.projectionmap")
        let doc = ProjectDocument(project: show)
        try store.write(doc, to: input, imageFiles: [sharedID: art], replaceExisting: false)
        let plan = ShowLayoutPlan(show: show, layout: layout)
        let result = try ShowLayoutCopy.create(show: doc, layout: ProjectDocument(project: layout), name: "Copy", assignments: plan.suggestions)
        try ShowLayoutCopy.write(result, source: input, reviewed: doc, photo: photo, to: output)
        #expect(throws: DeliveryError.self) { try ShowLayoutCopy.write(result, source: input, reviewed: doc, photo: photo, to: output) }
        let reopened = try store.read(output)
        let images = ImageImportService.loadAssets(reopened.project, package: output)
        let photoID = try #require(reopened.project.referencePhoto?.assetID)
        #expect(photoID != sharedID && reopened == result.document && reopened.project.surfaces[0].source.image?.assetID == sharedID)
        #expect(images.pixels[photoID]?.bytes == Data([255, 0, 0, 255]) && images.pixels[sharedID]?.bytes == Data([0, 0, 255, 255]))
        #expect(try store.read(input) == doc)
    }

    @Test func recordsAndReopensEncoreOnSecondLayout() async throws {
        let directory = try EncoreRehearsal.temporary()
        defer { try? FileManager.default.removeItem(at: directory) }
        let sourceURL = directory.appendingPathComponent("Encore Take.projectionmap")
        let copyURL = directory.appendingPathComponent("Encore on Second Layout.projectionmap")
        let store = ProjectPackageStore()
        let session = EncoreRehearsal.session()
        defer { session.releaseRuntimeResources() }

        var source = try store.read(EncoreRehearsal.fixture)
        let markerFace = MappingSurface(name: "Timing Window", color: SIMD4(0, 0, 0, 1), content: .solid)
        let controller = LightingController(name: "Timing Simulation", kind: .arduino)
        let plug = PatchedFixture(name: "Timing Plug", kind: .plug, controllerID: controller.id)
        let on = FixtureLookEntry(id: plug.id, state: .plug(true))
        let off = FixtureLookEntry(id: plug.id, state: .plug(false))
        let manual = LightingCue(name: "Timing On", time: 0, manualOnly: true, entries: [on])
        let look = FixtureLook(name: "Timing Off", entries: [off])
        let sourceFace = LayoutTargetID(domain: .face, id: markerFace.id)
        let sourceFixture = LayoutTargetID(domain: .fixture, id: plug.id)
        var flash = SourceLook(source: markerFace.source)
        flash.color = SIMD4(0, 1, 1, 1)
        let clip = EffectClip(sourceID: markerFace.source.id, start: 4.9, duration: 1.5, source: flash)
        source.project.surfaces.insert(markerFace, at: 0)
        source.project.timelineClips.append(clip)
        source.project.lighting.controllers.append(controller)
        source.project.lighting.fixtures.append(plug)
        source.project.lighting.cues.append(manual)
        source.project.lighting.looks.append(look)
        source.project.layoutRoles = [LayoutRole(name: "Timing Window", targets: [sourceFace]),
                                      LayoutRole(name: "Timing Plug", targets: [sourceFixture])]
        try store.write(source, to: sourceURL, assetsFrom: EncoreRehearsal.fixture, replaceExisting: false)
        try await EncoreRehearsal.load(sourceURL, into: session)
        session.songMuted = true
        session.switchWorkspace(to: .lighting)
        session.seekPlayback(to: 4.9)
        try await EncoreRehearsal.until(3, "seek to recording start") { abs(session.transport.position - 4.9) < 0.03 }
        try #require(session.startCueRecording())
        try await EncoreRehearsal.until(4, "soundtrack advances for recording") { session.transport.position >= 5.05 }
        session.nextManualCueID = manual.id
        try #require(session.goManualCue(), Comment(rawValue: session.cueRecordingMessage ?? "GO unavailable"))
        let first = try #require(session.recordedCues.first)
        try await EncoreRehearsal.until(3, "next trigger time") { session.transport.position >= first.time + 0.4 }
        session.triggerRecordedLook(look.id)
        try #require(session.recordedCues.count == 2)
        let second = session.recordedCues[1]
        session.setPlaying(false)
        #expect(first.time >= 5.05 && first.time < second.time && second.time < clip.end)
        try #require(session.addRecordedCues(times: [first.id: first.time, second.id: second.time]))
        try session.save(to: sourceURL)
        let reviewed = try store.read(sourceURL)

        var receiving = try PlaygroundExtraction.extract(reviewed, name: "Second Layout")
        let secondFace = MappingSurface(name: "Upstairs Window", corners: NormalizedRectangle(
            topLeft: SIMD2(0.1, 0.1), topRight: SIMD2(0.4, 0.1),
            bottomRight: SIMD2(0.4, 0.3), bottomLeft: SIMD2(0.1, 0.3)))
        let secondPlug = PatchedFixture(name: "Upstairs Plug", kind: .plug, controllerID: controller.id, address: 5)
        receiving.project.surfaces[0] = secondFace
        receiving.project.lighting.fixtures.removeAll { $0.id == plug.id }
        receiving.project.lighting.fixtures.append(secondPlug)
        let destinationFace = LayoutTargetID(domain: .face, id: secondFace.id)
        let destinationFixture = LayoutTargetID(domain: .fixture, id: secondPlug.id)
        receiving.project.layoutRoles = [LayoutRole(name: "Timing Window", targets: [destinationFace]),
                                         LayoutRole(name: "Timing Plug", targets: [destinationFixture])]
        let plan = ShowLayoutPlan(show: reviewed.project, layout: receiving.project)
        #expect(plan.suggestions[sourceFace] == [destinationFace] && plan.suggestions[sourceFixture] == [destinationFixture])
        let photo = receiving.project.referencePhoto.flatMap { session.playgroundImageFiles[$0.assetID] }
        let result = try ShowLayoutCopy.create(show: reviewed, layout: receiving, name: "Encore on Second Layout",
                                               assignments: plan.suggestions)
        try ShowLayoutCopy.write(result, source: sourceURL, reviewed: reviewed, photo: photo, to: copyURL)

        try await EncoreRehearsal.load(copyURL, into: session)
        #expect(session.project.surfaces[0].corners == secondFace.corners)
        #expect(session.project.lighting.fixtures.contains(secondPlug) && session.imageProblems.isEmpty && session.videoProblems.isEmpty)
        #expect(session.project.song == reviewed.project.song && !session.songPeaks.isEmpty)
        let copiedClip = try #require(session.project.timelineClips.first { $0.sourceID == secondFace.source.id })
        #expect(copiedClip.start == clip.start && copiedClip.duration == clip.duration)
        let copiedCues = session.project.lighting.cues.filter { $0.id == first.id || $0.id == second.id }
        #expect(copiedCues.map(\.time) == [first.time, second.time])
        #expect(copiedCues.flatMap(\.entries).map(\.id) == [secondPlug.id, secondPlug.id])

        try await EncoreRehearsal.show(session)
        session.seekPlayback(to: first.time - 0.1)
        try await EncoreRehearsal.until(3, "seek to remapped cue") { abs(session.transport.position - (first.time - 0.1)) < 0.03 }
        try #require(session.setPlaying(true))
        try await EncoreRehearsal.until(3, "remapped fixture turns on") {
            session.transport.position >= first.time && session.intendedLightingState(secondPlug) == .plug(true)
        }
        let scene = session.scene
        #expect(scene.surfaces.contains(where: { $0.sourceID == secondFace.source.id && $0.timelineClips.contains(copiedClip) }))
        #expect(copiedClip.contains(scene.transport.position))
        let renderer = try MetalRenderer(scene: scene)
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: MetalRenderer.pixelFormat,
                                                                   width: 320, height: 180, mipmapped: false)
        descriptor.usage = .renderTarget
        let texture = try #require(renderer.device.makeTexture(descriptor: descriptor))
        let pass = MTLRenderPassDescriptor()
        pass.colorAttachments[0].texture = texture
        let frame = try #require(renderer.encodeScene(to: pass, evaluationTime: scene.transport.position,
                                                      evaluationUptime: ProcessInfo.processInfo.systemUptime))
        let rendered = await withCheckedContinuation { continuation in
            frame.addCompletedHandler { continuation.resume(returning: $0.status == .completed) }
            frame.commit()
        }
        #expect(rendered)
        try await EncoreRehearsal.until(3, "remapped fixture turns off") {
            session.transport.position >= second.time && session.intendedLightingState(secondPlug) == .plug(false)
        }
        session.stopPlayback()

        if let reportPath = ProcessInfo.processInfo.environment["PROJECTION_BUILD44_REHEARSAL"] {
            let report = URL(fileURLWithPath: reportPath)
            for file in [sourceURL, copyURL] {
                try FileManager.default.copyItem(at: file, to: report.appendingPathComponent(file.lastPathComponent))
            }
            let readings = ["cueOnSeconds": first.time, "cueOffSeconds": second.time,
                            "projectionClipStartSeconds": copiedClip.start, "projectionClipEndSeconds": copiedClip.end,
                            "renderSampleSeconds": scene.transport.position]
            try JSONEncoder().encode(readings).write(to: report.appendingPathComponent("Timing.json"), options: .atomic)
        }
    }

    private func pixel(_ bgra: [UInt8]) throws -> Data {
        let pixels = ImagePixels(width: 1, height: 1, bytes: Data(bgra))
        let bytes = NSMutableData()
        let destination = try #require(CGImageDestinationCreateWithData(bytes, "public.png" as CFString, 1, nil))
        CGImageDestinationAddImage(destination, try #require(pixels.cgImage), nil)
        try #require(CGImageDestinationFinalize(destination))
        return bytes as Data
    }
}
