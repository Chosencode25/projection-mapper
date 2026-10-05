import Foundation
import Observation

@MainActor
@Observable
final class EditorSession {
    private(set) var project: MappingProject
    var isSidebarVisible = true
    var isInspectorVisible = true
    var hasUserChanges: Bool { project.name != MappingProject.defaultName }

    init(project: MappingProject = MappingProject()) { self.project = project }

    func renameProject(_ name: String, now: Date = .now) {
        guard name != project.name else { return }
        project.name = name
        project.modifiedAt = now
    }

    func finishNameEditing(now: Date = .now) {
        let trimmed = project.name.trimmingCharacters(in: .whitespacesAndNewlines)
        renameProject(trimmed.isEmpty ? MappingProject.defaultName : trimmed, now: now)
    }

    func resetProject(now: Date = .now) { project = MappingProject(now: now) }
}
