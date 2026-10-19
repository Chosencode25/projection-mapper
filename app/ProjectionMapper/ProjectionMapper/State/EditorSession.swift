import AppKit
import UniformTypeIdentifiers
import Observation
import simd

@MainActor
@Observable
final class EditorSession {
    let videoPlayback = VideoPlaybackCoordinator()
    @ObservationIgnored private var managedVideoURLs = Set<URL>()
    @ObservationIgnored private var videoFileLeases = 0
    private(set) var videoFiles: [UUID:URL] = [:]
    private(set) var videoPosters: [UUID:ImagePixels] = [:]
    private(set) var videoProblems: [UUID:String] = [:]
    @ObservationIgnored private var videoImportTask: Task<Void,Never>?
    private(set) var isImportingVideo = false
    @ObservationIgnored private var saveWorker: Task<Void,Error>?
    private(set) var isSavingMedia = false
    var videoAudioEnabled = false
    private(set) var imagePixels: [UUID:ImagePixels] = [:]
    private var imageFiles: [UUID:Data] = [:]
    private(set) var imageProblems: [UUID:String] = [:]
    private var mediaGeneration = UUID()
    private(set) var isImportingImage = false
    var referencePhotoVisible = true
    private struct EditSnapshot {
        var project: MappingProject
        var pixels: [UUID:ImagePixels]
        var imageFiles: [UUID:Data]
        var imageProblems: [UUID:String]
        var videoFiles: [UUID:URL]
        var posters: [UUID:ImagePixels]
        var videoProblems: [UUID:String]
        var mediaStamps: [UUID:UUID]
    }
    private struct HistoryEntry { var snapshot: EditSnapshot; var name: String }
    private var undoHistory: [HistoryEntry] = []
    private var redoHistory: [HistoryEntry] = []
    private var mediaStamps: [UUID:UUID] = [:]
    private var savedMediaStamps: [UUID:UUID] = [:]
    private var editCheckpoint: EditSnapshot?
    private var continuousEditName: String?
    private var continuousEditRecorded = false
    private(set) var historyNotice: String?
    var canUndo: Bool { !undoHistory.isEmpty && !isSavingMedia && !isImportingVideo && !isImportingImage }
    var canRedo: Bool { !redoHistory.isEmpty && !isSavingMedia && !isImportingVideo && !isImportingImage }
    var undoTitle: String { undoHistory.last.map { "Undo " + $0.name } ?? "Undo" }
    var redoTitle: String { redoHistory.last.map { "Redo " + $0.name } ?? "Redo" }
    private(set) var identifyingSourceID: UUID?
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
        var result = RenderScene(surfaces: identifyingSourceID.map { id in faces.filter { $0.sourceID == id } } ?? faces, transport: transport)
        result.masterBrightness = project.masterOutput.brightness; result.showOutput = showOutput; result.calibration = calibration
        if identifyingSourceID != nil {
            result.calibration.pattern = .white
        }
        result.images = imagePixels
        result.videoFrames = videoPlayback.frames
        return result
    }
    private func updateOutputScene() {
        videoPlayback.configure(scene: scene,assets: project.videoAssets,urls: videoFiles,audio: project.videoAudio,enabled: videoAudioEnabled)
        testOutput.setScene(scene)
        projectorOutput.setScene(scene)
    }
    func seekPlayback(to seconds: Double, at uptime: TimeInterval = ProcessInfo.processInfo.systemUptime) {
        guard seconds.isFinite, (0...3600).contains(seconds), uptime.isFinite else { return }
        let delta = seconds - transport.elapsed(at: uptime)
        transport.seek(to: seconds, at: uptime)
        for id in Array(sourcePlayback.keys) {
            if let frozen = sourcePlayback[id]?.frozenTime { sourcePlayback[id]?.frozenTime = max(0,frozen + delta) }
        }
        updateOutputScene()
    }
    func setSelectedPaused(_ paused: Bool, at uptime: TimeInterval = ProcessInfo.processInfo.systemUptime) {
        guard let source = selectedSource, uptime.isFinite else { return }
        var clock = sourcePlayback[source.id] ?? SourcePlayback()
        clock.setPaused(paused, at: transport.elapsed(at: uptime)); sourcePlayback[source.id] = clock
        updateOutputScene()
    }
    func restartSelectedPlayback(at uptime: TimeInterval = ProcessInfo.processInfo.systemUptime) {
        guard let source = selectedSource, uptime.isFinite else { return }
        var clock = sourcePlayback[source.id] ?? SourcePlayback()
        clock.restart(at: transport.elapsed(at: uptime)); sourcePlayback[source.id] = clock
        updateOutputScene()
    }
    private func copyPlayback(from original: UUID, to copy: UUID) {
        if let clock = sourcePlayback[original] { sourcePlayback[copy] = clock }
        let originals = project.timelineClips.filter { $0.sourceID == original }
        if project.timelineClips.count + originals.count <= 2000 {
            project.timelineClips += originals.map { var clip = $0; clip.id = UUID(); clip.sourceID = copy; return clip }
        } else { timelineMessage = "The copied object uses live content: the project has reached its 2000-clip limit." }
    }
    func setPlaying(_ playing: Bool, at uptime: TimeInterval = ProcessInfo.processInfo.systemUptime) {
        transport.setPlaying(playing, at: uptime); updateOutputScene()
    }
    func restartPlayback(at uptime: TimeInterval = ProcessInfo.processInfo.systemUptime) {
        guard uptime.isFinite else { return }
        transport.restart(at: uptime)
        for id in Array(sourcePlayback.keys) { sourcePlayback[id] = sourcePlayback[id]?.isPaused == true ? SourcePlayback(frozenTime: 0) : SourcePlayback() }
        updateOutputScene()
    }
    func setPlaybackSpeed(_ value: Double, at uptime: TimeInterval = ProcessInfo.processInfo.systemUptime) {
        transport.setSpeed(value, at: uptime); updateOutputScene()
    }
    var selectedClipID: UUID?
    var timelineMessage: String?
    var selectedClip: EffectClip? { project.timelineClips.first { $0.id == selectedClipID } }
    func selectTimelineTrack(_ track: TimelineTrack) {
        if track.isObject { selectObject(track.targetID) } else { selectSurface(track.targetID) }
    }
    @discardableResult
    func addTimelineClip(sourceID: UUID, at seconds: Double, duration: Double = 5) -> UUID? {
        guard let track = project.timelineTracks.first(where: { $0.id == sourceID }) else { return nil }
        var source = SourceLook(source: project.resolvedSource(track.source))
        source.primaryBinding = nil; source.secondaryBinding = nil
        let length = source.content == .video ? min(3600-seconds,source.video?.timelineDuration ?? duration) : duration
        let clip = EffectClip(sourceID: sourceID, start: seconds, duration: length, source: source)
        var candidate = project; candidate.timelineClips.append(clip)
        guard commitTimeline(candidate) else { return nil }
        selectedClipID = clip.id; selectTimelineTrack(track); return clip.id
    }
    @discardableResult
    func updateTimelineClip(_ clip: EffectClip) -> Bool {
        guard let i = project.timelineClips.firstIndex(where: { $0.id == clip.id }), project.timelineClips[i].sourceID == clip.sourceID else { return false }
        var candidate = project; candidate.timelineClips[i] = clip
        return commitTimeline(candidate)
    }
    func deleteTimelineClip(_ id: UUID) {
        var candidate = project; candidate.timelineClips.removeAll { $0.id == id }
        if commitTimeline(candidate), selectedClipID == id { selectedClipID = nil }
    }
    func duplicateTimelineClip(_ id: UUID) {
        guard var copy = project.timelineClips.first(where: { $0.id == id }) else { return }
        copy.id = UUID(); copy.start = copy.end
        var candidate = project; candidate.timelineClips.append(copy)
        if commitTimeline(candidate) { selectedClipID = copy.id }
    }
    func captureTimelineClip(_ id: UUID) {
        guard var clip = project.timelineClips.first(where: { $0.id == id }),
              let track = project.timelineTracks.first(where: { $0.id == clip.sourceID }) else { return }
        clip.source = SourceLook(source: project.resolvedSource(track.source))
        clip.source.primaryBinding = nil; clip.source.secondaryBinding = nil
        if let video = clip.source.video, clip.source.content == .video, !video.loops { clip.duration = video.timelineDuration }
        _ = updateTimelineClip(clip)
    }
    private func commitTimeline(_ candidate: MappingProject) -> Bool {
        do { try ProjectCodec.validate(ProjectDocument(project: candidate)) }
        catch { timelineMessage = "Clips need a free time range, at least 0.1 seconds long, within 0–3600 seconds and inside the video source range."; return false }
        timelineMessage = nil
        guard candidate != project else { return true }
        project = candidate; changed(); return true
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
    let projectorOutput: ProjectorOutputCoordinator
    let testOutput: TestOutputCoordinator
    var isSidebarVisible = true
    var isInspectorVisible = true
    var inspectorTab: InspectorTab = .edit
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
        return isRecovered || current != savedBaseline || mediaStamps != savedMediaStamps
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
            do { try await self.flushRecoveryMedia(); self.fileMessage = "Recovery copy updated" }
            catch { self.fileMessage = "Recovery could not be updated: \(error.localizedDescription)" }
        }
    }
    private func flushRecoveryMedia() async throws {
        guard hasUserChanges, let recoveryStore, !isSavingMedia else { return }
        videoFileLeases += 1
        defer { videoFileLeases -= 1; cleanupManagedVideos() }
        let data = try ProjectCodec.encode(document), original = documentURL, source = assetSourceURL
        let images = imageFiles, videos = videoFiles, directory = recoveryStore.directory
        let worker = Task.detached(priority: .utility) {
            let document = try ProjectCodec.decode(data)
            try ProjectRecoveryStore(directory: directory).save(document,original: original,assetsFrom: source,imageFiles: images,videoFiles: videos)
        }
        try await withTaskCancellationHandler { try await worker.value } onCancel: { worker.cancel() }
    }
    func flushRecovery() throws {
        guard hasUserChanges, let recoveryStore else { return }
        try recoveryStore.save(document,original: documentURL,assetsFrom: assetSourceURL, imageFiles: imageFiles, videoFiles: videoFiles)
    }
    func clearRecovery() {
        autosaveTask?.cancel(); autosaveTask = nil; recoveryStore?.remove(projectID: project.id)
    }
    func save(to url: URL, store: ProjectPackageStore = ProjectPackageStore()) throws {
        try store.write(document,to: url,assetsFrom: assetSourceURL, imageFiles: imageFiles, videoFiles: videoFiles)
        documentURL = url; assetSourceURL = url; savedBaseline = project; savedMediaStamps = mediaStamps; isRecovered = false
        clearRecovery(); fileMessage = "Saved \(url.lastPathComponent)"
    }
    func load(_ document: ProjectDocument, from url: URL, recovering: Bool = false, store: ProjectPackageStore = ProjectPackageStore(), loadedMedia: (pixels: [UUID:ImagePixels], files: [UUID:Data], problems: [UUID:String])? = nil, loadedVideos: (urls: [UUID:URL],posters: [UUID:ImagePixels],problems: [UUID:String])? = nil) throws {
        try ProjectCodec.validate(document)
        closeOutput()
        clearEditHistory(); mediaStamps.removeAll(); savedMediaStamps.removeAll()
        identifyingSourceID = nil
        if !recovering || project.id != document.project.id { clearRecovery() }
        let media = loadedMedia ?? ImageImportService.loadAssets(document.project,package: url)
        videoPlayback.reset(); videoAudioEnabled = false
        videoFiles = loadedVideos?.urls ?? [:]; videoPosters = loadedVideos?.posters ?? [:]; videoProblems = loadedVideos?.problems ?? [:]
        if loadedVideos == nil {
            for asset in document.project.videoAssets {
                let file = url.appendingPathComponent("assets").appendingPathComponent(asset.fileName)
                if (try? VideoImportService.safeFile(file)) == asset.byteCount {
                    do {
                        try FileManager.default.createDirectory(at: VideoImportService.stagingDirectory,withIntermediateDirectories: true)
                        let staged = VideoImportService.stagingDirectory.appendingPathComponent(UUID().uuidString + "." + asset.fileExtension)
                        do { try VideoImportService.copy(file,to: staged) } catch { try? FileManager.default.removeItem(at: staged); throw error }
                        videoFiles[asset.id] = staged
                    } catch { videoProblems[asset.id] = "Video could not be staged: " + error.localizedDescription }
                }
                else { videoProblems[asset.id] = "Missing video; relink the asset." }
            }
        }
        managedVideoURLs.formUnion(videoFiles.values.filter { $0.deletingLastPathComponent() == VideoImportService.stagingDirectory })
        imagePixels = media.pixels; imageFiles = media.files; imageProblems = media.problems; referencePhotoVisible = true
        mediaGeneration = UUID()
        project = document.project; savedBaseline = project; isRecovered = recovering || document.recovery != nil
        documentURL = isRecovered ? nil : url; assetSourceURL = url
        if isRecovered, let path = document.recovery?.originalPath {
            let original = URL(fileURLWithPath: path)
            if let saved = try? store.read(original), saved.project.id == project.id { documentURL = original; savedBaseline = saved.project }
        }
        output.restoreProjectPreference(document.output.destination,resolution: document.output.resolution)
        selectedClipID = nil; timelineMessage = nil; clearMaskEditing(); resetEditorDisplay(); inspectorTab = .edit; sourcePlayback.removeAll(); transport = AnimationTransport(); showOutput = ShowOutputState(); calibration = CalibrationState(); lastLookReport = nil; selectedSurfaceID = project.surfaces.first?.id
        selectedObjectID = nil; selectedCorner = nil; groupingSelection.removeAll(); editMessage = nil
        testOutput.setResolution(output.testResolution); testOutput.destinationDidChange(output.destination); updateOutputScene()
        fileMessage = isRecovered ? "Recovered unsaved project — Save to keep it" : "Opened \(url.lastPathComponent)"
        if !videoProblems.isEmpty { fileMessage = (fileMessage ?? "") + " · missing/damaged videos, relink in the inspector" }
        if !imageProblems.isEmpty { fileMessage = (fileMessage ?? "") + " · \(imageProblems.count) missing/damaged image(s), relink in the inspector" }
        editCheckpoint = snapshotForHistory()
        cleanupManagedVideos()
        scheduleRecovery()
    }
    var editMessage: String?

    init(presentOutput: @escaping (NSWindow) -> Void = { $0.makeKeyAndOrderFront(nil) },
         project: MappingProject = MappingProject(), output: OutputSelectionState = OutputSelectionState(),
         projectorOutput: ProjectorOutputCoordinator = ProjectorOutputCoordinator()) {
        self.project = project; self.savedBaseline = project; self.output = output; self.projectorOutput = projectorOutput
        isRecovered = !project.hasDefaultContent
        selectedSurfaceID = project.surfaces.first?.id
        testOutput = TestOutputCoordinator(presentWindow: presentOutput, scene: project.renderScene)
        editCheckpoint = snapshotForHistory()
        videoPlayback.changed = { [weak self] in guard let self else { return }; self.testOutput.setScene(self.scene); self.projectorOutput.setScene(self.scene) }
        output.changed = { [weak self] in self?.outputDestinationChanged() }
    }
    private func changed(now: Date = .now) {
        let active = Set(project.surfaces.map { project.source(for: $0).id })
        sourcePlayback = sourcePlayback.filter { active.contains($0.key) }
        project.timelineClips.removeAll { !active.contains($0.sourceID) }
        // Capture the previous complete model/media state before resource collection.
        if let previous = editCheckpoint, previous.project != project || previous.mediaStamps != mediaStamps {
            if continuousEditName == nil || !continuousEditRecorded {
                undoHistory.append(HistoryEntry(snapshot: previous, name: continuousEditName ?? (previous.mediaStamps != mediaStamps ? "Change Media" : editName(from: previous.project))))
                continuousEditRecorded = continuousEditName != nil
            }
            redoHistory.removeAll()
        }
        collectImages(); collectVideos()
        mediaStamps = mediaStamps.filter { project.referencedImageIDs.contains($0.key) || project.referencedVideoIDs.contains($0.key) }
        project.modifiedAt = now; editCheckpoint = snapshotForHistory(); boundHistory(); editMessage = nil; updateOutputScene(); scheduleRecovery()
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
    var isOutputOpen: Bool { testOutput.isOpen || projectorOutput.isOpen }
    var outputStatusText: String {
        if let message = projectorOutput.message { return message }
        return output.destination == .testWindow ? testOutput.statusText : projectorOutput.statusText
    }
    var canOpenOutput: Bool {
        output.destination == .testWindow || output.selectedDisplay.map { ProjectorOutputCoordinator.validTarget($0, in: output.displays) } == true
    }
    func outputDestinationChanged() {
        testOutput.destinationDidChange(output.destination)
        projectorOutput.reconcile(destination: output.destination, snapshot: output.displays)
    }
    func openOutput() {
        if output.destination == .testWindow {
            projectorOutput.close()
            testOutput.open(for: .testWindow, resolution: output.testResolution)
        } else {
            testOutput.close()
            projectorOutput.open(output.selectedDisplay, snapshot: output.displays, scene: scene)
        }
    }
    func closeOutput() { testOutput.close(); projectorOutput.close() }
    func setTestResolution(_ resolution: TestResolution) { output.setTestResolution(resolution); testOutput.setResolution(resolution) }
    func renameProject(_ name: String, now: Date = .now) {
        guard name != project.name else { return }; project.name = name; changed(now: now)
    }
    func finishNameEditing(now: Date = .now) { renameProject(cleanName(project.name, fallback: MappingProject.defaultName), now: now) }
    func selectSurface(_ id: UUID?) {
        guard id == nil || project.surfaces.contains(where: { $0.id == id }) else { return }
        if id != nil { inspectorTab = .edit }
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
        inspectorTab = .edit
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
    func setSurfaceContent(_ content: SurfaceContent, now: Date = .now) {
        guard (content != .image || selectedSource?.image != nil) && (content != .video || selectedSource?.video != nil) else { return }
        updateSource(now: now) { $0.content = content }
    }
    func setSourceColor(_ color: SIMD4<Float>) {
        guard (0..<4).allSatisfy({ color[$0].isFinite && (0...1).contains(color[$0]) }) else { return }
        updateSource { $0.color = color; $0.primaryBinding = nil }
    }
    @discardableResult
    func saveGeneratorPreset(name: String) -> UUID? {
        guard let source = selectedSource, source.content.isProceduralAnimation else { return nil }
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
        guard let source = selectedSource, source.content.isProceduralAnimation,
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
        guard selectedSource?.content.isProceduralAnimation == true else { return }
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
        projectorOutput.close()
        clearEditHistory(); mediaStamps.removeAll(); savedMediaStamps.removeAll(); identifyingSourceID = nil
        imagePixels.removeAll(); imageFiles.removeAll(); imageProblems.removeAll(); mediaGeneration = UUID(); referencePhotoVisible = true
        clearRecovery(); documentURL = nil; assetSourceURL = nil; isRecovered = false; fileMessage = nil
        videoPlayback.reset(); videoFiles.removeAll(); videoPosters.removeAll(); videoProblems.removeAll(); videoAudioEnabled = false; cleanupManagedVideos()
        selectedClipID = nil; timelineMessage = nil; clearMaskEditing(); resetEditorDisplay(); inspectorTab = .edit; sourcePlayback.removeAll(); transport = AnimationTransport(); showOutput = ShowOutputState(); calibration = CalibrationState(); lastLookReport = nil; project = MappingProject(now: now); savedBaseline = project; selectedSurfaceID = project.surfaces.first?.id
        selectedObjectID = nil; selectedCorner = nil; groupingSelection.removeAll(); editMessage = nil; editCheckpoint = snapshotForHistory(); updateOutputScene()
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
        showOutput.fade(to: 0, duration: project.masterOutput.fadeDuration, at: uptime); updateOutputScene()
    }
    func restoreOutput(at uptime: TimeInterval = ProcessInfo.processInfo.systemUptime) {
        showOutput.restore(duration: project.masterOutput.fadeDuration, at: uptime); updateOutputScene()
    }
    func blackoutOutput() { showOutput.blackout(); updateOutputScene() }
}

extension EditorSession {
    private func setCalibration(_ value: CalibrationState) {
        guard value.isValid else { editMessage = "Calibration requires 2–64 rows/columns and a 1–4 pixel line width."; return }
        editMessage = nil
        guard value != calibration else { return }
        calibration = value; updateOutputScene()
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


enum ImageImportTarget: Equatable, Sendable {
    case owner(UUID), detach(UUID), newFace, reference, relink(UUID)
}

extension EditorSession {
    var selectedImageTarget: ImageImportTarget? { selectedSource.map { .owner($0.id) } }
    var selectedImageName: String? {
        guard let id = selectedSource?.image?.assetID else { return nil }
        return project.imageAssets.first { $0.id == id }?.name
    }
    private func collectImages() {
        for i in project.surfaces.indices where project.surfaces[i].layout.objectID != nil {
            project.surfaces[i].source.image = nil
            if project.surfaces[i].source.content == .image { project.surfaces[i].source.content = .diagnosticGrid }
        }
        let ids = project.referencedImageIDs
        project.imageAssets.removeAll { !ids.contains($0.id) }
        imagePixels = imagePixels.filter { ids.contains($0.key) }
        imageFiles = imageFiles.filter { ids.contains($0.key) }
        imageProblems = imageProblems.filter { ids.contains($0.key) }
    }
    private func sourceForImageTarget(_ target: ImageImportTarget) -> SurfaceSource? {
        switch target {
        case .owner(let id): return (project.objects.map(\.source) + project.surfaces.filter { $0.layout.objectID == nil }.map(\.source)).first { $0.id == id }
        case .detach(let id): return project.surfaces.first { $0.id == id }.map { project.source(for: $0) }
        default: return nil
        }
    }
    /// Capture the owner before a picker or drop; async completion never follows a new selection.
    func chooseImage(target: ImageImportTarget) {
        guard !isImportingImage else { return }
        let token = mediaGeneration, expected = sourceForImageTarget(target)
        let panel = NSOpenPanel(); panel.allowedContentTypes = [.png,.jpeg]
        panel.allowsMultipleSelection = false; panel.canChooseDirectories = false
        panel.message = target == .reference ? "Choose an editor-only reference photo" : "Choose an image for this content owner"
        panel.begin { [weak self] response in
            guard response == .OK, let url = panel.url else { return }
            Task { @MainActor [weak self] in
                guard let self, token == self.mediaGeneration, expected == self.sourceForImageTarget(target) else { return }
                await self.importImage(from: url,target: target)
            }
        }
    }
    func importImage(from url: URL, target: ImageImportTarget,
                     decode: @Sendable (URL) async throws -> ImportedImage = { url in
                         try await Task.detached(priority: .userInitiated) { try ImageImportService.read(url) }.value
                     }) async {
        guard !isImportingImage else { editMessage = "Wait for the current image import to finish."; return }
        let generation = mediaGeneration, expected = sourceForImageTarget(target)
        isImportingImage = true
        defer { isImportingImage = false }
        do {
            let imported = try await decode(url)
            guard generation == mediaGeneration, expected == sourceForImageTarget(target) else {
                editMessage = "The target changed during import. Choose the image again."; return
            }
            try installImage(imported,target: target)
        } catch { editMessage = error.localizedDescription }
    }
    /// Validate before publishing, including memory limits; failed imports preserve the old content.
    func installImage(_ imported: ImportedImage, target: ImageImportTarget) throws {
        var candidate = project, asset = imported.asset
        guard asset.isValid, imported.pixels.width == asset.width, imported.pixels.height == asset.height,
              imported.pixels.bytes.count == asset.width*asset.height*4, !imported.png.isEmpty else {
            throw ImageImportError.invalid("Invalid prepared image data.")
        }
        var ownerID: UUID?
        switch target {
        case .owner(let id):
            guard sourceForImageTarget(target) != nil else { throw ImageImportError.invalid("That content owner no longer exists.") }
            ownerID = id
        case .detach(let id):
            guard let i = candidate.surfaces.firstIndex(where: { $0.id == id }), let object = candidate.object(for: candidate.surfaces[i]) else { throw ImageImportError.invalid("That grouped face no longer exists.") }
            candidate.surfaces[i].layout.isGeometryLocked = candidate.isGeometryLocked(candidate.surfaces[i])
            candidate.surfaces[i].appearance = candidate.appearance(for: candidate.surfaces[i]); candidate.surfaces[i].appearanceOverride = nil
            candidate.surfaces[i].layout.isVisible = candidate.surfaces[i].layout.isVisible && object.isVisible
            candidate.surfaces[i].source = object.source.independentCopy()
            candidate.surfaces[i].layout.objectID = nil
            for j in candidate.objects.indices { candidate.objects[j].links.removeAll { $0.firstFace == id || $0.secondFace == id } }
            candidate.objects.removeAll { object in !candidate.surfaces.contains { $0.layout.objectID == object.id } }
            ownerID = candidate.surfaces[i].source.id
        case .newFace:
            guard candidate.surfaces.count < 1000 else { throw ImageImportError.invalid("The project already has 1000 surfaces.") }
            let face = MappingSurface(name: "Image \(candidate.surfaces.count+1)")
            candidate.surfaces.insert(face,at: 0); ownerID = face.source.id
        case .reference: candidate.referencePhoto = ReferencePhoto(assetID: asset.id)
        case .relink(let id):
            guard let existing = candidate.imageAssets.first(where: { $0.id == id }) else { throw ImageImportError.invalid("That asset no longer exists.") }
            asset.id = existing.id
            candidate.imageAssets.removeAll { $0.id == id }
        }
        if let ownerID {
            let image = ImageContent(assetID: asset.id,canvasAspect: Float(output.aspectRatio))
            if let i = candidate.objects.firstIndex(where: { $0.source.id == ownerID }) {
                candidate.objects[i].source.content = .image; candidate.objects[i].source.image = image
            } else if let i = candidate.surfaces.firstIndex(where: { $0.source.id == ownerID }) {
                candidate.surfaces[i].source.content = .image; candidate.surfaces[i].source.image = image
            }
        }
        if let existing = candidate.imageAssets.first(where: { $0.id == asset.id }), target != .relink(asset.id) {
            guard existing == asset && imagePixels[asset.id] == imported.pixels else { throw ImageImportError.invalid("Image asset identity conflict.") }
        }
        candidate.imageAssets.removeAll { $0.id == asset.id }
        candidate.imageAssets.append(asset)
        let ids = candidate.referencedImageIDs
        candidate.imageAssets.removeAll { !ids.contains($0.id) }
        let encoded = imageFiles.filter { ids.contains($0.key) && $0.key != asset.id }.values.reduce(0) { $0+$1.count } + imported.png.count
        guard encoded <= ImageImportService.maximumEncodedBytes else { throw ImageImportError.invalid("Project images exceed the 256 MB packaged-image limit.") }
        try ProjectCodec.validate(ProjectDocument(project: candidate))
        if imageFiles[asset.id] != imported.png { mediaStamps[asset.id] = UUID() }
        project = candidate; imagePixels[asset.id] = imported.pixels; imageFiles[asset.id] = imported.png; imageProblems.removeValue(forKey: asset.id)
        if case .newFace = target { selectSurface(project.surfaces.first?.id) }
        if case .detach(let id) = target { selectSurface(id) }
        if case .reference = target { referencePhotoVisible = true }
        changed()
    }
    func removeSelectedImage() { updateSource { $0.content = .diagnosticGrid; $0.image = nil } }
    func setImagePlacement(_ value: ImagePlacement) { updateSource { $0.image?.placement = value } }
    func setImageCanvasAspect(_ value: Float) {
        guard value.isFinite, (0.01...100).contains(value) else { return }
        updateSource { $0.image?.canvasAspect = value }
    }
    func setReferencePhoto(_ value: ReferencePhoto?) {
        guard value?.isValid ?? true, value != project.referencePhoto else { return }
        project.referencePhoto = value; changed()
    }
    var editorScene: RenderScene {
        var copy = scene
        copy.editorTransparentBackground = referencePhotoVisible && project.referencePhoto.flatMap { imagePixels[$0.assetID] } != nil
        return copy
    }
}

extension EditorSession {
    private func collectVideos() {
        for i in project.surfaces.indices where project.surfaces[i].layout.objectID != nil {
            project.surfaces[i].source.video = nil
            if project.surfaces[i].source.content == .video { project.surfaces[i].source.content = .diagnosticGrid }
        }
        let ids = project.referencedVideoIDs
        project.videoAssets.removeAll { !ids.contains($0.id) }
        videoFiles = videoFiles.filter { ids.contains($0.key) }
        videoPosters = videoPosters.filter { ids.contains($0.key) }
        videoProblems = videoProblems.filter { ids.contains($0.key) }
        cleanupManagedVideos()
    }
    private func cleanupManagedVideos() {
        guard videoFileLeases == 0 else { return }
        let live = Set(videoFiles.values).union(historySnapshots.flatMap { $0.videoFiles.values })
        for url in managedVideoURLs.subtracting(live) { try? FileManager.default.removeItem(at: url); managedVideoURLs.remove(url) }
    }
    func importMedia(from url: URL,target: ImageImportTarget) async {
        if ["mp4","mov"].contains(url.pathExtension.lowercased()) {
            let task = Task { @MainActor in await importVideo(from: url,target: target) }
            videoImportTask = task; await task.value; videoImportTask = nil
        }
        else { await importImage(from: url,target: target) }
    }
    func cancelVideoImport() { videoImportTask?.cancel(); mediaGeneration = UUID() }
    func chooseVideo(target: ImageImportTarget) {
        guard !isImportingVideo else { return }
        let generation = mediaGeneration, expected = sourceForImageTarget(target)
        let panel = NSOpenPanel(); panel.allowedContentTypes = [.mpeg4Movie,.quickTimeMovie]
        panel.allowsMultipleSelection = false; panel.canChooseDirectories = false
        panel.message = "Choose an SDR H.264/HEVC video for this content owner"
        panel.begin { [weak self] response in
            guard response == .OK, let url = panel.url else { return }
            Task { @MainActor [weak self] in
                guard let self, generation == self.mediaGeneration, expected == self.sourceForImageTarget(target) else { return }
                await self.importMedia(from: url,target: target)
            }
        }
    }
    func importVideo(from url: URL,target: ImageImportTarget,
        read: @Sendable (URL) async throws -> ImportedVideo = { url in
            let worker = Task.detached(priority: .userInitiated) { try await VideoImportService.read(url) }
            return try await withTaskCancellationHandler { try await worker.value } onCancel: { worker.cancel() }
        }) async {
        guard !isImportingVideo else { editMessage = "Wait for the current video import to finish."; return }
        let generation = mediaGeneration, expected = sourceForImageTarget(target)
        isImportingVideo = true
        defer { isImportingVideo = false }
        do {
            let imported = try await read(url)
            guard !Task.isCancelled, generation == mediaGeneration, expected == sourceForImageTarget(target) else {
                if imported.url.deletingLastPathComponent() == VideoImportService.stagingDirectory { try? FileManager.default.removeItem(at: imported.url) }
                editMessage = "The target changed during import. Choose the video again."; return
            }
            do { try installVideo(imported,target: target) }
            catch {
                if imported.url.deletingLastPathComponent() == VideoImportService.stagingDirectory { try? FileManager.default.removeItem(at: imported.url) }
                throw error
            }
        } catch { editMessage = error is CancellationError ? "Video import cancelled." : error.localizedDescription }
    }
    func installVideo(_ imported: ImportedVideo,target: ImageImportTarget) throws {
        var candidate = project, asset = imported.asset
        guard asset.isValid, try VideoImportService.safeFile(imported.url) == asset.byteCount else { throw ProjectFileError.invalid("Invalid prepared video.") }
        var owner: UUID?
        switch target {
        case .owner(let id):
            guard sourceForImageTarget(target) != nil else { throw ProjectFileError.invalid("The content owner no longer exists.") }; owner = id
        case .detach(let id):
            guard let i = candidate.surfaces.firstIndex(where: { $0.id == id }), let object = candidate.object(for: candidate.surfaces[i]) else { throw ProjectFileError.invalid("The grouped face no longer exists.") }
            candidate.surfaces[i].source = object.source.independentCopy(); owner = candidate.surfaces[i].source.id
            candidate.surfaces[i].appearance = candidate.appearance(for: candidate.surfaces[i]); candidate.surfaces[i].appearanceOverride = nil
            candidate.surfaces[i].layout.isGeometryLocked = candidate.isGeometryLocked(candidate.surfaces[i])
            candidate.surfaces[i].layout.isVisible = candidate.surfaces[i].layout.isVisible && object.isVisible
            if object.mode == .repeatContent { candidate.surfaces[i].layout.inputMap = .full }
            candidate.surfaces[i].layout.objectID = nil
            candidate.timelineClips += candidate.timelineClips.filter { $0.sourceID == object.source.id }.map { var clip = $0; clip.id = UUID(); clip.sourceID = owner!; return clip }
            for j in candidate.objects.indices { candidate.objects[j].links.removeAll { $0.firstFace == id || $0.secondFace == id } }
            candidate.objects.removeAll { obj in !candidate.surfaces.contains { $0.layout.objectID == obj.id } }
        case .newFace:
            guard candidate.surfaces.count < 1000 else { throw ProjectFileError.invalid("Maximum of 1000 faces.") }
            let face = MappingSurface(name: "Video \(candidate.surfaces.count+1)")
            candidate.surfaces.insert(face,at: 0); owner = face.source.id
        case .relink(let id):
            guard candidate.videoAssets.contains(where: { $0.id == id }) else { throw ProjectFileError.invalid("That asset no longer exists.") }
            asset.id = id; candidate.videoAssets.removeAll { $0.id == id }
        case .reference: throw ProjectFileError.invalid("Reference photos accept images only.")
        }
        if let owner {
            let content = VideoContent(assetID: asset.id,outPoint: asset.duration,canvasAspect: Float(output.aspectRatio))
            if let i = candidate.objects.firstIndex(where: { $0.source.id == owner }) {
                candidate.objects[i].source.content = .video; candidate.objects[i].source.video = content
            } else if let i = candidate.surfaces.firstIndex(where: { $0.source.id == owner }) {
                candidate.surfaces[i].source.content = .video; candidate.surfaces[i].source.video = content
            }
        }
        if let old = candidate.videoAssets.first(where: { $0.id == asset.id }) {
            guard old == asset, videoFiles[asset.id] == imported.url else { throw ProjectFileError.invalid("Video identity conflict.") }
        } else { candidate.videoAssets.append(asset) }
        let active = Set(candidate.timelineTracks.map(\.id)); candidate.timelineClips.removeAll { !active.contains($0.sourceID) }
        let referenced = candidate.referencedVideoIDs
        candidate.videoAssets.removeAll { !referenced.contains($0.id) }
        try ProjectCodec.validate(ProjectDocument(project: candidate))
        if imported.url.deletingLastPathComponent() == VideoImportService.stagingDirectory { managedVideoURLs.insert(imported.url) }
        if videoFiles[asset.id] != imported.url { mediaStamps[asset.id] = UUID() }
        project = candidate; videoFiles[asset.id] = imported.url; videoPosters[asset.id] = imported.poster; videoProblems.removeValue(forKey: asset.id)
        transport.setPlaying(false,at: ProcessInfo.processInfo.systemUptime)
        if case .newFace = target { selectSurface(project.surfaces.first?.id) }
        if case .detach(let id) = target { selectSurface(id) }
        changed()
    }
    func setSelectedVideo(_ content: VideoContent) {
        guard !project.videoProblem(content) else { editMessage = "Choose a valid source range inside the video's duration."; return }
        updateSource { $0.video = content }
    }
    func removeSelectedVideo() { updateSource { $0.content = .diagnosticGrid; $0.video = nil } }
    func setVideoAudio(_ settings: VideoAudioSettings) {
        guard settings.isValid else { return }
        project.videoAudio = settings; changed()
    }
    func enableVideoAudio(_ enabled: Bool) { videoAudioEnabled = enabled; if enabled { videoPlayback.rearmAudio() }; updateOutputScene() }
    /// Native Save runs asset copies off the main actor; edits after the snapshot remain dirty.
    func cancelMediaSave() { saveWorker?.cancel() }
    func saveMedia(to url: URL) async throws {
        guard !isSavingMedia else { throw ProjectFileError.io("A media save is already in progress.") }
        let snapshot = project, stampSnapshot = mediaStamps, generation = mediaGeneration, data = try ProjectCodec.encode(document)
        let images = imageFiles, videos = videoFiles, source = assetSourceURL
        isSavingMedia = true; videoFileLeases += 1
        defer { saveWorker = nil; isSavingMedia = false; videoFileLeases -= 1; cleanupManagedVideos() }
        let worker = Task.detached(priority: .userInitiated) {
            let document = try ProjectCodec.decode(data)
            for asset in document.project.videoAssets {
                try Task.checkCancellation()
                guard let file = videos[asset.id] else { throw ProjectFileError.invalid("Missing video; relink before saving.") }
                let actual = try await VideoImportService.inspect(file).0
                guard actual.byteCount == asset.byteCount, actual.duration >= asset.duration-0.00001,
                      actual.width == asset.width, actual.height == asset.height, actual.transform == asset.transform else {
                    throw ProjectFileError.invalid("Video changed; relink before saving.")
                }
            }
            try ProjectPackageStore().write(document,to: url,assetsFrom: source,imageFiles: images,videoFiles: videos)
        }
        saveWorker = worker
        try await withTaskCancellationHandler { try await worker.value } onCancel: { worker.cancel() }
        guard generation == mediaGeneration else { throw ProjectFileError.io("Project changed while saving; the captured project was saved separately.") }
        documentURL = url; assetSourceURL = url; savedBaseline = snapshot; savedMediaStamps = stampSnapshot; isRecovered = false
        // Keep staged originals alive: future package replacement must not invalidate undo media.
        editCheckpoint = snapshotForHistory()
        if !hasUserChanges { clearRecovery() } else { scheduleRecovery() }
        fileMessage = "Saved \(url.lastPathComponent)"; updateOutputScene()
    }
}


extension EditorSession {
    private func snapshotForHistory() -> EditSnapshot {
        EditSnapshot(project: project,pixels: imagePixels,imageFiles: imageFiles,imageProblems: imageProblems,
                     videoFiles: videoFiles,posters: videoPosters,videoProblems: videoProblems,mediaStamps: mediaStamps)
    }
    private var historySnapshots: [EditSnapshot] {
        undoHistory.map(\.snapshot) + redoHistory.map(\.snapshot) + (editCheckpoint.map { [$0] } ?? [])
    }
    private func clearEditHistory() {
        undoHistory.removeAll(); redoHistory.removeAll(); editCheckpoint = nil
        continuousEditName = nil; continuousEditRecorded = false; historyNotice = nil
    }
    func beginContinuousEdit(_ name: String = "Adjust Settings") {
        guard continuousEditName == nil else { return }
        continuousEditName = name; continuousEditRecorded = false
    }
    func endContinuousEdit() {
        if continuousEditRecorded, let entry = undoHistory.last {
            var current = project; current.modifiedAt = entry.snapshot.project.modifiedAt
            if current == entry.snapshot.project && mediaStamps == entry.snapshot.mediaStamps { undoHistory.removeLast() }
        }
        continuousEditName = nil; continuousEditRecorded = false
    }
    func continuousEditing(_ editing: Bool) {
        if editing { beginContinuousEdit() } else { endContinuousEdit() }
    }
    private func editName(from old: MappingProject) -> String {
        if old.name != project.name { return "Rename Project" }
        if old.objects != project.objects { return "Edit Object" }
        if old.timelineClips != project.timelineClips { return "Edit Timeline" }
        if old.imageAssets != project.imageAssets || old.videoAssets != project.videoAssets { return "Change Media" }
        if old.looks != project.looks { return "Edit Looks" }
        if old.palettes != project.palettes { return "Edit Palette" }
        if old.videoAudio != project.videoAudio { return "Audio Settings" }
        if old.masterOutput != project.masterOutput { return "Output Settings" }
        if old.referencePhoto != project.referencePhoto { return "Reference Photo" }
        return "Edit Surface"
    }
    private func boundHistory() {
        // Models/Data use copy-on-write. Conservatively charge image bytes per snapshot and distinct video files.
        while undoHistory.count + redoHistory.count > 100 || retainedHistoryExceedsBudget {
            if !undoHistory.isEmpty { undoHistory.removeFirst() }
            else if !redoHistory.isEmpty { redoHistory.removeFirst() }
            else { break }
            historyNotice = "Old undo steps were released to keep history within 100 steps, 256 MiB image data and 2 GiB video originals."
        }
        cleanupManagedVideos()
    }
    private var retainedHistoryExceedsBudget: Bool {
        var imageBytes = 0
        var videos = [URL:Int64]()
        for snapshot in undoHistory.map(\.snapshot) + redoHistory.map(\.snapshot) {
            imageBytes += snapshot.pixels.values.reduce(0) { $0 + $1.bytes.count }
            imageBytes += snapshot.imageFiles.values.reduce(0) { $0 + $1.count }
            imageBytes += snapshot.posters.values.reduce(0) { $0 + $1.bytes.count }
            for (id,url) in snapshot.videoFiles { videos[url] = max(videos[url] ?? 0,snapshot.project.videoAssets.first { $0.id == id }?.byteCount ?? 0) }
        }
        return imageBytes > 256*1024*1024 || videos.values.reduce(0,+) > 2*1024*1024*1024
    }
    func undoProjectEdit() {
        guard canUndo else { return }
        endContinuousEdit()
        guard let entry = undoHistory.popLast() else { return }
        redoHistory.append(HistoryEntry(snapshot: snapshotForHistory(),name: entry.name))
        restoreHistory(entry.snapshot)
    }
    func redoProjectEdit() {
        guard canRedo else { return }
        endContinuousEdit()
        guard let entry = redoHistory.popLast() else { return }
        undoHistory.append(HistoryEntry(snapshot: snapshotForHistory(),name: entry.name))
        restoreHistory(entry.snapshot)
    }
    private func restoreHistory(_ snapshot: EditSnapshot) {
        mediaGeneration = UUID(); videoPlayback.reset()
        project = snapshot.project; imagePixels = snapshot.pixels; imageFiles = snapshot.imageFiles
        imageProblems = snapshot.imageProblems; videoFiles = snapshot.videoFiles; videoPosters = snapshot.posters
        videoProblems = snapshot.videoProblems; mediaStamps = snapshot.mediaStamps
        let faces = Set(project.surfaces.map(\.id)), objects = Set(project.objects.map(\.id))
        if let id = selectedSurfaceID, !faces.contains(id) { selectedSurfaceID = project.surfaces.first?.id }
        if let id = selectedObjectID, !objects.contains(id) { selectedObjectID = nil }
        if let id = selectedClipID, !project.timelineClips.contains(where: { $0.id == id }) { selectedClipID = nil }
        groupingSelection.formIntersection(faces); selectedCorner = nil; clearMaskEditing()
        sourcePlayback = sourcePlayback.filter { id,_ in project.timelineTracks.contains { $0.id == id } }
        identifyingSourceID = nil; editCheckpoint = snapshotForHistory()
        editMessage = nil; timelineMessage = nil; lastLookReport = nil
        boundHistory(); updateOutputScene(); scheduleRecovery()
    }
    func releaseRuntimeResources() {
        closeOutput()
        autosaveTask?.cancel(); videoImportTask?.cancel(); saveWorker?.cancel()
        videoPlayback.reset(); clearEditHistory(); videoFiles.removeAll(); cleanupManagedVideos()
    }
    func identifySelectedObject() {
        identifyingSourceID = selectedSource?.id; updateOutputScene()
    }
    func finishIdentification() { identifyingSourceID = nil; updateOutputScene() }
}

struct ReadinessIssue: Identifiable, Equatable {
    enum Severity: String { case blocker = "Fix", warning = "Warning", information = "Info" }
    var id: String
    var severity: Severity
    var message: String
    var faceID: UUID?
}
struct PlaybackReadinessReport {
    var issues: [ReadinessIssue]
    var blockerCount: Int
    var warningCount: Int
    var omittedCount: Int
    var checkedAt: Date
    var summary: String { blockerCount > 0 ? "\(blockerCount) item(s) need attention" : "No project blockers found" }
}
extension EditorSession {
    /// Explicit, bounded inspection. Does not play, seek, enable audio or populate edit history.
    func playbackReadiness() -> PlaybackReadinessReport {
        var issues = [ReadinessIssue](), blockers = 0, warnings = 0, omitted = 0
        func add(_ key: String,_ severity: ReadinessIssue.Severity,_ text: String,_ face: UUID? = nil) {
            if severity == .blocker { blockers += 1 }; if severity == .warning { warnings += 1 }
            if issues.count < 200 { issues.append(ReadinessIssue(id: key,severity: severity,message: text,faceID: face)) }
            else { omitted += 1 }
        }
        for face in project.surfaces {
            if PerspectiveTransform(face.corners) == nil { add("geometry-\(face.id)",.blocker,"\(face.name): invalid output corners. Repair or reset geometry in Edit.",face.id) }
            if !face.layout.inputMap.isValid { add("map-\(face.id)",.blocker,"\(face.name): invalid input map. Repair or reset the input region.",face.id) }
            if face.mask?.isEnabled == true, let problem = face.mask?.validationMessage { add("mask-\(face.id)",.blocker,"\(face.name): \(problem) Repair or disable this mask.",face.id) }
        }
        for object in project.objects {
            for link in object.links {
                if let message = project.joinMessage(link,objectID: object.id) {
                    add("join-\(link.id)",link.isSeam ? .information : .warning,"\(object.name): \(message). Check input edge alignment.",link.firstFace)
                }
            }
        }
        for id in project.referencedImageIDs.sorted(by: { $0.uuidString < $1.uuidString }) {
            if imagePixels[id] == nil || imageProblems[id] != nil {
                let name = project.imageAssets.first { $0.id == id }?.name ?? id.uuidString
                add("image-\(id)",.blocker,"\(name): \(imageProblems[id] ?? "image unavailable"). Relink from Edit / Images or Reference Photo.")
            }
        }
        for id in project.referencedVideoIDs.sorted(by: { $0.uuidString < $1.uuidString }) {
            let asset = project.videoAssets.first { $0.id == id }
            let name = asset?.name ?? id.uuidString
            if asset?.isValid != true { add("metadata-\(id)",.blocker,"\(name): unsupported video metadata. Replace with SDR H.264/HEVC MP4/MOV.") }
            if let url = videoFiles[id], (try? VideoImportService.safeFile(url)) == asset?.byteCount, videoProblems[id] == nil {
                if videoPosters[id] == nil { add("decode-\(id)",.warning,"\(name): decoder preview has not been verified. Relink to inspect the media.") }
            } else { add("video-\(id)",.blocker,"\(name): \(videoProblems[id] ?? "missing or changed video"). Relink from Edit / Video.") }
        }
        do { try ProjectCodec.validate(document) }
        catch { add("package",.blocker,"Project/timeline validation: \(error.localizedDescription) Repair clip ranges or unresolved references before saving.") }
        for (id,message) in videoPlayback.problems.sorted(by: { $0.key.uuidString < $1.key.uuidString }) {
            add("runtime-\(id)",.warning,"Video owner \(id.uuidString.prefix(8)): \(message)")
        }
        if let uid = project.videoAudio.deviceUID, !videoPlayback.availableAudioDevices().contains(where: { $0.id == uid }) {
            add("audio-device",.warning,"Chosen audio device is unavailable. Select System default or a connected device, then Enable Audio again.")
        }
        if !videoAudioEnabled { add("audio-muted",.information,"Audio is safely disabled. Enable Audio deliberately after choosing output and volume.") }
        if !canOpenOutput { add("output",.blocker,"Selected output is unavailable. Refresh Displays and select an independent external display or Test Window.") }
        else if !isOutputOpen { add("output",.information,"Output is closed. Explicitly open the selected output to inspect it.") }
        if let message = projectorOutput.message { add("output-recovery",.warning,message) }
        if projectorOutput.diagnostic != .normal { add("output-diagnostic",.information,"Full-output calibration is active. Finish Output Calibration to restore content.") }
        if let profile = output.calibrationProfile, let display = output.selectedDisplay, !profile.matches(display) {
            add("output-profile",.warning,"Display mode changed since calibration. Remeasure and save a profile for this mode.")
        }
        if project.surfaces.isEmpty { add("empty",.warning,"No surfaces. Add a surface or open the V1 Demo from Help.") }
        if showOutput.isBlackout || project.masterOutput.brightness == 0 { add("dark",.warning,"Output is blacked out or master brightness is zero. Restore Output or increase brightness.") }
        if calibration.pattern.isActive { add("calibration",.information,"Calibration is active. Choose Normal Content to see timeline content.") }
        if identifyingSourceID != nil { add("identify",.information,"Object identification is active. Finish Identification to restore all owners.") }
        add("resource-scope",.information,"Inspection checks loaded media, ranges and reported decoder failures without autoplay. Smooth playback and audio timing require the user check; physical projector alignment, reconnect and optical delay require hardware acceptance.")
        return PlaybackReadinessReport(issues: issues,blockerCount: blockers,warningCount: warnings,omittedCount: omitted,checkedAt: .now)
    }
}
