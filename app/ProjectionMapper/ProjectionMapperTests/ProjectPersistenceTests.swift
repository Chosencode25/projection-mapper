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
