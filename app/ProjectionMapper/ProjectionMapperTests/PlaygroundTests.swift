import Foundation
import Testing

@MainActor
struct PlaygroundTests {
    private var encoreURL: URL {
        URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
            .deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("assets/demos/Winter Lights Encore.projectionmap")
    }
    private func temporary() throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }
    private func session() -> EditorSession {
        EditorSession(output: OutputSelectionState(preferences: OutputPreferences(defaults:
            UserDefaults(suiteName: "playgrounds.tests." + UUID().uuidString)!)))
    }
    @Test func finishedShowRetainsLayoutButClearsAllProgramming() throws {
        var original = try ProjectPackageStore().read(encoreURL)
        original.project.surfaces[0].layout.isGeometryLocked = true
        original.project.surfaces[0].appearance.flipHorizontal = true
        original.project.visualLayers?[0].track.isVisible = false
        let before = try ProjectCodec.encode(original)
        let setup = try PlaygroundExtraction.extract(original, name: "My House")
        let a = original.project, b = setup.project
        #expect(a.id != b.id)
        #expect(b.surfaces.map(\.layout) == a.surfaces.map(\.layout))
        #expect(b.surfaces.map(\.mask) == a.surfaces.map(\.mask))
        #expect(b.surfaces.map(\.appearance) == a.surfaces.map(\.appearance))
        #expect(b.objects.map(\.links) == a.objects.map(\.links))
        #expect(b.objects.map(\.mode) == a.objects.map(\.mode))
        #expect(b.layers.map(\.ownerID) == a.layers.map(\.ownerID))
        #expect(b.visualTracks.map(\.id) == a.visualTracks.map(\.id))
        #expect(b.visualTracks.map(\.center) == a.visualTracks.map(\.center))
        #expect(b.regions.map(\.shape) == a.regions.map(\.shape))
        #expect(b.lighting.fixtures == a.lighting.fixtures)
        #expect(b.lighting.controllers == a.lighting.controllers)
        #expect(b.song == nil && b.timelineClips.isEmpty && b.showMarkers.isEmpty && b.choreographyClips.isEmpty)
        #expect(b.lighting.cues.isEmpty && b.lighting.looks.isEmpty)
        #expect(b.looks.isEmpty && b.palettes.isEmpty && b.generatorPresets.isEmpty && b.videoAssets.isEmpty)
        #expect(b.visualTracks.allSatisfy { $0.kind == .media && $0.text.message.isEmpty && $0.text.markerID == nil && $0.mouthKeys.isEmpty && $0.source.color.w == 0 })
        #expect((b.surfaces.map(\.source) + b.objects.map(\.source) + b.additionalSources).allSatisfy {
            $0.content == .solid && $0.image == nil && $0.video == nil && $0.primaryBinding == nil && $0.secondaryBinding == nil && $0.generator == .defaults
        })
        #expect(setup.output == original.output)
        #expect(try ProjectCodec.encode(original) == before)
        try PlaygroundExtraction.validateSetup(setup)
    }
    @Test func blankProjectionOnlyLightingOnlyAndMixedAreSupported() throws {
        let mixed = try ProjectPackageStore().read(encoreURL)
        for type in 0..<4 {
            var source = type == 0 ? ProjectDocument(project: MappingProject()) : mixed
            if type == 1 { source.project.lighting = ProjectLighting() }
            if type == 2 {
                source.project.surfaces = []; source.project.objects = []
                source.project.visualLayers = []; source.project.faceRegions = []
                source.project.timelineClips = []; source.project.choreography = []
            }
            let setup = try PlaygroundExtraction.extract(source, name: "Setup")
            try PlaygroundExtraction.validateSetup(setup)
            #expect(setup.project.surfaces.count == source.project.surfaces.count)
            #expect(setup.project.lighting.fixtures.count == source.project.lighting.fixtures.count)
        }
    }
    @Test func rejectsProgrammingAndFutureMetadata() throws {
        let folder = try temporary(); defer { try? FileManager.default.removeItem(at: folder) }
        let library = PlaygroundLibrary(directory: folder)
        var setup = try PlaygroundExtraction.extract(ProjectDocument(project: MappingProject()), name: "House")
        setup.project.surfaces[0].source.content = .snowfall
        #expect(throws: (any Error).self) { try PlaygroundExtraction.validateSetup(setup) }
        setup = try PlaygroundExtraction.extract(setup, name: "House")
        let url = try library.save(setup, info: PlaygroundInfo(name: "House"), images: [:])
        var info = try library.read(url).info; info.schemaVersion = 99
        try JSONEncoder().encode(info).write(to: url.appendingPathComponent("playground.json"))
        #expect(throws: (any Error).self) { try library.read(url) }
    }
    @Test func libraryRenameDuplicateUpdateImportExportAndRollback() throws {
        let folder = try temporary(); defer { try? FileManager.default.removeItem(at: folder) }
        let library = PlaygroundLibrary(directory: folder.appendingPathComponent("Library"))
        let setup = try PlaygroundExtraction.extract(ProjectPackageStore().read(encoreURL), name: "House")
        let info = PlaygroundInfo(name: "House", note: "Front yard")
        let url = try library.save(setup, info: info, images: [:])
        try library.rename(url, name: "My House", note: "Winter setup")
        let copy = try library.copy(url, name: "Neighbor")
        #expect(try library.read(copy).info.id != info.id)
        #expect(try library.entries().count == 2)
        let export = folder.appendingPathComponent("House.projectionplayground")
        _ = try library.copy(url, to: export)
        let imported = try library.copy(export)
        #expect(try library.entries().count == 3)
        #expect(try library.read(imported).document.project.surfaces.map(\.layout) == setup.project.surfaces.map(\.layout))
        let before = try Data(contentsOf: url.appendingPathComponent("manifest.json"))
        let saved = try library.read(url)
        var update = saved.document; update.project.surfaces[0].name = "Changed Roof"
        #expect(throws: (any Error).self) {
            try library.save(update, info: saved.info, images: [:], to: url, beforeCommit: { _ in throw ProjectFileError.io("injected failure") })
        }
        #expect(try Data(contentsOf: url.appendingPathComponent("manifest.json")) == before)
        try library.save(update, info: saved.info, images: [:], to: url)
        #expect(try library.read(url).document.project.surfaces[0].name == "Changed Roof")
        #expect(try library.read(copy).document.project.surfaces[0].name != "Changed Roof")
        #expect(try FileManager.default.contentsOfDirectory(atPath: folder.path).allSatisfy { !$0.contains("staging") })
    }
    @Test func referencePhotoTravelsWithoutSongOrUnusedMedia() throws {
        let folder = try temporary(); defer { try? FileManager.default.removeItem(at: folder) }
        // The bundled V1 demo includes a portable reference image.
        let url = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("ProjectionMapper/Resources/V1-Demo.projectionmap")
        var original = try ProjectPackageStore().read(url)
        let image = try #require(original.project.imageAssets.first)
        original.project.referencePhoto = ReferencePhoto(assetID: image.id)
        let setup = try PlaygroundExtraction.extract(original, name: "Photo House")
        let media = ImageImportService.loadAssets(setup.project, package: url)
        let library = PlaygroundLibrary(directory: folder)
        let saved = try library.save(setup, info: PlaygroundInfo(name: "Photo House"), images: media.files)
        let entry = try library.read(saved)
        #expect(entry.images.count == 1)
        #expect(entry.document.project.referencePhoto == original.project.referencePhoto)
        #expect(try FileManager.default.contentsOfDirectory(atPath: saved.appendingPathComponent("assets").path) == [image.fileName])
        try FileManager.default.removeItem(at: saved.appendingPathComponent("assets/" + image.fileName))
        #expect(throws: (any Error).self) { try library.read(saved) }
    }
    @Test func failedCreationRetainsOriginalAndSourcePackage() async throws {
        let folder = try temporary(); defer { try? FileManager.default.removeItem(at: folder) }
        let s = session(); defer { s.releaseRuntimeResources() }
        let original = s.project
        let unavailable = folder.appendingPathComponent("not-a-directory")
        try Data([1]).write(to: unavailable)
        s.configureAutosave(directory: unavailable)
        let setup = try PlaygroundExtraction.extract(ProjectDocument(project: original), name: "New Show")
        await #expect(throws: (any Error).self) { try await s.startPlaygroundShow(setup, images: [:]) }
        #expect(s.project == original)
        #expect(s.documentURL == nil)
    }
    @Test func twoIndependentShowsAutosaveReopenAndStartPausedDark() async throws {
        let folder = try temporary(); defer { try? FileManager.default.removeItem(at: folder) }
        let previousDraft = UserDefaults.standard.string(forKey: "ProjectionMapper.lastDraft")
        defer { UserDefaults.standard.set(previousDraft, forKey: "ProjectionMapper.lastDraft") }
        let source = try ProjectPackageStore().read(encoreURL)
        let setup = try PlaygroundExtraction.extract(source, name: "First Song")
        let s = session(); s.configureAutosave(directory: folder)
        defer { s.releaseRuntimeResources() }
        s.songMuted = true; s.songVolume = 0.2
        s.setPlaying(true)
        try await s.startPlaygroundShow(setup, images: [:])
        let first = try #require(s.documentURL), firstID = s.project.id
        #expect(s.isManagedDraft && !s.hasUserChanges && !s.transport.isPlaying && s.transport.elapsed(at: ProcessInfo.processInfo.systemUptime) == 0)
        #expect(!s.songMuted && s.songVolume == 1)
        #expect(s.workspace == .edit && s.selectedSurfaceID == nil && !s.canUndo)
        #expect(s.lightingSimulation.overrides.isEmpty && s.lightingSimulation.isStopped)
        #expect(s.testOutput.window == nil && s.projectorOutput.window == nil)
        let songA = folder.appendingPathComponent("Song A.wav")
        let songB = folder.appendingPathComponent("Song B.wav")
        try writeSong(to: songA, frequency: 220)
        try writeSong(to: songB, frequency: 440)
        s.prepareSong(at: songA)
        for _ in 0..<200 where s.songBusy { try await Task.sleep(for: .milliseconds(10)) }
        let firstSong = try #require(s.project.song)
        s.renameProject("First Song Edited"); try await s.flushAutosave()
        try await s.startPlaygroundShow(PlaygroundExtraction.extract(source, name: "Second Song"), images: [:])
        #expect(s.project.id != firstID && s.documentURL != first)
        #expect(try ProjectPackageStore().read(first).project.name == "First Song Edited")
        #expect(source.project.timelineClips.count == 18)
        #expect(s.project.song == nil && s.songPeaks.isEmpty)
        s.prepareSong(at: songB)
        for _ in 0..<200 where s.songBusy { try await Task.sleep(for: .milliseconds(10)) }
        let secondSong = try #require(s.project.song)
        #expect(secondSong.id != firstSong.id && secondSong.name != firstSong.name)
        try await s.flushAutosave()
        #expect(try ProjectPackageStore().read(first).project.song == firstSong)
        let second = try #require(s.documentURL)
        try s.load(ProjectPackageStore().read(second), from: second)
        #expect(!s.transport.isPlaying && s.project.timelineClips.isEmpty && s.project.lighting.cues.isEmpty)
        #expect(s.project.song == secondSong)
        #expect(setup.project.name == "First Song")
    }
    private func writeSong(to url: URL, frequency: Double) throws {
        var data = Data()
        func text(_ value: String) { data.append(contentsOf: value.utf8) }
        func u16(_ value: UInt16) { var v = value.littleEndian; withUnsafeBytes(of: &v) { data.append(contentsOf: $0) } }
        func u32(_ value: UInt32) { var v = value.littleEndian; withUnsafeBytes(of: &v) { data.append(contentsOf: $0) } }
        let count = 24000
        text("RIFF"); u32(UInt32(36 + count * 2)); text("WAVEfmt "); u32(16)
        u16(1); u16(1); u32(24000); u32(48000); u16(2); u16(16); text("data"); u32(UInt32(count * 2))
        for i in 0..<count { u16(UInt16(bitPattern: Int16(sin(Double(i) * 2 * .pi * frequency / 24000) * 3000))) }
        try data.write(to: url)
    }

}
