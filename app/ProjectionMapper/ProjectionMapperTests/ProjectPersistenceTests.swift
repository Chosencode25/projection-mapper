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
