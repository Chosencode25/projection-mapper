import Foundation
import UniformTypeIdentifiers

enum EffectPackAction: String, Identifiable {
    case export, importPack
    var id: Self { self }
    var title: String { self == .export ? "Export Effect & Palette Pack" : "Import Effect & Palette Pack" }
}

enum EffectPackItem: Codable, Identifiable {
    case palette(ColorPalette)
    case projection(GeneratorPreset)
    case lighting(LightingEffectPreset)

    enum Kind: String, CaseIterable, Hashable, Identifiable {
        case palette = "Palettes"
        case projection = "Projection Effects"
        case lighting = "Lighting Effects"
        var id: Self { self }
    }

    struct ID: Hashable {
        let kind: Kind
        let uuid: UUID
    }

    var id: ID {
        switch self {
        case .palette(let value): ID(kind: .palette, uuid: value.id)
        case .projection(let value): ID(kind: .projection, uuid: value.id)
        case .lighting(let value): ID(kind: .lighting, uuid: value.id)
        }
    }

    var name: String {
        switch self {
        case .palette(let value): value.name
        case .projection(let value): value.name
        case .lighting(let value): value.name
        }
    }

    var detail: String {
        switch self {
        case .palette(let value): "\(value.slots.count) colors"
        case .projection(let value): value.content.title
        case .lighting(let value): value.pattern.rawValue
        }
    }

    func copied(named name: String) -> Self {
        switch self {
        case .palette(var value):
            value.id = UUID()
            value.name = name
            for index in value.slots.indices { value.slots[index].id = UUID() }
            return .palette(value)
        case .projection(var value):
            value.id = UUID()
            value.name = name
            return .projection(value)
        case .lighting(var value):
            value.id = UUID()
            value.name = name
            return .lighting(value)
        }
    }
}

extension MappingProject {
    var effectPackItems: [EffectPackItem] {
        palettes.map(EffectPackItem.palette) + generatorPresets.map(EffectPackItem.projection) +
            lighting.lightingEffectPresets.map(EffectPackItem.lighting)
    }

    mutating func setEffectPackItems(_ items: [EffectPackItem]) {
        palettes = []
        generatorPresets = []
        var lightingPresets: [LightingEffectPreset] = []
        for item in items {
            switch item {
            case .palette(let value): palettes.append(value)
            case .projection(let value): generatorPresets.append(value)
            case .lighting(let value): lightingPresets.append(value)
            }
        }
        lighting.effectPresets = lightingPresets.isEmpty ? nil : lightingPresets
    }
}

struct EffectPack: Codable {
    var version = 1
    let name: String
    let items: [EffectPackItem]

    enum ImportChoice: Hashable {
        case keepBoth
        case replace(EffectPackItem.ID)
    }

    struct Merge {
        let items: [EffectPackItem]
        let removedSlots: [UUID: Set<UUID>]
    }

    static func nameKey(_ name: String) -> String {
        name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    func validate() throws {
        guard version == 1 else { throw DeliveryError.invalid("This effect pack uses an unsupported version.") }
        guard !Self.nameKey(name).isEmpty, name.count <= 80, (1...328).contains(items.count),
              items.allSatisfy({ !Self.nameKey($0.name).isEmpty }) else {
            throw DeliveryError.invalid("Name the pack and choose at least one valid item.")
        }
        var sample = MappingProject()
        sample.setEffectPackItems(items)
        try ProjectCodec.validate(ProjectDocument(project: sample))
    }

    func matches(for item: EffectPackItem, in catalog: [EffectPackItem]) -> [EffectPackItem] {
        catalog.filter { $0.id.kind == item.id.kind && Self.nameKey($0.name) == Self.nameKey(item.name) }
    }

    /// A missing choice skips the item. Replacing requires a specific existing matching identity.
    func merge(into catalog: [EffectPackItem], choices: [EffectPackItem.ID: ImportChoice]) throws -> Merge {
        try validate()
        guard !choices.isEmpty, Set(choices.keys).isSubset(of: Set(items.map(\.id))) else {
            throw DeliveryError.invalid("Choose at least one item from this pack.")
        }
        let replacementIDs = choices.values.compactMap { choice -> EffectPackItem.ID? in
            if case .replace(let id) = choice { return id }
            return nil
        }
        guard Set(replacementIDs).count == replacementIDs.count else {
            throw DeliveryError.invalid("Choose a different replacement for each item.")
        }
        var result = catalog
        var removed: [UUID: Set<UUID>] = [:]
        for item in items {
            guard let choice = choices[item.id] else { continue }
            switch choice {
            case .keepBoth:
                let initial = item.name.trimmingCharacters(in: .whitespacesAndNewlines)
                let reserved = Set(result.filter { $0.id.kind == item.id.kind }.map { Self.nameKey($0.name) })
                var name = initial
                var index = 2
                while reserved.contains(Self.nameKey(name)) {
                    let suffix = " (\(index))"
                    name = String(initial.prefix(80 - suffix.count)) + suffix
                    index += 1
                }
                result.append(item.copied(named: name))
            case .replace(let id):
                guard let index = catalog.firstIndex(where: { $0.id == id }),
                      matches(for: item, in: [catalog[index]]).count == 1 else {
                    throw DeliveryError.invalid("The selected replacement for “\(item.name)” changed. Review the import.")
                }
                switch (item, catalog[index]) {
                case (.palette(var incoming), .palette(let existing)):
                    incoming.id = existing.id
                    incoming.name = existing.name
                    let oldByName = Dictionary(grouping: existing.slots) { Self.nameKey($0.name) }
                    let newByName = Dictionary(grouping: incoming.slots) { Self.nameKey($0.name) }
                    var retained = Set<UUID>()
                    for slot in incoming.slots.indices {
                        let key = Self.nameKey(incoming.slots[slot].name)
                        if let matches = oldByName[key], matches.count == 1, newByName[key]?.count == 1 {
                            incoming.slots[slot].id = matches[0].id
                            retained.insert(matches[0].id)
                        } else {
                            incoming.slots[slot].id = UUID()
                        }
                    }
                    removed[existing.id] = Set(existing.slots.map(\.id)).subtracting(retained)
                    result[index] = .palette(incoming)
                case (.projection(var incoming), .projection(let existing)):
                    incoming.id = existing.id
                    incoming.name = existing.name
                    result[index] = .projection(incoming)
                case (.lighting(var incoming), .lighting(let existing)):
                    incoming.id = existing.id
                    incoming.name = existing.name
                    result[index] = .lighting(incoming)
                default:
                    throw DeliveryError.invalid("The selected replacement has an incompatible type.")
                }
            }
        }
        return Merge(items: result, removedSlots: removed)
    }
}

enum EffectPackStore {
    static let contentType = UTType(exportedAs: "local.keith.projectionpack", conformingTo: .json)
    private static let sizeLimit = 2 * 1024 * 1024

    static func read(_ url: URL) throws -> EffectPack {
        let values = try url.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey, .fileSizeKey])
        guard values.isRegularFile == true, values.isSymbolicLink != true,
              (values.fileSize ?? Int.max) <= sizeLimit else {
            throw DeliveryError.invalid("Choose a regular effect-pack file no larger than 2 MB.")
        }
        let input = try FileHandle(forReadingFrom: url)
        defer { try? input.close() }
        let bytes = try input.read(upToCount: sizeLimit + 1) ?? Data()
        guard bytes.count <= sizeLimit else { throw DeliveryError.invalid("This effect pack exceeds 2 MB.") }
        let pack = try JSONDecoder().decode(EffectPack.self, from: bytes)
        try pack.validate()
        return pack
    }

    static func write(_ pack: EffectPack, to destination: URL) throws {
        try pack.validate()
        try DeliveryFile.requireVacant(destination)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let bytes = try encoder.encode(pack)
        guard bytes.count <= sizeLimit else { throw DeliveryError.invalid("This effect pack exceeds 2 MB.") }
        let folder = destination.deletingLastPathComponent()
            .appendingPathComponent(".effect-pack-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: false)
        defer { try? FileManager.default.removeItem(at: folder) }
        let file = folder.appendingPathComponent("pack.projectionpack")
        try bytes.write(to: file)
        try DeliveryFile.publish(file, to: destination)
    }
}
