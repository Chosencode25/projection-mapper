import Foundation
import Testing

@MainActor
struct LightingEditingTests {
    private func session() -> EditorSession {
        let dmx = LightingController(name: "Heads", kind: .dmx)
        let relays = LightingController(name: "Relays", kind: .arduino)
        var a = PatchedFixture(name: "Front Head", group: "Front", kind: .movingHead, controllerID: dmx.id)
        a.address = 1
        var b = PatchedFixture(name: "Back Head", group: "Back", kind: .movingHead, controllerID: dmx.id)
        b.address = 10
        let plug = PatchedFixture(name: "Front Plug", group: "Front", kind: .plug, controllerID: relays.id)
        var strip = PatchedFixture(name: "Front Strip", group: "Front", kind: .rgb, controllerID: relays.id)
        strip.address = 2; strip.green = 3; strip.blue = 4
        var project = MappingProject(name: "Lighting rehearsal")
        project.lighting.controllers = [dmx, relays]; project.lighting.fixtures = [a, b, plug, strip]
        let defaults = UserDefaults(suiteName: "lighting.workspace." + UUID().uuidString)!
        return EditorSession(project: project, output: OutputSelectionState(preferences: OutputPreferences(defaults: defaults)))
    }
    @Test func switchingPreservesProjectClockAndSharedUndoAndRequiresShowPause() async throws {
        let s = session(); defer { s.releaseRuntimeResources() }
        s.renameProject("Shared show"); s.timelineScale = 60
        s.setPlaying(true, at: 100)
        let p = s.project, clock = s.transport
        s.switchWorkspace(to: .lighting, at: 101)
        #expect(s.project == p && s.transport == clock && s.canUndo)
        #expect(s.transport.elapsed(at: 102) == 2)
        s.selectLighting(.group("Front"))
        let selected = s.lightingSelection
        s.switchWorkspace(to: .edit); s.switchWorkspace(to: .lighting)
        #expect(s.lightingSelection == selected && s.timelineScale == 60)
        s.switchWorkspace(to: .show, at: 102)
        #expect(s.workspace == .show && !s.playbackRequested && s.transport.position == 2)
        await s.prepareShow()
        #expect(s.setPlaying(true, at: 102))
        s.switchWorkspace(to: .lighting, at: 103)
        #expect(s.workspace == .show && s.transport.isPlaying && !s.canUndo)
        s.switchWorkspace(to: .lighting, pauseRunningShow: true, at: 103)
        #expect(s.workspace == .lighting && !s.transport.isPlaying && s.transport.elapsed(at: 999) == 3)
        #expect(s.project == p && s.canUndo && s.testOutput.window == nil)
        s.undoProjectEdit()
        #expect(s.project.name == "Lighting rehearsal")
    }
    @Test func mixedGroupAuditionTargetsOnlySupportedSelectedFixturesAndCaptureIsUndoable() throws {
        let s = session(); defer { s.releaseRuntimeResources() }
        s.switchWorkspace(to: .lighting); s.selectLighting(.group("Front"))
        #expect(s.selectedLightingFixtures.count == 3 && s.lightingGroups == ["Back", "Front"])
        let before = s.project
        s.lightingSimulation.resume(); s.refreshLighting(at: 100)
        s.auditionLighting { _, state in
            switch state {
            case .head(var head): head.pan = 0.3; head.dimmer = 0.7; return .head(head)
            case .plug: return .plug(true)
            case .rgb: return .rgb(.red)
            }
        }
        #expect(s.project == before)
        #expect(Set(s.lightingSimulation.overrides.keys) == s.selectedLightingFixtureIDs)
        let back = s.project.lighting.fixtures[1]
        #expect(s.lightingSimulation.overrides[back.id] == nil)
        for fixture in s.selectedLightingFixtures {
            switch s.intendedLightingState(fixture) {
            case .head(let head): #expect(head.pan == 0.3 && head.dimmer == 0.7)
            case .plug(let on): #expect(on)
            case .rgb(let color): #expect(color == .red)
            }
        }
        let id = try #require(s.captureLightingSelection(name: "Front red"))
        #expect(s.project.lighting.looks.first?.entries.count == 3 && s.selectedFixtureLookID == id)
        let retained = s.project.lighting.looks.first
        s.auditionLighting { _, state in
            if case .head(var head) = state { head.pan = 4; return .head(head) }
            return state
        }
        #expect(s.project.lighting.looks.first == retained)
        s.clearSelectedLightingOverrides()
        #expect(s.lightingSimulation.overrides.isEmpty)
        s.auditionSelectedLightingLook()
        #expect(s.lightingSimulation.overrides.count == 3)
        s.undoProjectEdit()
        #expect(s.project.lighting.looks.isEmpty && s.lightingSelection == nil)
        s.redoProjectEdit()
        #expect(s.project.lighting.looks.first?.id == id)
    }
    @Test func cueTargetsSnapAndSeekReconstructSimulationWithoutChangingMapping() throws {
        let s = session(); defer { s.releaseRuntimeResources() }
        s.switchWorkspace(to: .lighting); s.selectLighting(.group("Front"))
        s.lightingSimulation.resume(); s.refreshLighting()
        s.auditionLighting { fixture, state in fixture.kind == .plug ? .plug(true) : state }
        let lookID = try #require(s.captureLightingSelection(name: "On"))
        let plug = s.project.lighting.fixtures.first { $0.kind == .plug }!
        let surfaces = s.project.surfaces
        s.timelineSnap = true
        s.placeSelectedLightingLook(at: 2.1, fixtureIDs: [plug.id])
        let cue = try #require(s.selectedLightingCue)
        #expect(cue.time == 2 && cue.entries.map(\.id) == [plug.id])
        #expect(s.lightingSelection == nil && s.selectedFixtureLookID == lookID)
        s.clearSelectedLightingOverrides()
        s.lightingSimulation.override(nil, for: plug)
        s.seekPlayback(to: 1, at: 100)
        s.lightingSimulation.resume(); s.refreshLighting(at: 100)
        #expect(s.intendedLightingState(plug) == .plug(false))
        s.seekPlayback(to: 3, at: 100); s.refreshLighting(at: 100)
        #expect(s.intendedLightingState(plug) == .plug(true))
        s.seekPlayback(to: 0.5, at: 100); s.refreshLighting(at: 100)
        #expect(s.intendedLightingState(plug) == .plug(false))
        #expect(s.project.surfaces == surfaces)
        s.timelineSnap = false
        #expect(s.lightingInsertionTime(2.125) == 2.125)
        s.switchWorkspace(to: .show)
        s.placeSelectedLightingLook(at: 4)
        #expect(s.project.lighting.cues.count == 1)
    }
    @Test func keyboardActionsNeverTouchStaleProjectionSelection() throws {
        let s = session(); defer { s.releaseRuntimeResources() }
        let surfaces = s.project.surfaces, selectedFace = s.selectedSurfaceID
        s.switchWorkspace(to: .lighting)
        for action: EditorAction in [.delete, .duplicate, .visibility, .addSurface, .importImage, .addClip, .previousSurface] {
            #expect(!s.canPerformEditorAction(action))
            s.performEditorAction(action)
        }
        #expect(s.project.surfaces == surfaces)
        s.selectLighting(.group("Front")); s.performEditorAction(.deselect)
        #expect(s.selectedSurfaceID == selectedFace && s.lightingSelection == nil)
        let plug = s.project.lighting.fixtures.first { $0.kind == .plug }!
        s.putLightingCue(LightingCue(name: "Plug", time: 2, entries: [FixtureLookEntry(id: plug.id, state: .plug(true))]))
        #expect(s.canPerformEditorAction(.delete) && s.canPerformEditorAction(.duplicate))
        s.performEditorAction(.duplicate)
        #expect(s.project.lighting.cues.count == 2)
        s.performEditorAction(.delete)
        #expect(s.project.lighting.cues.count == 1 && s.project.surfaces == surfaces)
    }
    @Test func selectionCleanupAndPatchCreationKeepRelationshipsValid() throws {
        let s = session(); defer { s.releaseRuntimeResources() }
        s.switchWorkspace(to: .lighting)
        let first = s.project.lighting.fixtures[0]
        s.selectLighting(.fixture(first.id)); s.lightingHiddenFixtureIDs = [first.id]
        #expect(s.editLighting { $0.removeFixture(first.id) })
        #expect(s.lightingSelection == nil && s.lightingHiddenFixtureIDs.isEmpty)
        s.selectLighting(.group("Front"))
        #expect(s.editLighting { lighting in
            for i in lighting.fixtures.indices { lighting.fixtures[i].group = "" }
        })
        #expect(s.lightingSelection == nil)
        for kind in FixtureKind.allCases {
            let fixture = try #require(s.newLightingFixture(kind: kind))
            #expect(s.editLighting { $0.fixtures.append(fixture) })
            #expect(s.project.lighting.validationIssue() == nil)
        }
        s.selectLighting(.fixture(UUID()))
        #expect(s.selectedLightingFixtures.isEmpty && s.lightingSelection == nil)
    }
    @Test func autosaveReopenAndPlaygroundLightingEntryShareTheSameProject() async throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: folder) }
        let previous = UserDefaults.standard.string(forKey: "ProjectionMapper.lastDraft")
        defer { UserDefaults.standard.set(previous, forKey: "ProjectionMapper.lastDraft") }
        let s = session(); defer { s.releaseRuntimeResources() }
        s.configureAutosave(directory: folder); s.switchWorkspace(to: .lighting)
        s.selectLighting(.group("Front"))
        #expect(s.captureLightingSelection(name: "Dark") != nil)
        try await s.flushAutosave()
        let url = try #require(s.documentURL)
        let saved = try ProjectPackageStore().read(url)
        #expect(saved.project.lighting.looks.count == 1)
        let reopened = session(); defer { reopened.releaseRuntimeResources() }
        try reopened.load(saved, from: url)
        #expect(reopened.project.id == s.project.id && reopened.project.lighting == s.project.lighting)
        reopened.configureAutosave(directory: folder)
        try await reopened.startPlaygroundShow(saved, images: [:], startingWorkspace: .lighting)
        #expect(reopened.workspace == .lighting && reopened.isManagedDraft && reopened.project.id != saved.project.id)
        #expect(reopened.project.lighting.fixtures == saved.project.lighting.fixtures && reopened.project.lighting.looks.isEmpty)
        #expect(!reopened.transport.isPlaying && reopened.lightingSelection == nil)
    }
}
