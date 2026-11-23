import Foundation
import Testing

@MainActor
struct EffectPackTests {
    @Test func exportImportSelectsItemsRenamesConflictsAndSurvivesRoundTrip() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: false)
        defer { try? FileManager.default.removeItem(at: directory) }
        let red = PaletteSlot(name: "Red", color: SIMD4(1, 0, 0, 1))
        let palette = ColorPalette(name: "Christmas", slots: [red])
        let snow = GeneratorPreset(name: "Snow", content: .snowfall, color: SIMD4(1, 1, 1, 1), settings: .defaults)
        let chase = LightingEffectPreset(clip: ChoreographyClip(name: "Roof Chase", pattern: .bounce))
        let pack = EffectPack(name: "Christmas looks", items: [.palette(palette), .projection(snow), .lighting(chase)])
        let url = directory.appendingPathComponent("Christmas.projectionpack")
        try EffectPackStore.write(pack, to: url)
        let originalBytes = try Data(contentsOf: url)
        #expect(throws: DeliveryError.self) { try EffectPackStore.write(pack, to: url) }
        #expect(try Data(contentsOf: url) == originalBytes)
        let imported = try EffectPackStore.read(url)
        #expect(imported.name == pack.name && imported.items.map(\.id) == pack.items.map(\.id))

        var destination = MappingProject(name: "Different show")
        var old = palette
        old.name = "CHRISTMAS"
        destination.palettes = [old, ColorPalette(name: "Christmas (2)", slots: [])]
        let session = EditorSession(presentOutput: { _ in }, project: destination)
        defer { session.releaseRuntimeResources() }
        try session.importEffectPack(imported, choices: [
            imported.items[0].id: .keepBoth, imported.items[2].id: .keepBoth
        ])
        #expect(session.project.palettes.map(\.name) == ["CHRISTMAS", "Christmas (2)", "Christmas (3)"])
        let new = try #require(session.project.palettes.last)
        #expect(new.id != palette.id && new.slots.first?.id != red.id && new.slots.first?.color == red.color)
        #expect(session.project.generatorPresets.isEmpty)
        let light = try #require(session.project.lighting.lightingEffectPresets.first)
        #expect(light.id != chase.id && light.pattern == .bounce)
        #expect(session.project.surfaces == destination.surfaces && session.project.timelineClips.isEmpty)
        let document = session.document
        let package = directory.appendingPathComponent("New Show.projectionmap")
        try ProjectPackageStore().write(document, to: package)
        #expect(try ProjectPackageStore().read(package) == document)
        session.undoProjectEdit()
        #expect(session.project == destination)
        session.redoProjectEdit()
        #expect(session.document == document)
    }

    @Test func replacingPreservesMatchingBindingsAndFreezesRemovedColors() throws {
        let blue = PaletteSlot(name: "Blue", color: SIMD4(0, 0, 1, 1))
        let white = PaletteSlot(name: "White", color: SIMD4(1, 1, 1, 1))
        let shared = ColorPalette(name: "Winter", slots: [blue, white])
        let newBlue = PaletteSlot(name: "BLUE", color: SIMD4(0, 1, 1, 1))
        let incoming = ColorPalette(name: "winter", slots: [newBlue])
        let oldSnow = GeneratorPreset(name: "Snow", content: .snowfall, color: blue.color, settings: .defaults)
        let newSnow = GeneratorPreset(name: "snow", content: .snowfall, color: newBlue.color, settings: .defaults)
        let oldChase = LightingEffectPreset(clip: ChoreographyClip(name: "Chase", pattern: .forward))
        let newChase = LightingEffectPreset(clip: ChoreographyClip(name: "CHASE", pattern: .reverse))
        let pack = EffectPack(name: "Updated Winter", items: [.palette(incoming), .projection(newSnow), .lighting(newChase)])

        var project = MappingProject()
        project.palettes = [shared]
        project.generatorPresets = [oldSnow]
        project.lighting.effectPresets = [oldChase]
        let linked = ColorBinding(paletteID: shared.id, slotID: blue.id)
        let removed = ColorBinding(paletteID: shared.id, slotID: white.id)
        project.surfaces[0].source.primaryBinding = linked
        project.surfaces[0].source.secondaryBinding = removed
        var track = VisualTrack(name: "Snow layer")
        track.source.primaryBinding = removed
        project.visualLayers = [VisualLayer(ownerID: project.surfaces[0].source.id, track: track)]
        let session = EditorSession(presentOutput: { _ in }, project: project)
        defer { session.releaseRuntimeResources() }
        let choices: [EffectPackItem.ID: EffectPack.ImportChoice] = [
            pack.items[0].id: .replace(EffectPackItem.palette(shared).id),
            pack.items[1].id: .replace(EffectPackItem.projection(oldSnow).id),
            pack.items[2].id: .replace(EffectPackItem.lighting(oldChase).id)
        ]
        try session.importEffectPack(pack, choices: choices)
        let current = session.project
        #expect(current.palettes.first?.id == shared.id && current.palettes.first?.slots.map(\.id) == [blue.id])
        #expect(current.surfaces[0].source.primaryBinding == linked && current.paletteColor(for: linked) == newBlue.color)
        #expect(current.surfaces[0].source.secondaryBinding == nil && current.surfaces[0].source.generator.secondaryColor == white.color)
        #expect(current.layers.first?.track.source.primaryBinding == nil && current.layers.first?.track.source.color == white.color)
        #expect(current.generatorPresets.first?.id == oldSnow.id && current.generatorPresets.first?.color == newBlue.color)
        #expect(current.lighting.lightingEffectPresets.first?.id == oldChase.id && current.lighting.lightingEffectPresets.first?.pattern == .reverse)
        session.undoProjectEdit()
        #expect(session.project == project)
    }

    @Test func conflictingOrUnsupportedImportPreservesDestination() throws {
        let old = ColorPalette(name: "Shared", slots: [])
        let replacements = [
            EffectPackItem.palette(ColorPalette(name: "Shared", slots: [])),
            EffectPackItem.palette(ColorPalette(name: "shared", slots: []))
        ]
        var project = MappingProject()
        project.palettes = [old]
        let session = EditorSession(presentOutput: { _ in }, project: project)
        defer { session.releaseRuntimeResources() }
        let pack = EffectPack(name: "Conflict", items: replacements)
        let choices = Dictionary(uniqueKeysWithValues: replacements.map { ($0.id, EffectPack.ImportChoice.replace(EffectPackItem.palette(old).id)) })
        #expect(throws: DeliveryError.self) { try session.importEffectPack(pack, choices: choices) }
        #expect(throws: DeliveryError.self) { try EffectPack(version: 2, name: pack.name, items: pack.items).validate() }
        #expect(session.project == project && !session.canUndo)
    }
}
