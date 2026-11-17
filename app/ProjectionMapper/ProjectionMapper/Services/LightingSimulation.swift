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

    private struct ManualChange {
        let origin: FixtureState
        let target: FixtureState
        let started: Double
        let motion: Double
        let fade: Double
        let curve: CueCurve

        func value(at uptime: Double) -> FixtureState {
            guard case .head(var head) = target, case .head(let initial) = origin else { return target }
            let elapsed = max(0, uptime - started)
            if motion > 0, elapsed < motion {
                let amount = curve.evaluate(elapsed / motion)
                head.pan = initial.pan + (head.pan - initial.pan) * amount
                head.tilt = initial.tilt + (head.tilt - initial.tilt) * amount
            }
            if fade > 0, elapsed < fade {
                let amount = CueCurve.linear.evaluate(elapsed / fade)
                head.dimmer = initial.dimmer + (head.dimmer - initial.dimmer) * amount
            }
            return .head(head)
        }
    }

    @ObservationIgnored private var manual: [UUID: ManualChange] = [:]
    func hasManualTransitions(at now: Double) -> Bool {
        return manual.values.contains { now < $0.started + max($0.motion, $0.fade) }
    }

    func clearManualCues() { manual.removeAll() }

    func trigger(_ cue: LightingCue, at uptime: Double) {
        resume()
        let previous = Dictionary(uniqueKeysWithValues: reports.values.flatMap(\.fixtures).map { ($0.id, $0.effective) })
        for entry in cue.entries {
            let curve = cue.motionCurve ?? .snap
            manual[entry.id] = ManualChange(origin: previous[entry.id] ?? entry.state.kind.dark,
                                             target: entry.state, started: uptime,
                                             motion: curve == .snap ? 0 : cue.lead,
                                             fade: cue.dimmerFade ?? 0, curve: curve)
        }
    }

    @ObservationIgnored private var schedule = LightingSchedule()
    @ObservationIgnored private var patch = ProjectLighting()
    @ObservationIgnored private var stoppedPositions: [UUID: FixtureState] = [:]
    @ObservationIgnored private var lastSent: [UUID: [UUID: SimulatedFixture]] = [:]

    private static func choreographed(_ state: FixtureState, color: SIMD4<Float>) -> FixtureState {
        let red = color.x >= 0.5, green = color.y >= 0.5, blue = color.z >= 0.5
        switch state {
        case .plug: return .plug(red || green || blue)
        case .rgb:
            switch (red, green, blue) {
            case (false, false, false): return .rgb(.off)
            case (true, false, false): return .rgb(.red)
            case (false, true, false): return .rgb(.green)
            case (false, false, true): return .rgb(.blue)
            case (true, true, false): return .rgb(.yellow)
            case (true, false, true): return .rgb(.magenta)
            case (false, true, true): return .rgb(.cyan)
            case (true, true, true): return .rgb(.white)
            }
        case .head(var head):
            head.dimmer = Double(max(color.x, color.y, color.z))
            head.color = red && green && blue ? 0 : red && green ? 4 : red ? 1 : green ? 2 : blue ? 3 : 0
            return .head(head)
        }
    }

    func reset() {
        clearManualCues()
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
        clearManualCues()
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

    func update(_ lighting: ProjectLighting, at time: Double, uptime: Double = ProcessInfo.processInfo.systemUptime, choreography: [ChoreographyClip] = []) {
        if lighting != patch {
            if lighting.cues != patch.cues { schedule = LightingSchedule(cues: lighting.cues) }
            patch = lighting
            let fixtureIDs = Set(lighting.fixtures.map(\.id))
            manual = manual.filter { fixtureIDs.contains($0.key) }
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
                let scheduled = schedule.state(for: fixture, at: time)
                let sample = choreography.lazy.filter { $0.kind == .fixture }
                    .compactMap { $0.sample(at: time, target: fixture.id) }.first
                let base: FixtureState
                if let sample, !schedule.hasCue(for: fixture.id, from: sample.stepStart, through: time) {
                    base = sample.active ? Self.choreographed(scheduled, color: sample.color) : scheduled.darkened
                } else { base = scheduled }
                let intended = overrides[fixture.id] ?? manual[fixture.id]?.value(at: uptime) ?? base
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
