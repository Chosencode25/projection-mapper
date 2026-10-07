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
    private(set) var showOutput = ShowOutputState()
    private(set) var calibration = CalibrationState()
    private(set) var lastLookReport: String?
    var scene: RenderScene {
        let faces = project.renderScene.surfaces.map { face in
            var face = face; face.playback = face.sourceID.flatMap { sourcePlayback[$0] } ?? SourcePlayback(); return face
        }
        var result = RenderScene(surfaces: faces, transport: transport)
        result.masterBrightness = project.masterOutput.brightness; result.showOutput = showOutput; result.calibration = calibration
        return result
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
    private(set) var editorDisplay = EditorDisplayState.defaults
    var editorLabels: [EditorFaceLabel] { EditorDecorations.labels(project: project,selectedFace: selectedSurfaceID,selectedObject: selectedObjectID) }
    func setEditorDisplay(_ value: EditorDisplayState) {
        guard editorDisplay != value else { return }
        if !value.cornerHandles { selectedCorner = nil }
        if !value.maskHandles { selectedMaskVertex = nil; cancelMaskDrawing() }
        editorDisplay = value
    }
    func toggleEditorHandles() {
        var value = editorDisplay; let show = !value.hasHandles
        value.cornerHandles = show; value.maskHandles = show; setEditorDisplay(value)
    }
    func toggleEditorLabels() { var value = editorDisplay; value.faceLabels.toggle(); setEditorDisplay(value) }
    func resetEditorDisplay() { setEditorDisplay(.defaults) }
    func inspectJoins(objectID: UUID, pattern: CalibrationPattern) {
        guard project.objects.contains(where: { $0.id == objectID }) else { return }
        selectObject(objectID)
        var value = editorDisplay; value.faceLabels = true; value.edgeLabels = true; setEditorDisplay(value)
        setCalibrationPattern(pattern)
    }
    var isMaskEditing = false
    var selectedMaskRingID: UUID?
    var selectedMaskVertex: Int?
    private(set) var maskDraft: [SIMD2<Float>]?
    private(set) var maskDrawingHole = false
    func cancelMaskDrawing() { maskDraft = nil }
    private func clearMaskEditing() {
        isMaskEditing = false; selectedMaskRingID = nil; selectedMaskVertex = nil; maskDraft = nil
    }
    func setMask(_ mask: FaceMask?, faceID: UUID) {
        guard let i = project.surfaces.firstIndex(where: { $0.id == faceID }), mask?.isBounded ?? true,
              project.surfaces[i].mask != mask else { return }
        project.surfaces[i].mask = mask; changed()
        if mask == nil { clearMaskEditing() }
    }
    func createMask(faceID: UUID) {
        guard project.surfaces.first(where: { $0.id == faceID })?.mask == nil else { return }
        let mask = FaceMask(); setMask(mask,faceID: faceID)
        selectedMaskRingID = mask.boundary.id; selectedMaskVertex = nil; isMaskEditing = true
    }
    func selectMaskRing(_ id: UUID) {
        guard selectedSurface?.mask?.rings.contains(where: { $0.id == id }) == true else { return }
        selectedMaskRingID = id; selectedMaskVertex = nil; cancelMaskDrawing()
    }
    func beginMaskDrawing(hole: Bool) {
        guard let mask = selectedSurface?.mask, !hole || mask.holes.count < FaceMask.maxHoles else { return }
        var display = editorDisplay; display.maskHandles = true; setEditorDisplay(display)
        isMaskEditing = true; maskDrawingHole = hole; maskDraft = []; selectedMaskVertex = nil
    }
    func appendMaskDraft(_ point: SIMD2<Float>, faceID: UUID) {
        guard selectedSurfaceID == faceID, let draft = maskDraft, draft.count < FaceMask.maxPoints,
              point.x.isFinite, point.y.isFinite, (0...1).contains(point.x), (0...1).contains(point.y) else { return }
        maskDraft = draft + [point]
    }
    func removeLastMaskDraftPoint() { if maskDraft?.isEmpty == false { maskDraft?.removeLast() } }
    func finishMaskDrawing() {
        guard let face = selectedSurface, var mask = face.mask, let points = maskDraft else { return }
        if maskDrawingHole {
            guard mask.holes.count < FaceMask.maxHoles else { return }
            let ring = MaskPolygon(points: points); mask.holes.append(ring)
        } else { mask.boundary.points = points }
        if let message = mask.validationMessage { editMessage = message; return }
        selectedMaskRingID = maskDrawingHole ? mask.holes.last?.id : mask.boundary.id
        maskDraft = nil; selectedMaskVertex = nil; setMask(mask,faceID: face.id)
    }
    func editMaskRing(faceID: UUID, ringID: UUID, edit: (inout [SIMD2<Float>]) -> Void) {
        guard selectedSurfaceID == faceID, var mask = selectedSurface?.mask else { return }
        if mask.boundary.id == ringID { edit(&mask.boundary.points) }
        else if let i = mask.holes.firstIndex(where: { $0.id == ringID }) { edit(&mask.holes[i].points) }
        else { return }
        setMask(mask,faceID: faceID)
    }
    func moveMaskPoint(_ point: SIMD2<Float>, faceID: UUID, ringID: UUID, index: Int) {
        guard point.x.isFinite, point.y.isFinite else { return }
        editMaskRing(faceID: faceID,ringID: ringID) { points in
            guard points.indices.contains(index) else { return }
            points[index] = SIMD2(min(1,max(0,point.x)),min(1,max(0,point.y)))
        }
    }
    func insertMaskPoint() {
        guard let face = selectedSurface, let ring = face.mask?.rings.first(where: { $0.id == selectedMaskRingID }),
              !ring.points.isEmpty, ring.points.count < FaceMask.maxPoints else { return }
        let i = min(max(0,selectedMaskVertex ?? 0),ring.points.count-1)
        editMaskRing(faceID: face.id,ringID: ring.id) { $0.insert((ring.points[i]+ring.points[(i+1)%ring.points.count])/2,at: i+1) }
        selectedMaskVertex = i+1
    }
    func deleteMaskPoint() {
        guard let face = selectedSurface, let ring = face.mask?.rings.first(where: { $0.id == selectedMaskRingID }),
              let i = selectedMaskVertex, ring.points.indices.contains(i), ring.points.count > 3 else { return }
        editMaskRing(faceID: face.id,ringID: ring.id) { $0.remove(at: i) }; selectedMaskVertex = nil
    }
    func removeSelectedMaskHole() {
        guard let face = selectedSurface, var mask = face.mask, mask.holes.contains(where: { $0.id == selectedMaskRingID }) else { return }
        mask.holes.removeAll { $0.id == selectedMaskRingID }; setMask(mask,faceID: face.id)
        selectedMaskRingID = mask.boundary.id; selectedMaskVertex = nil; cancelMaskDrawing()
    }

    var selectedSurface: MappingSurface? { project.surfaces.first { $0.id == selectedSurfaceID } }
    var selectedObject: MappingObject? { project.objects.first { $0.id == selectedObjectID } }
    var selectedSource: SurfaceSource? {
        if let object = selectedObject { return object.source }
        return selectedSurface.map { project.source(for: $0) }
    }
    let testOutput: TestOutputCoordinator
    var isSidebarVisible = true
    var isInspectorVisible = true
    private var savedBaseline: MappingProject
    private(set) var documentURL: URL?
    private var assetSourceURL: URL?
    private var isRecovered = false
    private var recoveryStore: ProjectRecoveryStore?
    private var autosaveTask: Task<Void,Never>?
    var recentProjectURLs: [URL] = (UserDefaults.standard.stringArray(forKey: "recentProjects") ?? []).map { URL(fileURLWithPath: $0) }
    var fileMessage: String?
    var hasUserChanges: Bool {
        var current = project; current.modifiedAt = savedBaseline.modifiedAt
        return isRecovered || current != savedBaseline
    }
    var document: ProjectDocument {
        ProjectDocument(project: project,output: ProjectOutputSettings(destination: output.savedPreference,resolution: output.testResolution))
    }
    func configureRecovery(_ store: ProjectRecoveryStore) { recoveryStore = store; scheduleRecovery() }
    private func scheduleRecovery() {
        autosaveTask?.cancel()
        guard recoveryStore != nil else { return }
        guard hasUserChanges else { recoveryStore?.remove(projectID: project.id); return }
        autosaveTask = Task { @MainActor [weak self] in
            do { try await Task.sleep(for: .seconds(2)) } catch { return }
            guard let self, !Task.isCancelled else { return }
            do { try self.flushRecovery(); self.fileMessage = "Recovery copy updated" }
            catch { self.fileMessage = "Recovery could not be updated: \(error.localizedDescription)" }
        }
    }
    func flushRecovery() throws {
        guard hasUserChanges, let recoveryStore else { return }
        try recoveryStore.save(document,original: documentURL,assetsFrom: assetSourceURL)
    }
    func clearRecovery() {
        autosaveTask?.cancel(); autosaveTask = nil; recoveryStore?.remove(projectID: project.id)
    }
    func save(to url: URL, store: ProjectPackageStore = ProjectPackageStore()) throws {
        try store.write(document,to: url,assetsFrom: assetSourceURL)
        documentURL = url; assetSourceURL = url; savedBaseline = project; isRecovered = false
        clearRecovery(); fileMessage = "Saved \(url.lastPathComponent)"
    }
    func load(_ document: ProjectDocument, from url: URL, recovering: Bool = false, store: ProjectPackageStore = ProjectPackageStore()) throws {
        try ProjectCodec.validate(document)
        if !recovering || project.id != document.project.id { clearRecovery() }
        project = document.project; savedBaseline = project; isRecovered = recovering || document.recovery != nil
        documentURL = isRecovered ? nil : url; assetSourceURL = url
        if isRecovered, let path = document.recovery?.originalPath {
            let original = URL(fileURLWithPath: path)
            if let saved = try? store.read(original), saved.project.id == project.id { documentURL = original; savedBaseline = saved.project }
        }
        output.restoreProjectPreference(document.output.destination,resolution: document.output.resolution)
        clearMaskEditing(); resetEditorDisplay(); sourcePlayback.removeAll(); transport = AnimationTransport(); showOutput = ShowOutputState(); calibration = CalibrationState(); lastLookReport = nil; selectedSurfaceID = project.surfaces.first?.id
        selectedObjectID = nil; selectedCorner = nil; groupingSelection.removeAll(); editMessage = nil
        testOutput.setResolution(output.testResolution); testOutput.destinationDidChange(output.destination); testOutput.setScene(scene)
        fileMessage = isRecovered ? "Recovered unsaved project — Save to keep it" : "Opened \(url.lastPathComponent)"
        scheduleRecovery()
    }
    var editMessage: String?

    init(presentOutput: @escaping (NSWindow) -> Void = { $0.makeKeyAndOrderFront(nil) },
         project: MappingProject = MappingProject(), output: OutputSelectionState = OutputSelectionState()) {
        self.project = project; self.savedBaseline = project; self.output = output
        isRecovered = !project.hasDefaultContent
        selectedSurfaceID = project.surfaces.first?.id
        testOutput = TestOutputCoordinator(presentWindow: presentOutput, scene: project.renderScene)
    }
    private func changed(now: Date = .now) {
        let active = Set(project.surfaces.map { project.source(for: $0).id })
        sourcePlayback = sourcePlayback.filter { active.contains($0.key) }
        project.modifiedAt = now; editMessage = nil; testOutput.setScene(scene); scheduleRecovery()
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
        if id != selectedSurfaceID { selectedCorner = nil; clearMaskEditing() }
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
        clearMaskEditing(); selectedObjectID = id; selectedSurfaceID = nil; selectedCorner = nil; editMessage = nil
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
        face.appearance = original.appearance; face.appearanceOverride = original.appearanceOverride; face.mask = original.mask?.independentCopy()
        copyPlayback(from: original.source.id, to: face.source.id)
        project.surfaces.insert(face, at: i); selectSurface(face.id); changed()
    }
    private func uniqueCopyName(_ name: String, names: [String]) -> String {
        var result = String(name.prefix(75)) + " copy", index = 2
        while names.contains(result) { result = String(name.prefix(70)) + " copy \(index)"; index += 1 }
        return result
    }
    func deleteSurface(_ id: UUID) {
        guard let i = project.surfaces.firstIndex(where: { $0.id == id }) else { return }
        guard !project.isGeometryLocked(project.surfaces[i]) else { editMessage = "Unlock this face before deleting it."; return }
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
    func setGeometryLocked(_ locked: Bool, faceID: UUID? = nil, objectID: UUID? = nil) {
        if let i = project.objects.firstIndex(where: { $0.id == objectID }), project.objects[i].isGeometryLocked != locked {
            project.objects[i].isGeometryLocked = locked; changed()
        } else if let i = project.surfaces.firstIndex(where: { $0.id == faceID }), project.surfaces[i].layout.isGeometryLocked != locked {
            project.surfaces[i].layout.isGeometryLocked = locked; changed()
        }
    }
    func moveObject(_ id: UUID, by requested: SIMD2<Float>, now: Date = .now) {
        guard requested.x.isFinite, requested.y.isFinite, project.objects.contains(where: { $0.id == id }) else { return }
        guard project.canMoveObject(id) else { editMessage = "Unlock the object and all member faces before moving it."; return }
        guard let bounds = project.outputBounds(forObject: id) else { return }
        let delta = SIMD2(max(-bounds.topLeft.x,min(1-bounds.bottomRight.x,requested.x)),max(-bounds.topLeft.y,min(1-bounds.bottomRight.y,requested.y)))
        guard delta != .zero else { return }
        // One shared offset, one published scene and one modification timestamp for the whole object.
        for i in project.surfaces.indices where project.surfaces[i].layout.objectID == id {
            project.surfaces[i].corners = project.surfaces[i].corners.translated(by: delta)
        }
        changed(now: now)
    }
    func nudgeSelectedObject(direction: SIMD2<Float>, larger: Bool) {
        guard let id = selectedObjectID else { return }; moveObject(id,by: direction * (larger ? 0.01 : 0.001))
    }
    private func defaultContent(_ source: SurfaceSource) -> SurfaceSource {
        var result = SurfaceSource(); result.id = source.id; return result
    }
    func resetFace(_ id: UUID, scope: FaceResetScope) {
        guard let i = project.surfaces.firstIndex(where: { $0.id == id }) else { return }
        let old = project.surfaces[i], grouped = old.layout.objectID != nil
        if scope == .outputGeometry || scope == .fullFace {
            guard !project.isGeometryLocked(old) else { editMessage = "Unlock this face's output geometry before resetting it."; return }
        }
        var face = old
        switch scope {
        case .outputGeometry: face.corners = .diagnostic
        case .appearance, .cropAndFlip:
            guard !grouped || face.appearanceOverride != nil else { editMessage = "Enable this face's override or reset the object controls."; return }
            var value = project.appearance(for: face)
            if scope == .appearance { value.opacity = 1; value.brightness = 1 }
            else { value.crop = ContentCrop(); value.flipHorizontal = false; value.flipVertical = false }
            if grouped { face.appearanceOverride = value } else { face.appearance = value }
        case .generatorParameters, .content:
            guard !grouped else { editMessage = "Reset shared content from the object inspector."; return }
            if scope == .content { face.source = defaultContent(face.source) }
            else { face.source.generator = .defaults; face.source.color = SurfaceSource().color; face.source.primaryBinding = nil; face.source.secondaryBinding = nil }
        case .fullFace:
            face.corners = .diagnostic; face.layout.isVisible = true; face.appearance = .defaults; face.appearanceOverride = nil
            if !grouped { face.source = defaultContent(face.source) }
        }
        guard face != old else { return }; project.surfaces[i] = face; changed()
    }
    func resetObject(_ id: UUID, scope: ObjectResetScope) {
        guard let i = project.objects.firstIndex(where: { $0.id == id }) else { return }
        let old = project
        switch scope {
        case .appearance: project.objects[i].appearance.opacity = 1; project.objects[i].appearance.brightness = 1
        case .cropAndFlip: project.objects[i].appearance.crop = ContentCrop(); project.objects[i].appearance.flipHorizontal = false; project.objects[i].appearance.flipVertical = false
        case .generatorParameters: project.objects[i].source.generator = .defaults; project.objects[i].source.color = SurfaceSource().color; project.objects[i].source.primaryBinding = nil; project.objects[i].source.secondaryBinding = nil
        case .content: project.objects[i].source = defaultContent(project.objects[i].source)
        case .inputLayout:
            let indices = project.surfaces.indices.filter { project.surfaces[$0].layout.objectID == id }
            guard !indices.isEmpty else { return }
            for (n,index) in indices.enumerated() { project.surfaces[index].layout.inputMap = FaceInputMap(origin: SIMD2(Float(n)/Float(indices.count),0),size: SIMD2(1/Float(indices.count),1)) }
        }
        if project != old { changed() }
    }
    func moveSelectedCorner(to point: SIMD2<Float>, surfaceID: UUID, now: Date = .now) {
        guard let corner = selectedCorner, selectedSurfaceID == surfaceID,
              let i = project.surfaces.firstIndex(where: { $0.id == surfaceID }), point.x.isFinite, point.y.isFinite else { return }
        guard !project.isGeometryLocked(project.surfaces[i]) else { editMessage = "Output geometry is locked. Unlock it in the inspector."; return }
        let clamped = SIMD2(min(1, max(0, point.x)), min(1, max(0, point.y)))
        guard project.surfaces[i].corners[corner] != clamped else { return }
        project.surfaces[i].corners = project.surfaces[i].corners.replacing(corner, with: clamped); changed(now: now)
    }
    /// Face edits are independent only when an explicit object-member override is enabled.
    func setAppearance(_ value: SurfaceAppearance, faceID: UUID? = nil, objectID: UUID? = nil) {
        guard value.isValid else { editMessage = "Appearance must use bounded finite values and a valid crop."; return }
        if let i = project.objects.firstIndex(where: { $0.id == objectID }) {
            guard project.objects[i].appearance != value else { return }
            project.objects[i].appearance = value; changed()
        } else if let i = project.surfaces.firstIndex(where: { $0.id == faceID }) {
            if project.surfaces[i].layout.objectID != nil {
                guard project.surfaces[i].appearanceOverride != nil else { editMessage = "Inspect the object or enable this face's override."; return }
                guard project.surfaces[i].appearanceOverride != value else { return }
                project.surfaces[i].appearanceOverride = value
            } else {
                guard project.surfaces[i].appearance != value else { return }
                project.surfaces[i].appearance = value
            }
            changed()
        }
    }
    func setAppearanceOverride(_ enabled: Bool, faceID: UUID) {
        guard let i = project.surfaces.firstIndex(where: { $0.id == faceID }), project.object(for: project.surfaces[i]) != nil,
              (project.surfaces[i].appearanceOverride != nil) != enabled else { return }
        let effective = project.appearance(for: project.surfaces[i])
        project.surfaces[i].appearanceOverride = enabled ? effective : nil; changed()
    }
    func setSurfaceContent(_ content: SurfaceContent, now: Date = .now) { updateSource(now: now) { $0.content = content } }
    func setSourceColor(_ color: SIMD4<Float>) {
        guard (0..<4).allSatisfy({ color[$0].isFinite && (0...1).contains(color[$0]) }) else { return }
        updateSource { $0.color = color; $0.primaryBinding = nil }
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
        let resolved = project.resolvedSource(source)
        let preset = GeneratorPreset(name: name, content: resolved.content, color: resolved.color, settings: resolved.generator)
        project.generatorPresets.append(preset); changed(); return preset.id
    }
    func applyGeneratorPreset(_ id: UUID) {
        guard let preset = project.generatorPresets.first(where: { $0.id == id }) else { return }
        updateSource { $0.content = preset.content; $0.color = preset.color; $0.generator = preset.settings; $0.primaryBinding = nil; $0.secondaryBinding = nil }
    }
    func updateGeneratorPreset(_ id: UUID) {
        guard let source = selectedSource, source.content.isAnimated,
              let i = project.generatorPresets.firstIndex(where: { $0.id == id }) else { return }
        let old = project.generatorPresets[i]
        let resolved = project.resolvedSource(source)
        project.generatorPresets[i].content = resolved.content; project.generatorPresets[i].color = resolved.color
        project.generatorPresets[i].settings = resolved.generator
        if old != project.generatorPresets[i] { changed() }
    }
    func deleteGeneratorPreset(_ id: UUID) {
        guard project.generatorPresets.contains(where: { $0.id == id }) else { return }
        project.generatorPresets.removeAll { $0.id == id }; changed()
    }
    func resetGeneratorSettings() {
        guard selectedSource?.content.isAnimated == true else { return }
        updateSource { $0.generator = .defaults; $0.color = SIMD4(1,0.25,0,1); $0.primaryBinding = nil; $0.secondaryBinding = nil }
    }
    func setGeneratorSettings(_ settings: GeneratorSettings) {
        guard settings.isValid else { return }
        updateSource { $0.generator = settings }
    }
    func setSecondaryColor(_ color: SIMD4<Float>) {
        guard (0..<4).allSatisfy({ color[$0].isFinite && (0...1).contains(color[$0]) }) else { return }
        updateSource { $0.generator.secondaryColor = color; $0.secondaryBinding = nil }
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
        object.appearance = project.appearance(for: faces[0])
        copyPlayback(from: project.source(for: faces[0]).id, to: object.source.id)
        var number = 1
        while project.objects.contains(where: { $0.name == object.name }) { number += 1; object.name = "Object \(number)" }
        for (n,face) in faces.enumerated() {
            detachSurface(face.id, notify: false)
            let i = project.surfaces.firstIndex { $0.id == face.id }!
            project.surfaces[i].layout.objectID = object.id
            project.surfaces[i].appearanceOverride = nil
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
        project.surfaces[i].layout.objectID = objectID; project.surfaces[i].appearanceOverride = nil; changed()
    }
    func detachSurface(_ id: UUID, notify: Bool = true) {
        guard let i = project.surfaces.firstIndex(where: { $0.id == id }), let object = project.object(for: project.surfaces[i]) else { return }
        project.surfaces[i].layout.isGeometryLocked = project.isGeometryLocked(project.surfaces[i])
        project.surfaces[i].appearance = project.appearance(for: project.surfaces[i])
        project.surfaces[i].appearanceOverride = nil
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
        guard project.canMoveObject(id) else { editMessage = "Unlock the object and its faces before deleting it."; return }
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
            copy.appearance = original.appearance; copy.appearanceOverride = original.appearanceOverride; copy.mask = original.mask?.independentCopy()
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
        clearRecovery(); documentURL = nil; assetSourceURL = nil; isRecovered = false; fileMessage = nil
        clearMaskEditing(); resetEditorDisplay(); sourcePlayback.removeAll(); transport = AnimationTransport(); showOutput = ShowOutputState(); calibration = CalibrationState(); lastLookReport = nil; project = MappingProject(now: now); savedBaseline = project; selectedSurfaceID = project.surfaces.first?.id
        selectedObjectID = nil; selectedCorner = nil; groupingSelection.removeAll(); editMessage = nil; testOutput.setScene(scene)
    }
}

extension EditorSession {
    /// Publish one validated edit so failed library actions cannot leave partial state.
    private func commitShowEdit(_ candidate: MappingProject) -> Bool {
        do {
            try ProjectCodec.validate(ProjectDocument(project: candidate, output: document.output))
        } catch {
            editMessage = "Show controls could not be changed: \(error.localizedDescription)"; return false
        }
        editMessage = nil
        guard candidate != project else { return true }
        project = candidate; changed(); return true
    }
    @discardableResult
    func createPalette(name: String) -> UUID? {
        guard project.palettes.count < 100 else { editMessage = "Maximum of 100 palettes reached."; return nil }
        let palette = ColorPalette(name: cleanName(name, fallback: "Palette \(project.palettes.count + 1)"), slots: [])
        var candidate = project; candidate.palettes.append(palette)
        return commitShowEdit(candidate) ? palette.id : nil
    }
    func renamePalette(_ id: UUID, name: String) {
        guard let i = project.palettes.firstIndex(where: { $0.id == id }) else { return }
        var candidate = project; candidate.palettes[i].name = cleanName(name, fallback: candidate.palettes[i].name)
        _ = commitShowEdit(candidate)
    }
    @discardableResult
    func addPaletteSlot(_ id: UUID, name: String, color: SIMD4<Float>) -> UUID? {
        guard let i = project.palettes.firstIndex(where: { $0.id == id }) else { return nil }
        guard project.palettes[i].slots.count < 32 else { editMessage = "Maximum of 32 colors per palette reached."; return nil }
        let slot = PaletteSlot(name: cleanName(name, fallback: "Color \(project.palettes[i].slots.count + 1)"), color: color)
        var candidate = project; candidate.palettes[i].slots.append(slot)
        return commitShowEdit(candidate) ? slot.id : nil
    }
    func renamePaletteSlot(_ id: UUID, slotID: UUID, name: String) {
        guard let i = project.palettes.firstIndex(where: { $0.id == id }),
              let j = project.palettes[i].slots.firstIndex(where: { $0.id == slotID }) else { return }
        var candidate = project; candidate.palettes[i].slots[j].name = cleanName(name, fallback: candidate.palettes[i].slots[j].name)
        _ = commitShowEdit(candidate)
    }
    func setPaletteColor(_ id: UUID, slotID: UUID, color: SIMD4<Float>) {
        guard let i = project.palettes.firstIndex(where: { $0.id == id }),
              let j = project.palettes[i].slots.firstIndex(where: { $0.id == slotID }) else { return }
        var candidate = project; candidate.palettes[i].slots[j].color = color
        _ = commitShowEdit(candidate)
    }
    func movePaletteSlot(_ id: UUID, slotID: UUID, offset: Int) {
        guard offset == -1 || offset == 1, let i = project.palettes.firstIndex(where: { $0.id == id }),
              let j = project.palettes[i].slots.firstIndex(where: { $0.id == slotID }),
              project.palettes[i].slots.indices.contains(j + offset) else { return }
        var candidate = project; candidate.palettes[i].slots.swapAt(j,j + offset); _ = commitShowEdit(candidate)
    }
    func paletteReferenceCount(_ id: UUID, slotID: UUID? = nil) -> Int {
        func count(_ primary: ColorBinding?, _ secondary: ColorBinding?) -> Int {
            [primary,secondary].compactMap { $0 }.filter { $0.paletteID == id && (slotID == nil || $0.slotID == slotID) }.count
        }
        let live = project.surfaces.map(\.source) + project.objects.map(\.source)
        return live.reduce(0) { $0 + count($1.primaryBinding,$1.secondaryBinding) } +
            project.looks.flatMap(\.entries).compactMap(\.source).reduce(0) { $0 + count($1.primaryBinding,$1.secondaryBinding) }
    }
    private func materializePalette(_ id: UUID, slotID: UUID?, in candidate: inout MappingProject) {
        func removed(_ binding: ColorBinding?) -> Bool { binding?.paletteID == id && (slotID == nil || binding?.slotID == slotID) }
        func materialize(_ source: inout SurfaceSource) {
            let resolved = project.resolvedSource(source)
            if removed(source.primaryBinding) { source.color = resolved.color; source.primaryBinding = nil }
            if removed(source.secondaryBinding) { source.generator.secondaryColor = resolved.generator.secondaryColor; source.secondaryBinding = nil }
        }
        // Include dormant face sources retained under objects and all stored look entries.
        for i in candidate.surfaces.indices { materialize(&candidate.surfaces[i].source) }
        for i in candidate.objects.indices { materialize(&candidate.objects[i].source) }
        for i in candidate.looks.indices {
            for j in candidate.looks[i].entries.indices {
                guard let lookSource = candidate.looks[i].entries[j].source else { continue }
                var source = lookSource.applying(to: SurfaceSource()); materialize(&source)
                candidate.looks[i].entries[j].source = SourceLook(source: source)
            }
        }
    }
    func deletePalette(_ id: UUID) {
        guard project.palettes.contains(where: { $0.id == id }) else { return }
        var candidate = project; materializePalette(id, slotID: nil, in: &candidate)
        candidate.palettes.removeAll { $0.id == id }; _ = commitShowEdit(candidate)
    }
    func deletePaletteSlot(_ id: UUID, slotID: UUID) {
        guard let i = project.palettes.firstIndex(where: { $0.id == id }), project.palettes[i].slots.contains(where: { $0.id == slotID }) else { return }
        var candidate = project; materializePalette(id, slotID: slotID, in: &candidate)
        candidate.palettes[i].slots.removeAll { $0.id == slotID }; _ = commitShowEdit(candidate)
    }
    func bindColor(faceID: UUID, channel: ColorChannel, binding: ColorBinding?) {
        guard let faceIndex = project.surfaces.firstIndex(where: { $0.id == faceID }) else { return }
        if let binding {
            guard project.palettes.contains(where: { $0.id == binding.paletteID && $0.slots.contains(where: { $0.id == binding.slotID }) }) else {
                editMessage = "That palette color no longer exists."; return
            }
        }
        var candidate = project
        func bind(_ source: inout SurfaceSource) {
            let resolved = project.resolvedSource(source)
            if channel == .primary { source.color = resolved.color; source.primaryBinding = binding }
            else { source.generator.secondaryColor = resolved.generator.secondaryColor; source.secondaryBinding = binding }
            let updated = project.resolvedSource(source)
            if channel == .primary { source.color = updated.color } else { source.generator.secondaryColor = updated.generator.secondaryColor }
        }
        if let objectID = candidate.surfaces[faceIndex].layout.objectID,
           let i = candidate.objects.firstIndex(where: { $0.id == objectID }) { bind(&candidate.objects[i].source) }
        else { bind(&candidate.surfaces[faceIndex].source) }
        _ = commitShowEdit(candidate)
    }
    private func captureLookEntries() -> [LookEntry] {
        var entries = project.objects.map { object in
            LookEntry(targetID: object.id, kind: .object, source: SourceLook(source: project.resolvedSource(object.source)), appearance: object.appearance)
        }
        entries += project.surfaces.map { face in
            if let objectID = face.layout.objectID {
                return LookEntry(targetID: face.id, kind: .memberFace, expectedObjectID: objectID, appearance: face.appearanceOverride)
            }
            return LookEntry(targetID: face.id, kind: .standaloneFace, source: SourceLook(source: project.resolvedSource(face.source)), appearance: face.appearance)
        }
        return entries
    }
    @discardableResult
    func saveLook(name: String) -> UUID? {
        guard project.looks.count < 100 else { editMessage = "Maximum of 100 looks reached."; return nil }
        let look = ProjectLook(name: cleanName(name, fallback: "Look \(project.looks.count + 1)"), entries: captureLookEntries())
        var candidate = project; candidate.looks.append(look)
        return commitShowEdit(candidate) ? look.id : nil
    }
    func renameLook(_ id: UUID, name: String) {
        guard let i = project.looks.firstIndex(where: { $0.id == id }) else { return }
        var candidate = project; candidate.looks[i].name = cleanName(name, fallback: candidate.looks[i].name); _ = commitShowEdit(candidate)
    }
    func updateLook(_ id: UUID) {
        guard let i = project.looks.firstIndex(where: { $0.id == id }) else { return }
        var candidate = project; candidate.looks[i].entries = captureLookEntries(); _ = commitShowEdit(candidate)
    }
    func deleteLook(_ id: UUID) {
        guard project.looks.contains(where: { $0.id == id }) else { return }
        var candidate = project; candidate.looks.removeAll { $0.id == id }; _ = commitShowEdit(candidate)
    }
    func applyLook(_ id: UUID) {
        guard let look = project.looks.first(where: { $0.id == id }) else { lastLookReport = "That look no longer exists."; return }
        var candidate = project, applied = 0, skipped: [String] = []
        for entry in look.entries {
            var didApply = false
            switch entry.kind {
            case .object:
                if let i = candidate.objects.firstIndex(where: { $0.id == entry.targetID }), let source = entry.source, let appearance = entry.appearance {
                    candidate.objects[i].source = source.applying(to: candidate.objects[i].source)
                    candidate.objects[i].appearance = appearance; didApply = true
                }
            case .standaloneFace:
                if let i = candidate.surfaces.firstIndex(where: { $0.id == entry.targetID && $0.layout.objectID == nil }), let source = entry.source, let appearance = entry.appearance {
                    candidate.surfaces[i].source = source.applying(to: candidate.surfaces[i].source)
                    candidate.surfaces[i].appearance = appearance; didApply = true
                }
            case .memberFace:
                if let i = candidate.surfaces.firstIndex(where: { $0.id == entry.targetID && $0.layout.objectID == entry.expectedObjectID }), entry.expectedObjectID != nil {
                    candidate.surfaces[i].appearanceOverride = entry.appearance; didApply = true
                }
            }
            if didApply { applied += 1 }
            else { skipped.append("\(entry.kind.rawValue) \(entry.targetID.uuidString.prefix(8)): missing target or changed membership") }
        }
        guard commitShowEdit(candidate) else { lastLookReport = "Look could not be applied; no targets changed."; return }
        lastLookReport = "Applied \(applied) target(s); skipped \(skipped.count)." + (skipped.isEmpty ? "" : "\n" + skipped.joined(separator: "\n"))
    }
    func setMasterBrightness(_ value: Float) {
        var candidate = project; candidate.masterOutput.brightness = value; _ = commitShowEdit(candidate)
    }
    func setFadeDuration(_ value: Double) {
        var candidate = project; candidate.masterOutput.fadeDuration = value; _ = commitShowEdit(candidate)
    }
    func fadeToBlack(at uptime: TimeInterval = ProcessInfo.processInfo.systemUptime) {
        showOutput.fade(to: 0, duration: project.masterOutput.fadeDuration, at: uptime); testOutput.setScene(scene)
    }
    func restoreOutput(at uptime: TimeInterval = ProcessInfo.processInfo.systemUptime) {
        showOutput.restore(duration: project.masterOutput.fadeDuration, at: uptime); testOutput.setScene(scene)
    }
    func blackoutOutput() { showOutput.blackout(); testOutput.setScene(scene) }
}

extension EditorSession {
    private func setCalibration(_ value: CalibrationState) {
        guard value.isValid else { editMessage = "Calibration requires 2–64 rows/columns and a 1–4 pixel line width."; return }
        editMessage = nil
        guard value != calibration else { return }
        calibration = value; testOutput.setScene(scene)
    }
    func setCalibrationPattern(_ pattern: CalibrationPattern) { var value = calibration; value.pattern = pattern; setCalibration(value) }
    func setCalibrationColumns(_ columns: Int) { var value = calibration; value.columns = columns; setCalibration(value) }
    func setCalibrationRows(_ rows: Int) { var value = calibration; value.rows = rows; setCalibration(value) }
    func setCalibrationLineWidth(_ width: Float) { var value = calibration; value.lineWidth = width; setCalibration(value) }
    func toggleCalibration() { setCalibrationPattern(calibration.pattern.isActive ? .normal : .grid) }
    func calibrationStatus(at uptime: TimeInterval = ProcessInfo.processInfo.systemUptime) -> String {
        let count = scene.effectiveSurfaces.filter { $0.perspective != nil }.count
        var text = "\(calibration.pattern.title) · \(count) mapped face(s)"
        if count == 0 { text += " · No visible valid mapped faces" }
        if showOutput.isBlackout { text += " · Blackout overrides output" }
        else if calibration.pattern == .black { text += " · Black test selected" }
        else if project.masterOutput.brightness == 0 { text += " · Master brightness is zero" }
        else if showOutput.isFading(at: uptime) { text += showOutput.targetGain == 0 ? " · Fading to black" : " · Restoring brightness" }
        else if showOutput.gain(at: uptime) == 0 { text += " · Faded to black" }
        return text
    }
}
