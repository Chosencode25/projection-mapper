import AppKit
import Observation
import simd

@MainActor
@Observable
final class EditorSession {
    private(set) var project: MappingProject
    let output: OutputSelectionState
    private(set) var transport = AnimationTransport()
    private(set) var sourcePlayback: [UUID:SourcePlayback] = [:]
    var selectedPlayback: SourcePlayback { selectedSource.flatMap { sourcePlayback[$0.id] } ?? SourcePlayback() }
    var scene: RenderScene {
        let faces = project.renderScene.surfaces.map { face in
            var face = face; face.playback = face.sourceID.flatMap { sourcePlayback[$0] } ?? SourcePlayback(); return face
        }
        return RenderScene(surfaces: faces, transport: transport)
    }
    func seekPlayback(to seconds: Double, at uptime: TimeInterval = ProcessInfo.processInfo.systemUptime) {
        guard seconds.isFinite, (0...3600).contains(seconds), uptime.isFinite else { return }
        let delta = seconds - transport.elapsed(at: uptime)
        transport.seek(to: seconds, at: uptime)
        for id in Array(sourcePlayback.keys) {
            if let frozen = sourcePlayback[id]?.frozenTime { sourcePlayback[id]?.frozenTime = max(0,frozen + delta) }
        }
        testOutput.setScene(scene)
    }
    func setSelectedPaused(_ paused: Bool, at uptime: TimeInterval = ProcessInfo.processInfo.systemUptime) {
        guard let source = selectedSource, uptime.isFinite else { return }
        var clock = sourcePlayback[source.id] ?? SourcePlayback()
        clock.setPaused(paused, at: transport.elapsed(at: uptime)); sourcePlayback[source.id] = clock
        testOutput.setScene(scene)
    }
    func restartSelectedPlayback(at uptime: TimeInterval = ProcessInfo.processInfo.systemUptime) {
        guard let source = selectedSource, uptime.isFinite else { return }
        var clock = sourcePlayback[source.id] ?? SourcePlayback()
        clock.restart(at: transport.elapsed(at: uptime)); sourcePlayback[source.id] = clock
        testOutput.setScene(scene)
    }
    private func copyPlayback(from original: UUID, to copy: UUID) {
        if let clock = sourcePlayback[original] { sourcePlayback[copy] = clock }
    }
    func setPlaying(_ playing: Bool, at uptime: TimeInterval = ProcessInfo.processInfo.systemUptime) {
        transport.setPlaying(playing, at: uptime); testOutput.setScene(scene)
    }
    func restartPlayback(at uptime: TimeInterval = ProcessInfo.processInfo.systemUptime) {
        guard uptime.isFinite else { return }
        transport.restart(at: uptime)
        for id in Array(sourcePlayback.keys) { sourcePlayback[id] = sourcePlayback[id]?.isPaused == true ? SourcePlayback(frozenTime: 0) : SourcePlayback() }
        testOutput.setScene(scene)
    }
    func setPlaybackSpeed(_ value: Double, at uptime: TimeInterval = ProcessInfo.processInfo.systemUptime) {
        transport.setSpeed(value, at: uptime); testOutput.setScene(scene)
    }
    private(set) var selectedSurfaceID: UUID?
    private(set) var selectedObjectID: UUID?
    private(set) var selectedCorner: SurfaceCorner?
    private(set) var groupingSelection: Set<UUID> = []
    var selectedSurface: MappingSurface? { project.surfaces.first { $0.id == selectedSurfaceID } }
    var selectedObject: MappingObject? { project.objects.first { $0.id == selectedObjectID } }
    var selectedSource: SurfaceSource? {
        if let object = selectedObject { return object.source }
        return selectedSurface.map { project.source(for: $0) }
    }
    let testOutput: TestOutputCoordinator
    var isSidebarVisible = true
    var isInspectorVisible = true
    var hasUserChanges: Bool { !project.hasDefaultContent }
    var editMessage: String?

    init(presentOutput: @escaping (NSWindow) -> Void = { $0.makeKeyAndOrderFront(nil) },
         project: MappingProject = MappingProject(), output: OutputSelectionState = OutputSelectionState()) {
        self.project = project; self.output = output
        selectedSurfaceID = project.surfaces.first?.id
        testOutput = TestOutputCoordinator(presentWindow: presentOutput, scene: project.renderScene)
    }
    private func changed(now: Date = .now) {
        let active = Set(project.surfaces.map { project.source(for: $0).id })
        sourcePlayback = sourcePlayback.filter { active.contains($0.key) }
        project.modifiedAt = now; editMessage = nil; testOutput.setScene(scene)
    }
    private func cleanName(_ name: String, fallback: String) -> String {
        let trimmed = String(name.trimmingCharacters(in: .whitespacesAndNewlines).prefix(80))
        return trimmed.isEmpty ? fallback : trimmed
    }
    private func tags(_ text: String) -> [String] {
        var result: [String] = []
        for part in text.split(separator: ",") {
            let tag = cleanName(String(part), fallback: "")
            if !tag.isEmpty && !result.contains(tag) { result.append(tag) }
            if result.count == 16 { break }
        }
        return result
    }
    func setTestResolution(_ resolution: TestResolution) { output.setTestResolution(resolution); testOutput.setResolution(resolution) }
    func renameProject(_ name: String, now: Date = .now) {
        guard name != project.name else { return }; project.name = name; changed(now: now)
    }
    func finishNameEditing(now: Date = .now) { renameProject(cleanName(project.name, fallback: MappingProject.defaultName), now: now) }
    func selectSurface(_ id: UUID?) {
        guard id == nil || project.surfaces.contains(where: { $0.id == id }) else { return }
        if id != selectedSurfaceID { selectedCorner = nil }
        selectedSurfaceID = id; selectedObjectID = nil; editMessage = nil
    }
    /// Pick the frontmost rendered face. Selection never changes project content.
    func selectSurface(at point: SIMD2<Float>?) {
        let hit = point.flatMap { point in
            project.surfaces.first { face in
                guard face.layout.isVisible, project.object(for: face)?.isVisible != false,
                      face.layout.inputMap.isValid, let transform = PerspectiveTransform(face.corners) else { return false }
                let mapped = transform.inverse * SIMD3<Double>(Double(point.x), Double(point.y), 1)
                guard mapped.z.isFinite, abs(mapped.z) > 1e-12 else { return false }
                let uv = SIMD2(mapped.x, mapped.y) / mapped.z
                return uv.x.isFinite && uv.y.isFinite && (-1e-7...1.0000001).contains(uv.x) && (-1e-7...1.0000001).contains(uv.y)
            }?.id
        }
        selectSurface(hit)
        selectedCorner = nil
    }
    func selectObject(_ id: UUID) {
        guard project.objects.contains(where: { $0.id == id }) else { return }
        selectedObjectID = id; selectedSurfaceID = nil; selectedCorner = nil; editMessage = nil
    }
    func selectCorner(_ corner: SurfaceCorner?) { selectedCorner = selectedSurface == nil ? nil : corner }
    func toggleGrouping(_ id: UUID) {
        guard project.surfaces.contains(where: { $0.id == id }) else { return }
        if groupingSelection.contains(id) { groupingSelection.remove(id) } else { groupingSelection.insert(id) }
    }
    func selectTag(_ tag: String) {
        groupingSelection = Set(project.surfaces.filter { face in face.tags.contains(tag) || project.object(for: face)?.tags.contains(tag) == true }.map(\.id))
    }
    func renameSurface(_ id: UUID, _ name: String) {
        guard let i = project.surfaces.firstIndex(where: { $0.id == id }) else { return }
        let name = cleanName(name, fallback: project.surfaces[i].name)
        guard name != project.surfaces[i].name else { return }; project.surfaces[i].name = name; changed()
    }
    func renameObject(_ id: UUID, _ name: String) {
        guard let i = project.objects.firstIndex(where: { $0.id == id }) else { return }
        let name = cleanName(name, fallback: project.objects[i].name)
        guard name != project.objects[i].name else { return }; project.objects[i].name = name; changed()
    }
    func setTags(_ text: String, faceID: UUID? = nil, objectID: UUID? = nil) {
        let value = tags(text)
        if let i = project.surfaces.firstIndex(where: { $0.id == faceID }), project.surfaces[i].tags != value {
            project.surfaces[i].tags = value; changed()
        } else if let i = project.objects.firstIndex(where: { $0.id == objectID }), project.objects[i].tags != value {
            project.objects[i].tags = value; changed()
        }
    }
    func addSurface() {
        let names = Set(project.surfaces.map(\.name)); var number = 1
        while names.contains("Surface \(number)") { number += 1 }
        let face = MappingSurface(name: "Surface \(number)")
        project.surfaces.insert(face, at: 0); selectSurface(face.id); changed()
    }
    func duplicateSurface(_ id: UUID) {
        guard let i = project.surfaces.firstIndex(where: { $0.id == id }) else { return }
        let original = project.surfaces[i]
        var face = MappingSurface(name: uniqueCopyName(original.name, names: project.surfaces.map(\.name)))
        face.layout = original.layout; face.tags = original.tags; face.source = original.source.independentCopy()
        copyPlayback(from: original.source.id, to: face.source.id)
        project.surfaces.insert(face, at: i); selectSurface(face.id); changed()
    }
    private func uniqueCopyName(_ name: String, names: [String]) -> String {
        var result = "\(name) copy", index = 2
        while names.contains(result) { result = "\(name) copy \(index)"; index += 1 }
        return result
    }
    func deleteSurface(_ id: UUID) {
        guard let i = project.surfaces.firstIndex(where: { $0.id == id }) else { return }
        project.surfaces.remove(at: i); groupingSelection.remove(id)
        for n in project.objects.indices { project.objects[n].links.removeAll { $0.firstFace == id || $0.secondFace == id } }
        removeEmptyObjects()
        if selectedSurfaceID == id { selectSurface(project.surfaces.isEmpty ? nil : project.surfaces[min(i,project.surfaces.count-1)].id) }
        changed()
    }
    private func removeEmptyObjects() {
        let occupied = Set(project.surfaces.compactMap { $0.layout.objectID })
        project.objects.removeAll { !occupied.contains($0.id) }
        if let id = selectedObjectID, !project.objects.contains(where: { $0.id == id }) { selectedObjectID = nil }
    }
    func moveSurface(_ id: UUID, offset: Int) {
        guard let i = project.surfaces.firstIndex(where: { $0.id == id }) else { return }
        let target = i + offset; guard project.surfaces.indices.contains(target) else { return }
        project.surfaces.swapAt(i, target); changed()
    }
    func setVisible(_ visible: Bool, faceID: UUID? = nil, objectID: UUID? = nil) {
        if let i = project.surfaces.firstIndex(where: { $0.id == faceID }), project.surfaces[i].layout.isVisible != visible {
            project.surfaces[i].layout.isVisible = visible; changed()
        } else if let i = project.objects.firstIndex(where: { $0.id == objectID }), project.objects[i].isVisible != visible {
            project.objects[i].isVisible = visible; changed()
        }
    }
    func moveSelectedCorner(to point: SIMD2<Float>, surfaceID: UUID, now: Date = .now) {
        guard let corner = selectedCorner, selectedSurfaceID == surfaceID,
              let i = project.surfaces.firstIndex(where: { $0.id == surfaceID }), point.x.isFinite, point.y.isFinite else { return }
        let clamped = SIMD2(min(1, max(0, point.x)), min(1, max(0, point.y)))
        guard project.surfaces[i].corners[corner] != clamped else { return }
        project.surfaces[i].corners = project.surfaces[i].corners.replacing(corner, with: clamped); changed(now: now)
    }
    func setSurfaceContent(_ content: SurfaceContent, now: Date = .now) { updateSource(now: now) { $0.content = content } }
    func setSourceColor(_ color: SIMD4<Float>) {
        guard (0..<4).allSatisfy({ color[$0].isFinite && (0...1).contains(color[$0]) }) else { return }
        updateSource { $0.color = color }
    }
    @discardableResult
    func saveGeneratorPreset(name: String) -> UUID? {
        guard let source = selectedSource, source.content.isAnimated else { return nil }
        guard project.generatorPresets.count < 100 else { editMessage = "Maximum of 100 presets reached."; return nil }
        let base = cleanName(name, fallback: source.content.title)
        var name = base, n = 2
        while project.generatorPresets.contains(where: { $0.name == name }) {
            let suffix = " \(n)"; name = String(base.prefix(80 - suffix.count)) + suffix; n += 1
        }
        let preset = GeneratorPreset(name: name, content: source.content, color: source.color, settings: source.generator)
        project.generatorPresets.append(preset); changed(); return preset.id
    }
    func applyGeneratorPreset(_ id: UUID) {
        guard let preset = project.generatorPresets.first(where: { $0.id == id }) else { return }
        updateSource { $0.content = preset.content; $0.color = preset.color; $0.generator = preset.settings }
    }
    func updateGeneratorPreset(_ id: UUID) {
        guard let source = selectedSource, source.content.isAnimated,
              let i = project.generatorPresets.firstIndex(where: { $0.id == id }) else { return }
        let old = project.generatorPresets[i]
        project.generatorPresets[i].content = source.content; project.generatorPresets[i].color = source.color
        project.generatorPresets[i].settings = source.generator
        if old != project.generatorPresets[i] { changed() }
    }
    func deleteGeneratorPreset(_ id: UUID) {
        guard project.generatorPresets.contains(where: { $0.id == id }) else { return }
        project.generatorPresets.removeAll { $0.id == id }; changed()
    }
    func resetGeneratorSettings() {
        guard selectedSource?.content.isAnimated == true else { return }
        updateSource { $0.generator = .defaults; $0.color = SIMD4(1,0.25,0,1) }
    }
    func setGeneratorSettings(_ settings: GeneratorSettings) {
        guard settings.isValid else { return }
        updateSource { $0.generator = settings }
    }
    func setSecondaryColor(_ color: SIMD4<Float>) {
        guard (0..<4).allSatisfy({ color[$0].isFinite && (0...1).contains(color[$0]) }) else { return }
        updateSource { $0.generator.secondaryColor = color }
    }
    private func updateSource(now: Date = .now, _ edit: (inout SurfaceSource) -> Void) {
        let objectID = selectedObjectID ?? selectedSurface?.layout.objectID
        if let i = project.objects.firstIndex(where: { $0.id == objectID }) {
            let old = project.objects[i].source; edit(&project.objects[i].source)
            if old != project.objects[i].source { changed(now: now) }
        } else if let i = project.surfaces.firstIndex(where: { $0.id == selectedSurfaceID }) {
            let old = project.surfaces[i].source; edit(&project.surfaces[i].source)
            if old != project.surfaces[i].source { changed(now: now) }
        }
    }
    func nudgeSelectedCorner(direction: SIMD2<Float>, larger: Bool) {
        guard let corner = selectedCorner, let face = selectedSurface else { return }
        moveSelectedCorner(to: face.corners[corner] + direction * (larger ? 0.01 : 0.001), surfaceID: face.id)
    }
    func createObject(faceIDs: Set<UUID>? = nil) {
        let ids = faceIDs ?? groupingSelection
        let faces = project.surfaces.filter { ids.contains($0.id) }
        guard !faces.isEmpty else { editMessage = "Check faces in the sidebar first."; return }
        var object = MappingObject(name: "Object \(project.objects.count + 1)", source: project.source(for: faces[0]).independentCopy())
        copyPlayback(from: project.source(for: faces[0]).id, to: object.source.id)
        var number = 1
        while project.objects.contains(where: { $0.name == object.name }) { number += 1; object.name = "Object \(number)" }
        for (n,face) in faces.enumerated() {
            detachSurface(face.id, notify: false)
            let i = project.surfaces.firstIndex { $0.id == face.id }!
            project.surfaces[i].layout.objectID = object.id
            project.surfaces[i].layout.inputMap = FaceInputMap(origin: SIMD2(Float(n)/Float(faces.count),0), size: SIMD2(1/Float(faces.count),1))
            if n > 0 { object.links.append(FaceEdgeLink(firstFace: faces[n-1].id, firstEdge: .right, secondFace: face.id, secondEdge: .left)) }
        }
        project.objects.append(object); groupingSelection.removeAll(); selectObject(object.id); changed()
    }
    func attachSurface(_ faceID: UUID, to objectID: UUID) {
        guard project.objects.contains(where: { $0.id == objectID }),
              let face = project.surfaces.first(where: { $0.id == faceID }), face.layout.objectID != objectID else { return }
        detachSurface(faceID, notify: false)
        let i = project.surfaces.firstIndex { $0.id == faceID }!
        project.surfaces[i].layout.objectID = objectID; changed()
    }
    func detachSurface(_ id: UUID, notify: Bool = true) {
        guard let i = project.surfaces.firstIndex(where: { $0.id == id }), let object = project.object(for: project.surfaces[i]) else { return }
        project.surfaces[i].source = object.source.independentCopy()
        copyPlayback(from: object.source.id, to: project.surfaces[i].source.id)
        // Bake effective group visibility; preserve the input region for appearance continuity.
        project.surfaces[i].layout.isVisible = project.surfaces[i].layout.isVisible && object.isVisible
        if object.mode == .repeatContent { project.surfaces[i].layout.inputMap = .full }
        project.surfaces[i].layout.objectID = nil
        for n in project.objects.indices { project.objects[n].links.removeAll { $0.firstFace == id || $0.secondFace == id } }
        removeEmptyObjects(); if notify { changed() }
    }
    func ungroupObject(_ id: UUID) {
        let members = project.surfaces.filter { $0.layout.objectID == id }.map(\.id)
        guard !members.isEmpty else { return }
        for member in members { detachSurface(member, notify: false) }
        selectSurface(members.first); changed()
    }
    func deleteObject(_ id: UUID) {
        let members = Set(project.surfaces.filter { $0.layout.objectID == id }.map(\.id))
        guard !members.isEmpty else { return }
        project.surfaces.removeAll { members.contains($0.id) }; groupingSelection.subtract(members)
        project.objects.removeAll { $0.id == id }; selectSurface(project.surfaces.first?.id); changed()
    }
    func duplicateObject(_ id: UUID) {
        guard var object = project.objects.first(where: { $0.id == id }) else { return }
        let originals = project.surfaces.filter { $0.layout.objectID == id }
        let oldSource = object.source.id
        object.id = UUID(); object.name = uniqueCopyName(object.name, names: project.objects.map(\.name)); object.source = object.source.independentCopy()
        copyPlayback(from: oldSource, to: object.source.id)
        var ids: [UUID:UUID] = [:], copies: [MappingSurface] = []
        for original in originals {
            var copy = MappingSurface(name: uniqueCopyName(original.name, names: project.surfaces.map(\.name) + copies.map(\.name)))
            copy.layout = original.layout; copy.layout.objectID = object.id; copy.source = original.source.independentCopy(); copy.tags = original.tags
            ids[original.id] = copy.id; copies.append(copy)
        }
        object.links = object.links.compactMap { link in
            guard let a = ids[link.firstFace], let b = ids[link.secondFace] else { return nil }
            var copy = link; copy.id = UUID(); copy.firstFace = a; copy.secondFace = b; return copy
        }
        project.surfaces.insert(contentsOf: copies, at: 0); project.objects.append(object); selectObject(object.id); changed()
    }
    func setObjectMode(_ mode: ObjectContentMode, id: UUID) {
        guard let i = project.objects.firstIndex(where: { $0.id == id }), project.objects[i].mode != mode else { return }
        project.objects[i].mode = mode; changed()
    }
    func setInputMap(_ map: FaceInputMap, faceID: UUID) {
        guard map.isValid, let i = project.surfaces.firstIndex(where: { $0.id == faceID }), project.surfaces[i].layout.inputMap != map else { return }
        project.surfaces[i].layout.inputMap = map; changed()
    }
    func addLink(_ link: FaceEdgeLink, objectID: UUID, align: Bool = false) {
        guard let i = project.objects.firstIndex(where: { $0.id == objectID }), link.firstFace != link.secondFace,
              let a = project.surfaces.first(where: { $0.id == link.firstFace && $0.layout.objectID == objectID }),
              let b = project.surfaces.first(where: { $0.id == link.secondFace && $0.layout.objectID == objectID }) else { return }
        if project.objects[i].links.contains(where: { $0.firstFace == link.firstFace && $0.firstEdge == link.firstEdge && $0.secondFace == link.secondFace && $0.secondEdge == link.secondEdge }) {
            editMessage = "This edge pair is already linked. Remove its existing link to change it."; return
        }
        if align && !link.isSeam {
            guard let map = Self.alignedMap(first: a.layout.inputMap, second: b.layout.inputMap, link: link) else {
                editMessage = "Edges cannot fit in this canvas. Adjust input regions or mark a deliberate seam."; return
            }
            let index = project.surfaces.firstIndex { $0.id == b.id }!; project.surfaces[index].layout.inputMap = map
        }
        project.objects[i].links.append(link); changed()
    }
    static func alignedMap(first: FaceInputMap, second: FaceInputMap, link: FaceEdgeLink) -> FaceInputMap? {
        let (a0,a1) = link.firstEdge.endpoints, (edge0,edge1) = link.secondEdge.endpoints
        let b0 = link.reversed ? edge1 : edge0, b1 = link.reversed ? edge0 : edge1
        let target0 = first.sample(a0), delta = first.sample(a1) - target0
        for mirror in [second.mirrored, !second.mirrored] {
            for turn in 0..<4 {
                var map = second; map.mirrored = mirror; map.quarterTurns = turn
                let unit = FaceInputMap(quarterTurns: turn, mirrored: mirror)
                let direction = unit.sample(b1) - unit.sample(b0)
                if abs(direction.x) > 0.5 { map.size.x = delta.x / direction.x }
                else { map.size.y = delta.y / direction.y }
                map.origin = .zero
                map.origin = target0 - map.sample(b0)
                guard map.isValid, simd_length(map.sample(b1) - first.sample(a1)) < 0.0001 else { continue }
                let centerA = first.sample(SIMD2(0.5,0.5)) - target0
                let centerB = map.sample(SIMD2(0.5,0.5)) - target0
                let sideA = delta.x * centerA.y - delta.y * centerA.x
                let sideB = delta.x * centerB.y - delta.y * centerB.x
                guard sideA * sideB < 0 else { continue }
                return map
            }
        }
        return nil
    }
    func removeLink(_ linkID: UUID, objectID: UUID) {
        guard let i = project.objects.firstIndex(where: { $0.id == objectID }), project.objects[i].links.contains(where: { $0.id == linkID }) else { return }
        project.objects[i].links.removeAll { $0.id == linkID }; changed()
    }
    func resetProject(now: Date = .now) {
        sourcePlayback.removeAll(); transport = AnimationTransport(); project = MappingProject(now: now); selectedSurfaceID = project.surfaces.first?.id
        selectedObjectID = nil; selectedCorner = nil; groupingSelection.removeAll(); editMessage = nil; testOutput.setScene(scene)
    }
}
