import AppKit
import Observation

@MainActor
@Observable
final class EditorSession {
    private(set) var project: MappingProject
    let output: OutputSelectionState
    var scene: RenderScene { project.surface.renderScene }
    private(set) var selectedSurfaceID: UUID?
    var selectedSurface: MappingSurface? {
        selectedSurfaceID == project.surface.id ? project.surface : nil
    }
    let testOutput: TestOutputCoordinator
    var isSidebarVisible = true
    var isInspectorVisible = true
    var hasUserChanges: Bool {
        project.name != MappingProject.defaultName || !project.surface.hasDefaultContent
    }

    init(presentOutput: @escaping (NSWindow) -> Void = { $0.makeKeyAndOrderFront(nil) },
         project: MappingProject = MappingProject(), output: OutputSelectionState = OutputSelectionState()) {
        self.project = project
        self.output = output
        selectedSurfaceID = project.surface.id
        testOutput = TestOutputCoordinator(presentWindow: presentOutput, scene: project.surface.renderScene)
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

    func selectSurface(_ id: UUID?) {
        guard id == nil || id == project.surface.id else { return }
        selectedSurfaceID = id
    }

    func resetProject(now: Date = .now) {
        project = MappingProject(now: now)
        selectedSurfaceID = project.surface.id
        testOutput.setScene(scene)
    }
}
