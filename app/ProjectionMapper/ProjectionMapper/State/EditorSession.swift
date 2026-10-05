import AppKit
import Observation

@MainActor
@Observable
final class EditorSession {
    private(set) var project: MappingProject
    let output: OutputSelectionState
    var scene: RenderScene { project.surface.renderScene }
    private(set) var selectedSurfaceID: UUID?
    private(set) var selectedCorner: SurfaceCorner?
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
        if id != selectedSurfaceID { selectedCorner = nil }
        selectedSurfaceID = id
    }

    func selectCorner(_ corner: SurfaceCorner?) {
        selectedCorner = selectedSurface == nil ? nil : corner
    }

    func moveSelectedCorner(to point: SIMD2<Float>, surfaceID: UUID, now: Date = .now) {
        guard let corner = selectedCorner, selectedSurfaceID == surfaceID,
              project.surface.id == surfaceID, point.x.isFinite, point.y.isFinite else { return }
        let clamped = SIMD2(min(1, max(0, point.x)), min(1, max(0, point.y)))
        guard project.surface.corners[corner] != clamped else { return }
        project.surface.corners = project.surface.corners.replacing(corner, with: clamped)
        project.modifiedAt = now
        testOutput.setScene(scene)
    }

    func setSurfaceContent(_ content: SurfaceContent, now: Date = .now) {
        guard selectedSurface != nil, project.surface.content != content else { return }
        project.surface.content = content
        project.modifiedAt = now
        testOutput.setScene(scene)
    }

    func nudgeSelectedCorner(direction: SIMD2<Float>, larger: Bool) {
        guard let corner = selectedCorner, selectedSurface != nil else { return }
        moveSelectedCorner(to: project.surface.corners[corner] + direction * (larger ? 0.01 : 0.001),
                           surfaceID: project.surface.id)
    }

    func resetProject(now: Date = .now) {
        project = MappingProject(now: now)
        selectedSurfaceID = project.surface.id
        selectedCorner = nil
        testOutput.setScene(scene)
    }
}
