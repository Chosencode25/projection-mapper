import SwiftUI

/// Timeline controls and selection are runtime state; clips belong to the saved project.
struct PlaybackTimelineView: View {
    @Bindable var session: EditorSession
    @State private var showChoreography = false
    @State private var selectedChoreography: UUID?
    @State private var cueGroup = ""
    @State private var editMarkers = false
    @State private var showCueList = false
    @State private var waveformRangeMode = false
    @State private var waveformDrag: SongLoop?
    private var pixelsPerSecond: Double {
        get { session.timelineScale }
        nonmutating set { session.timelineScale = newValue }
    }
    private var showsVisualTracks: Bool {
        get { session.showsVisualTracks }
        nonmutating set { session.showsVisualTracks = newValue }
    }
    @State private var verticalPosition = ScrollPosition(y: 0)
    private var visibleTracks: [TimelineTrack] {
        guard showsVisualTracks else { return session.project.baseTimelineTracks }
        var owner: UUID?
        return session.project.timelineTracks.filter { track in
            if track.visualKind == nil { owner = track.id; return true }
            return owner.map { !session.collapsedTimelineOwners.contains($0) } ?? true
        }
    }
    private var snap: Bool {
        get { session.timelineSnap }
        nonmutating set { session.timelineSnap = newValue }
    }
    private var follow: Bool {
        get { session.timelineFollow }
        nonmutating set { session.timelineFollow = newValue }
    }
    @State private var timelinePosition = ScrollPosition(x: 0)
    @State private var viewportWidth = 720.0
    @State private var playbackExtent = 0.0
    @State private var requestedTime = 0.0
    @State private var scrollRequest = 0
    private let laneHeight = 44.0
    private let rulerHeight = 28.0
    private var tickStep: Int { TimelinePresentation.tickStep(pixelsPerSecond: pixelsPerSecond) }
    private var anchorStep: Int { max(1, Int(ceil(60 / pixelsPerSecond))) }

    private var lighting: ProjectLighting { session.project.lighting }
    private var contentEnd: Double { session.project.timelineContentEnd }
    private var selectedCue: LightingCue? { session.selectedLightingCue }

    var body: some View {
        // These collections and the clip editor stay outside the playback animation.
        // Only the transport readout and lightweight overlay redraw at clock cadence.
        let tracks = visibleTracks
        let clipsByTrack = Dictionary(grouping: session.project.timelineClips, by: \.sourceID)
        let time = session.transport.elapsed(at: ProcessInfo.processInfo.systemUptime)
        let horizon = TimelinePresentation.horizon(contentEnd: contentEnd, playhead: max(time, playbackExtent),
            visibleDuration: viewportWidth / pixelsPerSecond)
        VStack(spacing: 0) {
            ScrollView(.horizontal) { transportBar }.scrollIndicators(.hidden)
            if let message = session.songMessage {
                Text(message).font(.caption).foregroundStyle(.orange)
                    .frame(maxWidth: .infinity, alignment: .leading).padding(.horizontal, 10)
            }
            Divider()
            ScrollView(.vertical) {
                HStack(alignment: .top, spacing: 0) {
                    VStack(spacing: 0) {
                        HStack {
                            Text("TRACKS").font(.caption2.weight(.semibold))
                            Spacer()
                            if !session.project.visualTracks.isEmpty {
                                Button {
                                    showsVisualTracks.toggle()
                                } label: {
                                    Image(systemName: showsVisualTracks ? "rectangle.compress.vertical" : "rectangle.expand.vertical")
                                }.buttonStyle(.plain)
                                    .help(showsVisualTracks ? "Collapse layers and regions" : "Expand layers and regions")
                            }
                            Text("\(tracks.count)").monospacedDigit()
                        }.foregroundStyle(.secondary).padding(.horizontal, 10).frame(height: rulerHeight)
                        if let song = session.project.song {
                            Label(song.name, systemImage: "waveform")
                                .font(.caption.weight(.semibold)).lineLimit(1)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal, 10).frame(height: laneHeight)
                        }
                        if !session.project.showMarkers.isEmpty { markerHeader }
                        ForEach(tracks) { track in
                            trackHeader(track)
                            if track.visualKind == .singingFace {
                                Label("Mouth shapes", systemImage: "diamond")
                                    .font(.caption).foregroundStyle(.secondary)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(.horizontal, 22).frame(height: laneHeight)
                            }
                        }
                        if !session.project.choreographyClips.isEmpty {
                            Label("Choreography", systemImage: "sparkles").font(.caption)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal, 10).frame(height: laneHeight)
                        }
                        if !lighting.fixtures.isEmpty { lightingHeader }
                    }.frame(width: 180)
                    Divider()
                    ScrollView(.horizontal) {
                        VStack(spacing: 0) {
                            ruler(horizon: horizon)
                            VStack(spacing: 0) {
                                if let song = session.project.song {
                                    waveform(song)
                                }
                                if !session.project.showMarkers.isEmpty { markerLane }
                                ForEach(tracks) { track in
                                    lane(track, clips: clipsByTrack[track.id] ?? [], horizon: horizon)
                                    if track.visualKind == .singingFace { mouthLane(track) }
                                }
                                if !session.project.choreographyClips.isEmpty { choreographyLane }
                                if !lighting.fixtures.isEmpty { lightingLane }
                            }
                            .background {
                                TimelineGrid(spacing: Double(tickStep) * pixelsPerSecond)
                                    .stroke(Color.white.opacity(0.07), lineWidth: 1)
                            }
                        }
                        .frame(width: horizon * pixelsPerSecond, alignment: .leading)
                        .overlay(alignment: .topLeading) {
                            playbackOverlay(horizon: horizon, tracks: tracks, clipsByTrack: clipsByTrack)
                        }
                    }
                    .scrollPosition($timelinePosition)
                    .onScrollGeometryChange(for: Double.self) { $0.contentOffset.x } action: { _, offset in
                        session.timelineScrollX = max(0, offset)
                    }
                    .onGeometryChange(for: Double.self) { $0.size.width } action: { viewportWidth = $0 }
                    .onAppear { timelinePosition.scrollTo(x: session.timelineScrollX) }
                    .onChange(of: scrollRequest) { _, _ in
                        centerTimeline(at: requestedTime, horizon: horizon)
                    }
                }
            }
            .scrollPosition($verticalPosition)
            .onScrollGeometryChange(for: Double.self) { $0.contentOffset.y } action: { _, offset in session.timelineScrollY = max(0, offset) }
            .onAppear { verticalPosition.scrollTo(y: session.timelineScrollY) }
            Divider()
            if let message = session.timelineMessage {
                Text(message).font(.caption).foregroundStyle(.orange).padding(6)
            }

        }
        .background(Color(nsColor: .controlBackgroundColor))
        .onChange(of: session.project.id) { _, _ in
            playbackExtent = 0; requestedTime = 0; scrollRequest += 1
        }
        .onAppear { applyKeyboardRequest() }
        .onChange(of: session.timelineViewRequest) { _, _ in applyKeyboardRequest() }
    }

    private func applyKeyboardRequest() {
        guard let request = session.timelineViewRequest else { return }
        session.timelineViewRequest = nil
        switch request.action {
        case .zoomIn: setTimelineScale(pixelsPerSecond * 1.5, center: playhead)
        case .zoomOut: setTimelineScale(pixelsPerSecond / 1.5, center: playhead)
        case .fit: fitTimeline()
        case .snap: snap.toggle()
        case .follow: follow.toggle()
        case .playhead: revealTimelineTime(playhead)
        }
    }

    private var transportBar: some View {
        HStack(spacing: 10) {
            Image(systemName: "film.stack").foregroundStyle(.secondary)
            TimelineTransportControls(session: session)
            SongMenu(session: session)
            Button("Choreography", systemImage: "sparkles") {
                selectedChoreography = nil
                showChoreography = true
            }.popover(isPresented: $showChoreography) {
                ChoreographyEditor(session: session, existingID: selectedChoreography, playhead: playhead)
                    .id(selectedChoreography)
            }
            BeatQueueMenu(session: session)
            markerTools
            if !lighting.cues.isEmpty {
                Button { showCueList.toggle() } label: { Label("Cue List", systemImage: "list.bullet") }
                    .popover(isPresented: $showCueList) {
                        ManualCueList(session: session) { cue in
                            session.selectLightingCue(cue.id)
                            showCueList = false
                        }
                    }
            }
            if session.project.song != nil {
                Toggle("Draw Loop", isOn: $waveformRangeMode).toggleStyle(.checkbox)
                    .help("Drag across the waveform to set a loop")
            }
            Divider().frame(height: 18)
            Spacer(minLength: 0)
            Toggle("Snap", isOn: $session.timelineSnap).toggleStyle(.checkbox).help("Snap to nearby markers or whole seconds (Option-Command-S)")
            Toggle("Follow", isOn: $session.timelineFollow).toggleStyle(.checkbox).help("Scroll to follow the playhead (Option-Command-F)")
            Button { setTimelineScale(pixelsPerSecond / 1.5, center: playhead) } label: {
                Image(systemName: "minus.magnifyingglass")
            }.accessibilityLabel("Zoom timeline out")
            Slider(value: Binding(get: { log2(pixelsPerSecond) }, set: {
                setTimelineScale(pow(2, $0), center: playhead)
            }), in: log2(0.1)...log2(480))
                .frame(width: 76).accessibilityLabel("Timeline zoom")
            Button { setTimelineScale(pixelsPerSecond * 1.5, center: playhead) } label: {
                Image(systemName: "plus.magnifyingglass")
            }.accessibilityLabel("Zoom timeline in")
            Button("Fit", action: fitTimeline).help("Fit the song or sequence (Command-0)")
            Menu("Zoom To") {
                Button("Selection") { zoomToSelection() }.disabled(session.selectedClip == nil && selectedCue == nil)
                Button("Loop") {
                    if let loop = session.project.song?.loop { zoomToRange(loop.start...loop.end) }
                }.disabled(session.project.song?.loop == nil)
            }.fixedSize()
            Button { revealTimelineTime(playhead) } label: {
                Label("Playhead", systemImage: "scope")
            }.help("Center the current playback position (Shift-Command-P)")
        }.buttonStyle(.borderless).controlSize(.small).padding(.horizontal, 10).padding(.vertical, 7)
    }

    private var playhead: Double { session.transport.elapsed(at: ProcessInfo.processInfo.systemUptime) }

    private func revealTimelineTime(_ time: Double) {
        requestedTime = time
        scrollRequest += 1
    }

    private func setTimelineScale(_ scale: Double, center: Double) {
        pixelsPerSecond = min(480, max(0.1, scale))
        revealTimelineTime(center)
    }

    private func fitTimeline() {
        let end = session.project.song?.duration ?? contentEnd
        setTimelineScale(TimelinePresentation.fitScale(contentEnd: end, viewportWidth: viewportWidth), center: 0)
    }

    private func zoomToSelection() {
        if let cue = selectedCue {
            zoomToRange(max(0, cue.time - max(1, cue.lead, cue.dimmerFade ?? 0))...min(3600, cue.time + 1))
        } else if let clip = session.selectedClip {
            zoomToRange(clip.start...clip.end)
        }
    }

    private func zoomToRange(_ range: ClosedRange<Double>) {
        setTimelineScale(max(1, viewportWidth - 48) / max(0.1, range.upperBound - range.lowerBound),
                         center: (range.lowerBound + range.upperBound) / 2)
    }

    private func centerTimeline(at time: Double, horizon: Double) {
        timelinePosition.scrollTo(x: TimelinePresentation.centeredOffset(
            time: time, pixelsPerSecond: pixelsPerSecond, viewportWidth: viewportWidth, horizon: horizon))
    }

    private func playbackOverlay(horizon: Double, tracks: [TimelineTrack], clipsByTrack: [UUID: [EffectClip]]) -> some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30, paused: !session.transport.isPlaying)) { _ in
            let time = session.transport.elapsed(at: ProcessInfo.processInfo.systemUptime)
            ZStack(alignment: .topLeading) {
                Path { path in
                    for (index, track) in tracks.enumerated() {
                        guard let clip = clipsByTrack[track.id]?.first(where: { $0.contains(time) }) else { continue }
                        let precedingRows = (session.project.song == nil ? 0 : 1) + (session.project.showMarkers.isEmpty ? 0 : 1)
                        let precedingMouthLanes = tracks.prefix(index).filter { $0.visualKind == .singingFace }.count
                        let y = rulerHeight + Double(index + precedingRows + precedingMouthLanes) * laneHeight + 6
                        let inset = min(3, clip.duration * pixelsPerSecond / 3)
                        path.move(to: CGPoint(x: clip.start * pixelsPerSecond + inset, y: y))
                        path.addLine(to: CGPoint(x: clip.end * pixelsPerSecond - inset, y: y))
                    }
                }.stroke(Color.white.opacity(0.65), lineWidth: 2)
                Rectangle().fill(Color.orange).frame(width: 1.5)
                    .overlay(alignment: .top) {
                        Image(systemName: "arrowtriangle.down.fill").font(.system(size: 9)).foregroundStyle(.orange)
                    }
                    .offset(x: min(horizon, time) * pixelsPerSecond)
            }
            .allowsHitTesting(false).accessibilityHidden(true)
            .onChange(of: Int(time / Double(anchorStep))) { _, _ in
                if follow && session.transport.isPlaying { centerTimeline(at: time, horizon: horizon) }
            }
            .onChange(of: Int(time / 30)) { _, _ in playbackExtent = time }
        }
    }

    private var choreographyLane: some View {
        ZStack(alignment: .leading) {
            Color.mint.opacity(0.08)
            ForEach(session.project.choreographyClips) { clip in
                Button {
                    selectedChoreography = clip.id
                    showChoreography = true
                } label: {
                    Text(clip.name).font(.caption).lineLimit(1).padding(.horizontal, 5)
                        .frame(width: max(8, clip.duration * pixelsPerSecond), height: 23, alignment: .leading)
                        .clipped().background(.mint.opacity(0.26), in: RoundedRectangle(cornerRadius: 4))
                }.buttonStyle(.plain).offset(x: clip.start * pixelsPerSecond)
            }
        }.frame(height: laneHeight)
    }

    private func trackHeader(_ track: TimelineTrack) -> some View {
        HStack(spacing: 7) {
            if track.visualKind == nil, showsVisualTracks {
                Button {
                    if session.collapsedTimelineOwners.contains(track.id) { session.collapsedTimelineOwners.remove(track.id) }
                    else { session.collapsedTimelineOwners.insert(track.id) }
                } label: { Image(systemName: session.collapsedTimelineOwners.contains(track.id) ? "chevron.right" : "chevron.down") }
                    .buttonStyle(.plain).font(.caption2).accessibilityLabel("Expand or collapse " + track.name)
            }
            Button { session.selectedLightingCueID = nil; session.selectTimelineTrack(track); session.selectedClipID = nil } label: {
                HStack(spacing: 7) {
                    Image(systemName: track.isVisible ? (track.isObject ? "cube" : "square") : "eye.slash")
                    VStack(alignment: .leading, spacing: 1) {
                        Text(track.name).font(.caption.weight(.semibold)).lineLimit(1)
                        Text(track.visualKind != nil ? (track.isRegion ? "Region" : "Layer") :
                             track.isObject ? "\(track.faceCount) faces" : "")
                            .font(.system(size: 9)).foregroundStyle(.secondary)
                    }
                    Spacer(minLength: 0)
                }.contentShape(Rectangle())
            }.buttonStyle(.plain).help("Select " + track.name)
            Button {
                let time = snapped(min(3595, session.transport.elapsed(at: ProcessInfo.processInfo.systemUptime)))
                session.selectedLightingCueID = nil
                session.addTimelineClip(sourceID: track.id, at: time)
            } label: { Image(systemName: "plus.circle") }
                .buttonStyle(.borderless).help("Add current content at playhead").accessibilityLabel("Add clip for " + track.name)
        }
        .padding(.leading, track.visualKind == nil ? 10 : 24).padding(.trailing, 10).frame(height: laneHeight)
        .background((session.selectedVisualID ?? session.selectedSource?.id) == track.id ? Color.accentColor.opacity(0.15) : Color.clear)
        .overlay(alignment: .bottom) { Divider() }
    }

    private func mouthLane(_ track: TimelineTrack) -> some View {
        ZStack(alignment: .leading) {
            Color.mint.opacity(0.07)
            if let visual = session.project.visualTrack(track.id) {
                ForEach(visual.mouthKeys) { key in
                    Button {
                        session.selectMouthKey(key.id, on: track)
                        session.setPlaying(false)
                        session.seekPlayback(to: key.time)
                    } label: {
                        Image(systemName: "diamond.fill").font(.caption2).foregroundStyle(.mint)
                    }.buttonStyle(.plain)
                        .help(key.shape.title + " at " + TimelinePresentation.timecode(key.time))
                        .accessibilityLabel(key.shape.title + " mouth shape at " + TimelinePresentation.timecode(key.time))
                        .contextMenu {
                            ForEach(MouthShape.allCases) { shape in
                                Button(shape.title) { session.setMouthShape(shape, on: track.id, at: key.time) }
                            }
                            Divider()
                            Button("Delete mouth key", role: .destructive) {
                                session.updateVisual(track.id) { $0.mouthKeys.removeAll { $0.id == key.id } }
                            }
                        }
                        .offset(x: max(0, key.time * pixelsPerSecond - 5))
                }
            }
        }.frame(height: laneHeight)
    }

    private func ruler(horizon: Double) -> some View {
        ZStack(alignment: .topLeading) {
            Color(nsColor: .windowBackgroundColor)
            ForEach(Array(stride(from: 0, through: Int(horizon), by: tickStep)), id: \.self) { tick in
                VStack(alignment: .leading, spacing: 2) {
                    Text(TimelinePresentation.timecode(Double(tick))).font(.system(size: 9, design: .monospaced)).foregroundStyle(.secondary)
                    Rectangle().fill(Color.secondary).frame(width: 1, height: 7)
                }.offset(x: Double(tick) * pixelsPerSecond + 2)
            }
        }.frame(height: rulerHeight).clipped().contentShape(Rectangle())
            .gesture(DragGesture(minimumDistance: 0).onChanged { value in
                session.setPlaying(false)
                session.seekPlayback(to: min(3600, max(0, value.location.x / pixelsPerSecond)))
            })
            .help("Click or drag to scrub playback")
    }

    private func lane(_ track: TimelineTrack, clips: [EffectClip], horizon: Double) -> some View {
        ZStack(alignment: .leading) {
            Color.black.opacity((session.selectedVisualID ?? session.selectedSource?.id) == track.id ? 0.06 : 0.16)
            if clips.isEmpty {
                HStack {
                    Image(systemName: "infinity")
                    Text(track.visualKind == .text ? "Add a clip to show text" :
                         (track.visualKind == .singingFace ? "Singing face" : track.source.content.title) + " · Live content")
                        .font(.caption)
                    Text("Add a clip to sequence this track").font(.caption2).foregroundStyle(.tertiary)
                }.foregroundStyle(.secondary).padding(.horizontal, 12)
                    .frame(width: horizon * pixelsPerSecond, height: 30, alignment: .leading)
                    .background(Color.accentColor.opacity(0.06)).allowsHitTesting(false)
            }
            ForEach(clips) { clip in
                TimelineClipBlock(clip: clip, selected: session.selectedClipID == clip.id,
                    pixelsPerSecond: pixelsPerSecond, snap: snap, markerTimes: session.project.showMarkers.map(\.time),
                    poster: clip.source.video.flatMap { session.videoPosters[$0.assetID] },
                    titleOverride: track.visualKind == .media ? nil : track.visualKind?.title,
                    select: { session.selectedLightingCueID = nil; session.selectedClipID = clip.id; session.selectTimelineTrack(track) },
                    commit: { _ = session.updateTimelineClip($0) })
                    .offset(x: clip.start * pixelsPerSecond)
                    .contextMenu {
                        Button("Apply Edited Content") { session.captureTimelineClip(clip.id) }
                        Button("Duplicate After Clip") { session.duplicateTimelineClip(clip.id) }
                        Divider()
                        Button("Delete Clip", role: .destructive) { session.deleteTimelineClip(clip.id) }
                    }
            }
        }.frame(height: laneHeight)
            .contentShape(Rectangle())
            .gesture(SpatialTapGesture(count: 2).onEnded { value in
                session.selectedLightingCueID = nil
                session.addTimelineClip(sourceID: track.id, at: snapped(min(3595, max(0, value.location.x / pixelsPerSecond))))
            })
            .overlay(alignment: .bottom) { Divider() }
    }

    private var lightingHeader: some View {
        HStack(spacing: 6) {
            Label("Lighting", systemImage: "light.beacon.max").font(.caption.weight(.semibold))
            Spacer(minLength: 0)
            Picker("Lighting look", selection: $session.selectedFixtureLookID) {
                Text("Look").tag(UUID?.none)
                ForEach(lighting.looks) { Text($0.name).tag(Optional($0.id)) }
            }.labelsHidden().controlSize(.small).help("Choose a captured lighting look")
            if !fixtureGroups.isEmpty {
                Menu {
                    Button("All Fixtures") { cueGroup = "" }
                    ForEach(fixtureGroups, id: \.self) { group in
                        Button(group) { cueGroup = group }
                    }
                } label: { Image(systemName: cueGroup.isEmpty ? "person.2" : "person.2.fill") }
                    .help(cueGroup.isEmpty ? "Target all fixtures in the look" : "Target group: " + cueGroup)
                    .menuIndicator(.hidden).fixedSize()
            }
            Button {
                addCue(at: session.transport.elapsed(at: ProcessInfo.processInfo.systemUptime))
            } label: {
                Image(systemName: "plus.circle")
            }.buttonStyle(.borderless)
                .disabled(session.selectedFixtureLook == nil)
                .help("Place the selected look at the playhead")
                .accessibilityLabel("Add lighting cue")
        }
        .padding(.horizontal, 10).frame(height: laneHeight)
        .overlay(alignment: .bottom) { Divider() }
    }

    private var lightingLane: some View {
        ZStack(alignment: .leading) {
            Color.orange.opacity(0.08)
            ForEach(lighting.cues.filter { !$0.isManual }) { cue in
                if cue.lead > 0, (cue.motionCurve ?? .snap) != .snap {
                    let start = max(0, cue.time - cue.lead)
                    Capsule().fill(Color.orange.opacity(0.35))
                        .frame(width: (cue.time - start) * pixelsPerSecond, height: 4)
                        .offset(x: start * pixelsPerSecond + 9, y: 12)
                }
                Button {
                    session.selectLightingCue(cue.id)
                } label: {
                    Image(systemName: session.selectedLightingCueID == cue.id ? "diamond.fill" : "diamond")
                        .foregroundStyle(Color.orange)
                        .frame(width: 18, height: 28)
                }
                .buttonStyle(.plain)
                .help("\(cue.name) at \(TimelinePresentation.timecode(cue.time))")
                .accessibilityLabel("\(cue.name) at \(TimelinePresentation.timecode(cue.time))")
                .offset(x: cue.time * pixelsPerSecond)
            }
        }.frame(height: laneHeight)
            .contentShape(Rectangle())
            .gesture(SpatialTapGesture(count: 2).onEnded { value in
                addCue(at: value.location.x / pixelsPerSecond)
            })
            .overlay(alignment: .bottom) { Divider() }
    }

    private func addCue(at time: Double) {
        guard let look = session.selectedFixtureLook else { return }
        let groupIDs = Set(lighting.fixtures.filter { $0.group == cueGroup }.map(\.id))
        let entries = cueGroup.isEmpty ? look.entries : look.entries.filter { groupIDs.contains($0.id) }
        guard !entries.isEmpty else {
            session.lightingMessage = "The selected look has no fixtures in " + cueGroup + "."
            return
        }
        session.putLightingCue(LightingCue(name: look.name, time: snapped(min(3600, max(0, time))), entries: entries))
    }

    private var fixtureGroups: [String] {
        Array(Set(lighting.fixtures.map(\.group).filter { !$0.isEmpty })).sorted()
    }

    private var markerTools: some View {
        HStack(spacing: 6) {
            Button { session.moveToShowMarker(forward: false) } label: { Image(systemName: "backward.end") }
                .help("Previous marker").disabled(session.project.showMarkers.isEmpty)
            Button { editMarkers.toggle() } label: { Label("Markers", systemImage: "flag") }
                .popover(isPresented: $editMarkers) { ShowMarkerEditor(session: session) }
            Button { session.moveToShowMarker(forward: true) } label: { Image(systemName: "forward.end") }
                .help("Next marker").disabled(session.project.showMarkers.isEmpty)
            Button {
                session.putShowMarker(ShowMarker(time: min(3600, session.transport.elapsed(at: ProcessInfo.processInfo.systemUptime)),
                                                 kind: .beat, name: "Beat"))
            } label: { Image(systemName: "metronome") }
                .help("Tap a beat at the current playhead").accessibilityLabel("Tap beat")
        }
    }

    private var markerHeader: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(ShowMarkerKind.allCases) { kind in
                Text(kind.rawValue).font(.caption2).foregroundStyle(markerTint(kind))
                    .frame(maxHeight: .infinity)
            }
        }.frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 10).frame(height: laneHeight)
    }

    private var markerLane: some View {
        VStack(spacing: 0) {
            ForEach(ShowMarkerKind.allCases) { kind in
                ZStack(alignment: .leading) {
                    markerTint(kind).opacity(0.08)
                    ForEach(session.project.showMarkers.filter { $0.kind == kind }) { marker in
                        Button {
                            session.jumpToShowMarker(marker)
                            editMarkers = true
                        } label: {
                            Image(systemName: session.selectedMarkerID == marker.id ? "flag.fill" : "flag")
                                .font(.system(size: 9)).foregroundStyle(markerTint(kind))
                        }.buttonStyle(.plain).offset(x: marker.time * pixelsPerSecond)
                            .help(marker.name).accessibilityLabel(marker.name)
                    }
                }.frame(height: laneHeight / 3)
            }
        }
    }

    private func markerTint(_ kind: ShowMarkerKind) -> Color {
        switch kind {
        case .beat: .yellow
        case .lyric: .pink
        case .section: .mint
        }
    }

    private func waveform(_ song: ShowSong) -> some View {
        SongWaveform(peaks: session.songPeaks, song: song, pixelsPerSecond: pixelsPerSecond,
                     rangePreview: waveformDrag)
            .frame(height: laneHeight)
            .contentShape(Rectangle())
            .gesture(DragGesture(minimumDistance: 0).onChanged { value in
                guard waveformRangeMode else { return }
                let start = min(song.duration, max(0, snapped(value.startLocation.x / pixelsPerSecond)))
                let end = min(song.duration, max(0, snapped(value.location.x / pixelsPerSecond)))
                waveformDrag = SongLoop(start: min(start, end), end: max(start, end))
            }.onEnded { value in
                if waveformRangeMode {
                    if let range = waveformDrag { session.setSongLoop(range) }
                    waveformDrag = nil
                } else {
                    session.setPlaying(false)
                    session.seekPlayback(to: min(song.duration, max(0, value.location.x / pixelsPerSecond)))
                }
            })
    }

    private func snapped(_ time: Double) -> Double {
        guard snap else { return time }
        if let marker = session.project.showMarkers.min(by: { abs($0.time - time) < abs($1.time - time) }),
           abs(marker.time - time) <= min(0.3, 10 / pixelsPerSecond) { return marker.time }
        return time.rounded()
    }
}

/// Pure display calculations also bound scrolling and fit behavior for very long sequences.
enum TimelinePresentation {
    static func horizon(contentEnd: Double, playhead: Double, visibleDuration: Double = 0) -> Double {
        let contentHorizon = (max(contentEnd, playhead) / 30).rounded(.up) * 30 + 30
        let visibleHorizon = (visibleDuration / 30).rounded(.up) * 30
        return min(3600, max(60, max(contentHorizon, visibleHorizon)))
    }
    static func tickStep(pixelsPerSecond: Double) -> Int {
        [1, 2, 5, 10, 15, 30, 60, 120, 300, 600, 900].first { Double($0) * pixelsPerSecond >= 68 } ?? 900
    }
    static func fitScale(contentEnd: Double, viewportWidth: Double) -> Double {
        min(80, max(0.1, max(1, viewportWidth - 24) / max(10, contentEnd + 1)))
    }
    static func centeredOffset(time: Double, pixelsPerSecond: Double, viewportWidth: Double, horizon: Double) -> Double {
        min(max(0, horizon * pixelsPerSecond - viewportWidth),
            max(0, time * pixelsPerSecond - viewportWidth / 2))
    }
    static func timecode(_ time: Double) -> String {
        let centiseconds = Int(max(0, min(360000, time.isFinite ? time * 100 : 0)))
        return String(format: "%02d:%02d.%02d", centiseconds / 6000, (centiseconds / 100) % 60, centiseconds % 100)
    }
}

private struct TimelineGrid: Shape {
    let spacing: Double
    func path(in rect: CGRect) -> Path {
        Path { path in
            for x in stride(from: 0.0, through: rect.width, by: spacing) {
                path.move(to: CGPoint(x: x, y: 0)); path.addLine(to: CGPoint(x: x, y: rect.height))
            }
        }
    }
}

private struct TimelineTransportControls: View {
    @Bindable var session: EditorSession
    @State private var showingSeek = false
    @State private var seekTime = 0.0
    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 15, paused: !session.transport.isPlaying)) { _ in
            let time = session.transport.elapsed(at: ProcessInfo.processInfo.systemUptime)
            HStack(spacing: 8) {
                Button { session.stopPlayback() } label: { Image(systemName: "stop.fill") }
                    .help("Stop and return to the beginning (Shift-Command-Return)").accessibilityLabel("Stop and return to beginning")
                Button { session.seekPlayback(to: max(0, min(3600, time - 1))) } label: { Image(systemName: "backward.frame.fill") }
                    .help("Back one second").accessibilityLabel("Back one second")
                Button { session.setPlaying(!session.transport.isPlaying) } label: {
                    Label(session.transport.isPlaying ? "Pause" : "Play", systemImage: session.transport.isPlaying ? "pause.fill" : "play.fill")
                        .frame(width: 56)
                }.buttonStyle(.borderedProminent).help("Play or pause (Space or Command-Return)")
                    .accessibilityLabel(session.transport.isPlaying ? "Pause playback" : "Play playback")
                Button { session.seekPlayback(to: min(3600, time + 1)) } label: { Image(systemName: "forward.frame.fill") }
                    .help("Forward one second").accessibilityLabel("Forward one second")
                Button { seekTime = min(3600, time); showingSeek = true } label: {
                    Text(TimelinePresentation.timecode(time) + (session.project.song.map { " / " + TimelinePresentation.timecode($0.duration) } ?? ""))
                        .font(.system(.body, design: .monospaced).weight(.semibold)).foregroundStyle(.orange)
                        .padding(.horizontal, 7).padding(.vertical, 3)
                        .background(.black.opacity(0.18), in: RoundedRectangle(cornerRadius: 5))
                }.help("Click to jump to a time").accessibilityLabel("Playhead " + TimelinePresentation.timecode(time) + ". Jump to time")
                    .popover(isPresented: $showingSeek) {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Jump to time").font(.headline)
                            HStack {
                                TextField("Seconds", value: $seekTime, format: .number.precision(.fractionLength(0...2)))
                                    .frame(width: 100).textFieldStyle(.roundedBorder).onSubmit(jump)
                                Text("seconds").foregroundStyle(.secondary)
                            }
                            Button("Go to Time", action: jump).buttonStyle(.borderedProminent)
                                .disabled(!seekTime.isFinite || !(0...3600).contains(seekTime))
                        }.padding(14)
                    }
                Picker("Speed", selection: Binding(get: { session.transport.speed }, set: { session.setPlaybackSpeed($0) })) {
                    ForEach([0.25, 0.5, 1.0, 2.0, 4.0], id: \.self) { Text($0.formatted() + "×").tag($0) }
                }.labelsHidden().frame(width: 60).help("Playback speed").accessibilityLabel("Playback speed")
                    .disabled(session.project.song != nil)
            }
        }
    }
    private func jump() {
        guard seekTime.isFinite, (0...3600).contains(seekTime) else { return }
        session.setPlaying(false); session.seekPlayback(to: seekTime); showingSeek = false
    }
}

private struct TimelineClipBlock: View {
    let clip: EffectClip
    let selected: Bool
    let pixelsPerSecond: Double
    let snap: Bool
    let markerTimes: [Double]
    let poster: ImagePixels?
    var titleOverride: String? = nil
    private var title: String { titleOverride ?? clip.source.content.title }
    let select: () -> Void
    let commit: (EffectClip) -> Void
    @State private var draft: EffectClip?
    private var displayed: EffectClip { draft ?? clip }
    private var width: Double { max(4, displayed.duration * pixelsPerSecond) }
    private var symbol: String {
        switch clip.source.content { case .image: "photo"; case .video: "film"; default: "sparkles" }
    }

    @ViewBuilder
    private var blockContent: some View {
        if width < 30 {
            Color.clear.contentShape(Rectangle()).gesture(drag(mode: 0))
        } else {
            HStack(spacing: 0) {
                trimHandle(leading: true)
                HStack(spacing: 5) {
                    if clip.source.content == .video, width >= 140 {
                        VideoPoster(pixels: poster).frame(width: 30, height: 26).clipShape(RoundedRectangle(cornerRadius: 3))
                            .allowsHitTesting(false)
                    }
                    if width >= 64 {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(title).font(.system(size: 11, weight: .semibold))
                                .lineLimit(1).truncationMode(.tail)
                            if width >= 90 {
                                Text("\(displayed.duration.formatted(.number.precision(.fractionLength(0...1))))s")
                                    .font(.system(size: 9, design: .monospaced)).foregroundStyle(.white.opacity(0.75))
                            }
                        }.frame(maxWidth: .infinity, alignment: .leading)
                    } else {
                        Image(systemName: symbol).font(.system(size: 10)).frame(maxWidth: .infinity)
                    }
                }.padding(.horizontal, 3).frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
                    .clipped().contentShape(Rectangle()).gesture(drag(mode: 0))
                trimHandle(leading: false)
            }
        }
    }
    var body: some View {
        blockContent
        .frame(width: width, height: 34)
        .foregroundStyle(.white)
        .background(RoundedRectangle(cornerRadius: 5).fill(selected ? Color.accentColor.opacity(0.85) : Color.indigo.opacity(0.65)))
        .overlay { RoundedRectangle(cornerRadius: 5).stroke(selected ? Color.orange : Color.white.opacity(0.23), lineWidth: selected ? 2 : 1) }
        .contentShape(Rectangle()).onTapGesture(perform: select)
        .offset(x: ((draft?.start ?? clip.start) - clip.start) * pixelsPerSecond)
        .help("\(title) · \(TimelinePresentation.timecode(clip.start))–\(TimelinePresentation.timecode(clip.end)) · Select to edit; drag to move")
        .accessibilityElement(children: .ignore).accessibilityLabel("\(title), starts at \(clip.start) seconds, duration \(clip.duration) seconds")
        .accessibilityAddTraits(.isButton).accessibilityAction { select() }
    }
    private func trimHandle(leading: Bool) -> some View {
        RoundedRectangle(cornerRadius: 2).fill(Color.white.opacity(selected ? 0.6 : 0.2))
            .frame(width: 5, height: 20).padding(.horizontal, 2)
            .contentShape(Rectangle()).gesture(drag(mode: leading ? -1 : 1))
    }
    private func drag(mode: Int) -> some Gesture {
        DragGesture(minimumDistance: 3, coordinateSpace: .global).onChanged { value in
            select()
            let delta = value.translation.width / pixelsPerSecond
            func quantize(_ value: Double) -> Double {
                guard snap else { return value }
                if let marker = markerTimes.min(by: { abs($0 - value) < abs($1 - value) }),
                   abs(marker - value) <= min(0.3, 10 / pixelsPerSecond) { return marker }
                return value.rounded()
            }
            var copy = clip
            if mode == 0 { copy.start = min(3600 - clip.duration, max(0, quantize(clip.start + delta))) }
            if mode == -1 {
                copy.start = min(clip.end - 0.1, max(0, quantize(clip.start + delta))); copy.duration = clip.end - copy.start
            }
            if mode == 1 { copy.duration = min(3600 - clip.start, max(0.1, quantize(clip.end + delta) - clip.start)) }
            if mode != 0 { copy = clip.trimming(start: copy.start,duration: copy.duration) }
            draft = copy
        }.onEnded { _ in if let draft { commit(draft) }; draft = nil }
    }
}

private struct SongWaveform: View {
    let peaks: [Float]
    let song: ShowSong
    let pixelsPerSecond: Double
    let rangePreview: SongLoop?

    var body: some View {
        Canvas { context, size in
            let width = song.duration * pixelsPerSecond
            let height = size.height
            if let loop = rangePreview ?? song.loop {
                let region = CGRect(x: loop.start * pixelsPerSecond, y: 0,
                                    width: (loop.end - loop.start) * pixelsPerSecond, height: height)
                context.fill(Path(region), with: .color(.orange.opacity(0.18)))
            }
            var wave = Path()
            for (index, peak) in peaks.enumerated() {
                let x = width * (Double(index) + 0.5) / Double(peaks.count)
                let amplitude = max(0.6, Double(peak) * (height / 2 - 4))
                wave.move(to: CGPoint(x: x, y: height / 2 - amplitude))
                wave.addLine(to: CGPoint(x: x, y: height / 2 + amplitude))
            }
            context.stroke(wave, with: .color(.cyan.opacity(0.9)), lineWidth: 1)
        }
        .background(.cyan.opacity(0.06))
        .accessibilityLabel("Waveform for " + song.name)
    }
}

private struct SongMenu: View {
    @Bindable var session: EditorSession
    @State private var editingLoop = false
    @State private var start = 0.0
    @State private var end = 0.0

    var body: some View {
        Menu {
            Button(session.project.song == nil ? "Import Song…" : "Replace Song…") { session.chooseSong() }
                .disabled(session.songBusy || session.isSavingMedia)
            if let song = session.project.song {
                Button("Remove Song") { session.removeSong() }.disabled(session.songBusy)
                Divider()
                Button(song.loop == nil ? "Set Loop Range…" : "Edit Loop Range…") {
                    start = song.loop?.start ?? 0
                    end = song.loop?.end ?? song.duration
                    editingLoop = true
                }
                if song.loop != nil { Button("Clear Loop") { session.setSongLoop(nil) } }
                Divider()
                Toggle("Mute Soundtrack", isOn: $session.songMuted)
                Toggle("Audio-Only Rehearsal", isOn: $session.songAudioOnly)
                Menu("Audio Output") {
                    Button("Mac Default Output") { session.selectSongDevice(nil) }
                    ForEach(session.songDevices) { device in
                        Button(device.name) { session.selectSongDevice(device.id) }
                    }
                    Button("Refresh Devices") { session.refreshSongDevices() }
                }
            }
        } label: {
            Label(session.project.song == nil ? "Add Song" : "Song", systemImage: "music.note")
        }
        .onAppear { session.refreshSongDevices() }
        .popover(isPresented: $editingLoop) {
            VStack(alignment: .leading, spacing: 10) {
                Text("Loop range in seconds").font(.headline)
                TextField("Start", value: $start, format: .number.precision(.fractionLength(0...3)))
                TextField("End", value: $end, format: .number.precision(.fractionLength(0...3)))
                HStack {
                    Button("Cancel") { editingLoop = false }
                    Spacer()
                    Button("Apply Loop") {
                        session.setSongLoop(SongLoop(start: start, end: end))
                        editingLoop = false
                    }
                    .disabled(!SongLoop(start: start, end: end).isValid(for: session.project.song?.duration ?? 0))
                }
            }.padding(16).frame(width: 240)
        }
        if session.project.song != nil {
            Slider(value: $session.songVolume, in: 0...1)
                .frame(width: 70).accessibilityLabel("Soundtrack volume").help("Soundtrack volume")
        }
    }
}

private struct ShowMarkerEditor: View {
    @Bindable var session: EditorSession
    @State private var importText = ""
    @State private var importing = false

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack {
                Text("Show Markers").font(.headline)
                Spacer()
                Menu("Add at Playhead") {
                    ForEach(ShowMarkerKind.allCases) { kind in
                        Button(kind.rawValue) {
                            let time = session.transport.elapsed(at: ProcessInfo.processInfo.systemUptime)
                            session.putShowMarker(ShowMarker(time: min(3600, time), kind: kind, name: kind.rawValue))
                        }
                    }
                }
            }
            if !session.project.showMarkers.isEmpty {
                Picker("Marker", selection: $session.selectedMarkerID) {
                    Text("Choose a marker").tag(UUID?.none)
                    ForEach(session.project.showMarkers.sorted { $0.time < $1.time }) { marker in
                        Text(TimelinePresentation.timecode(marker.time) + " · " + marker.name).tag(Optional(marker.id))
                    }
                }
            }
            if let marker = session.project.showMarkers.first(where: { $0.id == session.selectedMarkerID }) {
                markerFields(marker)
            }
            HStack {
                Button("Suggest Beats") {
                    guard let song = session.project.song else { return }
                    let existing = session.project.showMarkers
                    let suggestions = ShowMarker.suggestedBeats(peaks: session.songPeaks, duration: song.duration)
                        .filter { candidate in !existing.contains { $0.kind == .beat && abs($0.time - candidate.time) < 0.1 } }
                    session.setShowMarkers(existing + suggestions)
                }.disabled(session.songPeaks.isEmpty)
                Button(importing ? "Hide Import" : "Paste Markers…") { importing.toggle() }
            }
            if importing {
                Text("One marker per line. Separate seconds, kind, and name with tabs.")
                    .font(.caption).foregroundStyle(.secondary)
                TextEditor(text: $importText).font(.system(.caption, design: .monospaced)).frame(height: 82)
                    .accessibilityLabel("Tab-separated marker rows")
                Button("Import Rows") {
                    do {
                        guard importText.utf8.count <= 512 * 1024 else {
                            throw ProjectFileError.invalid("Marker import is too large.")
                        }
                        let imported = try ShowMarker.importRows(importText)
                        session.setShowMarkers(session.project.showMarkers + imported)
                        if session.markerMessage == nil { importText = ""; importing = false }
                    } catch { session.markerMessage = error.localizedDescription }
                }
            }
            if let message = session.markerMessage { Text(message).font(.caption).foregroundStyle(.orange) }
        }.padding(14).frame(width: 350)
    }

    private func markerFields(_ marker: ShowMarker) -> some View {
        VStack(alignment: .leading) {
            TextField("Name", text: binding(marker, \.name))
            HStack {
                TextField("Seconds", value: binding(marker, \.time), format: .number.precision(.fractionLength(0...3)))
                Picker("Kind", selection: binding(marker, \.kind)) {
                    ForEach(ShowMarkerKind.allCases) { Text($0.rawValue).tag($0) }
                }.fixedSize()
            }
            if marker.kind == .beat {
                Toggle("Downbeat (start of bar)", isOn: Binding(get: { marker.downbeat == true }, set: {
                    var edited = marker
                    edited.downbeat = $0
                    session.putShowMarker(edited)
                }))
            }
            HStack {
                Button("Jump") { session.jumpToShowMarker(marker) }
                Button("Delete", role: .destructive) {
                    session.setShowMarkers(session.project.showMarkers.filter { $0.id != marker.id })
                    session.selectedMarkerID = nil
                }
            }
        }
    }

    private func binding<T>(_ marker: ShowMarker, _ key: WritableKeyPath<ShowMarker, T>) -> Binding<T> {
        Binding(get: { marker[keyPath: key] }, set: {
            var edited = marker
            edited[keyPath: key] = $0
            session.putShowMarker(edited)
        })
    }
}

struct ManualCueList: View {
    @Bindable var session: EditorSession
    var edit: ((LightingCue) -> Void)? = nil

    var body: some View {
        let cues = session.manualCueList
        VStack(alignment: .leading, spacing: 10) {
            Text("Manual Lighting Cues").font(.headline)
            Picker("Next cue", selection: $session.nextManualCueID) {
                Text(session.lastManualCueID == nil ? "First Cue" : "End of List").tag(UUID?.none)
                ForEach(cues) { cue in
                    Text(cue.name + (cue.isManual ? " · Manual only" : "")).tag(Optional(cue.id))
                }
            }
            HStack {
                Button("GO") { session.goManualCue() }.buttonStyle(.borderedProminent)
                    .disabled(session.songAudioOnly || cues.isEmpty ||
                              (session.nextManualCueID == nil && session.lastManualCueID != nil))
                Button("Release to Timeline") {
                    session.resetManualCues()
                    session.refreshLighting()
                }
                Button("Stop Fixtures") {
                    session.stopManualFixtures()
                }
            }
            if let edit, let cue = cues.first(where: { $0.id == session.nextManualCueID }) ?? (session.lastManualCueID == nil ? cues.first : nil) {
                Button("Edit Next Cue") { edit(cue) }
            }
        }.padding(14).frame(width: 360)
    }
}

struct BeatQueueMenu: View {
    let session: EditorSession
    var body: some View {
        Menu {
            ForEach(BeatBoundary.allCases) { boundary in
                Button("GO · " + boundary.rawValue) { session.queueBeat(boundary) }
                if !session.project.lighting.looks.isEmpty {
                    Menu("Lighting Look · " + boundary.rawValue) {
                        ForEach(session.project.lighting.looks) { look in
                            Button(look.name) { session.queueBeat(boundary, lookID: look.id) }
                        }
                    }
                }
            }
            if session.queuedBeat != nil { Button("Cancel Queue") { session.cancelBeatQueue() } }
            if let message = session.beatMessage { Text(message) }
        } label: {
            Label(session.queuedBeat == nil ? "Beat Queue" : "Cue Queued", systemImage: "metronome")
        }
    }
}

struct ClipTransitionEditor: View {
    let session: EditorSession
    let clip: EffectClip
    @State private var duration = 0.5
    @State private var curve = CueCurve.linear

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Fade from Previous Clip").font(.headline)
            TextField("Seconds", value: $duration, format: .number.precision(.fractionLength(0...3)))
            Picker("Curve", selection: $curve) {
                Text("Linear").tag(CueCurve.linear)
                Text("Ease In/Out").tag(CueCurve.eased)
            }
            HStack {
                Button("Cut") { session.setClipTransition(clip, duration: 0, curve: curve) }
                Button("Apply Fade") { session.setClipTransition(clip, duration: duration, curve: curve) }
                    .buttonStyle(.borderedProminent)
            }
            if let message = session.timelineMessage { Text(message).font(.caption).foregroundStyle(.orange) }
        }
        .padding(14).frame(width: 290)
        .onAppear { duration = clip.transition ?? 0.5; curve = clip.transitionCurve ?? .linear }
    }
}

private struct ChoreographyEditor: View {
    let session: EditorSession
    let existingID: UUID?
    let playhead: Double
    @State private var draft = ChoreographyClip()
    @State private var targetID: UUID?
    @Environment(\.dismiss) private var dismiss

    private var candidates: [(id: UUID, name: String)] {
        if draft.kind == .fixture { return session.project.lighting.fixtures.map { ($0.id, $0.name) } }
        return session.project.baseTimelineTracks.map { ($0.id, $0.name) }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 9) {
                Text(existingID == nil ? "New Choreography Clip" : "Edit Choreography Clip").font(.headline)
                TextField("Name", text: $draft.name)
                HStack {
                    Picker("Targets", selection: $draft.kind) {
                        ForEach(ChoreographyTargetKind.allCases) { Text($0.rawValue).tag($0) }
                    }.disabled(!draft.targets.isEmpty)
                    Picker("Pattern", selection: $draft.pattern) {
                        ForEach(ChoreographyPattern.allCases) { Text($0.rawValue).tag($0) }
                    }
                }
                HStack {
                    Text("Start (s)")
                    TextField("Start", value: $draft.start, format: .number).frame(width: 72)
                    Text("Step (s)")
                    TextField("Interval", value: $draft.interval, format: .number).frame(width: 65)
                    Text("Repeats")
                    TextField("Repeats", value: $draft.repeats, format: .number).frame(width: 45)
                }
                targetPicker
                ForEach($draft.targets) { $target in
                    targetRow($target)
                }
                if draft.pattern == .wave { waveDiagram }
                Menu("Colors") {
                    Button("Red and Green") { draft.colors = [SIMD4(1,0,0,1), SIMD4(0,1,0,1)] }
                    Button("Blue and White") { draft.colors = [SIMD4(0,0,1,1), SIMD4(1,1,1,1)] }
                    ForEach(session.project.palettes.filter { !$0.slots.isEmpty }) { palette in
                        Button(palette.name) { draft.colors = Array(palette.slots.prefix(16).map(\.color)) }
                    }
                }
                HStack {
                    if let existingID {
                        Button("Delete", role: .destructive) {
                            if session.setChoreography(session.project.choreographyClips.filter { $0.id != existingID }) { dismiss() }
                        }
                    }
                    Spacer()
                    Button("Save Clip") {
                        var clips = session.project.choreographyClips
                        if let i = clips.firstIndex(where: { $0.id == existingID }) { clips[i] = draft }
                        else { clips.append(draft) }
                        if session.setChoreography(clips) { dismiss() }
                    }.buttonStyle(.borderedProminent).disabled(!draft.isValid)
                }
                if let message = session.timelineMessage { Text(message).font(.caption).foregroundStyle(.orange) }
            }.padding(14)
        }.frame(width: 480, height: 440)
            .onAppear {
                if let original = session.project.choreographyClips.first(where: { $0.id == existingID }) { draft = original }
                else { draft.start = min(3599, max(0, playhead)) }
            }
    }

    private var targetPicker: some View {
        HStack {
            Picker("Add target", selection: $targetID) {
                Text("Choose target").tag(UUID?.none)
                ForEach(candidates.filter { choice in !draft.targets.contains { $0.id == choice.id } }, id: \.id) { choice in
                    Text(choice.name).tag(Optional(choice.id))
                }
            }
            Button("Add") {
                guard let targetID, candidates.contains(where: { $0.id == targetID }),
                      !draft.targets.contains(where: { $0.id == targetID }) else { return }
                let x = min(0.95, 0.1 + Double(draft.targets.count) * 0.15)
                draft.targets.append(ChoreographyTarget(id: targetID, position: .init(x: x, y: 0.5)))
                self.targetID = nil
            }.disabled(targetID == nil || draft.targets.count >= 128)
        }
    }

    private func targetRow(_ target: Binding<ChoreographyTarget>) -> some View {
        let id = target.wrappedValue.id
        let name = candidates.first(where: { $0.id == id })?.name
        return HStack {
            Text(name ?? "Missing target").foregroundStyle(name == nil ? .orange : .primary)
            Spacer()
            if draft.pattern == .wave {
                TextField("X", value: target.position.x, format: .number).frame(width: 45).accessibilityLabel("X")
                TextField("Y", value: target.position.y, format: .number).frame(width: 45).accessibilityLabel("Y")
            }
            Button {
                if let index = draft.targets.firstIndex(where: { $0.id == id }), index > 0 {
                    draft.targets.swapAt(index, index - 1)
                }
            } label: { Image(systemName: "arrow.up") }.accessibilityLabel("Move target earlier")
            Button(role: .destructive) { draft.targets.removeAll { $0.id == id } }
                label: { Image(systemName: "minus.circle") }.accessibilityLabel("Remove target")
        }
    }

    private var waveDiagram: some View {
        VStack(alignment: .leading, spacing: 4) {
            TextField("Direction (degrees)", value: $draft.angle, format: .number)
            Canvas { context, size in
                for (index, target) in draft.targets.enumerated() where target.position.isValid {
                    let point = CGPoint(x: 10 + target.position.x * (size.width - 20),
                                        y: 10 + target.position.y * (size.height - 20))
                    context.draw(Text(String(index + 1)).font(.caption).foregroundStyle(Color.mint), at: point)
                }
            }.frame(height: 80).background(.black.opacity(0.25), in: RoundedRectangle(cornerRadius: 5))
                .accessibilityLabel("Authored wave layout")
        }
    }
}
