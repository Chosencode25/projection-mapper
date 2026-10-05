import Foundation
import CoreGraphics

@MainActor
final class OutputPreferences {
    private let defaults: UserDefaults
    private let key = "output.explicitPreference.v1"

    init(defaults: UserDefaults = .standard) { self.defaults = defaults }
    func load() -> SavedOutputPreference {
        guard let data = defaults.data(forKey: key),
              let value = try? JSONDecoder().decode(SavedOutputPreference.self, from: data) else { return .testWindow }
        return value
    }
    func loadTestResolution() -> TestResolution {
        defaults.string(forKey: "output.testResolution.v1").flatMap(TestResolution.init(rawValue:)) ?? .hd
    }
    func saveTestResolution(_ resolution: TestResolution) {
        defaults.set(resolution.rawValue, forKey: "output.testResolution.v1")
    }
    func loadTestWindowFrame() -> CGRect? {
        guard let values = defaults.array(forKey: "output.testWindowFrame.v1") as? [Double],
              values.count == 4, values.allSatisfy({ $0.isFinite }),
              values[2] > 0, values[3] > 0 else { return nil }
        return CGRect(x: values[0], y: values[1], width: values[2], height: values[3])
    }
    func saveTestWindowFrame(_ frame: CGRect) {
        let values = [frame.origin.x, frame.origin.y, frame.width, frame.height]
        guard values.allSatisfy({ $0.isFinite }), frame.width > 0, frame.height > 0 else { return }
        defaults.set(values, forKey: "output.testWindowFrame.v1")
    }
    func save(_ preference: SavedOutputPreference) {
        if let data = try? JSONEncoder().encode(preference) { defaults.set(data, forKey: key) }
    }
}
