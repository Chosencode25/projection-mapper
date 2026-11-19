import Foundation
import CoreGraphics
import Testing

@MainActor
struct HeadPositionTests {
    private func session() -> EditorSession {
        let controller = LightingController(name: "Heads", kind: .dmx)
        let relay = LightingController(name: "Relay", kind: .arduino)
        let a = PatchedFixture(name: "Head A", group: "Front", kind: .movingHead, controllerID: controller.id)
        var b = PatchedFixture(name: "Head B", group: "Front", kind: .movingHead, controllerID: controller.id); b.address = 10
        let plug = PatchedFixture(name: "Plug", group: "Front", kind: .plug, controllerID: relay.id)
        var project = MappingProject(name: "Paths")
        project.lighting.controllers = [controller, relay]; project.lighting.fixtures = [a, b, plug]
        let defaults = UserDefaults(suiteName: "head.positions." + UUID().uuidString)!
        let s = EditorSession(project: project, output: OutputSelectionState(preferences: OutputPreferences(defaults: defaults)))
        s.switchWorkspace(to: .lighting)
        return s
    }
    private func head(_ state: FixtureState) throws -> HeadLook {
        guard case .head(let value) = state else { throw ProjectFileError.invalid("Expected a moving head") }
        return value
    }
    @Test func lightingPresetRetargetsIndependentlyAndSurvivesRoundTrip() throws {
        let s = session()
        defer { s.releaseRuntimeResources() }
        let fixtures = s.project.lighting.fixtures
        let first = [fixtures[1], fixtures[0]]
        var clip = ChoreographyClip(name: "Holiday Wave", pattern: .wave, interval: 0.4, repeats: 2, angle: 45)
        clip.targets = s.effectTargets(for: first)
        #expect(clip.targets.map(\.id) == first.map(\.id))
        #expect(clip.targets[0].position == FixturePreviewPlacement.initial(index: 1, kind: .movingHead).origin)
        #expect(s.saveLightingEffectPreset(from: clip))
        let preset = try #require(s.project.lighting.lightingEffectPresets.first)
        s.undoProjectEdit()
        #expect(s.project.lighting.lightingEffectPresets.isEmpty)
        s.redoProjectEdit()

        var second = ChoreographyClip(targets: s.effectTargets(for: [fixtures[2]]), start: 3)
        let id = second.id
        preset.apply(to: &second)
        #expect(second.id == id && second.start == 3 && second.targets.map(\.id) == [fixtures[2].id])
        #expect(second.colors == clip.colors && second.angle == 45 && second.repeats == 2 && second.pattern == .wave)
        second.interval = 0.7
        #expect(s.setChoreography([clip, second]))
        #expect(s.project.lighting.lightingEffectPresets.first?.interval == 0.4)
        var updated = clip
        updated.repeats = 4
        #expect(s.saveLightingEffectPreset(from: updated))
        #expect(s.project.lighting.lightingEffectPresets.first?.id == preset.id)
        #expect(s.project.choreographyClips == [clip, second])
        let reopened = try ProjectCodec.decode(ProjectCodec.encode(s.document))
        #expect(reopened == s.document)
        let playground = try PlaygroundExtraction.extract(reopened, name: "House")
        #expect(playground.project.lighting.lightingEffectPresets.isEmpty && playground.project.choreographyClips.isEmpty)
        s.removeLightingEffectPreset(preset.id)
        #expect(s.project.lighting.lightingEffectPresets.isEmpty && s.project.choreographyClips == [clip, second])
    }

    @Test func effectPreviewTracksSharedTimeAndRespectsOverridesAndBlackout() throws {
        let s = session()
        defer { s.releaseRuntimeResources() }
        let fixtures = s.project.lighting.fixtures
        let clip = ChoreographyClip(name: "Chase", targets: s.effectTargets(for: [fixtures[0], fixtures[2]]), interval: 1, repeats: 2)
        #expect(s.setChoreography([clip]))
        s.lightingSimulation.resume()
        func report(_ fixture: PatchedFixture) throws -> SimulatedFixture {
            try #require(s.lightingSimulation.reports[fixture.controllerID]?.fixtures.first { $0.id == fixture.id })
        }
        for time in [0.0, 1.25, 3.5, 0.0, 4.0] {
            s.seekPlayback(to: time, at: 100)
            s.refreshLighting(at: 100)
            #expect(try report(fixtures[0]).activeEffect == (time == 0 ? "Chase" : nil))
            #expect(try report(fixtures[2]).activeEffect == ((time == 1.25 || time == 3.5) ? "Chase" : nil))
            #expect(try report(fixtures[1]).activeEffect == nil)
        }
        s.seekPlayback(to: 0, at: 100)
        s.lightingSimulation.override(.head(HeadLook()), for: fixtures[0])
        s.refreshLighting(at: 100)
        #expect(try report(fixtures[0]).activeEffect == nil)
        s.lightingSimulation.override(nil, for: fixtures[0])
        s.lightingSimulation.blackout = true
        s.refreshLighting(at: 100)
        #expect(try report(fixtures[0]).activeEffect == nil)
        s.lightingSimulation.blackout = false
        s.refreshLighting(at: 100)
        #expect(try report(fixtures[0]).activeEffect == "Chase")
    }

    @Test func exactBoundariesAndCurvesPreserveBrightnessColorAndGobo() throws {
        let id = UUID()
        let a = HeadPositionKey(fixtureID: id, time: 1, pan: 0.1, tilt: 0.2)
        var b = HeadPositionKey(fixtureID: id, time: 5, pan: 0.9, tilt: 0.8)
        let base = HeadLook(pan: 0.4, tilt: 0.6, dimmer: 0.75, color: 2, gobo: 3)
        func sample(_ time: Double) throws -> HeadLook {
            try head(HeadPositionSchedule(keys: [b, a]).applying(to: .head(base), fixtureID: id, at: time))
        }
        #expect(try sample(0.99) == base)
        #expect(try sample(1).pan == 0.1)
        #expect(try abs(sample(3).pan - 0.5) < 0.000001)
        #expect(try abs(sample(3).tilt - 0.5) < 0.000001)
        #expect(try sample(6).pan == 0.9)
        b.curve = .eased
        #expect(try abs(sample(2).pan - 0.225) < 0.000001)
        b.curve = .snap
        #expect(try sample(1).pan == 0.1 && sample(4.999).pan == 0.1 && sample(5).pan == 0.9)
        for time in [0.0, 1, 3, 6, 1.1, 5, 3, 0.5] {
            let value = try sample(time)
            #expect(value.dimmer == base.dimmer && value.color == base.color && value.gobo == base.gobo)
        }
        #expect(HeadPositionSchedule(keys: [a, b]).applying(to: .plug(true), fixtureID: id, at: 3) == .plug(true))
        #expect(HeadPositionSchedule(keys: [a]).applying(to: .head(base), fixtureID: id, at: .nan) == .head(base))
    }
    @Test func simulationSeekWrapManualOverrideBlackoutAndStopUseOnePositionEvaluator() throws {
        let s = session(); defer { s.releaseRuntimeResources() }
        let fixture = s.project.lighting.fixtures[0]
        let lighting = s.project.lighting
        let a = HeadPositionKey(fixtureID: fixture.id, time: 0, pan: 0.1, tilt: 0.2)
        let b = HeadPositionKey(fixtureID: fixture.id, time: 4, pan: 0.9, tilt: 0.8, curve: .eased)
        #expect(s.editLighting { data in
            data.headPositions = [a, b]
            data.cues = [LightingCue(name: "Brightness", time: 0, entries: [FixtureLookEntry(id: fixture.id, state: .head(HeadLook(dimmer: 0.8, color: 2, gobo: 3)))])]
        })
        s.lightingSimulation.resume()
        let p = s.project
        for time in [2.0, 4, 0.25, 3, 0, 2] {
            s.seekPlayback(to: time, at: 100); s.refreshLighting(at: 100)
            let expected = try head(HeadPositionSchedule(keys: [a,b]).applying(to: .head(HeadLook(dimmer: 0.8, color: 2, gobo: 3)), fixtureID: fixture.id, at: time))
            #expect(try head(s.intendedLightingState(fixture)) == expected)
            #expect(s.scene.transport.elapsed(at: 100) == time)
        }
        let override = HeadLook(pan: 0.7, tilt: 0.3, dimmer: 0.2)
        s.lightingSimulation.override(.head(override), for: fixture); s.refreshLighting(at: 100)
        #expect(try head(s.intendedLightingState(fixture)) == override)
        s.lightingSimulation.override(nil, for: fixture); s.refreshLighting(at: 100)
        #expect(try head(s.intendedLightingState(fixture)).pan == 0.5)
        s.lightingSimulation.blackout = true; s.refreshLighting(at: 100)
        let black = try #require(s.lightingSimulation.reports[fixture.controllerID]?.fixtures.first { $0.id == fixture.id })
        #expect(try head(black.effective).dimmer == 0 && head(black.effective).pan == 0.5)
        s.stopManualFixtures()
        s.seekPlayback(to: 4, at: 100); s.refreshLighting(at: 100)
        let stopped = try #require(s.lightingSimulation.reports[fixture.controllerID]?.fixtures.first { $0.id == fixture.id })
        #expect(try head(stopped.effective).dimmer == 0)
        s.lightingSimulation.blackout = false; s.lightingSimulation.resume(); s.refreshLighting(at: 100)
        #expect(try head(s.intendedLightingState(fixture)).pan == 0.9)
        #expect(s.project == p && s.project.lighting.fixtures == lighting.fixtures)
    }
    @Test func groupCaptureUpdatesSameTimeAndUndoRedoRemainAtomic() throws {
        let s = session(); defer { s.releaseRuntimeResources() }
        let fixtures = s.project.lighting.fixtures.filter { $0.kind == .movingHead }
        let surfaces = s.project.surfaces
        s.selectLighting(.group("Front")); s.lightingSimulation.resume(); s.refreshLighting()
        for (index, fixture) in fixtures.enumerated() {
            s.lightingSimulation.override(.head(HeadLook(pan: index == 0 ? 0.2 : 0.7, tilt: 0.3)), for: fixture)
        }
        s.refreshLighting(); s.captureHeadPositions(at: 0)
        #expect(s.project.lighting.positionKeys.count == 2)
        let ids = Set(s.project.lighting.positionKeys.map(\.id))
        s.selectLighting(.group("Front")); s.captureHeadPositions(at: 0)
        #expect(Set(s.project.lighting.positionKeys.map(\.id)) == ids)
        s.selectLighting(.group("Front")); s.captureHeadPositions(at: 4)
        #expect(s.project.lighting.positionKeys.count == 4 && s.project.timelineContentEnd == 4)
        s.undoProjectEdit(); #expect(s.project.lighting.positionKeys.count == 2)
        s.redoProjectEdit(); #expect(s.project.lighting.positionKeys.count == 4)
        #expect(s.project.surfaces == surfaces)
        #expect(s.project.lighting.positionKeys.allSatisfy { key in fixtures.contains { $0.id == key.fixtureID } })
    }
    @Test func editingCollisionDeletionAndKeyboardRoutingPreserveOtherProgramming() throws {
        let s = session(); defer { s.releaseRuntimeResources() }
        s.selectLighting(.fixture(s.project.lighting.fixtures[0].id))
        s.captureHeadPositions(at: 0); s.captureHeadPositions(at: 3)
        let original = try #require(s.selectedHeadPositionKey), baseline = s.project
        var invalid = original; invalid.time = 0
        s.updateHeadPosition(invalid); #expect(s.project == baseline)
        invalid = original; invalid.pan = .nan
        s.updateHeadPosition(invalid); #expect(s.project == baseline)
        var changed = original; changed.time = 2; changed.pan = 0.8; changed.curve = .eased
        s.updateHeadPosition(changed)
        #expect(s.selectedHeadPositionKey == changed)
        s.performEditorAction(.duplicate, at: 100)
        #expect(s.project.lighting.positionKeys.count == 3)
        s.performEditorAction(.delete, at: 100)
        #expect(s.project.lighting.positionKeys.count == 2 && s.project.surfaces == baseline.surfaces)
        s.selectHeadPositionKey(changed.id)
        let faceID = s.selectedSurfaceID
        s.cancelEditorSelection()
        #expect(s.selectedHeadPositionKeyID == nil && s.selectedSurfaceID == faceID)
        s.selectHeadPositionKey(changed.id)
        s.switchWorkspace(to: .show)
        s.updateHeadPosition(original); s.deleteHeadPosition(changed.id); s.captureHeadPositions(at: 4)
        #expect(s.project.lighting.positionKeys.count == 2 && !s.canPerformEditorAction(.delete))
        s.switchWorkspace(to: .lighting)
        #expect(s.editLighting { $0.removeFixture(changed.fixtureID) })
        #expect(s.project.lighting.positionKeys.isEmpty && s.selectedHeadPositionKeyID == nil)
    }
    @Test func validationRejectsBadReferencesDuplicateTimesAndExcessiveKeys() throws {
        let s = session(); defer { s.releaseRuntimeResources() }
        let id = s.project.lighting.fixtures[0].id
        let valid = HeadPositionKey(fixtureID: id, time: 0, pan: 0.5, tilt: 0.5)
        var data = s.project.lighting; data.headPositions = [valid]
        #expect(data.validationIssue() == nil)
        var other = valid; other.id = UUID()
        data.headPositions = [valid, other]; #expect(data.validationIssue() != nil)
        other = valid; other.fixtureID = s.project.lighting.fixtures.last!.id
        data.headPositions = [other]; #expect(data.validationIssue() != nil)
        other = valid; other.tilt = 1.001; data.headPositions = [other]; #expect(data.validationIssue() != nil)
        data.headPositions = (0...256).map { HeadPositionKey(fixtureID: id, time: Double($0), pan: 0.5, tilt: 0.5) }
        #expect(data.validationIssue() != nil)
    }
    @Test func format14MigrationAndFormat15RoundTripPreserveKeysAndClearPlaygrounds() throws {
        let s = session(); defer { s.releaseRuntimeResources() }
        s.selectLighting(.fixture(s.project.lighting.fixtures[0].id)); s.captureHeadPositions(at: 2)
        let document = s.document
        #expect(try ProjectCodec.decode(ProjectCodec.encode(document)) == document)
        #expect(document.formatVersion == ProjectDocument.currentVersion)
        var json = try JSONSerialization.jsonObject(with: ProjectCodec.encode(document)) as! [String: Any]
        json["formatVersion"] = 14
        var project = json["project"] as! [String: Any], lighting = (json["project"] as! [String: Any])["lighting"] as! [String: Any]
        lighting.removeValue(forKey: "headPositions"); project["lighting"] = lighting; json["project"] = project
        let old = try ProjectCodec.decode(JSONSerialization.data(withJSONObject: json))
        #expect(old.formatVersion == ProjectDocument.currentVersion && old.project.lighting.positionKeys.isEmpty)
        #expect(old.project.surfaces == document.project.surfaces && old.project.lighting.fixtures == document.project.lighting.fixtures)
        json["formatVersion"] = ProjectDocument.currentVersion + 1
        #expect(throws: (any Error).self) { try ProjectCodec.decode(JSONSerialization.data(withJSONObject: json)) }
        let setup = try PlaygroundExtraction.extract(document, name: "House")
        #expect(setup.project.lighting.positionKeys.isEmpty && setup.project.lighting.fixtures == document.project.lighting.fixtures)
        try PlaygroundExtraction.validateSetup(setup)
        #expect(throws: (any Error).self) { try PlaygroundExtraction.validateSetup(document) }
    }
    @Test func autosaveRecoveryAndReopenPreservePositionProgramming() async throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: folder) }
        let previous = UserDefaults.standard.string(forKey: "ProjectionMapper.lastDraft")
        defer { UserDefaults.standard.set(previous, forKey: "ProjectionMapper.lastDraft") }
        let s = session(); defer { s.releaseRuntimeResources() }
        let recovery = ProjectRecoveryStore(directory: folder.appendingPathComponent("Recovery"))
        s.configureAutosave(directory: folder.appendingPathComponent("Drafts")); s.configureRecovery(recovery)
        s.selectLighting(.fixture(s.project.lighting.fixtures[0].id)); s.captureHeadPositions(at: 0)
        s.captureHeadPositions(at: 4); try await s.flushAutosave()
        let url = try #require(s.documentURL)
        let saved = try ProjectPackageStore().read(url)
        #expect(saved.project.lighting.positionKeys == s.project.lighting.positionKeys)
        var key = try #require(s.selectedHeadPositionKey); key.pan = 0.2
        s.updateHeadPosition(key); try s.flushRecovery()
        let recovered = try #require(recovery.entries().first)
        #expect(recovered.document.project.lighting.positionKeys == s.project.lighting.positionKeys)
        let reopened = session(); defer { reopened.releaseRuntimeResources() }
        try reopened.load(saved, from: url)
        #expect(reopened.project.lighting.positionKeys == saved.project.lighting.positionKeys)
        #expect(!reopened.transport.isPlaying && reopened.selectedHeadPositionKeyID == nil)
    }
    @Test func chartCoordinatesRoundTripAtEdgesAndClampSafely() throws {
        for size in [CGSize(width: 180, height: 120), CGSize(width: 480, height: 184)] {
            for pan in [0.0, 0.2, 0.5, 1] { for tilt in [0.0, 0.7, 1] {
                let point = HeadPathGeometry.point(pan: pan, tilt: tilt, size: size)
                let pose = try #require(HeadPathGeometry.position(at: point, size: size))
                #expect(abs(pose.pan - pan) < 0.000001 && abs(pose.tilt - tilt) < 0.000001)
            } }
            let clamped = try #require(HeadPathGeometry.position(at: CGPoint(x: -100, y: 900), size: size))
            #expect(clamped.pan == 0 && clamped.tilt == 0)
        }
        #expect(HeadPathGeometry.position(at: .zero, size: .zero) == nil)
        #expect(HeadPathGeometry.position(at: CGPoint(x: CGFloat.nan, y: 10), size: CGSize(width: 180, height: 120)) == nil)
    }
}
