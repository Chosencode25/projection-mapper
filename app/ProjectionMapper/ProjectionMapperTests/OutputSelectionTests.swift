import Foundation
import CoreGraphics
import Testing

@MainActor
struct OutputSelectionTests {
    private func withState(_ body: (OutputSelectionState, OutputPreferences) -> Void) {
        let suite = "ProjectionMapperTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let preferences = OutputPreferences(defaults: defaults)
        body(OutputSelectionState(preferences: preferences), preferences)
    }
    private func display(_ id: UInt32 = 2, uuid: String? = "projector", name: String = "Projector") -> DisplayDescriptor {
        DisplayDescriptor(id: id, uuid: uuid, name: name,
            desktopFrame: CGRect(x: 0, y: 0, width: 1920, height: 1080),
            renderWidth: 3840, renderHeight: 2160, scale: 2, refreshRate: 59.94)
    }

    @Test func firstLaunchDefaultsToTestEvenWithConnectedDisplay() {
        withState { state, preferences in
            state.update([display()])
            #expect(state.destination == .testWindow)
            #expect(state.renderSizeText == "1280 × 720 px")
            #expect(state.aspectRatio == 16.0 / 9.0)
            #expect(preferences.load() == .testWindow)
        }
    }
    @Test func explicitSelectionRestoresByUUIDDespiteNameOrderAndRuntimeIDChanges() {
        withState { state, preferences in
            state.update([display(), display(3, uuid: "other", name: "Projector")])
            state.select(.display(2))
            let nextRun = OutputSelectionState(preferences: preferences)
            nextRun.update([display(3, uuid: "other"), display(99, name: "Renamed")])
            #expect(nextRun.destination == .display(99))
            #expect(nextRun.selectedName == "Renamed")
            #expect(nextRun.recoveryMessage == nil)
        }
    }
    @Test func disconnectRetainsPreferenceAndReconnectRequiresSelection() {
        withState { state, preferences in
            state.update([display()]); state.select(.display(2))
            state.update([])
            #expect(state.destination == .testWindow)
            #expect(state.statusText.contains("Projector disconnected"))
            #expect(preferences.load().displayUUID == "projector")
            state.update([display(9)])
            #expect(state.destination == .testWindow)
            state.select(.display(9))
            #expect(state.recoveryMessage == nil)
            #expect(state.destination == .display(9))
        }
    }
    @Test func missingSavedDisplayFallsBackWithoutErasingPreference() {
        withState { _, preferences in
            preferences.save(.init(displayUUID: "missing", displayName: "Missing Projector"))
            let state = OutputSelectionState(preferences: preferences)
            state.update([display()])
            #expect(state.destination == .testWindow)
            #expect(state.statusText.contains("Missing Projector not connected"))
            #expect(preferences.load().displayUUID == "missing")
        }
    }
    @Test func ambiguousSavedUUIDDoesNotSelectByName() {
        withState { _, preferences in
            preferences.save(.init(displayUUID: "projector", displayName: "Projector"))
            let state = OutputSelectionState(preferences: preferences)
            state.update([display(), display(3)])
            #expect(state.destination == .testWindow)
            #expect(state.statusText.contains("ambiguous"))
        }
    }
    @Test func explicitTestChoiceClearsRecoveryAndSavedDisplay() {
        withState { state, preferences in
            state.update([display()]); state.select(.display(2)); state.update([])
            state.select(.testWindow)
            #expect(state.recoveryMessage == nil)
            #expect(preferences.load() == .testWindow)
            let next = OutputSelectionState(preferences: preferences)
            next.update([display()])
            #expect(next.destination == .testWindow)
        }
    }
    @Test func unavailableChoicesCannotBeSelectedAndSavedIneligibleTargetFallsBack() {
        withState { state, preferences in
            var editor = display(); editor.isEditorDisplay = true
            var mirror = display(3, uuid: "mirror"); mirror.isMirrored = true
            var unavailable = display(4, uuid: "offline"); unavailable.hasIndependentScreen = false
            state.update([editor, mirror, unavailable])
            for id: UInt32 in [2, 3, 4] { state.select(.display(id)); #expect(state.destination == .testWindow) }
            #expect(preferences.load() == .testWindow)
            preferences.save(.init(displayUUID: "mirror", displayName: "Projector"))
            let next = OutputSelectionState(preferences: preferences)
            next.update([mirror])
            #expect(next.statusText.contains("extended display"))
            #expect(next.destination == .testWindow)
        }
    }
    @Test func editorMovementAndMirroringInvalidateActiveDisplay() {
        withState { state, _ in
            state.update([display()]); state.select(.display(2))
            var moved = display(); moved.isEditorDisplay = true
            state.update([moved])
            #expect(state.destination == .testWindow)
            #expect(state.statusText.contains("Editor display"))
            state.update([display()]); state.select(.display(2))
            var mirrored = display(); mirrored.isMirrored = true
            state.update([mirrored])
            #expect(state.destination == .testWindow)
            #expect(state.statusText.contains("Mirroring enabled"))
        }
    }
    @Test func metadataChangesAndUnrelatedRemovalPreserveSelection() {
        withState { state, _ in
            state.update([display(), display(3, uuid: "other")]); state.select(.display(2))
            var rotated = display(); rotated.renderWidth = 2160; rotated.renderHeight = 3840
            rotated.refreshRate = 120
            state.update([rotated])
            #expect(state.destination == .display(2))
            #expect(state.aspectRatio == 9.0 / 16.0)
            #expect(state.selectedDisplay?.refreshText == "120 Hz")
        }
    }
    @Test func invalidDimensionsAndUnknownRefreshUseHonestFallbacks() {
        withState { state, _ in
            var invalid = display(); invalid.renderWidth = 0; invalid.renderHeight = -1
            invalid.refreshRate = 0; invalid.scale = .nan
            state.update([invalid]); state.select(.display(2))
            #expect(state.aspectRatio == 16.0 / 9.0)
            #expect(state.renderSizeText == "Not reported")
            #expect(state.selectedDisplay?.refreshText == "Not reported")
            #expect(state.selectedDisplay?.scaleText == "Not reported")
            invalid.refreshRate = .infinity
            #expect(invalid.refreshText == "Not reported")
            invalid.refreshRate = nil
            #expect(invalid.refreshText == "Not reported")
        }
    }
    @Test func missingOrDuplicateIdentityRequiresManualSelectionOnRelaunch() {
        for uuid: String? in [nil, "duplicate"] {
            withState { state, preferences in
                state.update([display(uuid: uuid), display(3, uuid: "duplicate")])
                state.select(.display(2))
                #expect(state.destination == .display(2))
                #expect(preferences.load().requiresManualSelection)
                let next = OutputSelectionState(preferences: preferences)
                next.update([display(uuid: uuid)])
                #expect(next.destination == .testWindow)
                #expect(next.statusText.contains("manually"))
            }
        }
    }
    @Test func discoveryFailurePreservesPreferenceAndAllowsStartupRetry() {
        withState { _, preferences in
            preferences.save(.init(displayUUID: "projector", displayName: "Projector"))
            let state = OutputSelectionState(preferences: preferences)
            state.update([], error: "Scan failed")
            #expect(state.destination == .testWindow)
            #expect(preferences.load().displayUUID == "projector")
            state.update([display()])
            #expect(state.destination == .display(2))
            state.update([], error: "Scan failed")
            state.update([display()])
            #expect(state.destination == .testWindow)
        }
    }
    @Test func stableUUIDPreservesActiveSelectionWhenRuntimeIDChanges() {
        withState { state, _ in
            state.update([display()]); state.select(.display(2))
            state.update([display(99)])
            #expect(state.destination == .display(99))
            #expect(state.recoveryMessage == nil)
        }
    }
    @Test func reusedRuntimeIDDoesNotSilentlySelectAnotherDisplay() {
        withState { state, _ in
            state.update([display()]); state.select(.display(2))
            state.update([display(uuid: "replacement")])
            #expect(state.destination == .testWindow)
        }
    }
    @Test func duplicateLabelsAreDistinctAndHiDPIMetadataKeepsPixelsSeparateFromPoints() {
        withState { state, _ in
            state.update([display(), display(3, uuid: "other")])
            #expect(state.menuName(for: state.displays[0]) != state.menuName(for: state.displays[1]))
            #expect(state.displays[0].desktopSizeText == "1,920 × 1,080 pt")
            #expect(state.displays[0].renderSizeText == "3840 × 2160 px")
            #expect(state.displays[0].refreshText == "59.94 Hz")
        }
    }
    @Test func outputChangesDoNotDirtyProjectAndResetPreservesOutput() {
        withState { state, preferences in
            let session = EditorSession(output: state)
            let original = session.project
            state.update([display()]); state.select(.display(2))
            #expect(session.project == original)
            #expect(!session.hasUserChanges)
            session.renameProject("House")
            session.resetProject()
            #expect(session.project.id != original.id)
            #expect(state.destination == .display(2))
            #expect(preferences.load().displayUUID == "projector")
        }
    }
}
