import Foundation

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
    func save(_ preference: SavedOutputPreference) {
        if let data = try? JSONEncoder().encode(preference) { defaults.set(data, forKey: key) }
    }
}
