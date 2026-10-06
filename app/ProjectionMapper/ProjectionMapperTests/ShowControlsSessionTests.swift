import Foundation
import Testing

@MainActor
struct ShowControlsSessionTests {
    private func session() -> EditorSession {
        let defaults = UserDefaults(suiteName: "v1113.tests." + UUID().uuidString)!
        return EditorSession(output: OutputSelectionState(preferences: OutputPreferences(defaults: defaults)))
    }
    private func palette(_ s: EditorSession) throws -> ColorBinding {
        let id = try #require(s.createPalette(name: "Christmas"))
        let slot = try #require(s.addPaletteSlot(id,name: "Red",color: SIMD4(1,0,0,1)))
        return ColorBinding(paletteID: id,slotID: slot)
    }
    @Test func paletteUpdatesOnlyBoundOwnersAndLiteralEditUnlinksOneChannel() throws {
        let s = session(), binding = try palette(s)
        let a = s.project.surfaces[0].id
        s.bindColor(faceID: a,channel: .primary,binding: binding)
        s.bindColor(faceID: a,channel: .secondary,binding: binding)
        s.addSurface(); let b = s.project.surfaces[0].id
        let untouched = s.project.surfaces[0].source
        s.setPaletteColor(binding.paletteID,slotID: binding.slotID,color: SIMD4(0,1,0,1))
        #expect(s.project.resolvedSource(s.project.surfaces.first { $0.id == a }!.source).color == SIMD4(0,1,0,1))
        #expect(s.project.surfaces.first { $0.id == b }!.source == untouched)
        s.selectSurface(a); s.setSourceColor(SIMD4(0,0,1,1))
        #expect(s.selectedSource?.primaryBinding == nil && s.selectedSource?.secondaryBinding == binding)
        s.bindColor(faceID: a,channel: .secondary,binding: nil)
        #expect(s.selectedSource?.generator.secondaryColor == SIMD4(0,1,0,1))
        #expect(s.selectedSource?.secondaryBinding == nil)
    }
    @Test func paletteSlotRenameReorderAndInvalidEditsPreserveReferences() throws {
        let s = session(), binding = try palette(s), face = s.project.surfaces[0].id
        s.bindColor(faceID: face,channel: .primary,binding: binding)
        _ = s.addPaletteSlot(binding.paletteID,name: "Blue",color: SIMD4(0,0,1,1))
        s.renamePalette(binding.paletteID,name: "Winter")
        s.renamePaletteSlot(binding.paletteID,slotID: binding.slotID,name: "Green")
        s.movePaletteSlot(binding.paletteID,slotID: binding.slotID,offset: 1)
        #expect(s.project.surfaces[0].source.primaryBinding == binding)
        #expect(s.project.palettes[0].slots[1].id == binding.slotID)
        let baseline = s.project
        s.setPaletteColor(binding.paletteID,slotID: binding.slotID,color: SIMD4(.nan,1,1,1))
        s.bindColor(faceID: face,channel: .primary,binding: ColorBinding(paletteID: UUID(),slotID: UUID()))
        s.setMasterBrightness(.nan); s.setFadeDuration(31)
        #expect(s.project == baseline)
        s.setFadeDuration(baseline.masterOutput.fadeDuration)
        #expect(s.editMessage == nil)
    }
    @Test func deletionMaterializesLiveDormantAndLookColorsAtomically() throws {
        let s = session(), binding = try palette(s), a = s.project.surfaces[0].id
        s.bindColor(faceID: a,channel: .primary,binding: binding)
        s.addSurface(); let b = s.project.surfaces[0].id
        s.bindColor(faceID: b,channel: .secondary,binding: binding)
        s.createObject(faceIDs: [a,b])
        let objectID = try #require(s.selectedObjectID)
        s.bindColor(faceID: a,channel: .primary,binding: binding)
        let look = try #require(s.saveLook(name: "Palette look"))
        s.setPaletteColor(binding.paletteID,slotID: binding.slotID,color: SIMD4(0,1,0,1))
        #expect(s.paletteReferenceCount(binding.paletteID) >= 3)
        let before = s.project.renderScene
        s.deletePalette(binding.paletteID)
        #expect(s.project.palettes.isEmpty && s.paletteReferenceCount(binding.paletteID) == 0)
        #expect(s.project.renderScene == before)
        #expect(s.project.objects.first { $0.id == objectID }?.source.color == SIMD4(0,1,0,1))
        s.setSourceColor(SIMD4(0,0,1,1)); s.applyLook(look)
        #expect(s.project.objects.first { $0.id == objectID }?.source.color == SIMD4(0,1,0,1))
        try ProjectCodec.validate(s.document)
    }
    @Test func deleteOneSlotKeepsOtherBindingsAndLooksFollowCurrentPalette() throws {
        let s = session(), binding = try palette(s), face = s.project.surfaces[0].id
        let otherSlot = try #require(s.addPaletteSlot(binding.paletteID,name: "Blue",color: SIMD4(0,0,1,1)))
        let other = ColorBinding(paletteID: binding.paletteID,slotID: otherSlot)
        s.bindColor(faceID: face,channel: .primary,binding: binding)
        s.bindColor(faceID: face,channel: .secondary,binding: other)
        let look = try #require(s.saveLook(name: "Bound"))
        s.setPaletteColor(binding.paletteID,slotID: binding.slotID,color: SIMD4(0,1,0,1))
        s.setSourceColor(SIMD4(0,0,0,1)); s.applyLook(look)
        #expect(s.project.resolvedSource(s.selectedSource!).color == SIMD4(0,1,0,1))
        s.deletePaletteSlot(binding.paletteID,slotID: binding.slotID)
        #expect(s.selectedSource?.color == SIMD4(0,1,0,1) && s.selectedSource?.primaryBinding == nil)
        #expect(s.selectedSource?.secondaryBinding == other)
        #expect(s.project.palettes[0].slots.count == 1)
        try ProjectCodec.validate(s.document)
    }
    @Test func groupingDetachDuplicationAndPresetsRetainDefinedColorOwnership() throws {
        let s = session(), binding = try palette(s)
        let a = s.project.surfaces[0].id
        s.bindColor(faceID: a,channel: .primary,binding: binding)
        s.addSurface(); let b = s.project.surfaces[0].id
        s.bindColor(faceID: b,channel: .primary,binding: binding)
        s.createObject(faceIDs: [a,b]); let object = try #require(s.selectedObjectID)
        #expect(s.selectedSource?.primaryBinding == binding)
        s.duplicateObject(object); #expect(s.selectedSource?.primaryBinding == binding)
        s.detachSurface(a); s.selectSurface(a)
        #expect(s.selectedSource?.primaryBinding == binding)
        s.setSurfaceContent(.gradient)
        s.setPaletteColor(binding.paletteID,slotID: binding.slotID,color: SIMD4(0,1,0,1))
        let preset = try #require(s.saveGeneratorPreset(name: "Literal"))
        #expect(s.project.generatorPresets[0].color == SIMD4(0,1,0,1))
        s.applyGeneratorPreset(preset); #expect(s.selectedSource?.primaryBinding == nil)
        s.bindColor(faceID: a,channel: .secondary,binding: binding)
        s.resetGeneratorSettings(); #expect(s.selectedSource?.secondaryBinding == nil)
    }
    @Test func lookRecallPreservesLayoutLocksVisibilityNamesIdentityAndPlayback() throws {
        let s = session(); s.addSurface(); s.createObject(faceIDs: Set(s.project.surfaces.map(\.id)))
        let object = try #require(s.selectedObjectID), face = s.project.surfaces[0].id
        s.setSurfaceContent(.particles); s.setPlaying(true,at: 10); s.seekPlayback(to: 20,at: 12)
        s.setSelectedPaused(true,at: 12)
        let look = try #require(s.saveLook(name: "Snow"))
        s.setSurfaceContent(.solid); s.renameObject(object,"Renamed"); s.setGeometryLocked(true,objectID: object)
        s.setVisible(false,faceID: face); s.setObjectMode(.repeatContent,id: object)
        let old = s.project, transport = s.transport, clocks = s.sourcePlayback
        s.blackoutOutput(); s.applyLook(look)
        #expect(s.project.objects[0].source.content == .particles)
        #expect(s.project.objects[0].source.id == old.objects[0].source.id)
        #expect(s.project.objects[0].name == "Renamed" && s.project.objects[0].isGeometryLocked)
        #expect(s.project.objects[0].mode == .repeatContent && s.showOutput.isBlackout)
        #expect(s.project.surfaces.map(\.layout) == old.surfaces.map(\.layout))
        #expect(s.project.objects[0].links == old.objects[0].links)
        #expect(s.transport == transport && s.sourcePlayback == clocks)
    }
    @Test func missingAndReparentedTargetsAreReportedWithoutRemapping() throws {
        let s = session(); s.addSurface(); s.createObject(faceIDs: Set(s.project.surfaces.map(\.id)))
        let object = try #require(s.selectedObjectID), face = s.project.surfaces[0].id
        let look = try #require(s.saveLook(name: "Original"))
        s.setAppearanceOverride(true,faceID: face)
        s.applyLook(look); #expect(s.project.surfaces[0].appearanceOverride == nil)
        s.detachSurface(face); s.selectSurface(face); s.setSurfaceContent(.solid)
        s.duplicateSurface(face); let copy = s.project.surfaces[0]
        s.applyLook(look)
        #expect(s.lastLookReport?.contains("skipped 1") == true)
        #expect(s.project.surfaces.first { $0.id == face }?.content == .solid)
        #expect(s.project.surfaces.first { $0.id == copy.id } == copy)
        s.deleteObject(object); s.applyLook(look)
        #expect(s.lastLookReport?.contains("Applied 0") == true)
    }
    @Test func lookUpdateRenameDeletePreserveIDAndExcludeMaster() throws {
        let s = session(), look = try #require(s.saveLook(name: "First"))
        s.setSurfaceContent(.solid); s.setMasterBrightness(0.3)
        s.updateLook(look); s.renameLook(look,name: "  Evening  ")
        #expect(s.project.looks[0].id == look && s.project.looks[0].name == "Evening")
        s.setSurfaceContent(.particles); s.setMasterBrightness(0.7); s.applyLook(look)
        #expect(s.selectedSource?.content == .solid && s.project.masterOutput.brightness == 0.7)
        s.deleteLook(look); #expect(s.project.looks.isEmpty)
    }
    @Test func malformedLookAbortsBeforePublishingAnyTargetChanges() {
        var project = MappingProject()
        var source = SourceLook(source: project.surfaces[0].source); source.content = .solid
        let first = LookEntry(targetID: project.surfaces[0].id, kind: .standaloneFace, source: source, appearance: .defaults)
        var appearance = SurfaceAppearance.defaults; appearance.opacity = -1
        let invalid = LookEntry(targetID: UUID(), kind: .standaloneFace, source: source, appearance: appearance)
        let look = ProjectLook(name: "Malformed", entries: [first,invalid]); project.looks = [look]
        let s = EditorSession(project: project)
        s.applyLook(look.id)
        #expect(s.project == project && s.lastLookReport?.contains("no targets changed") == true)
    }
    @Test func temporaryOutputActionsStayCleanAndSharedEvenWithPausedStaticContent() throws {
        let s = session(), original = s.project
        s.fadeToBlack(at: 10)
        #expect(s.showOutput.gain(at: 10.5) == 0.5)
        #expect(s.scene == s.testOutput.scene)
        s.restoreOutput(at: 10.5)
        #expect(s.showOutput.gain(at: 11) == 0.75)
        s.blackoutOutput(); s.setPlaying(true,at: 11); s.seekPlayback(to: 15,at: 12)
        #expect(s.showOutput.isBlackout)
        s.restoreOutput(at: 12)
        #expect(s.showOutput.gain(at: 12) == 0 && s.showOutput.gain(at: 13) == 1)
        #expect(s.project == original && !s.hasUserChanges)
        #expect(s.scene == s.testOutput.scene)
    }
    @Test func savingRecoveryAndOpeningPersistLibrariesButResetTransientOutput() throws {
        let s = session(), binding = try palette(s), face = s.project.surfaces[0].id
        s.bindColor(faceID: face,channel: .primary,binding: binding)
        _ = try #require(s.saveLook(name: "Saved")); s.setMasterBrightness(0.4); s.setFadeDuration(2)
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: dir,withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        let url = dir.appendingPathComponent("Show.projectionmap")
        try s.save(to: url); #expect(!s.hasUserChanges)
        let recovery = ProjectRecoveryStore(directory: dir.appendingPathComponent("Recovery"))
        s.configureRecovery(recovery); s.blackoutOutput(); try s.flushRecovery()
        #expect(recovery.entries().isEmpty && !s.hasUserChanges)
        s.renameLook(s.project.looks[0].id,name: "Recovery look"); try s.flushRecovery()
        #expect(recovery.entries().count == 1)
        let saved = try ProjectPackageStore().read(url)
        try s.load(saved,from: url)
        #expect(s.project.looks[0].name == "Saved" && s.project.masterOutput.brightness == 0.4)
        #expect(!s.showOutput.isBlackout && s.showOutput.gain(at: 0) == 1 && !s.hasUserChanges)
        #expect(!s.transport.isPlaying)
        s.blackoutOutput(); s.resetProject(); #expect(!s.showOutput.isBlackout && s.project.looks.isEmpty)
    }
}
