import Foundation
import Observation

struct SimulatedFixture: Equatable, Identifiable {
    var id: UUID
    var slots: [Int]
    var intended: FixtureState
    var effective: FixtureState
    var relayValues: [Bool] {
        switch effective {
        case .head: []
        case .plug(let on): [on]
        case .rgb(let color): color.outputs
        }
    }
}

struct LightingSimulationSend: Equatable, Identifiable {
    var id = UUID()
    var time: Double
    var fixtureCount: Int
}

struct LightingSimulationReport: Equatable {
    enum Status: String {
        case unconfigured = "Unconfigured"
        case unsupported = "Unsupported profile"
        case failed = "Simulated failure"
        case ready = "Simulation ready"
        case sent = "Simulated send"
    }
    var status: Status
    var fixtures: [SimulatedFixture]
    var history: [LightingSimulationSend]
}

@MainActor
@Observable
final class LightingSimulation {
    private(set) var reports: [UUID: LightingSimulationReport] = [:]
    private(set) var overrides: [UUID: FixtureState] = [:]
    private(set) var failures: Set<UUID> = []
    var blackout = false
    private(set) var isStopped = true

    @ObservationIgnored private var schedule = LightingSchedule()
    @ObservationIgnored private var patch = ProjectLighting()
    @ObservationIgnored private var stoppedPositions: [UUID: FixtureState] = [:]
    @ObservationIgnored private var lastSent: [UUID: [UUID: SimulatedFixture]] = [:]

    func reset() {
        overrides.removeAll()
        failures.removeAll()
        reports.removeAll()
        lastSent.removeAll()
        stoppedPositions.removeAll()
        blackout = false
        isStopped = true
    }

    func resume() {
        stoppedPositions.removeAll()
        isStopped = false
    }

    func stop() {
        guard !isStopped else { return }
        stoppedPositions = Dictionary(uniqueKeysWithValues: reports.values.flatMap(\.fixtures).map { ($0.id, $0.effective.darkened) })
        isStopped = true
        overrides.removeAll()
    }

    func override(_ state: FixtureState?, for fixture: PatchedFixture) {
        guard state == nil || !isStopped else { return }
        overrides[fixture.id] = state
    }

    func setFailure(_ fail: Bool, for controller: UUID) {
        if fail { failures.insert(controller) }
        else { failures.remove(controller) }
    }

    func update(_ lighting: ProjectLighting, at time: Double) {
        if lighting != patch {
            if lighting.cues != patch.cues { schedule = LightingSchedule(cues: lighting.cues) }
            patch = lighting
            let fixtureIDs = Set(lighting.fixtures.map(\.id))
            overrides = overrides.filter { fixtureIDs.contains($0.key) }
            stoppedPositions = stoppedPositions.filter { fixtureIDs.contains($0.key) }
            let controllerIDs = Set(lighting.controllers.map(\.id))
            failures.formIntersection(controllerIDs)
            lastSent = lastSent.filter { controllerIDs.contains($0.key) }
        }
        let assigned = Dictionary(grouping: lighting.fixtures, by: \.controllerID)
        var next: [UUID: LightingSimulationReport] = [:]
        for controller in lighting.controllers {
            let fixtures = (assigned[controller.id] ?? []).map { fixture in
                let intended = overrides[fixture.id] ?? schedule.state(for: fixture, at: time)
                let effective: FixtureState
                if isStopped { effective = stoppedPositions[fixture.id] ?? fixture.kind.dark }
                else { effective = blackout ? intended.darkened : intended }
                return SimulatedFixture(id: fixture.id, slots: fixture.slots, intended: intended, effective: effective)
            }
            var history = reports[controller.id]?.history ?? []
            let status: LightingSimulationReport.Status
            if controller.profile != .simulation {
                lastSent[controller.id] = nil
                status = controller.profile == .unconfigured ? .unconfigured : .unsupported
            } else if failures.contains(controller.id) {
                lastSent[controller.id] = nil
                status = .failed
            } else {
                // Only a change to assigned outputs requires a new simulated send.
                let payload = Dictionary(uniqueKeysWithValues: fixtures.map { fixture in
                    var output = fixture
                    output.intended = fixture.effective
                    return (fixture.id, output)
                })
                let previous = lastSent[controller.id]
                if previous != payload {
                    lastSent[controller.id] = payload
                    if !payload.isEmpty || previous?.isEmpty == false {
                        history.append(LightingSimulationSend(time: time, fixtureCount: fixtures.count))
                        history = Array(history.suffix(8))
                    }
                }
                status = history.isEmpty ? .ready : .sent
            }
            next[controller.id] = LightingSimulationReport(status: status, fixtures: fixtures, history: history)
        }
        if next != reports { reports = next }
    }
}
