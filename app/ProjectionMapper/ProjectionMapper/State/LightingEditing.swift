import Foundation

enum LightingSelection: Hashable {
    case fixture(UUID), group(String), look(UUID)
}

extension EditorSession {
    var lightingGroups: [String] {
        Array(Set(project.lighting.fixtures.map(\.group).filter { !$0.isEmpty })).sorted()
    }
    var selectedLightingFixtures: [PatchedFixture] {
        switch lightingSelection {
        case .fixture(let id): return project.lighting.fixtures.filter { $0.id == id }
        case .group(let name): return project.lighting.fixtures.filter { $0.group == name }
        case .look(let id):
            let ids = Set(project.lighting.looks.first { $0.id == id }?.entries.map(\.id) ?? [])
            return project.lighting.fixtures.filter { ids.contains($0.id) }
        case nil: return []
        }
    }
    var selectedLightingFixtureIDs: Set<UUID> { Set(selectedLightingFixtures.map(\.id)) }
    func selectLighting(_ selection: LightingSelection?) {
        selectedHeadPositionKeyID = nil
        lightingSelection = selection
        inspectorTab = .edit
        selectedLightingCueID = nil
        if case .look(let id) = selection { selectedFixtureLookID = id }
        reconcileLightingSelection()
    }
    func reconcileLightingSelection() {
        if let id = selectedHeadPositionKeyID, !project.lighting.positionKeys.contains(where: { $0.id == id }) { selectedHeadPositionKeyID = nil }
        switch lightingSelection {
        case .fixture(let id): if !project.lighting.fixtures.contains(where: { $0.id == id }) { lightingSelection = nil }
        case .group(let name): if !lightingGroups.contains(name) { lightingSelection = nil }
        case .look(let id): if !project.lighting.looks.contains(where: { $0.id == id }) { lightingSelection = nil }
        case nil: break
        }
        lightingHiddenFixtureIDs.formIntersection(Set(project.lighting.fixtures.map(\.id)))
    }
    func intendedLightingState(_ fixture: PatchedFixture) -> FixtureState {
        lightingSimulation.reports[fixture.controllerID]?.fixtures.first { $0.id == fixture.id }?.intended ?? fixture.kind.dark
    }
    /// Manual audition remains runtime-only; Capture Look publishes saved programming through undo.
    func auditionLighting(_ edit: (PatchedFixture, FixtureState) -> FixtureState) {
        guard workspace == .lighting, !lightingSimulation.isStopped else { return }
        for fixture in selectedLightingFixtures {
            let state = edit(fixture, intendedLightingState(fixture))
            guard state.kind == fixture.kind else { continue }
            if case .head(let head) = state, !head.isValid { continue }
            lightingSimulation.override(state, for: fixture)
        }
        refreshLighting()
    }
    func auditionSelectedLightingLook() {
        guard workspace == .lighting, case .look(let id) = lightingSelection,
              let look = project.lighting.looks.first(where: { $0.id == id }), !lightingSimulation.isStopped else { return }
        if isRecordingCues { triggerRecordedLook(look.id); return }
        for entry in look.entries {
            guard let fixture = project.lighting.fixtures.first(where: { $0.id == entry.id }) else { continue }
            lightingSimulation.override(entry.state, for: fixture)
        }
        refreshLighting()
    }
    func clearSelectedLightingOverrides() {
        guard workspace == .lighting else { return }
        for fixture in selectedLightingFixtures { lightingSimulation.override(nil, for: fixture) }
        refreshLighting()
    }
    @discardableResult
    func captureLightingSelection(name: String) -> UUID? {
        guard workspace == .lighting, !selectedLightingFixtures.isEmpty else { return nil }
        let look = FixtureLook(name: name.trimmingCharacters(in: .whitespacesAndNewlines), entries:
            selectedLightingFixtures.map { FixtureLookEntry(id: $0.id, state: intendedLightingState($0)) })
        guard editLighting({ $0.looks.append(look) }) else { return nil }
        selectedFixtureLookID = look.id
        selectLighting(.look(look.id))
        return look.id
    }
    func lightingInsertionTime(_ time: Double) -> Double {
        guard time.isFinite else { return 0 }
        let bounded = min(3600, max(0, time))
        guard timelineSnap else { return bounded }
        if let marker = project.showMarkers.min(by: { abs($0.time - bounded) < abs($1.time - bounded) }),
           abs(marker.time - bounded) <= min(0.3, 10 / max(1, timelineScale)) { return marker.time }
        return bounded.rounded()
    }
    func placeSelectedLightingLook(at time: Double, fixtureIDs: Set<UUID>? = nil) {
        guard workspace != .show, time.isFinite, (0...3600).contains(time), let look = selectedFixtureLook else { return }
        let entries = look.entries.filter { fixtureIDs?.contains($0.id) ?? true }
        guard !entries.isEmpty else { lightingMessage = "The selected look has no fixtures in this target."; return }
        putLightingCue(LightingCue(name: look.name, time: lightingInsertionTime(time), entries: entries))
    }
    func newLightingFixture(kind: FixtureKind) -> PatchedFixture? {
        for controller in project.lighting.controllers where controller.kind == kind.controllerKind {
            for address in 1...controller.capacity {
                var fixture = PatchedFixture(name: kind.rawValue, kind: kind, controllerID: controller.id)
                fixture.address = address; fixture.green = address + 1; fixture.blue = address + 2
                var candidate = project.lighting; candidate.fixtures.append(fixture)
                if candidate.validationIssue() == nil { return fixture }
            }
        }
        return nil
    }
}


extension EditorSession {
    var selectedHeadPositionKey: HeadPositionKey? {
        guard workspace == .lighting else { return nil }
        return project.lighting.positionKeys.first { $0.id == selectedHeadPositionKeyID }
    }
    var positionPathFixture: PatchedFixture? {
        if let key = selectedHeadPositionKey { return project.lighting.fixtures.first { $0.id == key.fixtureID } }
        return selectedLightingFixtures.first { $0.kind == .movingHead }
    }
    func headPositionKeys(for fixtureID: UUID) -> [HeadPositionKey] {
        project.lighting.positionKeys.filter { $0.fixtureID == fixtureID }.sorted { $0.time < $1.time }
    }
    func selectHeadPositionKey(_ id: UUID) {
        guard workspace == .lighting, let key = project.lighting.positionKeys.first(where: { $0.id == id }) else { return }
        selectLighting(.fixture(key.fixtureID))
        selectedClipID = nil; selectedMouthKeyID = nil
        selectedHeadPositionKeyID = id
    }
    func captureHeadPositions(at time: Double) {
        guard workspace == .lighting, time.isFinite else { return }
        let fixtures = selectedLightingFixtures.filter { $0.kind == .movingHead }
        guard !fixtures.isEmpty else { lightingMessage = "Select a moving head or a group containing moving heads."; return }
        let time = lightingInsertionTime(time)
        var keys = project.lighting.positionKeys, selectedID: UUID?
        for fixture in fixtures {
            guard case .head(let head) = intendedLightingState(fixture) else { continue }
            if let index = keys.firstIndex(where: { $0.fixtureID == fixture.id && $0.time == time }) {
                keys[index].pan = head.pan; keys[index].tilt = head.tilt
                selectedID = selectedID ?? keys[index].id
            } else {
                let key = HeadPositionKey(fixtureID: fixture.id, time: time, pan: head.pan, tilt: head.tilt)
                keys.append(key); selectedID = selectedID ?? key.id
            }
        }
        if editLighting({ $0.headPositions = keys }), let selectedID { selectHeadPositionKey(selectedID) }
    }
    func updateHeadPosition(_ key: HeadPositionKey) {
        guard workspace == .lighting, let index = project.lighting.headPositions?.firstIndex(where: { $0.id == key.id }),
              project.lighting.headPositions?[index].fixtureID == key.fixtureID else { return }
        if editLighting({ $0.headPositions?[index] = key }) { selectHeadPositionKey(key.id) }
    }
    func deleteHeadPosition(_ id: UUID) {
        guard workspace == .lighting else { return }
        _ = editLighting { $0.headPositions?.removeAll { $0.id == id } }
    }
    func duplicateHeadPosition(at time: Double) {
        guard workspace == .lighting, time.isFinite, var copy = selectedHeadPositionKey else { return }
        let occupied = Set(headPositionKeys(for: copy.fixtureID).map(\.time))
        var target = lightingInsertionTime(time)
        let step = timelineSnap ? 1.0 : 0.1
        for _ in 0...256 {
            if !occupied.contains(target) { break }
            target = (target + step) * 1000; target = target.rounded() / 1000
        }
        guard target <= 3600 else { lightingMessage = "No free key time at the end of the timeline."; return }
        copy.id = UUID(); copy.time = target
        if editLighting({ $0.headPositions = $0.positionKeys + [copy] }) { selectHeadPositionKey(copy.id) }
    }
}


extension EditorSession {
    func effectTargets(for fixtures: [PatchedFixture]) -> [ChoreographyTarget] {
        let indices = Dictionary(uniqueKeysWithValues: project.lighting.fixtures.enumerated().map { ($0.element.id, $0.offset) })
        return fixtures.compactMap { fixture in
            guard let index = indices[fixture.id] else { return nil }
            let placement = fixture.previewPlacement ?? .initial(index: index, kind: fixture.kind)
            return ChoreographyTarget(id: fixture.id, position: placement.origin)
        }
    }

    @discardableResult
    func saveLightingEffectPreset(from clip: ChoreographyClip) -> Bool {
        guard workspace == .lighting, clip.kind == .fixture else { return false }
        var preset = LightingEffectPreset(clip: clip)
        return editLighting { lighting in
            var presets = lighting.lightingEffectPresets
            if let index = presets.firstIndex(where: { $0.name.caseInsensitiveCompare(preset.name) == .orderedSame }) {
                preset.id = presets[index].id
                presets[index] = preset
            } else {
                presets.append(preset)
            }
            lighting.effectPresets = presets
        }
    }

    func removeLightingEffectPreset(_ id: UUID) {
        guard workspace == .lighting else { return }
        _ = editLighting { lighting in
            let remaining = lighting.lightingEffectPresets.filter { $0.id != id }
            lighting.effectPresets = remaining.isEmpty ? nil : remaining
        }
    }
}
