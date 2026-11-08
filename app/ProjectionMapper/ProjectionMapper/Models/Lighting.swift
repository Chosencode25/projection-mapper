import Foundation

enum LightingControllerKind: String, CaseIterable, Codable, Identifiable {
    case dmx = "DMX", arduino = "Arduino"
    var id: Self { self }
}

enum LightingSimulationProfile: String, CaseIterable, Codable, Identifiable {
    case simulation = "Simulation", unconfigured = "Unconfigured", unsupported = "Unsupported Profile"
    var id: Self { self }
}

struct LightingController: Codable, Equatable, Identifiable {
    var id = UUID()
    var name: String
    var kind: LightingControllerKind
    var relayCount = 8
    var profile = LightingSimulationProfile.simulation
    var capacity: Int { kind == .dmx ? 512 : relayCount }
}

enum FixtureKind: String, CaseIterable, Codable, Identifiable {
    case movingHead = "Moving Head", plug = "Switched Plug", rgb = "RGB Strip"
    var id: Self { self }
    var controllerKind: LightingControllerKind { self == .movingHead ? .dmx : .arduino }
    var dark: FixtureState {
        switch self {
        case .movingHead: .head(HeadLook())
        case .plug: .plug(false)
        case .rgb: .rgb(.off)
        }
    }
}

struct FixturePreviewPoint: Codable, Equatable {
    var x: Double
    var y: Double

    var isValid: Bool { (0...1).contains(x) && (0...1).contains(y) }
}

struct FixturePreviewPlacement: Codable, Equatable {
    var origin: FixturePreviewPoint
    var stripEnd: FixturePreviewPoint?

    var isValid: Bool { origin.isValid && stripEnd?.isValid != false }

    static func initial(index: Int, kind: FixtureKind) -> Self {
        let column = Double(index % 4)
        let row = Double(index / 4 % 4)
        let start = FixturePreviewPoint(x: 0.12 + column * 0.21, y: 0.22 + row * 0.19)
        return Self(origin: start, stripEnd: kind == .rgb ? FixturePreviewPoint(x: start.x + 0.15, y: start.y) : nil)
    }
}

struct PatchedFixture: Codable, Equatable, Identifiable {
    var id = UUID()
    var name: String
    var group = ""
    var kind: FixtureKind
    var controllerID: UUID
    var address = 1
    var headChannels = 9
    var green = 2
    var blue = 3
    var previewPlacement: FixturePreviewPlacement?

    var slots: [Int] {
        switch kind {
        case .movingHead:
            guard (1...512).contains(address), [9, 11].contains(headChannels) else { return [] }
            return Array(address..<(address + headChannels))
        case .plug: return [address]
        case .rgb: return [address, green, blue]
        }
    }
}

enum RelayColor: Int, CaseIterable, Codable, Identifiable {
    case off, red, green, yellow, blue, magenta, cyan, white
    var id: Self { self }
    var label: String { String(describing: self).capitalized }
    var outputs: [Bool] { [1, 2, 4].map { rawValue & $0 != 0 } }
}

struct HeadLook: Codable, Equatable {
    static let colors = ["White", "Red", "Green", "Blue", "Yellow", "Orange", "Light Blue", "Pink",
                         "Light Blue + Pink", "Orange + Light Blue", "Blue + Yellow", "Green + Blue", "Red + Green"]
    var pan = 0.5
    var tilt = 0.5
    var dimmer = 0.0
    var color = 0
    var gobo = 0

    var isValid: Bool {
        [pan, tilt, dimmer].allSatisfy { (0...1).contains($0) } &&
            Self.colors.indices.contains(color) && (0...7).contains(gobo)
    }
}

enum FixtureState: Codable, Equatable {
    case head(HeadLook), plug(Bool), rgb(RelayColor)

    var kind: FixtureKind {
        switch self {
        case .head: .movingHead
        case .plug: .plug
        case .rgb: .rgb
        }
    }

    var darkened: Self {
        guard case .head(var head) = self else { return kind.dark }
        head.dimmer = 0
        return .head(head)
    }

    var label: String {
        switch self {
        case .head(let head):
            "Pan \(head.pan.formatted(.percent.precision(.fractionLength(0)))) · Tilt \(head.tilt.formatted(.percent.precision(.fractionLength(0)))) · Dimmer \(head.dimmer.formatted(.percent.precision(.fractionLength(0)))) · \(HeadLook.colors[head.color]) · Gobo \(head.gobo)"
        case .plug(let on): on ? "On" : "Off"
        case .rgb(let color): color.label
        }
    }
}

struct FixtureLookEntry: Codable, Equatable, Identifiable {
    var id: UUID
    var state: FixtureState
}

struct FixtureLook: Codable, Equatable, Identifiable {
    var id = UUID()
    var name: String
    var entries: [FixtureLookEntry]
}

struct LightingCue: Codable, Equatable, Identifiable {
    var id = UUID()
    var name: String
    var time: Double
    var lead = 0.0
    var entries: [FixtureLookEntry]
}

struct ProjectLighting: Codable, Equatable {
    var controllers: [LightingController] = []
    var fixtures: [PatchedFixture] = []
    var looks: [FixtureLook] = []
    var cues: [LightingCue] = []

    mutating func removeFixture(_ id: UUID) {
        fixtures.removeAll { $0.id == id }
        for index in looks.indices { looks[index].entries.removeAll { $0.id == id } }
        for index in cues.indices { cues[index].entries.removeAll { $0.id == id } }
        looks.removeAll { $0.entries.isEmpty }
        cues.removeAll { $0.entries.isEmpty }
    }

    func validationIssue() -> String? {
        guard controllers.count <= 32, fixtures.count <= 256, looks.count <= 256, cues.count <= 2000 else {
            return "The project has reached its lighting limits."
        }
        guard Set(controllers.map(\.id)).count == controllers.count,
              Set(fixtures.map(\.id)).count == fixtures.count,
              Set(looks.map(\.id)).count == looks.count,
              Set(cues.map(\.id)).count == cues.count else { return "Duplicate lighting IDs." }
        let controllerByID = Dictionary(uniqueKeysWithValues: controllers.map { ($0.id, $0) })
        let fixtureByID = Dictionary(uniqueKeysWithValues: fixtures.map { ($0.id, $0.kind) })
        func validName(_ name: String) -> Bool {
            !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && name.count <= 80
        }
        guard controllers.allSatisfy({ validName($0.name) && (1...512).contains($0.relayCount) }) else {
            return "Enter a controller name and an output count from 1 to 512."
        }
        var reserved: [UUID: Set<Int>] = [:]
        for fixture in fixtures {
            guard fixture.previewPlacement?.isValid != false else { return "A fixture preview position is outside the canvas." }
            guard validName(fixture.name), fixture.group.count <= 80 else { return "Enter a valid fixture name and group." }
            guard let controller = controllerByID[fixture.controllerID], controller.kind == fixture.kind.controllerKind else {
                return "Choose a compatible controller for \(fixture.name)."
            }
            let slots = fixture.slots
            let unique = Set(slots)
            guard !slots.isEmpty, slots.allSatisfy({ (1...controller.capacity).contains($0) }) else {
                return "\(fixture.name) extends beyond the controller's output range."
            }
            guard unique.count == slots.count, reserved[controller.id, default: []].isDisjoint(with: unique) else {
                return "\(fixture.name) uses an output more than once or overlaps another fixture."
            }
            reserved[controller.id, default: []].formUnion(unique)
        }

        func validEntries(_ entries: [FixtureLookEntry]) -> Bool {
            !entries.isEmpty && Set(entries.map(\.id)).count == entries.count && entries.allSatisfy { entry in
                guard fixtureByID[entry.id] == entry.state.kind else { return false }
                if case .head(let head) = entry.state { return head.isValid }
                return true
            }
        }
        guard looks.allSatisfy({ validName($0.name) && validEntries($0.entries) }) else { return "Invalid lighting look." }
        var times: [UUID: Set<Double>] = [:]
        for cue in cues {
            guard validName(cue.name), (0...3600).contains(cue.time), (0...3600).contains(cue.lead),
                  validEntries(cue.entries) else { return "Invalid lighting cue time, lead, or fixture state." }
            for entry in cue.entries where !times[entry.id, default: []].insert(cue.time).inserted {
                return "A fixture can only have one cue at a given time."
            }
        }
        return nil
    }
}

/// Indexed on edits. Playback, seek and wrap all use the same point-in-time evaluation.
struct LightingSchedule {
    private struct Change {
        let time: Double
        let leadStart: Double
        let state: FixtureState
    }

    private var tracks: [UUID: [Change]] = [:]

    init(cues: [LightingCue] = []) {
        for cue in cues.sorted(by: { $0.time < $1.time }) {
            for entry in cue.entries {
                let previous = tracks[entry.id]?.last?.time ?? 0
                tracks[entry.id, default: []].append(Change(time: cue.time, leadStart: max(previous, cue.time - cue.lead), state: entry.state))
            }
        }
    }

    func state(for fixture: PatchedFixture, at time: Double) -> FixtureState {
        guard let track = tracks[fixture.id] else { return fixture.kind.dark }
        var lower = 0
        var upper = track.count
        while lower < upper {
            let middle = lower + (upper - lower) / 2
            if track[middle].time <= time { lower = middle + 1 }
            else { upper = middle }
        }
        let current = lower == 0 ? fixture.kind.dark : track[lower - 1].state
        guard lower < track.count, time >= track[lower].leadStart,
              case .head(let target) = track[lower].state,
              case .head(var head) = current else { return current }
        head.pan = target.pan
        head.tilt = target.tilt
        return .head(head)
    }
}
