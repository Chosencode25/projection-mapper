import Foundation
import Testing

@MainActor
struct ShowControlsPersistenceTests {
    func document() -> ProjectDocument {
        let first = PaletteSlot(name: "Warm", color: SIMD4(1, 0.2, 0.05, 1))
        let second = PaletteSlot(name: "Cool", color: SIMD4(0.1, 0.4, 1, 0.6))
        let palette = ColorPalette(name: "Christmas", slots: [first, second])
        var project = MappingProject()
        project.palettes = [palette]
        var source = SurfaceSource(content: .gradient)
        source.primaryBinding = ColorBinding(paletteID: palette.id, slotID: first.id)
        source.secondaryBinding = ColorBinding(paletteID: palette.id, slotID: second.id)
        var object = MappingObject(name: "House", source: source)
        object.appearance.brightness = 1.4; object.isGeometryLocked = true
        project.objects = [object]
        project.surfaces[0].layout.objectID = object.id
        // The retained dormant source must also carry valid references through save/load.
        project.surfaces[0].source.primaryBinding = source.primaryBinding
        project.surfaces.append(MappingSurface(name: "Tree", content: .solid))
        project.masterOutput = MasterOutputSettings(brightness: 0.65, fadeDuration: 2.5)
        project.looks = [ProjectLook(name: "Evening", entries: [
            LookEntry(targetID: object.id, kind: .object, source: SourceLook(source: source), appearance: object.appearance),
            LookEntry(targetID: project.surfaces[0].id, kind: .memberFace, expectedObjectID: object.id),
            LookEntry(targetID: project.surfaces[1].id, kind: .standaloneFace,
                      source: SourceLook(source: project.surfaces[1].source), appearance: project.surfaces[1].appearance)
        ])]
        return ProjectDocument(project: project)
    }

    @Test func librariesBindingsAndMasterRoundTripWithResolvedSharedRenderColors() throws {
        let original = document()
        let decoded = try ProjectCodec.decode(ProjectCodec.encode(original))
        #expect(decoded == original)
        #expect(decoded.formatVersion == 5)
        #expect(decoded.project.renderScene == original.project.renderScene)
        let raw = decoded.project.source(for: decoded.project.surfaces[0])
        #expect(raw.color == SIMD4(1, 0.25, 0, 1))
        let resolved = decoded.project.resolvedSource(raw)
        #expect(resolved.id == raw.id && resolved.primaryBinding == raw.primaryBinding)
        #expect(resolved.color == decoded.project.palettes[0].slots[0].color)
        #expect(resolved.generator.secondaryColor == decoded.project.palettes[0].slots[1].color)
        #expect(decoded.project.renderScene.surfaces.last?.sourceID == raw.id)
        #expect(decoded.project.renderScene.surfaces.last?.color == resolved.color)
        #expect(decoded.project.renderScene.masterBrightness == 0.65)
    }

    @Test func everyEarlierSchemaAddsDefaultsPreservesIDsAndV4KeepsAppearanceLocks() throws {
        let original = document()
        for version in 1...4 {
            var json = try #require(JSONSerialization.jsonObject(with: ProjectCodec.encode(original)) as? [String: Any])
            json["formatVersion"] = version
            var project = try #require(json["project"] as? [String: Any])
            for key in ["palettes", "looks", "masterOutput"] { project.removeValue(forKey: key) }
            for key in ["surfaces", "objects"] {
                let values = try #require(project[key] as? [[String: Any]])
                project[key] = try values.map { item in
                    var item = item
                    var source = try #require(item["source"] as? [String: Any])
                    source.removeValue(forKey: "primaryBinding"); source.removeValue(forKey: "secondaryBinding")
                    item["source"] = source; return item
                }
            }
            if version == 1 { project.removeValue(forKey: "generatorPresets"); json.removeValue(forKey: "output") }
            json["project"] = project
            let decoded = try ProjectCodec.decode(JSONSerialization.data(withJSONObject: json))
            #expect(decoded.formatVersion == 5 && decoded.project.palettes.isEmpty && decoded.project.looks.isEmpty)
            #expect(decoded.project.masterOutput == .defaults)
            #expect(decoded.project.id == original.project.id)
            #expect(decoded.project.surfaces.map(\.id) == original.project.surfaces.map(\.id))
            #expect(decoded.project.objects[0].source.id == original.project.objects[0].source.id)
            #expect(decoded.project.objects[0].source.primaryBinding == nil)
            #expect(decoded.project.surfaces[0].layout.inputMap == original.project.surfaces[0].layout.inputMap)
            if version == 4 {
                #expect(decoded.project.objects[0].appearance == original.project.objects[0].appearance)
                #expect(decoded.project.objects[0].isGeometryLocked)
            }
        }
    }

    @Test func staleTargetsAreAllowedButMalformedPayloadsAndDuplicateTargetKeysAreRejected() throws {
        var doc = document()
        doc.project.looks[0].entries[0].targetID = UUID()
        doc.project.looks[0].entries[1].expectedObjectID = UUID()
        #expect(try ProjectCodec.decode(ProjectCodec.encode(doc)) == doc)
        let original = doc
        doc.project.looks[0].entries[0].source = nil
        #expect(throws: ProjectFileError.self) { try ProjectCodec.validate(doc) }
        doc = original; doc.project.looks[0].entries[0].appearance = nil
        #expect(throws: ProjectFileError.self) { try ProjectCodec.validate(doc) }
        doc = original; doc.project.looks[0].entries[1].expectedObjectID = nil
        #expect(throws: ProjectFileError.self) { try ProjectCodec.validate(doc) }
        doc = original; doc.project.looks[0].entries[1].source = doc.project.looks[0].entries[0].source
        #expect(throws: ProjectFileError.self) { try ProjectCodec.validate(doc) }
        doc = original; doc.project.looks[0].entries.append(doc.project.looks[0].entries[0])
        #expect(throws: ProjectFileError.self) { try ProjectCodec.validate(doc) }
    }

    @Test func unresolvedPaletteReferencesOnLiveDormantAndStoredSourcesAreRejected() throws {
        let original = document()
        var doc = original; doc.project.objects[0].source.primaryBinding?.paletteID = UUID()
        #expect(throws: ProjectFileError.self) { try ProjectCodec.validate(doc) }
        doc = original; doc.project.objects[0].source.secondaryBinding?.slotID = UUID()
        #expect(throws: ProjectFileError.self) { try ProjectCodec.validate(doc) }
        doc = original; doc.project.surfaces[0].source.primaryBinding?.slotID = UUID()
        #expect(throws: ProjectFileError.self) { try ProjectCodec.validate(doc) }
        doc = original; doc.project.looks[0].entries[0].source?.primaryBinding?.slotID = UUID()
        #expect(throws: ProjectFileError.self) { try ProjectCodec.validate(doc) }
        var source = original.project.objects[0].source; source.primaryBinding?.slotID = UUID()
        #expect(original.project.resolvedSource(source).color == source.color)
        #expect(original.project.resolvedSource(source).generator.secondaryColor == original.project.palettes[0].slots[1].color)
    }

    @Test func newNamesIDsColorsSettingsAndCollectionBoundsAreValidated() throws {
        let original = document()
        var doc = original; doc.project.palettes[0].name = "  "
        #expect(throws: ProjectFileError.self) { try ProjectCodec.validate(doc) }
        doc = original; doc.project.palettes.append(doc.project.palettes[0])
        #expect(throws: ProjectFileError.self) { try ProjectCodec.validate(doc) }
        doc = original; doc.project.palettes[0].slots.append(doc.project.palettes[0].slots[0])
        #expect(throws: ProjectFileError.self) { try ProjectCodec.validate(doc) }
        doc = original; doc.project.palettes[0].slots[0].color.x = .nan
        #expect(throws: ProjectFileError.self) { try ProjectCodec.validate(doc) }
        doc = original; doc.project.looks[0].entries[0].source?.color.w = 1.1
        #expect(throws: ProjectFileError.self) { try ProjectCodec.validate(doc) }
        doc = original; doc.project.masterOutput.brightness = 1.01
        #expect(throws: ProjectFileError.self) { try ProjectCodec.validate(doc) }
        doc = original; doc.project.masterOutput.fadeDuration = .infinity
        #expect(throws: ProjectFileError.self) { try ProjectCodec.validate(doc) }
        doc = original; doc.project.masterOutput.fadeDuration = 30.01
        #expect(throws: ProjectFileError.self) { try ProjectCodec.validate(doc) }
        doc = original; doc.project.masterOutput.fadeDuration = 0
        try ProjectCodec.validate(doc)
        doc = original; doc.project.palettes[0].slots = (0..<33).map { PaletteSlot(name: "Slot \($0)", color: SIMD4(1,1,1,1)) }
        #expect(throws: ProjectFileError.self) { try ProjectCodec.validate(doc) }
        doc = original; doc.project.looks = (0..<101).map { ProjectLook(name: "Look \($0)", entries: []) }
        #expect(throws: ProjectFileError.self) { try ProjectCodec.validate(doc) }
        doc = original; doc.project.palettes = (0..<101).map { ColorPalette(name: "Palette \($0)", slots: []) }
        #expect(throws: ProjectFileError.self) { try ProjectCodec.validate(doc) }
        doc = original; doc.project.looks[0].entries = (0..<2001).map { _ in LookEntry(targetID: UUID(), kind: .memberFace, expectedObjectID: UUID()) }
        #expect(throws: ProjectFileError.self) { try ProjectCodec.validate(doc) }
    }

    @Test func newDeclarativeValuesParticipateInDefaultDetectionAndLookRecallPreservesSourceIdentity() {
        var project = MappingProject(); #expect(project.hasDefaultContent)
        project.masterOutput.brightness = 0.9; #expect(!project.hasDefaultContent)
        project.masterOutput = .defaults
        project.palettes = [ColorPalette(name: "Colors", slots: [])]; #expect(!project.hasDefaultContent)
        project.palettes = []; project.looks = [ProjectLook(name: "Empty", entries: [])]; #expect(!project.hasDefaultContent)
        var existing = SurfaceSource(content: .particles); existing.generator.seed = 713
        let look = SourceLook(source: document().project.objects[0].source)
        let applied = look.applying(to: existing)
        #expect(applied.id == existing.id && applied.content == look.content && applied.generator == look.generator)
        #expect(applied.primaryBinding == look.primaryBinding && applied.secondaryBinding == look.secondaryBinding)
    }

    @Test func invalidLibrarySaveKeepsLastGoodPackageAndRecoveryRetainsLibraries() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: false)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = ProjectPackageStore(), url = directory.appendingPathComponent("Show.projectionmap")
        let original = document(); try store.write(original, to: url)
        var invalid = original; invalid.project.palettes.removeAll()
        #expect(throws: ProjectFileError.self) { try store.write(invalid, to: url) }
        #expect(try store.read(url) == original)
        let recovery = ProjectRecoveryStore(directory: directory.appendingPathComponent("Recovery"))
        try recovery.save(original, original: url)
        let recovered = try #require(recovery.entries().first?.document)
        #expect(recovered.project == original.project && recovered.recovery?.originalPath == url.path)
    }

    @Test func oversizedStructurallyValidLibraryCannotProduceUnreadableManifest() throws {
        var doc = ProjectDocument(project: MappingProject())
        let source = SourceLook(source: SurfaceSource())
        // Stale targets are legal, and each look remains within the 2,000-entry bound.
        let entries = (0..<2000).map { _ in
            LookEntry(targetID: UUID(), kind: .standaloneFace, source: source, appearance: .defaults)
        }
        doc.project.looks = (0..<20).map { ProjectLook(name: "Look \($0)", entries: entries) }
        try ProjectCodec.validate(doc)
        do {
            _ = try ProjectCodec.encode(doc)
            Issue.record("An oversized library produced a manifest that cannot be reopened")
        } catch let ProjectFileError.invalid(message) {
            #expect(message == "manifest exceeds 16 MB")
        }
    }
}
