import Foundation
import Testing

@MainActor
struct ProjectPersistenceTests {
    func temporary() throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString,isDirectory: true)
        try FileManager.default.createDirectory(at: url,withIntermediateDirectories: true); return url
    }
    func session() -> EditorSession {
        let defaults = UserDefaults(suiteName: "v110.tests." + UUID().uuidString)!
        return EditorSession(output: OutputSelectionState(preferences: OutputPreferences(defaults: defaults)))
    }
    func rich() throws -> EditorSession {
        let s = session(); s.renameProject("Christmas House"); s.addSurface(); s.addSurface()
        s.createObject(faceIDs: Set(s.project.surfaces.map(\.id)))
        s.setSurfaceContent(.particles); var settings = GeneratorSettings.defaults; settings.seed = 987; settings.rate = 2
        s.setGeneratorSettings(settings); s.setTags("house, snow",objectID: s.project.objects[0].id)
        _ = s.saveGeneratorPreset(name: "Snowfall")
        s.duplicateObject(s.project.objects[0].id)
        s.detachSurface(s.project.surfaces[0].id)
        return s
    }
    @Test func groupedRoundTripPreservesEveryDeclarativeValueAndRenderSnapshot() throws {
        let s = try rich(); let original = s.document
        let decoded = try ProjectCodec.decode(ProjectCodec.encode(original))
        #expect(decoded == original)
        #expect(decoded.project.renderScene == original.project.renderScene)
        #expect(decoded.project.objects.count == 2 && decoded.project.surfaces.count == 6)
        #expect(decoded.project.generatorPresets.count == 1)
    }
    @Test func initialSchemaMigrationAddsDefaultsAndRejectsNewerAndCorruptData() throws {
        var json = try #require(JSONSerialization.jsonObject(with: ProjectCodec.encode(ProjectDocument(project: MappingProject()))) as? [String:Any])
        json["formatVersion"] = 1; json.removeValue(forKey: "output")
        var project = try #require(json["project"] as? [String:Any]); project.removeValue(forKey: "generatorPresets"); json["project"] = project
        let migrated = try ProjectCodec.decode(JSONSerialization.data(withJSONObject: json))
        #expect(migrated.formatVersion == ProjectDocument.currentVersion && migrated.project.generatorPresets.isEmpty && migrated.output.resolution == .hd)
        json["formatVersion"] = 999
        #expect(throws: ProjectFileError.self) { try ProjectCodec.decode(JSONSerialization.data(withJSONObject: json)) }
        #expect(throws: ProjectFileError.self) { try ProjectCodec.decode(Data("{bad".utf8)) }
    }
    @Test func invalidReferencesMapsColorsAndDuplicateOwnersAreRejected() throws {
        let original = try rich().document
        var bad = original; bad.project.surfaces[0].layout.objectID = UUID()
        #expect(throws: ProjectFileError.self) { try ProjectCodec.validate(bad) }
        bad = original; bad.project.surfaces[0].layout.inputMap.size.x = -1
        #expect(throws: ProjectFileError.self) { try ProjectCodec.validate(bad) }
        bad = original; bad.project.objects[0].source.color.x = .nan
        #expect(throws: ProjectFileError.self) { try ProjectCodec.validate(bad) }
        bad = original; bad.project.objects[0].links[0].secondFace = UUID()
        #expect(throws: ProjectFileError.self) { try ProjectCodec.validate(bad) }
        bad = original; bad.project.surfaces[1].source.id = bad.project.surfaces[0].source.id
        #expect(throws: ProjectFileError.self) { try ProjectCodec.validate(bad) }
    }
    @Test func editableCrossedGeometryIsRetainedButUnboundedCoordinatesAreRejected() throws {
        var doc = ProjectDocument(project: MappingProject())
        doc.project.surfaces[0].corners = NormalizedRectangle(topLeft: SIMD2(0,0),topRight: SIMD2(0,1),bottomRight: SIMD2(1,1),bottomLeft: SIMD2(0,1))
        #expect(try ProjectCodec.decode(ProjectCodec.encode(doc)) == doc)
        doc.project.surfaces[0].corners = NormalizedRectangle(topLeft: SIMD2(4,0),topRight: SIMD2(1,0),bottomRight: SIMD2(1,1),bottomLeft: SIMD2(0,1))
        #expect(throws: ProjectFileError.self) { try ProjectCodec.validate(doc) }
    }
    @Test func atomicReplacementFailureRetainsLastGoodPackageAndCleansStaging() throws {
        let dir = try temporary(); defer { try? FileManager.default.removeItem(at: dir) }
        let url = dir.appendingPathComponent("House.projectionmap"); let store = ProjectPackageStore()
        let old = ProjectDocument(project: MappingProject()); try store.write(old,to: url)
        var new = old; new.project.name = "Changed"
        store.beforeCommit = { _ in throw ProjectFileError.io("simulated disk failure") }
        #expect(throws: ProjectFileError.self) { try store.write(new,to: url) }
        #expect(try store.read(url) == old)
        #expect(try FileManager.default.contentsOfDirectory(atPath: dir.path) == [url.lastPathComponent])
        store.beforeCommit = nil; try store.write(new,to: url)
        #expect(try store.read(url) == new)
    }
    @Test func saveAsPreservesAssetsStableIDsAndOriginalPackage() throws {
        let dir = try temporary(); defer { try? FileManager.default.removeItem(at: dir) }
        let a = dir.appendingPathComponent("A.projectionmap"), b = dir.appendingPathComponent("B.projectionmap")
        let s = try rich(); try s.save(to: a)
        let bytes = Data([1,2,3,4]); try bytes.write(to: a.appendingPathComponent("assets/fixture.bin"))
        s.renameProject("Copy"); try s.save(to: b)
        #expect(s.documentURL == b && !s.hasUserChanges)
        #expect(try Data(contentsOf: b.appendingPathComponent("assets/fixture.bin")) == bytes)
        #expect(try ProjectPackageStore().read(a).project.name == "Christmas House")
        #expect(try ProjectPackageStore().read(b).project.id == s.project.id)
    }
    @Test func failedSaveDoesNotUpdateBaselineOrURLAndEditingBackIsClean() throws {
        let dir = try temporary(); defer { try? FileManager.default.removeItem(at: dir) }
        let s = session(); s.renameProject("Changed")
        let store = ProjectPackageStore(); store.beforeCommit = { _ in throw ProjectFileError.io("full") }
        #expect(throws: ProjectFileError.self) { try s.save(to: dir.appendingPathComponent("A.projectionmap"),store: store) }
        #expect(s.documentURL == nil && s.hasUserChanges)
        s.renameProject(MappingProject.defaultName); #expect(!s.hasUserChanges)
        s.setPlaying(true,at: 10); s.seekPlayback(to: 5,at: 10); s.setSelectedPaused(true,at: 10)
        #expect(!s.hasUserChanges)
    }
    @Test func openingResetsClocksStartsPausedAndInvalidLoadLeavesSessionIntact() throws {
        let s = try rich(); s.setPlaying(true,at: 10); s.seekPlayback(to: 8,at: 10); s.setSelectedPaused(true,at: 10)
        var doc = s.document; doc.output.resolution = .fullHD
        try s.load(doc,from: URL(fileURLWithPath: "/tmp/example.projectionmap"))
        #expect(!s.transport.isPlaying && s.transport.elapsed(at: 100) == 0 && s.sourcePlayback.isEmpty)
        #expect(s.output.testResolution == .fullHD && !s.hasUserChanges)
        let project = s.project; doc.project.surfaces[0].layout.objectID = UUID()
        #expect(throws: ProjectFileError.self) { try s.load(doc,from: URL(fileURLWithPath: "/tmp/bad.projectionmap")) }
        #expect(s.project == project && !s.hasUserChanges)
    }
    @Test func recoveryForUntitledRestoresDirtyPausedAndSuccessfulSaveClearsCopy() throws {
        let dir = try temporary(); defer { try? FileManager.default.removeItem(at: dir) }
        let store = ProjectRecoveryStore(directory: dir.appendingPathComponent("recovery"))
        let s = try rich(); s.configureRecovery(store); try s.flushRecovery()
        let entry = try #require(store.entries().first); #expect(entry.document.recovery?.originalPath == nil)
        let restored = session(); restored.configureRecovery(store)
        try restored.load(entry.document,from: entry.url,recovering: true)
        #expect(restored.hasUserChanges && restored.documentURL == nil && !restored.transport.isPlaying)
        try restored.save(to: dir.appendingPathComponent("Restored.projectionmap"))
        #expect(!restored.hasUserChanges && store.entries().isEmpty)
        s.clearRecovery()
    }
    @Test func repeatedRecoveryRetainsAssetsAndOriginalSavedBaseline() throws {
        let dir = try temporary(); defer { try? FileManager.default.removeItem(at: dir) }
        let recovery = ProjectRecoveryStore(directory: dir.appendingPathComponent("recovery"))
        let url = dir.appendingPathComponent("House.projectionmap"), s = try rich()
        try s.save(to: url); let bytes = Data([8,9]); try bytes.write(to: url.appendingPathComponent("assets/a.bin"))
        s.configureRecovery(recovery); s.renameProject("Unsaved"); try s.flushRecovery()
        let entry = try #require(recovery.entries().first)
        try s.load(entry.document,from: entry.url,recovering: true); try s.flushRecovery()
        #expect(s.documentURL?.path == url.path && s.hasUserChanges)
        #expect(try Data(contentsOf: entry.url.appendingPathComponent("assets/a.bin")) == bytes)
        s.clearRecovery(); #expect(recovery.entries().isEmpty)
    }
    @Test func recoveryRetentionIsBoundedAndMalformedEntriesAreIgnored() throws {
        let dir = try temporary(); defer { try? FileManager.default.removeItem(at: dir) }
        let recovery = ProjectRecoveryStore(directory: dir)
        for i in 0..<12 { var p = MappingProject(); p.name = "Project \(i)"; try recovery.save(ProjectDocument(project: p),original: nil) }
        #expect(recovery.entries().count == 10)
        let broken = dir.appendingPathComponent("broken.projectionmap"); try FileManager.default.createDirectory(at: broken,withIntermediateDirectories: false)
        #expect(recovery.entries().count == 10)
    }
    @Test func saveDiscardCancelContinuationRequiresSuccessfulSave() {
        #expect(!ProjectCloseChoice.save.canProceed(saveSucceeded: false))
        #expect(ProjectCloseChoice.save.canProceed(saveSucceeded: true))
        #expect(ProjectCloseChoice.discard.canProceed(saveSucceeded: false))
        #expect(!ProjectCloseChoice.cancel.canProceed(saveSucceeded: true))
    }
    @Test func debouncedRecoveryCoalescesEditsAndResetCancelsPendingWrites() async throws {
        let dir = try temporary(); defer { try? FileManager.default.removeItem(at: dir) }
        let store = ProjectRecoveryStore(directory: dir), s = session()
        s.configureRecovery(store); s.renameProject("First"); s.renameProject("Final")
        #expect(store.entries().isEmpty)
        for _ in 0..<80 { if !store.entries().isEmpty { break }; try await Task.sleep(for: .milliseconds(100)) }
        #expect(store.entries().count == 1 && store.entries().first?.document.project.name == "Final")
        s.renameProject("Cancelled"); s.resetProject()
        try await Task.sleep(for: .milliseconds(2400))
        #expect(store.entries().isEmpty && !s.hasUserChanges)
    }
    @Test func missingPhysicalDisplayPreferenceFallsBackToTestWindow() throws {
        let s = session(); var doc = s.document
        doc.output.destination = SavedOutputPreference(displayUUID: "missing-screen",displayName: "Projector")
        try s.load(doc,from: URL(fileURLWithPath: "/tmp/display.projectionmap"))
        #expect(s.output.destination == .testWindow)
        #expect(s.output.recoveryMessage != nil)
    }

    @Test func packageRejectsSymlinkManifestsAndAssetsAndPreservesUnrelatedFolders() throws {
        let dir = try temporary(); defer { try? FileManager.default.removeItem(at: dir) }
        let store = ProjectPackageStore(), doc = ProjectDocument(project: MappingProject())
        let url = dir.appendingPathComponent("A.projectionmap"); try store.write(doc,to: url)
        let outside = dir.appendingPathComponent("outside.json"); try ProjectCodec.encode(doc).write(to: outside)
        try FileManager.default.removeItem(at: url.appendingPathComponent("manifest.json"))
        try FileManager.default.createSymbolicLink(at: url.appendingPathComponent("manifest.json"),withDestinationURL: outside)
        #expect(throws: ProjectFileError.self) { try store.read(url) }
        let b = dir.appendingPathComponent("B.projectionmap"); try store.write(doc,to: b)
        try FileManager.default.createSymbolicLink(at: b.appendingPathComponent("assets/link"),withDestinationURL: outside)
        #expect(throws: ProjectFileError.self) { try store.write(doc,to: dir.appendingPathComponent("Copy.projectionmap"),assetsFrom: b) }
        let unrelated = dir.appendingPathComponent("Unrelated.projectionmap")
        try FileManager.default.createDirectory(at: unrelated,withIntermediateDirectories: false)
        let marker = unrelated.appendingPathComponent("keep.txt"); try Data([3]).write(to: marker)
        #expect(throws: (any Error).self) { try store.write(doc,to: unrelated) }
        #expect(try Data(contentsOf: marker) == Data([3]))
    }
    @Test func failedManualSaveKeepsRecoveryAvailable() throws {
        let dir = try temporary(); defer { try? FileManager.default.removeItem(at: dir) }
        let recovery = ProjectRecoveryStore(directory: dir.appendingPathComponent("recovery")), s = try rich()
        s.configureRecovery(recovery); try s.flushRecovery()
        let store = ProjectPackageStore(); store.beforeCommit = { _ in throw ProjectFileError.io("write failed") }
        #expect(throws: ProjectFileError.self) { try s.save(to: dir.appendingPathComponent("New.projectionmap"),store: store) }
        #expect(s.hasUserChanges && s.documentURL == nil && recovery.entries().count == 1)
        s.clearRecovery()
    }

}

@MainActor
struct LightingTests {
    private let dmx = LightingController(name: "DMX", kind: .dmx)
    private let arduino = LightingController(name: "Arduino", kind: .arduino)
    private var setup: (ProjectLighting, PatchedFixture, PatchedFixture) {
        let head = PatchedFixture(name: "Head", kind: .movingHead, controllerID: dmx.id)
        let strip = PatchedFixture(name: "Roof", kind: .rgb, controllerID: arduino.id)
        return (ProjectLighting(controllers: [dmx, arduino], fixtures: [head, strip]), head, strip)
    }

    @Test func patchValidationUsesFullFootprintsAndDistinctRelayOutputs() {
        var (lighting, head, strip) = setup
        var second = PatchedFixture(name: "Second", kind: .movingHead, controllerID: dmx.id, address: 9)
        lighting.fixtures.append(second)
        #expect(lighting.validationIssue() != nil)
        second.address = 502
        second.headChannels = 11
        lighting.fixtures[2] = second
        #expect(lighting.validationIssue() == nil)
        lighting.fixtures[2].address += 1
        #expect(lighting.validationIssue() != nil)
        lighting.fixtures.removeLast()
        strip.blue = strip.green
        lighting.fixtures[1] = strip
        #expect(lighting.validationIssue() != nil)
        lighting.fixtures[1].blue = 9
        #expect(lighting.validationIssue() != nil)
        lighting.fixtures[1].blue = 3
        head.controllerID = arduino.id
        lighting.fixtures[0] = head
        #expect(lighting.validationIssue() != nil)
    }

    @Test func evaluationReconstructsStateAcrossSeekAndWrap() {
        let (_, head, strip) = setup
        let warm = HeadLook(pan: 0.2, tilt: 0.3, dimmer: 0.7, color: 1, gobo: 2)
        let cool = HeadLook(pan: 0.8, tilt: 0.9, dimmer: 0.4, color: 3, gobo: 4)
        let first = LightingCue(name: "Warm", time: 4, lead: 2, entries: [.init(id: head.id, state: .head(warm))])
        let second = LightingCue(name: "Cool", time: 10, lead: 3,
                                 entries: [.init(id: head.id, state: .head(cool)), .init(id: strip.id, state: .rgb(.cyan))])
        let schedule = LightingSchedule(cues: [second, first])
        var leading = warm
        leading.pan = cool.pan
        leading.tilt = cool.tilt
        #expect(schedule.state(for: head, at: 1.99) == head.kind.dark)
        #expect(schedule.state(for: head, at: 2) == .head(HeadLook(pan: 0.2, tilt: 0.3)))
        #expect(schedule.state(for: head, at: 4) == .head(warm))
        #expect(schedule.state(for: head, at: 7) == .head(leading))
        #expect(schedule.state(for: strip, at: 9.99) == .rgb(.off))
        #expect(schedule.state(for: head, at: 10) == .head(cool))
        #expect(schedule.state(for: strip, at: 40) == .rgb(.cyan))
        #expect(schedule.state(for: strip, at: 0) == .rgb(.off))
        #expect(schedule.state(for: head, at: 5) == .head(warm))
    }

    @Test func saveMigratesAndRoundTripsWithoutRuntimeState() throws {
        var (lighting, head, strip) = setup
        let look = FixtureLook(name: "Holiday", entries: [.init(id: head.id, state: .head(HeadLook(dimmer: 1))),
                                                           .init(id: strip.id, state: .rgb(.white))])
        let placement = FixturePreviewPlacement(
            origin: FixturePreviewPoint(x: 0.2, y: 0.3),
            stripEnd: FixturePreviewPoint(x: 0.8, y: 0.35)
        )
        lighting.fixtures[1].previewPlacement = placement
        lighting.looks = [look]
        lighting.cues = [LightingCue(name: look.name, time: 8, entries: look.entries)]
        var project = MappingProject(name: "Holiday House")
        project.lighting = lighting
        let document = ProjectDocument(project: project)
        let encoded = try ProjectCodec.encode(document)
        #expect(try ProjectCodec.decode(encoded) == document)
        var invalid = document
        invalid.project.lighting.fixtures[1].previewPlacement?.origin.x = 2
        #expect(throws: ProjectFileError.self) { try ProjectCodec.encode(invalid) }
        var earlierFormat10 = try #require(JSONSerialization.jsonObject(with: encoded) as? [String: Any])
        var earlierProject = try #require(earlierFormat10["project"] as? [String: Any])
        var earlierLighting = try #require(earlierProject["lighting"] as? [String: Any])
        var earlierFixtures = try #require(earlierLighting["fixtures"] as? [[String: Any]])
        earlierFixtures[1]["previewPlacement"] = nil
        earlierLighting["fixtures"] = earlierFixtures
        earlierProject["lighting"] = earlierLighting
        earlierFormat10["project"] = earlierProject
        let earlier = try ProjectCodec.decode(JSONSerialization.data(withJSONObject: earlierFormat10))
        #expect(earlier.project.lighting.fixtures[1].previewPlacement == nil)
        #expect(earlier.project.lighting.cues == document.project.lighting.cues)
        var old = try #require(JSONSerialization.jsonObject(with: encoded) as? [String: Any])
        var oldProject = try #require(old["project"] as? [String: Any])
        oldProject["lighting"] = nil
        old["project"] = oldProject
        old["formatVersion"] = 9
        let migrated = try ProjectCodec.decode(JSONSerialization.data(withJSONObject: old))
        project.lighting = ProjectLighting()
        #expect(migrated.project == project)
    }

    @Test func simulationIsolatesFailuresAndHonorsBlackoutStopAndOverrides() throws {
        var (lighting, head, strip) = setup
        lighting.cues = [LightingCue(name: "On", time: 1,
                                     entries: [.init(id: head.id, state: .head(HeadLook(dimmer: 1))),
                                               .init(id: strip.id, state: .rgb(.yellow))])]
        let simulation = LightingSimulation()
        simulation.resume()
        simulation.update(lighting, at: 1)
        #expect(simulation.reports[arduino.id]?.fixtures.first?.relayValues == [true, true, false])
        let first = try #require(simulation.reports[arduino.id]?.history.last)
        simulation.update(lighting, at: 2)
        #expect(simulation.reports[arduino.id]?.history.last == first)
        simulation.setFailure(true, for: dmx.id)
        simulation.override(.rgb(.cyan), for: strip)
        simulation.update(lighting, at: 3)
        #expect(simulation.reports[dmx.id]?.status == .failed)
        #expect(simulation.reports[arduino.id]?.fixtures.first?.relayValues == [false, true, true])
        simulation.blackout = true
        simulation.update(lighting, at: 3)
        #expect(simulation.reports[arduino.id]?.fixtures.first?.intended == .rgb(.cyan))
        #expect(simulation.reports[arduino.id]?.fixtures.first?.effective == .rgb(.off))
        simulation.stop()
        simulation.blackout = false
        simulation.override(.rgb(.red), for: strip)
        simulation.update(lighting, at: 4)
        #expect(simulation.overrides.isEmpty)
        #expect(simulation.reports[arduino.id]?.fixtures.first?.effective == .rgb(.off))
        simulation.resume()
        simulation.update(lighting, at: 4)
        #expect(simulation.reports[arduino.id]?.fixtures.first?.effective == .rgb(.yellow))
        simulation.setFailure(false, for: dmx.id)
        simulation.setFailure(true, for: arduino.id)
        simulation.update(lighting, at: 5)
        #expect(simulation.reports[dmx.id]?.status == .sent)
        #expect(simulation.reports[arduino.id]?.status == .failed)
        lighting.controllers[1].profile = .unsupported
        simulation.update(lighting, at: 6)
        #expect(simulation.reports[arduino.id]?.status == .unsupported)
    }

    @Test func sessionEditsAreAtomicAndUndoRestoresCueReferences() {
        var (lighting, _, strip) = setup
        let cue = LightingCue(name: "Roof", time: 3, entries: [.init(id: strip.id, state: .rgb(.red))])
        lighting.cues = [cue]
        let session = ProjectPersistenceTests().session()
        defer { session.releaseRuntimeResources() }
        #expect(session.editLighting { $0 = lighting })
        #expect(!session.editLighting { $0.cues.append(LightingCue(name: "Conflict", time: 3, entries: cue.entries)) })
        #expect(session.project.lighting == lighting)
        #expect(session.editLighting { $0.removeFixture(strip.id) })
        #expect(session.project.lighting.cues.isEmpty)
        session.undoProjectEdit()
        #expect(session.project.lighting == lighting)
        session.setPlaying(true, at: 30)
        session.seekPlayback(to: 3, at: 30)
        session.setPlaying(false, at: 30)
        #expect(session.lightingSimulation.reports[arduino.id]?.fixtures.first?.effective == .rgb(.red))
        session.selectLightingCue(cue.id)
        session.performEditorAction(.duplicate, at: 30)
        #expect(session.project.lighting.cues.count == 1)
        session.seekPlayback(to: 6, at: 30)
        session.performEditorAction(.duplicate, at: 30)
        #expect(session.project.lighting.cues.map(\.time) == [3, 6])
        session.performEditorAction(.delete, at: 30)
        #expect(session.project.lighting.cues == [cue])
        #expect(session.project.surfaces.count == 1)
        session.stopPlayback(at: 30)
        session.seekPlayback(to: 3, at: 30)
        #expect(session.lightingSimulation.reports[arduino.id]?.fixtures.first?.effective == .rgb(.off))
        session.setPlaying(true, at: 30)
        #expect(session.lightingSimulation.reports[arduino.id]?.fixtures.first?.effective == .rgb(.red))
    }
}

@MainActor
struct SongTransportTests {
    private func writeReferenceSong(to url: URL) throws {
        let rate: UInt32 = 8000
        let samples = Int(rate) * 3
        var data = Data()
        func append<T: FixedWidthInteger>(_ number: T) {
            var value = number.littleEndian
            withUnsafeBytes(of: &value) { data.append(contentsOf: $0) }
        }
        data.append(contentsOf: "RIFF".utf8)
        append(UInt32(36 + samples * 2))
        data.append(contentsOf: "WAVEfmt ".utf8)
        append(UInt32(16)); append(UInt16(1)); append(UInt16(1))
        append(rate); append(rate * 2); append(UInt16(2)); append(UInt16(16))
        data.append(contentsOf: "data".utf8)
        append(UInt32(samples * 2))
        for sample in 0..<samples {
            append(Int16(sample % Int(rate) < 40 ? 16000 : 0))
        }
        try data.write(to: url)
    }

    @Test func importsWaveformAndSavesPortableSoundtrack() async throws {
        let directory = try ProjectPersistenceTests().temporary()
        defer { try? FileManager.default.removeItem(at: directory) }
        let source = directory.appendingPathComponent("Click.wav")
        try writeReferenceSong(to: source)
        let prepared = try PreparedSong.read(source)
        #expect(prepared.song.duration == 3)
        #expect(prepared.peaks.count == 2048)
        #expect(prepared.peaks.contains { $0 > 0.45 })
        #expect(prepared.peaks.contains(0))
        let session = ProjectPersistenceTests().session()
        defer { session.releaseRuntimeResources() }
        session.prepareSong(at: source)
        for _ in 0..<200 where session.songBusy { try await Task.sleep(for: .milliseconds(10)) }
        let song = try #require(session.project.song)
        session.setSongLoop(SongLoop(start: 1, end: 2))
        let package = directory.appendingPathComponent("Show.projectionmap")
        try session.save(to: package)
        try FileManager.default.removeItem(at: source)
        let reopened = ProjectPersistenceTests().session()
        defer { reopened.releaseRuntimeResources() }
        try reopened.load(ProjectPackageStore().read(package), from: package)
        for _ in 0..<200 where reopened.songBusy { try await Task.sleep(for: .milliseconds(10)) }
        #expect(reopened.project.song?.id == song.id)
        #expect(reopened.project.song?.loop == SongLoop(start: 1, end: 2))
        #expect(reopened.songPeaks == prepared.peaks)
        #expect(!reopened.transport.isPlaying)
        reopened.seekPlayback(to: 1.5)
        for _ in 0..<200 where abs(reopened.transport.position - 1.5) > 0.01 {
            try await Task.sleep(for: .milliseconds(10))
        }
        #expect(abs(reopened.transport.position - 1.5) < 0.01)
        #expect(reopened.scene.transport.elapsed(at: 500) == reopened.transport.position)
        reopened.removeSong()
        #expect(reopened.project.song == nil)
        reopened.undoProjectEdit()
        #expect(reopened.project.song?.id == song.id)
        #expect(reopened.songPeaks == prepared.peaks)
    }

    @Test func mutedSongDrivesFixtureAndProjectionThroughLoopAndStop() async throws {
        let directory = try ProjectPersistenceTests().temporary()
        defer { try? FileManager.default.removeItem(at: directory) }
        let source = directory.appendingPathComponent("Loop.wav")
        try writeReferenceSong(to: source)
        let session = ProjectPersistenceTests().session()
        defer { session.releaseRuntimeResources() }
        let controller = LightingController(name: "Arduino", kind: .arduino)
        let fixture = PatchedFixture(name: "Plug", kind: .plug, controllerID: controller.id)
        session.editLighting {
            $0.controllers = [controller]
            $0.fixtures = [fixture]
            $0.cues = [LightingCue(name: "Click", time: 1, entries: [.init(id: fixture.id, state: .plug(true))])]
        }
        session.prepareSong(at: source)
        for _ in 0..<200 where session.songBusy { try await Task.sleep(for: .milliseconds(10)) }
        _ = try #require(session.project.song)
        session.setSongLoop(SongLoop(start: 0.5, end: 1.5))
        session.songMuted = true
        session.setPlaying(true)
        var sawCue = false
        var wraps = 0
        var previous = 0.0
        for _ in 0..<450 {
            try await Task.sleep(for: .milliseconds(10))
            let time = session.transport.position
            guard session.transport.isPlaying else { continue }
            let state = session.lightingSimulation.reports[controller.id]?.fixtures.first?.effective
            #expect(session.scene.transport.position == time)
            #expect(state == .plug(time >= 1))
            if state == .plug(true) { sawCue = true }
            if previous > 1.3 && time < 0.9 { wraps += 1 }
            previous = time
            if wraps >= 2 { break }
        }
        #expect(sawCue)
        #expect(wraps >= 2)
        session.stopPlayback()
        for _ in 0..<200 where session.transport.position != 0 { try await Task.sleep(for: .milliseconds(10)) }
        #expect(!session.transport.isPlaying && session.transport.position == 0)
        #expect(session.lightingSimulation.reports[controller.id]?.fixtures.first?.effective == .plug(false))
    }

    @Test func projectorCompensationClampsWithinSongAndCurrentLoop() {
        let song = ShowSong(name: "Loop", fileExtension: "wav", byteCount: 10, duration: 3,
                            loop: SongLoop(start: 1, end: 2))
        #expect(abs(song.projectionPosition(at: 1.2, compensationMilliseconds: 100) - 1.3) < 0.00001)
        #expect(song.projectionPosition(at: 1.1, compensationMilliseconds: -500) == 1)
        #expect(song.projectionPosition(at: 1.9, compensationMilliseconds: 500) < 2)
        #expect(song.projectionPosition(at: 2.9, compensationMilliseconds: 500) == 3)
    }

    @Test func migrationAndClockPreserveOldProjectsAndHoldSampledPosition() throws {
        let document = ProjectDocument(project: MappingProject(name: "Old"))
        var json = try #require(JSONSerialization.jsonObject(with: ProjectCodec.encode(document)) as? [String: Any])
        json["formatVersion"] = 10
        let migrated = try ProjectCodec.decode(JSONSerialization.data(withJSONObject: json))
        #expect(migrated == document)
        var transport = AnimationTransport()
        transport.sampleSong(2, playing: true)
        #expect(transport.elapsed(at: 1000) == 2)
        transport.sampleSong(1, playing: false)
        #expect(transport.elapsed(at: 2000) == 1)
        #expect(!SongLoop(start: 2, end: 1).isValid(for: 3))
    }
}

@MainActor
struct TimelineCueMilestoneTests {
    private let controller = LightingController(name: "DMX", kind: .dmx)

    @Test func motionAndDimmerReachTheCueWhileColorAndRelaysSnap() throws {
        let head = PatchedFixture(name: "Head", kind: .movingHead, controllerID: controller.id)
        let plug = PatchedFixture(name: "Plug", kind: .plug, controllerID: UUID())
        let first = LightingCue(name: "First", time: 0, entries: [
            .init(id: head.id, state: .head(HeadLook(pan: 0.25, tilt: 0.25, dimmer: 0.2))),
            .init(id: plug.id, state: .plug(false))
        ])
        var second = LightingCue(name: "Second", time: 5, lead: 1, motionCurve: .linear, dimmerFade: 1,
                                 entries: [
                                    .init(id: head.id, state: .head(HeadLook(pan: 0.75, tilt: 0.75, dimmer: 0.8, color: 3, gobo: 2))),
                                    .init(id: plug.id, state: .plug(true))
                                 ])
        let linear = LightingSchedule(cues: [first, second])
        #expect(linear.state(for: head, at: 4) == first.entries[0].state)
        #expect(linear.state(for: head, at: 4.5) == .head(HeadLook(pan: 0.5, tilt: 0.5, dimmer: 0.5)))
        #expect(linear.state(for: plug, at: 4.999) == .plug(false))
        #expect(linear.state(for: head, at: 5) == second.entries[0].state)
        #expect(linear.state(for: plug, at: 5) == .plug(true))
        #expect(linear.state(for: head, at: 4.5) == .head(HeadLook(pan: 0.5, tilt: 0.5, dimmer: 0.5)))
        second.motionCurve = .eased
        let eased = LightingSchedule(cues: [first, second])
        guard case .head(let position) = eased.state(for: head, at: 4.25) else { Issue.record("Missing head"); return }
        #expect(position.pan == 0.328125)
        second.motionCurve = nil
        second.dimmerFade = nil
        guard case .head(let legacy) = LightingSchedule(cues: [first, second]).state(for: head, at: 4) else {
            Issue.record("Missing head")
            return
        }
        #expect(legacy.pan == 0.75 && legacy.dimmer == 0.2)
    }

    @Test func markerImportAndManualCueSurviveSaveAndUndo() throws {
        let head = PatchedFixture(name: "Head", kind: .movingHead, controllerID: controller.id)
        let session = ProjectPersistenceTests().session()
        defer { session.releaseRuntimeResources() }
        let timed = LightingCue(name: "Timed", time: 0, entries: [
            .init(id: head.id, state: .head(HeadLook(pan: 0.25, dimmer: 0.5)))
        ])
        let manual = LightingCue(name: "Manual", time: 0, lead: 2, motionCurve: .linear, dimmerFade: 2, manualOnly: true,
                                 entries: [.init(id: head.id, state: .head(HeadLook(pan: 0.75, dimmer: 1)))])
        #expect(session.editLighting {
            $0.controllers = [controller]
            $0.fixtures = [head]
            $0.cues = [timed, manual]
        })
        let markers = try ShowMarker.importRows("0\tsection\tIntro\n1.25\tbeat\tBeat 2\n2\tlyric\tHello")
        session.setShowMarkers(markers)
        #expect(try ProjectCodec.decode(ProjectCodec.encode(session.document)) == session.document)
        #expect(throws: ProjectFileError.self) { try ShowMarker.importRows("NaN\tbeat\tInvalid") }
        #expect(ShowMarker.suggestedBeats(peaks: [0, 0.8, 0, 0.7, 0], duration: 2).count == 2)
        session.undoProjectEdit()
        #expect(session.project.showMarkers.isEmpty)
        session.redoProjectEdit()
        #expect(session.project.showMarkers == markers)

        session.lightingSimulation.resume()
        session.refreshLighting(at: 10)
        session.nextManualCueID = manual.id
        session.goManualCue(at: 10)
        session.refreshLighting(at: 11)
        #expect(session.lightingSimulation.reports[controller.id]?.fixtures.first?.effective ==
                .head(HeadLook(pan: 0.5, dimmer: 0.75)))
        session.lightingSimulation.blackout = true
        session.refreshLighting(at: 11)
        #expect(session.lightingSimulation.reports[controller.id]?.fixtures.first?.effective ==
                .head(HeadLook(pan: 0.5)))
        session.lightingSimulation.blackout = false
        session.seekPlayback(to: 0, at: 11)
        #expect(session.lastManualCueID == nil)
        #expect(session.lightingSimulation.reports[controller.id]?.fixtures.first?.effective == timed.entries[0].state)
    }

    @Test func priorSoundtrackProjectsMigrateWithoutMarkersOrCurveChanges() throws {
        var project = MappingProject(name: "Format 11 Show")
        project.song = ShowSong(name: "Click", fileExtension: "wav", byteCount: 10, duration: 5)
        let document = ProjectDocument(project: project)
        var json = try #require(JSONSerialization.jsonObject(with: ProjectCodec.encode(document)) as? [String: Any])
        json["formatVersion"] = 11
        #expect(try ProjectCodec.decode(JSONSerialization.data(withJSONObject: json)) == document)
    }
}


@MainActor
struct WorkspaceTests {
    @Test func nextCueAccountsForLoopWrapAndIgnoresManualOnlyCues() {
        let cues = [
            LightingCue(name: "Before loop", time: 1, entries: []),
            LightingCue(name: "Loop start", time: 3, entries: []),
            LightingCue(name: "Manual", time: 4, manualOnly: true, entries: []),
            LightingCue(name: "Finale", time: 5, entries: []),
            LightingCue(name: "Exclusive end", time: 7, entries: [])
        ]
        let loop = SongLoop(start: 3, end: 7)
        let upcoming = ShowCuePreview.upcoming(cues, at: 4.5, loop: loop, songEnd: 10)
        #expect(upcoming.map { $0.cue.name } == ["Finale", "Loop start"])
        #expect(upcoming.map(\.delay) == [0.5, 2.5])
        #expect(upcoming.map(\.afterWrap) == [false, true])
        let wrapped = ShowCuePreview.upcoming(cues, at: 6, loop: loop, songEnd: 10)
        #expect(wrapped.first?.cue.name == "Loop start" && wrapped.first?.afterWrap == true)
        #expect(ShowCuePreview.upcoming(cues, at: 6, loop: nil, songEnd: 6.5).isEmpty)
    }

    @Test func showKeepsTransportAndProjectAndBlocksEditingShortcuts() async {
        let session = ProjectPersistenceTests().session()
        defer { session.releaseRuntimeResources() }
        session.renameProject("Rehearsal")
        session.seekPlayback(to: 4.5, at: 10)
        session.timelineScale = 60
        session.timelineSnap = false
        let project = session.project
        let transport = session.transport
        session.switchWorkspace(to: .show)
        #expect(session.workspace == .show && session.transport == transport)
        #expect(session.project == project)
        #expect(!session.canUndo && !session.canPerformEditorAction(.delete))
        session.performEditorAction(.addSurface, at: 10)
        session.undoProjectEdit()
        #expect(session.project == project)
        #expect(!session.canPerformEditorAction(.playPause))
        await session.prepareShow()
        #expect(session.showArmState == .armed && session.canPerformEditorAction(.playPause))
        session.performEditorAction(.playPause, at: 10)
        #expect(session.transport.elapsed(at: 11) == 5.5)
        #expect(session.needsPauseToEdit)
        session.switchWorkspace(to: .edit, at: 11)
        #expect(session.workspace == .show && session.transport.isPlaying)
        session.switchWorkspace(to: .edit, pauseRunningShow: true, at: 11)
        #expect(session.workspace == .edit && !session.transport.isPlaying)
        #expect(session.transport.elapsed(at: 99) == 5.5)
        #expect(session.canUndo && session.timelineScale == 60 && !session.timelineSnap)
        #expect(session.project == project)
    }
    @Test func showStopsAtTimelineEndWithProjectionBlackout() async throws {
        let session = ProjectPersistenceTests().session()
        defer { session.releaseRuntimeResources() }
        let owner = try #require(session.project.timelineTracks.first?.id)
        _ = try #require(session.addTimelineClip(sourceID: owner, at: 0, duration: 2))
        session.switchWorkspace(to: .show, at: 100)
        await session.prepareShow()
        #expect(session.setPlaying(true, at: 100))
        session.inspectArmedShow(at: 103)
        #expect(!session.playbackRequested && session.transport.position == 2)
        #expect(session.showOutput.isBlackout && session.lightingSimulation.isStopped)
    }

    @Test func showPreparationAndRecoveryShareThePhoneGateAndPreserveTheDocument() async throws {
        let session = ProjectPersistenceTests().session()
        defer { session.releaseRuntimeResources() }
        let controller = LightingController(name: "Rehearsal relay", kind: .arduino)
        let fixture = PatchedFixture(name: "Plug", kind: .plug, controllerID: controller.id)
        #expect(session.editLighting {
            $0.controllers = [controller]
            $0.fixtures = [fixture]
            $0.cues = [LightingCue(name: "On", time: 1, entries: [.init(id: fixture.id, state: .plug(true))])]
        })
        #expect(session.editLighting { $0.cues[0].manualOnly = true })
        let saved = session.project
        session.switchWorkspace(to: .show)
        let remote = PhoneRemote(session: session)
        remote.role = .editor
        let play: [String: Any] = ["action": "play", "projectID": saved.id.uuidString]
        #expect(throws: PhoneError.self) { try remote.perform(play) }
        #expect(!session.goManualCue())
        session.lightingSimulation.setFailure(true, for: controller.id)
        await session.prepareShow()
        #expect(session.showArmState == .unarmed && (session.showChecks?.blockerCount ?? 0) > 0)
        session.lightingSimulation.setFailure(false, for: controller.id)
        await session.prepareShow()
        #expect(session.showArmState == .armed && !session.playbackRequested && !session.isOutputOpen)
        session.setLiveProjectionGain(0.5)
        session.liveFadeDuration = 0
        #expect(session.scene.masterBrightness == 0.5)
        if let target = session.project.renderScene.surfaces.first?.sourceID {
            let count = session.scene.surfaces.count
            session.identifyShowTarget(target)
            #expect(session.identifyingSourceID == target)
            session.finishIdentification()
            #expect(session.identifyingSourceID == nil && session.scene.surfaces.count == count)
        }
        try remote.perform(play)
        #expect(session.playbackRequested)
        session.lightingSimulation.setFailure(true, for: controller.id)
        session.inspectArmedShow()
        let time = session.transport.position
        #expect(session.showArmState == .interrupted && !session.playbackRequested)
        #expect(session.showOutput.isBlackout && session.lightingSimulation.blackout)
        #expect(throws: PhoneError.self) { try remote.perform(play) }
        session.lightingSimulation.setFailure(false, for: controller.id)
        await session.prepareShow()
        #expect(session.showArmState == .armed && session.transport.position == time && !session.playbackRequested)
        #expect(session.showOutput.isBlackout && session.lightingSimulation.blackout)
        session.stopPlayback()
        #expect(session.transport.position == 0 && session.showOutput.isBlackout)
        session.disarmShow()
        #expect(session.showArmState == .unarmed)
        for n in 0..<60 { session.recordShowEvent("Event \(n)") }
        #expect(session.showLog.count == 40 && session.showLog.last?.message == "Event 59")
        #expect(session.project == saved)
    }

}

@MainActor
struct PhoneRemoteTests {
    @Test func localBindingIdentifiesTheSelectedIPv4Endpoint() {
        let loopback = PhoneNetworkBinding.current(address: "127.0.0.1")
        #expect(loopback?.interfaceName == "lo0")
        #expect(loopback?.address == "127.0.0.1")
        #expect(PhoneNetworkBinding.current(address: "invalid") == nil)
    }

    @Test func parserRejectsDuplicateLengthAndTruncatedRequests() throws {
        let prefix = "POST /command HTTP/1.1\r\nHost: remote.localhost:9443\r\n"
        #expect(try PhoneRequest.parse(Data((prefix + "Content-Length: 2\r\n\r\n{").utf8)) == nil)
        #expect(throws: PhoneError.self) {
            try PhoneRequest.parse(Data((prefix + "Content-Length: 2\r\nContent-Length: 0\r\n\r\n{}").utf8))
        }
        let parsed = try PhoneRequest.parse(Data((prefix + "Content-Length: 2\r\n\r\n{}").utf8))
        let request = try #require(parsed)
        #expect(request.body == Data("{}".utf8))
    }

    @Test func phoneEditsUseMacUndoAndRejectStaleAndShowEdits() throws {
        let session = ProjectPersistenceTests().session()
        defer { session.releaseRuntimeResources() }
        let remote = PhoneRemote(session: session)
        let face = try #require(session.project.surfaces.first)
        let base = remote.snapshot()
        var command: [String: Any] = ["action": "corner", "projectID": try #require(base["projectID"]),
                                      "revision": try #require(base["revision"]), "face": face.id.uuidString,
                                      "index": 0, "point": [0.2, 0.3]]
        #expect(throws: PhoneError.self) { try remote.perform(command) }
        remote.role = .editor
        try remote.perform(command)
        #expect(session.project.surfaces.first?.corners.topLeft == SIMD2<Float>(0.2, 0.3))
        #expect(throws: PhoneError.self) { try remote.perform(command) }
        command["revision"] = remote.snapshot()["revision"]
        session.switchWorkspace(to: .show)
        #expect(throws: PhoneError.self) { try remote.perform(command) }
        try remote.perform(["action": "projectionOff", "projectID": session.project.id.uuidString])
        #expect(session.showOutput.isBlackout)
        session.switchWorkspace(to: .edit)
        session.undoProjectEdit()
        #expect(session.project.surfaces.first?.corners == face.corners)
    }

    @Test func phoneTimelinePreservesConnectedOwnershipUndoAndRejectsStaleOrOverlappingEdits() throws {
        let session = ProjectPersistenceTests().session()
        defer { session.releaseRuntimeResources() }
        session.addSurface()
        session.createObject(faceIDs: Set(session.project.surfaces.map(\.id)))
        let owner = try #require(session.project.baseTimelineTracks.first?.id)
        let id = try #require(session.addTimelineClip(sourceID: owner, at: 1, duration: 3))
        _ = try #require(session.addTimelineClip(sourceID: owner, at: 8, duration: 2))
        let remote = PhoneRemote(session: session)
        remote.role = .editor
        let initial = session.project
        let revision = try #require(remote.snapshot()["revision"] as? String)
        var request: [String: Any] = ["action": "clipMove", "projectID": initial.id.uuidString, "revision": revision,
                                       "owner": owner.uuidString, "clip": id.uuidString, "start": 3.0]
        let lanes = try #require(remote.timelineSnapshot(start: 0, span: 10, page: 0)["tracks"] as? [[String: Any]])
        #expect(lanes.count == 1 && lanes[0]["faces"] as? Int == 2)
        try remote.perform(request)
        #expect(session.selectedClip?.sourceID == owner && session.selectedClip?.start == 3 && session.selectedClip?.duration == 3)
        #expect(session.project.surfaces == initial.surfaces && session.project.objects == initial.objects)
        #expect(throws: PhoneError.self) { try remote.perform(request) }
        request["revision"] = remote.snapshot()["revision"]
        request["start"] = 7.0
        #expect(throws: PhoneError.self) { try remote.perform(request) }
        request["action"] = "clipTrim"
        request["start"] = 4.0
        request["end"] = 6.0
        try remote.perform(request)
        #expect(session.selectedClip?.start == 4 && session.selectedClip?.duration == 2)
        #expect(try ProjectCodec.decode(ProjectCodec.encode(session.document)) == session.document)
        session.undoProjectEdit()
        #expect(session.project.timelineClips.first(where: { $0.id == id })?.start == 3)
        session.deleteTimelineClip(id)
        request["revision"] = remote.snapshot()["revision"]
        #expect(throws: PhoneError.self) { try remote.perform(request) }
        session.switchWorkspace(to: .show)
        #expect(throws: PhoneError.self) { try remote.perform(request) }
    }

    @Test func phoneCanChangeCueTimingAndSelectItOnMac() throws {
        let session = ProjectPersistenceTests().session()
        defer { session.releaseRuntimeResources() }
        let controller = LightingController(name: "Relay", kind: .arduino)
        let fixture = PatchedFixture(name: "Plug", kind: .plug, controllerID: controller.id)
        let cue = LightingCue(name: "On", time: 1, entries: [.init(id: fixture.id, state: .plug(true))])
        #expect(session.editLighting { $0.controllers = [controller]; $0.fixtures = [fixture]; $0.cues = [cue] })
        let remote = PhoneRemote(session: session)
        remote.role = .viewer
        let state = remote.snapshot()
        let payload: [String: Any] = ["action":"cueTime", "projectID":session.project.id.uuidString,
                                       "revision":state["revision"] as Any, "cue":cue.id.uuidString, "time":2.5]
        #expect(throws: PhoneError.self) { try remote.perform(payload) }
        remote.role = .editor
        var command = payload
        command["revision"] = remote.snapshot()["revision"]
        try remote.perform(command)
        #expect(session.selectedLightingCue?.time == 2.5)
        #expect(session.selectedLightingCue?.entries == cue.entries)
        session.undoProjectEdit()
        #expect(session.project.lighting.cues.first?.time == 1)
    }

    @Test func phonePreviewUsesSmallMacRenderedFramesAndDiscardsStaleProjectFrames() async throws {
        let session = ProjectPersistenceTests().session()
        defer { session.releaseRuntimeResources() }
        let preview = PhonePreview()
        let key = UUID()
        let instant = ProcessInfo.processInfo.systemUptime
        #expect(preview.request(scene: session.scene, aspect: 16 / 9, key: key, at: instant).status == "202 Accepted")
        func payload(_ response: PhoneResponse) throws -> [String: Any] {
            try #require(JSONSerialization.jsonObject(with: response.body) as? [String: Any])
        }
        var result: [String: Any] = [:]
        for _ in 0..<100 where result["jpeg"] == nil {
            try await Task.sleep(for: .milliseconds(10))
            result = try payload(preview.request(scene: session.scene, aspect: 16 / 9, key: key, at: instant + 0.5))
        }
        let jpeg = try #require((result["jpeg"] as? String).flatMap { Data(base64Encoded: $0) })
        #expect(jpeg.prefix(2) == Data([0xff, 0xd8]) && jpeg.count <= 144 * 1024)
        #expect(result["age"] as? Double == 0.5)
        let stale = try payload(preview.request(scene: session.scene, aspect: 1, key: UUID(), at: instant + 0.5))
        #expect(stale["jpeg"] == nil)
        #expect(PhonePreview.dimensions(aspect: 16 / 9).height == 270)
        preview.clear()
    }

    private nonisolated static func run(_ executable: String, _ arguments: [String]) throws -> Data {
        let process = Process()
        let pipe = Pipe()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice
        try process.run()
        let bytes = pipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else { throw PhoneError(executable + " failed.") }
        return bytes
    }

    @Test func localHTTPAutoSelectsAndRequiresApprovalAndExactOrigin() async throws {
        let candidates = PhoneNetworkBinding.available()
        #expect(candidates.allSatisfy { PhoneNetworkBinding.isPrivateIPv4($0.address) && $0.interfaceName != "lo0" })
        let session = ProjectPersistenceTests().session()
        defer { session.releaseRuntimeResources() }
        let remote = PhoneRemote(session: session, port: 19444)
        defer { remote.stop() }
        if candidates.isEmpty { try remote.startLocal(address: "127.0.0.1") }
        else { try remote.startLocal() }
        for _ in 0..<100 where remote.pairingURL == nil { try await Task.sleep(for: .milliseconds(20)) }
        let invitation = try #require(remote.pairingURL)
        #expect(invitation.scheme == "http" && !remote.isEncrypted)
        #expect(invitation.host == (candidates.first?.address ?? "127.0.0.1"))
        let code = try #require(invitation.fragment)
        let base = "http://" + (invitation.host ?? "") + ":19444"
        func request(_ path: String, payload: [String: Any]? = nil, token: String = "", origin: String? = nil,
                     host: String? = nil) async throws -> Data {
            var args = ["-sS", "--noproxy", "*", "--max-time", "4", "--http1.1"]
            if let host { args += ["-H", "Host: " + host] }
            if let payload {
                let json = String(decoding: try JSONSerialization.data(withJSONObject: payload), as: UTF8.self)
                args += ["-H", "Content-Type: application/json", "-H", "Origin: " + (origin ?? base),
                         "-H", "Authorization: Bearer " + token, "--data", json]
            }
            args.append(base + path)
            let arguments = args
            return try await Task.detached { try Self.run("/usr/bin/curl", arguments) }.value
        }
        func json(_ bytes: Data) throws -> [String: Any] {
            try #require(JSONSerialization.jsonObject(with: bytes) as? [String: Any])
        }
        let html = try await request("/")
        #expect(String(decoding: html, as: UTF8.self).contains("<html"))
        let script = try await request("/remote.js")
        #expect(String(decoding: script, as: UTF8.self) == PhonePage.script)
        let wrongHost = try json(await request("/", host: "other.example:19444"))
        #expect(wrongHost["error"] != nil)
        let wrongOrigin = try json(await request("/pair", payload: ["code": code], origin: "https://other.example"))
        #expect(wrongOrigin["error"] != nil)
        let paired = try json(await request("/pair", payload: ["code": code]))
        let token = try #require(paired["token"] as? String)
        let reused = try json(await request("/pair", payload: ["code": code]))
        #expect(reused["error"] != nil)
        let pending = try json(await request("/state", payload: [:], token: token))
        #expect(pending["pending"] as? Bool == true)
        let command: [String: Any] = ["action": "projectionOff", "projectID": session.project.id.uuidString, "sequence": 1]
        let unapproved = try json(await request("/command", payload: command, token: token))
        #expect(unapproved["error"] != nil && !session.showOutput.isBlackout)
        remote.role = .operatorRole
        remote.approve()
        let applied = try json(await request("/command", payload: command, token: token))
        #expect(applied["projectionBlackout"] as? Bool == true)
        let replay = try json(await request("/command", payload: command, token: token))
        #expect(replay["error"] != nil)
        try await Task.sleep(for: .seconds(1))
        var viewerTokens: [String] = []
        for _ in 0..<2 {
            remote.newViewerInvitation()
            let viewerCode = try #require(remote.pairingURL?.fragment)
            let joined = try json(await request("/pair", payload: ["code": viewerCode]))
            let viewerToken = try #require(joined["token"] as? String)
            let pending = try json(await request("/state", payload: [:], token: viewerToken))
            #expect(pending["pending"] as? Bool == true)
            remote.approve()
            viewerTokens.append(viewerToken)
            let state = try json(await request("/state", payload: [:], token: viewerToken))
            #expect(state["role"] as? String == PhoneRole.viewer.rawValue && state["faces"] == nil)
            let timeline = try json(await request("/timeline", payload: ["projectID": session.project.id.uuidString], token: viewerToken))
            #expect(timeline["tracks"] != nil)
            let attempt = try json(await request("/command", payload: command, token: viewerToken))
            #expect(attempt["error"] != nil)
        }
        #expect(remote.additionalViewerCount == 2 && remote.role == .operatorRole)
        let disabled: [String: Any] = ["projectID": session.project.id.uuidString]
        remote.allowsPreview = false
        let gated = try json(await request("/preview", payload: disabled, token: token))
        #expect(gated["error"] != nil && gated["jpeg"] == nil)
        remote.allowsPreview = true
        let anonymous = try json(await request("/preview", payload: disabled))
        #expect(anonymous["error"] != nil && anonymous["jpeg"] == nil)
        remote.revoke()
        let revoked = try json(await request("/state", payload: [:], token: token))
        #expect(revoked["error"] != nil)
        let revokedViewer = try json(await request("/state", payload: [:], token: viewerTokens[0]))
        #expect(revokedViewer["error"] != nil)
        remote.newInvitation()
        let oldInvitation = try json(await request("/pair", payload: ["code": code]))
        #expect(oldInvitation["error"] != nil)
        remote.stop()
        #expect(!remote.isRunning && remote.pairingURL == nil)
    }

    @Test func httpsPairApprovalAndReplayProtection() async throws {
        let folder = try ProjectPersistenceTests().temporary()
        defer { try? FileManager.default.removeItem(at: folder) }
        let config = folder.appendingPathComponent("test.cnf")
        let key = folder.appendingPathComponent("key.pem")
        let cert = folder.appendingPathComponent("cert.pem")
        let identity = folder.appendingPathComponent("identity.p12")
        try Data("""
        [req]
        distinguished_name = name
        x509_extensions = ext
        prompt = no
        [name]
        CN = remote.localhost
        [ext]
        subjectAltName = DNS:remote.localhost
        """.utf8).write(to: config)
        let bytes = try await Task.detached {
            _ = try Self.run("/usr/bin/openssl", ["req", "-new", "-x509", "-nodes", "-days", "1", "-newkey", "rsa:2048",
                "-config", config.path, "-keyout", key.path, "-out", cert.path])
            _ = try Self.run("/usr/bin/openssl", ["pkcs12", "-export", "-inkey", key.path, "-in", cert.path,
                "-out", identity.path, "-passout", "pass:test"])
            return try Data(contentsOf: identity)
        }.value
        let session = ProjectPersistenceTests().session()
        defer { session.releaseRuntimeResources() }
        let originalBinding = PhoneNetworkBinding(interfaceName: "lo0", address: "127.0.0.1", netmask: "255.0.0.0")
        var binding: PhoneNetworkBinding? = originalBinding
        let remote = PhoneRemote(session: session, port: 19443, networkBinding: { _ in binding })
        defer { remote.stop() }
        try remote.start(hostname: "remote.localhost", address: "127.0.0.1", identity: bytes, password: "test")
        for _ in 0..<100 where remote.pairingURL == nil { try await Task.sleep(for: .milliseconds(20)) }
        let code = try #require(remote.pairingURL?.fragment)
        func post(_ path: String, _ body: [String: Any], token: String = "",
                  origin: String = "https://remote.localhost:19443") async throws -> [String: Any] {
            let json = String(decoding: try JSONSerialization.data(withJSONObject: body), as: UTF8.self)
            let response = try await Task.detached {
                try Self.run("/usr/bin/curl", ["-sS", "--noproxy", "*", "--http1.1", "--max-time", "4",
                    "--cacert", cert.path, "--resolve", "remote.localhost:19443:127.0.0.1",
                    "-H", "Content-Type: application/json", "-H", "Origin: " + origin,
                    "-H", "Authorization: Bearer " + token, "--data", json, "https://remote.localhost:19443" + path])
            }.value
            return try #require(JSONSerialization.jsonObject(with: response) as? [String: Any])
        }
        let rejected = try await post("/pair", ["code": code], origin: "https://other.example")
        #expect(rejected["error"] != nil)
        let pairing = try await post("/pair", ["code": code])
        let token = try #require(pairing["token"] as? String)
        let pending = try await post("/state", [:], token: token)
        #expect(pending["pending"] as? Bool == true)
        remote.role = .operatorRole
        remote.approve()
        let command: [String: Any] = ["action": "projectionOff", "projectID": session.project.id.uuidString, "sequence": 1]
        let result = try await post("/command", command, token: token)
        #expect(result["projectionBlackout"] as? Bool == true)
        let replay = try await post("/command", command, token: token)
        #expect(replay["error"] != nil)
        for _ in 0..<20 { remote.checkNetworkBinding() }
        #expect(remote.isRunning && remote.hasPhone)
        binding = nil
        remote.checkNetworkBinding()
        #expect(remote.isRunning && remote.hasPhone)
        binding = originalBinding
        remote.checkNetworkBinding()
        try await Task.sleep(for: .milliseconds(2200))
        #expect(remote.isRunning && remote.hasPhone)
        let stillPaired = try await post("/state", [:], token: token)
        #expect(stillPaired["error"] == nil)
        binding = PhoneNetworkBinding(interfaceName: "en99", address: "127.0.0.1", netmask: "255.0.0.0")
        remote.checkNetworkBinding()
        #expect(!remote.isRunning && !remote.hasPhone && remote.pairingURL == nil)
        #expect(remote.status.contains("changed"))
        binding = originalBinding
        try remote.start(hostname: "remote.localhost", address: "127.0.0.1", identity: bytes, password: "test")
        for _ in 0..<100 where remote.pairingURL == nil { try await Task.sleep(for: .milliseconds(20)) }
        let revoked = try await post("/state", [:], token: token)
        #expect(revoked["error"] != nil)
        binding = nil
        remote.checkNetworkBinding()
        try await Task.sleep(for: .milliseconds(2200))
        #expect(!remote.isRunning && remote.status.contains("unavailable"))
    }
}

struct ShowPlaylistScheduleTests {
    @Test func playlistKeepsIntrosOutrosAndIntermissionsInTheirRoles() {
        let intro = ShowPlaylist.Entry(path: "/Intro.projectionmap", role: .intro)
        let main = ShowPlaylist.Entry(path: "/Show.projectionmap")
        let idle = ShowPlaylist.Entry(path: "/Idle.projectionmap", role: .idle, seconds: 3)
        let end = ShowPlaylist.Entry(path: "/Outro.projectionmap", role: .outro)
        let playlist = ShowPlaylist(entries: [main, end, intro, idle], repeats: 2)
        #expect(playlist.isValid)
        #expect(playlist.sequence() == [intro, main, idle, main, idle, end])
    }

    @Test func scheduleCrossesMidnightAndDeduplicatesConflictingStarts() throws {
        let parser = ISO8601DateFormatter()
        let now = try #require(parser.date(from: "2026-12-25T05:30:10Z"))
        let armed = try #require(parser.date(from: "2026-12-25T05:29:00Z"))
        var a = ShowSchedule(playlistID: UUID(), enabled: true, timeZoneID: "America/Chicago",
                             startMinute: 23 * 60 + 30, endMinute: 60)
        var b = a
        b.id = UUID()
        b.priority = 5
        #expect(a.conflicts(with: b, around: now))
        let due = ShowSchedule.due([a, b], now: now, armedAt: armed, seen: [])
        #expect(due.map { $0.0.id } == [b.id, a.id])
        #expect(due.first?.1.ends == parser.date(from: "2026-12-25T07:00:00Z"))
        #expect(ShowSchedule.due([a, b], now: now, armedAt: armed, seen: Set(due.map { $0.1.id })).isEmpty)
        #expect(ShowSchedule.due([a], now: now, armedAt: now, seen: []).isEmpty)
        a.excludedDates = "2026-12-24"
        #expect(a.occurrence(on: now) == nil)
    }

    @Test func scheduleUsesFirstFallOccurrenceAndSkipsMissingSpringTime() throws {
        let parser = ISO8601DateFormatter()
        let spring = try #require(parser.date(from: "2026-03-08T12:00:00Z"))
        let fall = try #require(parser.date(from: "2026-11-01T12:00:00Z"))
        var rule = ShowSchedule(playlistID: UUID(), enabled: true, timeZoneID: "America/Chicago",
                                startMinute: 150, endMinute: 240)
        #expect(rule.occurrence(on: spring) == nil)
        rule.startMinute = 90
        #expect(rule.occurrence(on: fall)?.starts == parser.date(from: "2026-11-01T06:30:00Z"))
    }
}

@MainActor
struct ShowPlaylistRunTests {
    @Test func runnerFinishesCurrentWithoutStartingNextAndReloadsSavedPlaylist() async throws {
        let files = ProjectPersistenceTests()
        let folder = try files.temporary()
        defer { try? FileManager.default.removeItem(at: folder) }
        let first = folder.appendingPathComponent("First.projectionmap")
        let second = folder.appendingPathComponent("Second.projectionmap")
        try ProjectPackageStore().write(ProjectDocument(project: MappingProject()), to: first)
        try ProjectPackageStore().write(ProjectDocument(project: MappingProject()), to: second)
        let domain = "ProjectionMapper.playlist.tests." + UUID().uuidString
        let defaults = try #require(UserDefaults(suiteName: domain))
        defer { defaults.removePersistentDomain(forName: domain) }
        let library = ShowLibrary(defaults: defaults)
        let playlist = ShowPlaylist(entries: [.init(path: first.path, seconds: 1), .init(path: second.path, seconds: 1)])
        library.put(playlist)
        #expect(ShowLibrary(defaults: defaults).playlists == [playlist])
        var started: [String] = []
        var complete = false
        var stopped = false
        library.canStart = { true }
        library.runEntry = { entry, _ in started.append(entry.url.standardizedFileURL.path) }
        library.stopOutput = { stopped = true }
        library.itemOutcome = { complete ? "" : nil }
        library.start(playlist)
        defer { library.stopNow() }
        for _ in 0..<50 where started.isEmpty { try await Task.sleep(for: .milliseconds(10)) }
        #expect(started == [first.standardizedFileURL.path])
        #expect(library.running)
        library.finishCurrent()
        #expect(library.running && library.stoppingAfterCurrent && !stopped)
        complete = true
        for _ in 0..<80 where library.running { try await Task.sleep(for: .milliseconds(10)) }
        #expect(started == [first.standardizedFileURL.path])
        #expect(stopped && !library.running)
    }

    @Test func timedStillCompletesItsPlaylistItemWithoutChangingTheProject() async {
        let session = ProjectPersistenceTests().session()
        defer { session.releaseRuntimeResources() }
        let project = session.project
        session.switchWorkspace(to: .show, at: 100)
        await session.prepareShow()
        session.configurePlaylistItem(end: 4) {}
        #expect(session.setPlaying(true, at: 100))
        session.inspectArmedShow(at: 105)
        #expect(session.playlistItemCompleted && session.transport.position == 4)
        #expect(!session.playbackRequested && session.project == project)
    }
}
