import AppKit
import Testing

@MainActor
struct CalibrationSessionTests {
    private func session() -> EditorSession {
        let defaults = UserDefaults(suiteName: "v1121." + UUID().uuidString)!
        return EditorSession(presentOutput: { _ in }, output: OutputSelectionState(preferences: OutputPreferences(defaults: defaults)))
    }
    private func directory() throws -> URL {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: dir,withIntermediateDirectories: true); return dir
    }
    @Test func calibrationEditsStayCleanAndDoNotCreateRecovery() throws {
        let s = session(), original = s.project, dir = try directory()
        defer { try? FileManager.default.removeItem(at: dir) }
        let store = ProjectRecoveryStore(directory: dir.appendingPathComponent("Recovery")); s.configureRecovery(store)
        s.setCalibrationRows(12); s.setCalibrationColumns(16); s.setCalibrationLineWidth(2.5)
        for pattern in CalibrationPattern.allCases {
            s.setCalibrationPattern(pattern)
            #expect(s.scene == s.testOutput.scene && s.project == original && !s.hasUserChanges)
        }
        try s.flushRecovery(); #expect(store.entries().isEmpty)
        let state = s.calibration
        s.setCalibrationRows(1); s.setCalibrationColumns(65); s.setCalibrationLineWidth(.nan)
        #expect(s.calibration == state && s.project == original)
        s.setCalibrationRows(12); #expect(s.editMessage == nil)
        s.setCalibrationPattern(.normal)
        s.toggleCalibration(); #expect(s.calibration.pattern == .grid)
        s.toggleCalibration(); #expect(s.calibration.pattern == .normal)
    }
    @Test func richLayoutLibrariesLocksAndSourceClocksSurvivePatterns() throws {
        let s = session(); s.addSurface(); s.createObject(faceIDs: Set(s.project.surfaces.map(\.id)))
        let object = try #require(s.selectedObjectID), face = s.project.surfaces[0].id
        s.setSurfaceContent(.particles); s.setPlaying(true,at: 100); s.seekPlayback(to: 42,at: 102)
        s.setSelectedPaused(true,at: 102)
        var appearance = SurfaceAppearance.defaults; appearance.opacity = 0; appearance.brightness = 0.2; appearance.flipHorizontal = true
        appearance.crop = ContentCrop(origin: SIMD2(0.1,0.2),size: SIMD2(0.5,0.5))
        s.setAppearance(appearance,objectID: object); s.setGeometryLocked(true,objectID: object)
        let palette = try #require(s.createPalette(name: "Colors")), slot = try #require(s.addPaletteSlot(palette,name: "White",color: SIMD4(1,1,1,1)))
        s.bindColor(faceID: face,channel: .primary,binding: ColorBinding(paletteID: palette,slotID: slot))
        _ = s.saveLook(name: "Saved")
        let original = s.project, clocks = s.sourcePlayback, transport = s.transport
        for pattern in CalibrationPattern.allCases {
            s.setCalibrationPattern(pattern)
            #expect(s.project == original && s.sourcePlayback == clocks && s.transport == transport)
            #expect(s.scene == s.testOutput.scene)
            if pattern.isActive { #expect(s.scene.effectiveSurfaces.allSatisfy { $0.appearance == .defaults }) }
        }
        s.moveObject(object,by: SIMD2(0.1,0.1)); #expect(s.project == original)
        s.setCalibrationPattern(.white); s.applyLook(s.project.looks[0].id)
        #expect(s.calibration.pattern == .white && s.project == original)
    }
    @Test func editsUnderCalibrationReturnAsCurrentContentWithLogicalPlaybackPhase() {
        let s = session(); s.setSurfaceContent(.particles); s.setPlaying(true,at: 100)
        let source = s.selectedSource!.id
        s.setCalibrationPattern(.grid)
        #expect(!s.scene.needsContinuousRendering(at: 103) && s.transport.elapsed(at: 103) == 3)
        s.setSourceColor(SIMD4(0,1,0,1)); s.setSurfaceContent(.noise)
        s.setCalibrationPattern(.normal)
        #expect(s.selectedSource?.id == source && s.scene.surfaces[0].content == .noise && s.scene.surfaces[0].color == SIMD4(0,1,0,1))
        #expect(s.scene.needsContinuousRendering(at: 104) && s.transport.elapsed(at: 104) == 4)
        s.setSelectedPaused(true,at: 104); let clock = s.selectedPlayback
        s.setCalibrationPattern(.checkerboard); s.setCalibrationPattern(.normal)
        #expect(s.selectedPlayback == clock && s.selectedPlayback.elapsed(at: 99) == 4)
    }
    @Test func savingRetainsRuntimeButOpeningAndResetClearItFailedLoadRetainsIt() throws {
        let s = session(), dir = try directory(); defer { try? FileManager.default.removeItem(at: dir) }
        let url = dir.appendingPathComponent("Calibration.projectionmap")
        s.setCalibrationPattern(.white); s.setCalibrationColumns(32); s.setCalibrationLineWidth(3)
        s.blackoutOutput(); try s.save(to: url)
        #expect(s.calibration.pattern == .white && s.showOutput.isBlackout && !s.hasUserChanges)
        let saved = try ProjectPackageStore().read(url)
        let json = String(decoding: try ProjectCodec.encode(saved),as: UTF8.self)
        #expect(!json.contains("calibration") && saved.formatVersion == ProjectDocument.currentVersion)
        var invalid = saved; invalid.formatVersion = 999
        #expect(throws: ProjectFileError.self) { try s.load(invalid,from: url) }
        #expect(s.calibration.pattern == .white && s.showOutput.isBlackout)
        try s.load(saved,from: url)
        #expect(s.calibration == CalibrationState() && !s.showOutput.isBlackout && !s.transport.isPlaying)
        s.setCalibrationPattern(.checkerboard); s.setCalibrationRows(64)
        s.resetProject(); #expect(s.calibration == CalibrationState())
    }
    @Test func failedSaveAndRecoveryRetainStateUntilSuccessfulRecoveryLoad() throws {
        let s = session(), dir = try directory(); defer { try? FileManager.default.removeItem(at: dir) }
        let url = dir.appendingPathComponent("Show.projectionmap")
        try s.save(to: url)
        s.setCalibrationPattern(.crosshair); s.renameProject("Updated")
        let store = ProjectPackageStore(); store.beforeCommit = { _ in throw ProjectFileError.io("simulated failure") }
        #expect(throws: ProjectFileError.self) { try s.save(to: url,store: store) }
        #expect(s.calibration.pattern == .crosshair && s.hasUserChanges)
        #expect(try ProjectPackageStore().read(url).project.name == MappingProject.defaultName)
        let recovery = ProjectRecoveryStore(directory: dir.appendingPathComponent("Recovery")); s.configureRecovery(recovery); try s.flushRecovery()
        let entry = try #require(recovery.entries().first)
        try s.load(entry.document,from: entry.url,recovering: true)
        #expect(s.calibration == CalibrationState() && s.project.name == "Updated" && s.hasUserChanges)
    }
    @Test func statusesAndRestoreDistinguishBlackTestBlackoutAndFade() {
        let s = session()
        s.setCalibrationPattern(.black)
        #expect(s.calibrationStatus(at: 100).contains("Black test selected"))
        s.blackoutOutput(); #expect(s.calibrationStatus(at: 100).contains("Blackout overrides"))
        s.setCalibrationPattern(.white); #expect(s.showOutput.isBlackout)
        s.restoreOutput(at: 100)
        #expect(s.calibration.pattern == .white && s.calibrationStatus(at: 100.5).contains("Restoring"))
        #expect(s.showOutput.gain(at: 101) == 1)
        s.fadeToBlack(at: 102); #expect(s.calibrationStatus(at: 103).contains("Faded to black"))
        s.setMasterBrightness(0); #expect(s.calibrationStatus(at: 104).contains("Master brightness is zero"))
        s.deleteSurface(s.project.surfaces[0].id)
        #expect(s.calibrationStatus(at: 104).contains("No visible valid mapped faces"))
    }
}
