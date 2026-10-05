import Foundation
import Observation

@MainActor
@Observable
final class EditorSession {
    private(set) var project: MappingProject
    let output: OutputSelectionState
    let scene: RenderScene
    let testOutput: TestOutputCoordinator
    var isSidebarVisible = true
    var isInspectorVisible = true
    var hasUserChanges: Bool { project.name != MappingProject.defaultName }

    init(project: MappingProject = MappingProject(), output: OutputSelectionState = OutputSelectionState(),
         scene: RenderScene = .diagnostic) {
        self.project = project
        self.output = output
        self.scene = scene
        testOutput = TestOutputCoordinator(scene: scene)
    }

    func setTestResolution(_ resolution: TestResolution) {
        output.setTestResolution(resolution)
        testOutput.setResolution(resolution)
    }

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
