import AppKit
import SwiftUI
import Testing

@MainActor @Suite(.serialized)
struct EditorShortcutTests {
    private func session() -> EditorSession { EditorSession(presentOutput: { _ in }) }

    @Test func keyRoutingPreservesUnassignedAndModifiedKeys() {
        #expect(EditorKeyRouting.action(keyCode: 49, modifiers: []) == .playPause)
        #expect(EditorKeyRouting.action(keyCode: 49, modifiers: .capsLock) == .playPause)
        for flags: NSEvent.ModifierFlags in [.command, .option, .control, .shift] {
            #expect(EditorKeyRouting.action(keyCode: 49, modifiers: flags) == nil)
            #expect(EditorKeyRouting.action(keyCode: 51, modifiers: flags) == nil)
        }
        #expect(EditorKeyRouting.action(keyCode: 123, modifiers: []) == nil) // mapping nudge
        #expect(EditorKeyRouting.action(keyCode: 124, modifiers: .shift) == nil)
        #expect(EditorKeyRouting.action(keyCode: 123, modifiers: .option) == .stepBack)
        #expect(EditorKeyRouting.action(keyCode: 124, modifiers: [.option, .shift]) == .secondForward)
        #expect(EditorKeyRouting.action(keyCode: 123, modifiers: [.option, .command]) == nil)
        #expect(EditorKeyRouting.action(keyCode: 115, modifiers: []) == .beginning)
        #expect(EditorKeyRouting.action(keyCode: 119, modifiers: []) == .sequenceEnd)
        #expect(EditorKeyRouting.action(keyCode: 117, modifiers: []) == .delete)
    }

    @Test func nativeTextAndModalFocusNeverAcceptEditorKeys() {
        _ = NSApplication.shared
        for responder in [NSTextView(), NSTextField(), NSSecureTextField()] as [NSResponder] {
            #expect(!EditorKeyRouting.accepts(firstResponder: responder, hasSheet: false, hasModal: false))
        }
        #expect(EditorKeyRouting.accepts(firstResponder: NSView(), hasSheet: false, hasModal: false))
        #expect(EditorKeyRouting.accepts(firstResponder: NSHostingView(rootView: Text("Canvas")), hasSheet: false, hasModal: false))
        #expect(!EditorKeyRouting.accepts(firstResponder: NSView(), hasSheet: true, hasModal: false))
        #expect(!EditorKeyRouting.accepts(firstResponder: NSView(), hasSheet: false, hasModal: true))
    }

    private func key(_ window: NSWindow, _ code: UInt16, repeat repeated: Bool = false,
                     modifiers: NSEvent.ModifierFlags = []) throws -> NSEvent {
        try #require(NSEvent.keyEvent(with: .keyDown, location: .zero, modifierFlags: modifiers,
            timestamp: 100, windowNumber: window.windowNumber, context: nil,
            characters: code == 49 ? " " : "", charactersIgnoringModifiers: code == 49 ? " " : "",
            isARepeat: repeated, keyCode: code))
    }
    private func window() -> EditorShortcutWindow {
        _ = NSApplication.shared
        let window = EditorShortcutWindow(contentRect: NSRect(x: 0, y: 0, width: 300, height: 200),
            styleMask: [.titled], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        return window // Never order this test window onscreen.
    }

    @Test func hiddenWindowRoutesSpaceOnceAndProtectsTextAndOtherWindows() throws {
        let s = session(), window = window(), other = self.window()
        defer { window.contentView = nil; window.close(); other.close() }
        window.performShortcut = { s.performEditorAction($0, at: 100); return true }
        let before = s.transport.isPlaying
        #expect(window.routeShortcut(try key(window, 49)))
        #expect(s.transport.isPlaying != before)
        #expect(window.routeShortcut(try key(window, 49, repeat: true)))
        #expect(s.transport.isPlaying != before)
        #expect(!window.routeShortcut(try key(other, 49)))
        window.shortcutsBlocked = { true }
        #expect(!window.routeShortcut(try key(window, 49)))
        window.shortcutsBlocked = nil
        let text = NSTextView(frame: window.contentView!.bounds)
        text.isFieldEditor = true; window.contentView = text
        #expect(window.makeFirstResponder(text))
        for code: UInt16 in [49, 51, 53, 115, 119] { #expect(!window.routeShortcut(try key(window, code))) }
        #expect(!window.routeShortcut(try key(window, 123, modifiers: .option)))
        text.insertText("name with spaces", replacementRange: NSRange(location: NSNotFound, length: 0))
        #expect(text.string == "name with spaces")
    }

    @Test func outputWindowRoutesPlaybackButNeverDeletesGeometry() throws {
        let s = session(), window = window()
        let project = s.project
        defer { window.close() }
        window.permitsEditing = false
        var actions: [EditorAction] = []
        window.performShortcut = { actions.append($0); s.performEditorAction($0, at: 100); return true }
        #expect(window.routeShortcut(try key(window, 49)))
        #expect(!window.routeShortcut(try key(window, 51)))
        #expect(!window.routeShortcut(try key(window, 53))) // physical output owns Escape
        #expect(actions == [.playPause])
        #expect(s.project == project)
    }

    @Test func holdingDeleteRemovesOnlyOneSelection() throws {
        let s = session(), window = window()
        defer { window.close() }
        s.addSurface(); s.addSurface()
        window.performShortcut = { s.performEditorAction($0); return true }
        #expect(window.routeShortcut(try key(window, 51)))
        #expect(s.project.surfaces.count == 2)
        #expect(window.routeShortcut(try key(window, 51, repeat: true)))
        #expect(s.project.surfaces.count == 2)
        s.undoProjectEdit(); #expect(s.project.surfaces.count == 3)
    }

    @Test func nativeTestOutputSpaceUsesTheSharedTransportAndScene() throws {
        let s = session()
        let before = s.project.surfaces.count
        s.openOutput()
        defer { s.closeOutput() }
        let output = try #require(s.testOutput.window as? EditorShortcutWindow)
        let wasPlaying = s.transport.isPlaying
        #expect(output.routeShortcut(try key(output, 49)))
        #expect(s.transport.isPlaying != wasPlaying)
        #expect(s.testOutput.scene.transport.isPlaying == s.transport.isPlaying)
        #expect(!output.routeShortcut(try key(output, 51)))
        #expect(s.project.surfaces.count == before && !s.hasUserChanges)
    }

    @Test func menuBindingsAreUniqueAndAllActionsHaveLabels() {
        let bindings = EditorAction.allCases.map { "\($0.key.character):\($0.modifiers.rawValue)" }
        #expect(Set(bindings).count == EditorAction.allCases.count)
        #expect(EditorAction.allCases.allSatisfy { !$0.title.isEmpty && !$0.keysLabel.isEmpty })
    }

    @Test func clipDuplicateDeleteAndUndoDoNotTouchMapping() throws {
        let s = session()
        let surfaces = s.project.surfaces.count
        let owner = s.project.timelineTracks[0].id
        let first = try #require(s.addTimelineClip(sourceID: owner, at: 0))
        let geometry = s.project.surfaces
        s.performEditorAction(.duplicate)
        #expect(s.project.timelineClips.count == 2 && s.selectedClipID != first)
        #expect(s.project.timelineClips.map(\.start).sorted() == [0, 5])
        s.performEditorAction(.delete)
        #expect(s.project.timelineClips.count == 1 && s.project.surfaces == geometry)
        s.undoProjectEdit()
        #expect(s.project.timelineClips.count == 2 && s.project.surfaces.count == surfaces)
    }

    @Test func explicitCanvasOrSidebarSelectionClearsStaleClipContext() throws {
        let s = session()
        let face = s.project.surfaces[0].id, track = s.project.timelineTracks[0]
        let clip = try #require(s.addTimelineClip(sourceID: track.id, at: 0))
        s.selectTimelineTrack(track)
        #expect(s.selectedClipID == clip)
        s.selectSurface(face)
        #expect(s.selectedClipID == nil)
        s.performEditorAction(.duplicate)
        #expect(s.project.surfaces.count == 2 && s.project.timelineClips.count == 2)
        s.selectedClipID = clip; s.selectCorner(.topLeft)
        #expect(s.selectedClipID == nil)
        s.selectedClipID = clip; s.performEditorAction(.deselect)
        #expect(s.selectedSurfaceID == nil && s.selectedClipID == nil)
        let before = s.project
        s.performEditorAction(.delete)
        #expect(s.project == before)
    }

    @Test func lockedFaceDeletionAndVisibilityUseExistingUndoAndGuards() throws {
        let s = session()
        let face = s.project.surfaces.count
        s.performEditorAction(.lock)
        #expect(s.selectedSurface?.layout.isGeometryLocked == true)
        s.performEditorAction(.delete)
        #expect(s.project.surfaces.count == face && s.editMessage != nil)
        s.performEditorAction(.visibility)
        #expect(s.selectedSurface?.layout.isVisible == false)
        s.undoProjectEdit()
        #expect(s.selectedSurface?.layout.isVisible == true)
        s.performEditorAction(.lock); s.performEditorAction(.delete)
        #expect(s.project.surfaces.isEmpty)
        s.undoProjectEdit(); #expect(s.project.surfaces.count == face)
    }

    @Test func maskDeleteAndEscapePreserveFaceAndUncommittedDrawing() throws {
        let s = session(), face = try #require(s.selectedSurface)
        s.createMask(faceID: face.id)
        s.selectMaskRing(try #require(s.selectedSurface?.mask?.boundary.id))
        s.selectedMaskVertex = 0
        s.performEditorAction(.delete)
        #expect(s.selectedSurface?.mask?.boundary.points.count == 3)
        s.performEditorAction(.delete) // no selected point; must not delete face
        #expect(s.project.surfaces.count == 1)
        s.beginMaskDrawing(hole: true)
        s.appendMaskDraft(SIMD2(0.2, 0.2), faceID: face.id)
        s.appendMaskDraft(SIMD2(0.3, 0.2), faceID: face.id)
        s.performEditorAction(.delete)
        #expect(s.maskDraft?.count == 1)
        let before = s.project
        s.cancelEditorSelection()
        #expect(s.maskDraft == nil && s.isMaskEditing && s.project == before)
        s.cancelEditorSelection(); #expect(!s.isMaskEditing && s.selectedSurfaceID == face.id)
    }

    @Test func groupingAndUngroupingRemainUndoable() {
        let s = session()
        let initial = s.project.surfaces.count
        s.addSurface()
        let before = s.project
        s.performEditorAction(.group)
        #expect(s.isGroupingFaces && s.project == before)
        for face in s.project.surfaces { s.toggleGrouping(face.id) }
        s.performEditorAction(.group)
        #expect(s.selectedObject != nil && s.project.objects.count == 1 && !s.isGroupingFaces)
        s.performEditorAction(.ungroup)
        #expect(s.project.objects.isEmpty && s.project.surfaces.count == initial + 1)
        s.undoProjectEdit(); #expect(s.project.objects.count == 1)
    }

    @Test func selectingAClipExitsMaskContextBeforeDelete() throws {
        let s = session(), face = try #require(s.selectedSurface)
        s.createMask(faceID: face.id)
        s.selectedMaskVertex = 0
        let mask = s.selectedSurface?.mask
        let id = try #require(s.addTimelineClip(sourceID: face.source.id, at: 0))
        #expect(!s.isMaskEditing && s.selectedClipID == id)
        s.performEditorAction(.delete)
        #expect(s.project.timelineClips.isEmpty && s.selectedSurface?.mask == mask)
        #expect(s.project.surfaces.count == 1)
    }

    @Test func playbackKeysPauseSeekClampAndNeverDirtyProject() throws {
        let s = session()
        let document = try ProjectCodec.encode(s.document)
        s.setPlaying(false, at: 100); s.seekPlayback(to: 0, at: 100)
        s.performEditorAction(.stepBack, at: 100)
        #expect(s.transport.position == 0 && !s.transport.isPlaying)
        s.performEditorAction(.stepForward, at: 100)
        #expect(abs(s.transport.position - 1.0 / 30) < 0.000001)
        s.seekPlayback(to: 3599.9, at: 100); s.setPlaying(true, at: 100)
        s.performEditorAction(.secondForward, at: 100)
        #expect(s.transport.position == 3600 && !s.transport.isPlaying)
        s.performEditorAction(.playPause, at: 100); #expect(s.transport.isPlaying)
        s.performEditorAction(.stop, at: 100)
        #expect(!s.transport.isPlaying && s.transport.position == 0)
        #expect(!s.hasUserChanges && !s.canUndo)
        #expect(try ProjectCodec.encode(s.document) == document)
    }

    @Test func timelineAndInspectorNavigationStayOutsideSavedState() throws {
        let s = session()
        let original = try ProjectCodec.encode(s.document)
        s.isTimelineVisible = false
        for action: EditorAction in [.zoomIn, .zoomOut, .fitTimeline, .revealPlayhead, .snap, .follow] {
            let previous = s.timelineViewRequest?.id
            s.performEditorAction(action)
            #expect(s.isTimelineVisible && s.timelineViewRequest?.id != previous)
        }
        s.isInspectorVisible = false; s.performEditorAction(.projectInspector)
        #expect(s.isInspectorVisible && s.inspectorTab == .project)
        s.performEditorAction(.showInspector); #expect(s.inspectorTab == .show)
        s.performEditorAction(.editInspector); #expect(s.inspectorTab == .edit)
        #expect(try ProjectCodec.encode(s.document) == original)
        #expect(!s.hasUserChanges && !s.canUndo)
        s.resetProject(); #expect(s.timelineViewRequest == nil)
    }

    @Test func clipNudgesRespectOverlapBoundsAndDoNotChangeSourcePhase() throws {
        let s = session()
        let id = try #require(s.addTimelineClip(sourceID: s.project.timelineTracks[0].id, at: 1, duration: 2))
        let source = try #require(s.selectedClip?.source)
        s.performEditorAction(.clipEarlier)
        #expect(abs((s.selectedClip?.start ?? -1) - 0.9) < 0.000001)
        s.performEditorAction(.clipSecondLater)
        #expect(abs((s.selectedClip?.start ?? -1) - 1.9) < 0.000001 && s.selectedClip?.source == source)
        s.undoProjectEdit(); #expect(abs((s.selectedClip?.start ?? -1) - 0.9) < 0.000001)
        s.performEditorAction(.clipSecondEarlier)
        #expect(abs((s.selectedClip?.start ?? -1) - 0.9) < 0.000001 && s.timelineMessage != nil)
        _ = s.addTimelineClip(sourceID: s.project.timelineTracks[0].id, at: 3)
        s.selectedClipID = id
        let before = s.project
        s.performEditorAction(.clipSecondLater)
        #expect(s.project == before && s.timelineMessage != nil)
    }

    @Test func surfaceNavigationWrapsAndClearsClipContextWithoutEditing() throws {
        let s = session()
        s.addSurface(); s.addSurface()
        let ids = s.project.surfaces.map(\.id)
        _ = s.addTimelineClip(sourceID: s.project.timelineTracks[0].id, at: 0)
        let before = s.project
        s.performEditorAction(.previousSurface)
        #expect(s.selectedSurfaceID == ids.last && s.selectedClipID == nil)
        s.performEditorAction(.nextSurface)
        #expect(s.selectedSurfaceID == ids.first)
        s.selectSurface(nil); s.performEditorAction(.nextSurface)
        #expect(s.selectedSurfaceID == ids.first && s.project == before)
    }

    @Test func videoSplitsPreserveRangeLoopPhaseRateAndUndo() throws {
        for loops in [false, true] {
            var project = MappingProject()
            let asset = VideoAsset(name: "fixture.mp4", fileExtension: "mp4", byteCount: 20, duration: 30,
                width: 128, height: 64, frameRate: 30, hasAudio: false, codec: "H.264", transform: [1, 0, 0, 1, 0, 0])
            project.videoAssets = [asset]
            var source = project.surfaces[0].source
            source.content = .video
            source.video = VideoContent(assetID: asset.id, inPoint: 3, outPoint: 15, rate: 2, loops: loops)
            let clip = EffectClip(sourceID: source.id, start: 10, duration: 6, source: SourceLook(source: source))
            project.timelineClips = [clip]
            let s = EditorSession(presentOutput: { _ in }, project: project)
            s.selectedClipID = clip.id
            for time in [clip.start, clip.start + 0.05, clip.end - 0.05, clip.end, .nan] {
                s.splitSelectedVideoClip(at: time)
                #expect(s.project == project)
            }
            s.seekPlayback(to: 12, at: 100)
            s.performEditorAction(.splitVideo, at: 100)
            let clips = s.project.timelineClips.sorted { $0.start < $1.start }
            #expect(clips.count == 2 && EffectClip.validSequence(clips))
            let left = try #require(clips.first), right = try #require(clips.last)
            #expect(left.id == clip.id && right.id != clip.id && s.selectedClipID == right.id)
            #expect(left.duration == 2 && right.start == 12 && right.duration == 4)
            #expect(right.source.video?.rate == 2)
            for offset in [0.0, 0.5, 2, 3.99] {
                #expect(right.source.video?.requestedTime(elapsed: offset) == clip.source.video?.requestedTime(elapsed: offset + 2))
            }
            if loops { #expect(right.source.video?.loopOffset == 4) }
            else { #expect(left.source.video?.outPoint == 7 && right.source.video?.inPoint == 7 && right.source.video?.outPoint == 15) }
            s.undoProjectEdit(); #expect(s.project.timelineClips == [clip])
            s.redoProjectEdit(); #expect(s.project.timelineClips.count == 2)
        }
    }

    @Test func splitRejectsTooShortOrNonVideoClipsAndOverlapIsAtomic() throws {
        let s = session()
        let owner = s.project.timelineTracks[0].id
        let first = try #require(s.addTimelineClip(sourceID: owner, at: 0))
        s.splitSelectedVideoClip(at: 2)
        #expect(s.project.timelineClips.count == 1 && !s.canPerformEditorAction(.splitVideo))
        _ = s.addTimelineClip(sourceID: owner, at: 5)
        s.selectedClipID = first
        let before = s.project
        s.performEditorAction(.duplicate)
        #expect(s.project == before && s.timelineMessage != nil)
    }
}
