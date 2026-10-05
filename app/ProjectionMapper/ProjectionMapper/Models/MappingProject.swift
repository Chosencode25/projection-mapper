import Foundation

struct MappingProject: Equatable {
    static let defaultName = "Untitled Project"
    let id: UUID
    var name: String
    let createdAt: Date
    var modifiedAt: Date
    var surface: MappingSurface

    init(id: UUID = UUID(), name: String = MappingProject.defaultName, now: Date = .now, surface: MappingSurface = MappingSurface()) {
        self.id = id
        self.name = name
        self.createdAt = now
        self.modifiedAt = now
        self.surface = surface
    }
}
