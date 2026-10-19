import AppKit
import SwiftUI
import Observation

@MainActor @Observable
final class EditorCommandFocus {
    var signature = ""
}

/// Shared by menus, native window routing and the keyboard reference.
enum EditorAction: String, CaseIterable, Identifiable {
    case playPause, stop, stepBack, stepForward, secondBack, secondForward, beginning, sequenceEnd
    case addSurface, duplicate, delete, deselect, group, ungroup, lock, visibility, forward, backward
    case importImage, importVideo, addClip, captureClip, splitVideo
    case clipEarlier, clipLater, clipSecondEarlier, clipSecondLater, previousSurface, nextSurface
    case zoomIn, zoomOut, fitTimeline, revealPlayhead, snap, follow
    case editInspector, showInspector, projectInspector, closeOutput, muteAudio

    var id: Self { self }
    var title: String {
        switch self {
        case .playPause: "Play / Pause"
        case .stop: "Stop and Return to Beginning"
        case .stepBack: "Step Back 1/30 Second"
        case .stepForward: "Step Forward 1/30 Second"
        case .secondBack: "Step Back One Second"
        case .secondForward: "Step Forward One Second"
        case .beginning: "Go to Beginning"
        case .sequenceEnd: "Go to Sequence End"
        case .addSurface: "Add Surface"
        case .duplicate: "Duplicate Selection"
        case .delete: "Delete Selection"
        case .deselect: "Deselect"
        case .group: "Group Faces"
        case .ungroup: "Ungroup Selected Object"
        case .lock: "Lock / Unlock Geometry"
        case .visibility: "Show / Hide Selection"
        case .forward: "Bring Face Forward"
        case .backward: "Send Face Backward"
        case .importImage: "Import Image as New Surface…"
        case .importVideo: "Import Video as New Surface…"
        case .addClip: "Add Current Content at Playhead"
        case .captureClip: "Apply Edited Content to Selected Clip"
        case .splitVideo: "Split Selected Video Clip at Playhead"
        case .clipEarlier: "Move Clip Earlier by 0.1 Seconds"
        case .clipLater: "Move Clip Later by 0.1 Seconds"
        case .clipSecondEarlier: "Move Clip Earlier by One Second"
        case .clipSecondLater: "Move Clip Later by One Second"
        case .previousSurface: "Select Previous Surface"
        case .nextSurface: "Select Next Surface"
        case .zoomIn: "Zoom In on Timeline"
        case .zoomOut: "Zoom Out on Timeline"
        case .fitTimeline: "Fit Complete Timeline"
        case .revealPlayhead: "Reveal Playhead"
        case .snap: "Toggle Timeline Snapping"
        case .follow: "Toggle Follow Playhead"
        case .editInspector: "Edit Inspector"
        case .showInspector: "Show Inspector"
        case .projectInspector: "Project Inspector"
        case .closeOutput: "Close Output"
        case .muteAudio: "Mute Video Audio"
        }
    }
    var key: KeyEquivalent {
        switch self {
        case .playPause, .stop: .return
        case .stepBack, .secondBack, .clipEarlier, .clipSecondEarlier: .leftArrow
        case .stepForward, .secondForward, .clipLater, .clipSecondLater: .rightArrow
        case .previousSurface: .upArrow
        case .nextSurface: .downArrow
        case .beginning: .home
        case .sequenceEnd: .end
        case .addSurface: "n"
        case .duplicate: "d"
        case .delete: .delete
        case .deselect: "a"
        case .group, .ungroup: "g"
        case .lock: "l"
        case .visibility: "h"
        case .forward: "]"
        case .backward: "["
        case .importImage, .importVideo: "i"
        case .addClip, .captureClip: "k"
        case .splitVideo: "b"
        case .zoomIn: "="
        case .zoomOut: "-"
        case .fitTimeline: "0"
        case .revealPlayhead: "p"
        case .snap: "s"
        case .follow: "f"
        case .editInspector: "1"
        case .showInspector: "2"
        case .projectInspector: "3"
        case .closeOutput: "w"
        case .muteAudio: "m"
        }
    }
    var modifiers: EventModifiers {
        switch self {
        case .stepBack, .stepForward: .option
        case .secondBack, .secondForward: [.option, .shift]
        case .clipSecondEarlier, .clipSecondLater: [.command, .option, .shift]
        case .clipEarlier, .clipLater, .previousSurface, .nextSurface: [.command, .option]
        case .beginning, .sequenceEnd: []
        case .stop, .addSurface, .deselect, .ungroup, .visibility, .importImage, .addClip, .revealPlayhead: [.command, .shift]
        case .importVideo, .captureClip, .snap, .follow, .editInspector, .showInspector, .projectInspector: [.command, .option]
        case .closeOutput: [.command, .control]
        case .muteAudio: [.command, .shift]
        default: .command
        }
    }
    var keysLabel: String {
        let prefix = (modifiers.contains(.control) ? "⌃" : "") + (modifiers.contains(.option) ? "⌥" : "") +
            (modifiers.contains(.shift) ? "⇧" : "") + (modifiers.contains(.command) ? "⌘" : "")
        let character: String
        switch self {
        case .playPause: return "Space / ⌘↩"
        case .stop: character = "↩"
        case .stepBack, .secondBack, .clipEarlier, .clipSecondEarlier: character = "←"
        case .stepForward, .secondForward, .clipLater, .clipSecondLater: character = "→"
        case .previousSurface: character = "↑"
        case .nextSurface: character = "↓"
        case .beginning: return "Home (fn-←)"
        case .sequenceEnd: return "End (fn-→)"
        case .delete: return "Delete / ⌘⌫"
        default: character = String(key.character).uppercased()
        }
        return prefix + character
    }
    var isTransport: Bool {
        [.playPause, .stop, .stepBack, .stepForward, .secondBack, .secondForward, .beginning, .sequenceEnd, .muteAudio, .closeOutput].contains(self)
    }
    var allowsRepeat: Bool {
        [.stepBack, .stepForward, .secondBack, .secondForward, .zoomIn, .zoomOut,
         .clipEarlier, .clipLater, .clipSecondEarlier, .clipSecondLater, .previousSurface, .nextSurface].contains(self)
    }
    static let editing: [Self] = [.addSurface, .duplicate, .delete, .deselect, .group, .ungroup, .lock, .visibility, .forward, .backward, .previousSurface, .nextSurface]
    static let timeline: [Self] = [.addClip, .captureClip, .splitVideo, .clipEarlier, .clipLater, .clipSecondEarlier, .clipSecondLater, .zoomIn, .zoomOut, .fitTimeline, .revealPlayhead, .snap, .follow]
}

/// No event monitor: only the editor and clean output windows use this routing.
/// Text fields, menus, sheets and popovers keep their native key handling.
@MainActor
enum EditorKeyRouting {
    static func accepts(firstResponder: NSResponder?, hasSheet: Bool, hasModal: Bool) -> Bool {
        guard !hasSheet, !hasModal else { return false }
        return !(firstResponder is NSTextInputClient) && !(firstResponder is NSTextField)
    }
    static func action(keyCode: UInt16, modifiers: NSEvent.ModifierFlags) -> EditorAction? {
        let flags = modifiers.intersection([.command, .control, .option, .shift])
        switch (keyCode, flags) {
        case (49, []): return .playPause
        case (51, []), (117, []): return .delete
        case (115, []): return .beginning
        case (119, []): return .sequenceEnd
        case (123, .option): return .stepBack
        case (124, .option): return .stepForward
        case (123, [.option, .shift]): return .secondBack
        case (124, [.option, .shift]): return .secondForward
        default: return nil
        }
    }
}

@MainActor
class EditorShortcutWindow: NSWindow {
    var performShortcut: ((EditorAction) -> Bool)?
    var cancelEditing: (() -> Void)?
    var permitsEditing = true
    var shortcutsBlocked: (() -> Bool)?

    /// Also used by hidden-window tests; sendEvent adds the real key-window guard.
    @discardableResult func routeShortcut(_ event: NSEvent) -> Bool {
        guard event.type == .keyDown, event.windowNumber == windowNumber,
              shortcutsBlocked?() != true, NSEvent.pressedMouseButtons == 0,
              EditorKeyRouting.accepts(firstResponder: firstResponder, hasSheet: attachedSheet != nil || NSApp.windows.contains { $0.attachedSheet != nil },
                                       hasModal: NSApp.modalWindow != nil) else { return false }
        if permitsEditing, event.keyCode == 53,
           event.modifierFlags.intersection([.command, .control, .option, .shift]).isEmpty,
           let cancelEditing {
            if !event.isARepeat { cancelEditing() }
            return true
        }
        guard let action = EditorKeyRouting.action(keyCode: event.keyCode, modifiers: event.modifierFlags),
              permitsEditing || action.isTransport else { return false }
        if event.isARepeat && !action.allowsRepeat { return true }
        return performShortcut?(action) ?? false
    }
    override func sendEvent(_ event: NSEvent) {
        if isKeyWindow && routeShortcut(event) { return }
        super.sendEvent(event)
    }
}

struct TimelineViewRequest: Equatable {
    enum Action: Equatable { case zoomIn, zoomOut, fit, playhead, snap, follow }
    let id = UUID()
    let action: Action
}

extension EditorSession {
    func canPerformEditorAction(_ action: EditorAction) -> Bool {
        let busy = isSavingMedia || isImportingImage || isImportingVideo
        switch action {
        case .duplicate: return !busy && (selectedClip != nil || selectedSurface != nil || selectedObject != nil) && !isMaskEditing
        case .delete: return !busy && (selectedClip != nil || selectedSurface != nil || selectedObject != nil)
        case .ungroup: return !busy && selectedObject != nil
        case .lock, .visibility: return !busy && (selectedSurface != nil || selectedObject != nil)
        case .forward, .backward: return !busy && selectedClip == nil && selectedSurface != nil
        case .addSurface, .group, .importImage, .importVideo: return !busy
        case .addClip: return !busy && selectedSource != nil
        case .captureClip: return !busy && selectedClip != nil
        case .clipEarlier, .clipLater, .clipSecondEarlier, .clipSecondLater: return !busy && selectedClip != nil
        case .previousSurface, .nextSurface: return !project.surfaces.isEmpty
        case .splitVideo: return !busy && selectedClip?.source.content == .video
        case .closeOutput: return isOutputOpen
        case .muteAudio: return videoAudioEnabled
        default: return true
        }
    }

    /// Shared menu/native-key implementation keeps edits on the normal undo path.
    func performEditorAction(_ action: EditorAction, at uptime: TimeInterval = ProcessInfo.processInfo.systemUptime) {
        guard canPerformEditorAction(action), uptime.isFinite else { return }
        switch action {
        case .playPause: setPlaying(!transport.isPlaying, at: uptime)
        case .stop: setPlaying(false, at: uptime); restartPlayback(at: uptime)
        case .stepBack, .stepForward, .secondBack, .secondForward, .beginning, .sequenceEnd:
            let time = transport.elapsed(at: uptime)
            let target: Double
            switch action {
            case .stepBack: target = time - 1.0 / 30
            case .stepForward: target = time + 1.0 / 30
            case .secondBack: target = time - 1
            case .secondForward: target = time + 1
            case .beginning: target = 0
            default: target = project.timelineClips.map(\.end).max() ?? 0
            }
            setPlaying(false, at: uptime); seekPlayback(to: min(3600, max(0, target)), at: uptime)
        case .addSurface: addSurface()
        case .duplicate:
            if let clip = selectedClip { duplicateTimelineClip(clip.id) }
            else if let object = selectedObject { duplicateObject(object.id) }
            else if let face = selectedSurface { duplicateSurface(face.id) }
        case .delete:
            if isMaskEditing {
                if maskDraft != nil { removeLastMaskDraftPoint() } else { deleteMaskPoint() }
            } else if let clip = selectedClip { deleteTimelineClip(clip.id) }
            else if let object = selectedObject { deleteObject(object.id) }
            else if let face = selectedSurface { deleteSurface(face.id) }
        case .deselect: selectedClipID = nil; selectSurface(nil); cancelGroupingFaces(); isMaskEditing = false; cancelMaskDrawing()
        case .group:
            if groupingSelection.count >= 2 { createObject(faceIDs: groupingSelection) } else { beginGroupingFaces() }
        case .ungroup: if let object = selectedObject { ungroupObject(object.id) }
        case .lock:
            if let object = selectedObject { setGeometryLocked(!object.isGeometryLocked, objectID: object.id) }
            else if let face = selectedSurface {
                if let object = project.object(for: face), object.isGeometryLocked { setGeometryLocked(false, objectID: object.id) }
                else { setGeometryLocked(!face.layout.isGeometryLocked, faceID: face.id) }
            }
        case .visibility:
            if let object = selectedObject { setVisible(!object.isVisible, objectID: object.id) }
            else if let face = selectedSurface { setVisible(!face.layout.isVisible, faceID: face.id) }
        case .forward: if let face = selectedSurface { moveSurface(face.id, offset: -1) }
        case .backward: if let face = selectedSurface { moveSurface(face.id, offset: 1) }
        case .importImage: chooseImage(target: .newFace)
        case .importVideo: chooseVideo(target: .newFace)
        case .addClip:
            if let source = selectedSource {
                isTimelineVisible = true
                addTimelineClip(sourceID: source.id, at: min(3595, max(0, transport.elapsed(at: uptime))))
            }
        case .captureClip: if let clip = selectedClip { captureTimelineClip(clip.id) }
        case .splitVideo: splitSelectedVideoClip(at: transport.elapsed(at: uptime))
        case .clipEarlier, .clipLater, .clipSecondEarlier, .clipSecondLater:
            if var clip = selectedClip {
                let step = action == .clipEarlier || action == .clipLater ? 0.1 : 1.0
                clip.start += action == .clipEarlier || action == .clipSecondEarlier ? -step : step
                _ = updateTimelineClip(clip)
            }
        case .previousSurface, .nextSurface:
            let index = project.surfaces.firstIndex { $0.id == selectedSurfaceID }
            let offset = action == .previousSurface ? -1 : 1
            let next = index.map { ($0 + offset + project.surfaces.count) % project.surfaces.count } ?? (offset > 0 ? 0 : project.surfaces.count - 1)
            selectSurface(project.surfaces[next].id)
        case .zoomIn: requestTimeline(.zoomIn)
        case .zoomOut: requestTimeline(.zoomOut)
        case .fitTimeline: requestTimeline(.fit)
        case .revealPlayhead: requestTimeline(.playhead)
        case .snap: requestTimeline(.snap)
        case .follow: requestTimeline(.follow)
        case .editInspector: isInspectorVisible = true; inspectorTab = .edit
        case .showInspector: isInspectorVisible = true; inspectorTab = .show
        case .projectInspector: isInspectorVisible = true; inspectorTab = .project
        case .closeOutput: closeOutput()
        case .muteAudio: enableVideoAudio(false)
        }
    }
    private func requestTimeline(_ action: TimelineViewRequest.Action) {
        isTimelineVisible = true; timelineViewRequest = TimelineViewRequest(action: action)
    }
    func cancelEditorSelection() {
        endContinuousEdit()
        if maskDraft != nil { cancelMaskDrawing() }
        else if isGroupingFaces { cancelGroupingFaces() }
        else if isMaskEditing { isMaskEditing = false; selectedMaskVertex = nil }
        else if selectedClipID != nil { selectedClipID = nil }
        else if selectedCorner != nil { selectCorner(nil) }
        else { selectSurface(nil) }
    }
}

struct KeyboardShortcutsView: View {
    @State private var search = ""
    private let sections: [(String, [EditorAction])] = [
        ("Playback", [.playPause, .stop, .stepBack, .stepForward, .secondBack, .secondForward, .beginning, .sequenceEnd, .muteAudio]),
        ("Editing", EditorAction.editing), ("Media", [.importImage, .importVideo]),
        ("Timeline", EditorAction.timeline), ("Workspace", [.editInspector, .showInspector, .projectInspector, .closeOutput])
    ]
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Keyboard Shortcuts").font(.title2.bold())
            TextField("Find a shortcut", text: $search).textFieldStyle(.roundedBorder)
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    ForEach(sections, id: \.0) { title, actions in
                        let matches = actions.filter { search.isEmpty || ($0.title + " " + $0.keysLabel).localizedCaseInsensitiveContains(search) }
                        if !matches.isEmpty {
                            VStack(alignment: .leading, spacing: 5) {
                                Text(title).font(.headline).foregroundStyle(.secondary)
                                ForEach(matches) { action in
                                    HStack { Text(action.title); Spacer(); Text(action.keysLabel).font(.system(.body, design: .monospaced)) }
                                }
                            }
                        }
                    }
                    Divider()
                    Text("Space and editing keys work outside text fields. Duplicate/Delete apply to the selected clip, face or object. Mask Delete removes a point or the last draft point. Escape cancels drawing/grouping, then clears selection. Arrow keys nudge a selected corner/object; Shift takes a larger step. Option-arrows pause and seek. Video split preserves source timing and requires at least 0.1 seconds on each side.")
                    Text("Files: ⌘N New · ⌘O Open · ⌘S Save · ⇧⌘S Save As\nHistory: ⌘Z Undo · ⇧⌘Z Redo; native Cut/Copy/Paste in text fields\nPanels: ⌃⌘S Sidebar · ⌃⌘I Inspector · ⌃⌘T Timeline\nOutput: ⌃⌘O Open · ⇧⌘B Blackout · ⇧⌘R Restore\nGuides: ⌃⌘H Handles · ⌃⌘L Names · ⌃⌘C Calibration\nWindows: ⌃⌘E Editor · ⌘W Close Window · ⌘Q Quit\nThis reference: ⌘/ · Physical output: Escape closes output")
                }.padding(.trailing, 8)
            }
        }.padding(20).frame(minWidth: 590, maxWidth: .infinity, minHeight: 360, maxHeight: .infinity)
    }
}
