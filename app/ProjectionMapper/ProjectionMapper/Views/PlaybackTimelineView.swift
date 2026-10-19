import SwiftUI

/// Timeline controls and selection are runtime state; clips belong to the saved project.
struct PlaybackTimelineView: View {
    @Bindable var session: EditorSession
    @State private var pixelsPerSecond = 24.0
    @State private var snap = true
    @State private var follow = true
    @State private var viewportWidth = 720.0
    @State private var playbackExtent = 0.0
    @State private var requestedTime = 0.0
    @State private var scrollRequest = 0
    private let laneHeight = 44.0
    private let rulerHeight = 28.0
    private var tickStep: Int { TimelinePresentation.tickStep(pixelsPerSecond: pixelsPerSecond) }
    private var anchorStep: Int { max(1, Int(ceil(60 / pixelsPerSecond))) }

    var body: some View {
        // These collections and the clip editor stay outside the playback animation.
        // Only the transport readout and lightweight overlay redraw at clock cadence.
        let tracks = session.project.timelineTracks
        let clipsByTrack = Dictionary(grouping: session.project.timelineClips, by: \.sourceID)
        let time = session.transport.elapsed(at: ProcessInfo.processInfo.systemUptime)
        let contentEnd = session.project.timelineClips.map(\.end).max() ?? 0
        let horizon = TimelinePresentation.horizon(contentEnd: contentEnd, playhead: max(time, playbackExtent),
            visibleDuration: viewportWidth / pixelsPerSecond)
        VStack(spacing: 0) {
            ScrollView(.horizontal) { transportBar(contentEnd: contentEnd) }.scrollIndicators(.hidden)
            Divider()
            ScrollView(.vertical) {
                HStack(alignment: .top, spacing: 0) {
                    VStack(spacing: 0) {
                        HStack {
                            Text("TRACKS").font(.caption2.weight(.semibold))
                            Spacer()
                            Text("\(tracks.count)").monospacedDigit()
                        }.foregroundStyle(.secondary).padding(.horizontal, 10).frame(height: rulerHeight)
                        ForEach(tracks) { track in trackHeader(track) }
                    }.frame(width: 180)
                    Divider()
                    ScrollViewReader { proxy in
                        ScrollView(.horizontal) {
                            VStack(spacing: 0) {
                                ruler(horizon: horizon)
                                VStack(spacing: 0) {
                                    ForEach(tracks) { track in
                                        lane(track, clips: clipsByTrack[track.id] ?? [], horizon: horizon)
                                    }
                                }
                                .background {
                                    TimelineGrid(spacing: Double(tickStep) * pixelsPerSecond)
                                        .stroke(Color.white.opacity(0.07), lineWidth: 1)
                                }
                            }
                            .frame(width: horizon * pixelsPerSecond, alignment: .leading)
                            .overlay(alignment: .topLeading) {
                                // Sparse invisible anchors let Follow work without one view per grid line.
                                HStack(spacing: 0) {
                                    ForEach(Array(stride(from: 0, through: Int(horizon), by: anchorStep)), id: \.self) { tick in
                                        Color.clear.frame(width: 1, height: 1).id(tick)
                                        Color.clear.frame(width: max(0, Double(anchorStep) * pixelsPerSecond - 1), height: 1)
                                    }
                                }
                            }
                            .overlay(alignment: .topLeading) {
                                playbackOverlay(horizon: horizon, tracks: tracks, clipsByTrack: clipsByTrack, proxy: proxy)
                            }
                        }
                        .onGeometryChange(for: Double.self) { $0.size.width } action: { viewportWidth = $0 }
                        .onChange(of: scrollRequest) { _, _ in
                            proxy.scrollTo(Int(min(horizon, requestedTime) / Double(anchorStep)) * anchorStep, anchor: .center)
                        }
                    }
                }
            }
            Divider()
            ScrollView([.horizontal, .vertical]) {
                VStack(alignment: .leading, spacing: 0) { clipEditor }
            }
            .frame(maxHeight: session.selectedClip?.source.content == .video ? 128 : session.selectedClip == nil ? 36 : 68)
            .scrollIndicators(.automatic)
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
        case .zoomIn: pixelsPerSecond = min(80, pixelsPerSecond * 1.5)
        case .zoomOut: pixelsPerSecond = max(0.1, pixelsPerSecond / 1.5)
        case .fit:
            pixelsPerSecond = TimelinePresentation.fitScale(contentEnd: session.project.timelineClips.map(\.end).max() ?? 0, viewportWidth: viewportWidth)
        case .snap: snap.toggle()
        case .follow: follow.toggle()
        case .playhead: break
        }
        requestedTime = request.action == .fit ? 0 : session.transport.elapsed(at: ProcessInfo.processInfo.systemUptime)
        scrollRequest += 1
    }

    private func transportBar(contentEnd: Double) -> some View {
        HStack(spacing: 10) {
            Label("Timeline", systemImage: "film.stack").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
            TimelineTransportControls(session: session)
            Divider().frame(height: 18)
            Spacer(minLength: 0)
            Toggle("Snap", isOn: $snap).toggleStyle(.checkbox).help("Snap clip edits to whole seconds (Option-Command-S)")
            Toggle("Follow", isOn: $follow).toggleStyle(.checkbox).help("Scroll to follow the playhead (Option-Command-F)")
            Image(systemName: "minus.magnifyingglass").foregroundStyle(.secondary)
            Slider(value: Binding(get: { log2(pixelsPerSecond) }, set: { pixelsPerSecond = pow(2, $0) }), in: log2(0.1)...log2(80))
                .frame(width: 76).accessibilityLabel("Timeline zoom")
            Image(systemName: "plus.magnifyingglass").foregroundStyle(.secondary)
            Button("Fit") {
                pixelsPerSecond = TimelinePresentation.fitScale(contentEnd: contentEnd, viewportWidth: viewportWidth)
                requestedTime = 0; scrollRequest += 1
            }.help("Fit the complete sequence in the visible timeline (Command-0)")
            Button { requestedTime = session.transport.elapsed(at: ProcessInfo.processInfo.systemUptime); scrollRequest += 1 } label: {
                Label("Playhead", systemImage: "scope")
            }.help("Scroll to the current playback position (Shift-Command-P)")
        }.buttonStyle(.borderless).controlSize(.small).padding(.horizontal, 10).padding(.vertical, 7)
    }

    private func playbackOverlay(horizon: Double, tracks: [TimelineTrack], clipsByTrack: [UUID: [EffectClip]], proxy: ScrollViewProxy) -> some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30, paused: !session.transport.isPlaying)) { _ in
            let time = session.transport.elapsed(at: ProcessInfo.processInfo.systemUptime)
            ZStack(alignment: .topLeading) {
                Path { path in
                    for (index, track) in tracks.enumerated() {
                        guard let clip = clipsByTrack[track.id]?.first(where: { $0.contains(time) }) else { continue }
                        let y = rulerHeight + Double(index) * laneHeight + 6
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
            .onChange(of: Int(time / Double(anchorStep))) { _, tick in
                if follow && session.transport.isPlaying { proxy.scrollTo(min(Int(horizon), tick * anchorStep), anchor: .center) }
            }
            .onChange(of: Int(time / 30)) { _, _ in playbackExtent = time }
        }
    }

    private func trackHeader(_ track: TimelineTrack) -> some View {
        HStack(spacing: 7) {
            Button { session.selectTimelineTrack(track); session.selectedClipID = nil } label: {
                HStack(spacing: 7) {
                    Image(systemName: track.isVisible ? (track.isObject ? "cube" : "square") : "eye.slash")
                    VStack(alignment: .leading, spacing: 1) {
                        Text(track.name).font(.caption.weight(.semibold)).lineLimit(1)
                        Text(track.isObject ? "\(track.faceCount) connected faces" : "Standalone face")
                            .font(.system(size: 9)).foregroundStyle(.secondary)
                    }
                    Spacer(minLength: 0)
                }.contentShape(Rectangle())
            }.buttonStyle(.plain).help("Select " + track.name)
            Button {
                let time = snapped(min(3595, session.transport.elapsed(at: ProcessInfo.processInfo.systemUptime)))
                session.addTimelineClip(sourceID: track.id, at: time)
            } label: { Image(systemName: "plus.circle") }
                .buttonStyle(.borderless).help("Add current content at playhead").accessibilityLabel("Add clip for " + track.name)
        }
        .padding(.horizontal, 10).frame(height: laneHeight)
        .background(session.selectedSource?.id == track.id ? Color.accentColor.opacity(0.15) : Color.clear)
        .overlay(alignment: .bottom) { Divider() }
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
            Color.black.opacity(session.selectedSource?.id == track.id ? 0.06 : 0.16)
            if clips.isEmpty {
                HStack {
                    Image(systemName: "infinity")
                    Text(track.source.content.title + " · Live content").font(.caption)
                    Text("Add a clip to sequence this track").font(.caption2).foregroundStyle(.tertiary)
                }.foregroundStyle(.secondary).padding(.horizontal, 12)
                    .frame(width: horizon * pixelsPerSecond, height: 30, alignment: .leading)
                    .background(Color.accentColor.opacity(0.06)).allowsHitTesting(false)
            }
            ForEach(clips) { clip in
                TimelineClipBlock(clip: clip, selected: session.selectedClipID == clip.id,
                    pixelsPerSecond: pixelsPerSecond, snap: snap,
                    poster: clip.source.video.flatMap { session.videoPosters[$0.assetID] },
                    select: { session.selectedClipID = clip.id; session.selectTimelineTrack(track) },
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
                session.addTimelineClip(sourceID: track.id, at: snapped(min(3595, max(0, value.location.x / pixelsPerSecond))))
            })
            .overlay(alignment: .bottom) { Divider() }
    }

    @ViewBuilder private var clipEditor: some View {
        if let clip = session.selectedClip {
            HStack(spacing: 10) {
                Label("Selected clip", systemImage: "film").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                Picker("Effect", selection: Binding(get: { clip.source.content }, set: { content in
                    var copy = clip; copy.source.content = content; _ = session.updateTimelineClip(copy)
                })) {
                    ForEach(SurfaceContent.allCases.filter { ($0 != .image || clip.source.image != nil) && ($0 != .video || clip.source.video != nil) }) { Text($0.title).tag($0) }
                }.frame(width: 200)
                Text("Start").font(.caption)
                TextField("Start", value: Binding(get: { clip.start }, set: { value in
                    var copy = clip; copy.start = value; _ = session.updateTimelineClip(copy)
                }), format: .number.precision(.fractionLength(0...2))).frame(width: 64).accessibilityLabel("Clip start in seconds")
                Text("Length").font(.caption)
                TextField("Duration", value: Binding(get: { clip.duration }, set: { value in
                    let copy = clip.trimming(start: clip.start,duration: value); _ = session.updateTimelineClip(copy)
                }), format: .number.precision(.fractionLength(0...2))).frame(width: 64).accessibilityLabel("Clip duration in seconds")
                Text("s").font(.caption).foregroundStyle(.secondary)
                Button("Apply Edited Content", systemImage: "arrow.down.doc") { session.captureTimelineClip(clip.id) }
                    .help("Copy the track's current editor settings and colors into this selected clip")
                Button { session.duplicateTimelineClip(clip.id) } label: { Image(systemName: "plus.square.on.square") }.help("Duplicate after clip").accessibilityLabel("Duplicate clip")
                Button(role: .destructive) { session.deleteTimelineClip(clip.id) } label: { Image(systemName: "trash") }.accessibilityLabel("Delete clip")
                Spacer(minLength: 0)
            }.textFieldStyle(.roundedBorder).padding(8)
            if clip.source.content == .video, let video = clip.source.video,
               let asset = session.project.videoAssets.first(where: { $0.id == video.assetID }) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading,spacing: 4) {
                        VideoPoster(pixels: session.videoPosters[asset.id]).frame(width: 110,height: 70)
                        Text(asset.name).font(.caption).lineLimit(2)
                        Button("Relink video…") { session.chooseVideo(target: .relink(asset.id)) }.disabled(session.isImportingVideo)
                    }
                    VideoRangeControls(content: video,duration: asset.duration) { content in
                        _ = session.updateTimelineClip(clip.replacingVideo(content))
                    }
                }.padding(.horizontal,10).padding(.bottom,8)
                if let problem = session.videoProblems[asset.id] ?? session.videoPlayback.problems[clip.sourceID] {
                    Text(problem).font(.caption).foregroundStyle(.orange).padding(.horizontal,10)
                }
            }
        } else {
            HStack(spacing: 7) {
                Image(systemName: "cursorarrow.and.square.on.square.dashed")
                Text("Select a clip to edit · + adds current content · Drag to move; drag edges to trim")
            }.font(.caption).foregroundStyle(.secondary).frame(maxWidth: .infinity, alignment: .leading).padding(8)
        }
        if let message = session.timelineMessage {
            Text(message).font(.caption).foregroundStyle(.orange).frame(maxWidth: .infinity, alignment: .leading).padding(.horizontal, 8).padding(.bottom, 5)
        }
    }
    private func snapped(_ time: Double) -> Double { snap ? time.rounded() : time }
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
                Button { session.setPlaying(false); session.restartPlayback() } label: { Image(systemName: "stop.fill") }
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
                    Text(TimelinePresentation.timecode(time))
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
    let poster: ImagePixels?
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
                            Text(clip.source.content.title).font(.system(size: 11, weight: .semibold))
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
        .help("\(clip.source.content.title) · \(TimelinePresentation.timecode(clip.start))–\(TimelinePresentation.timecode(clip.end)) · Select to edit; drag to move")
        .accessibilityElement(children: .ignore).accessibilityLabel("\(clip.source.content.title), starts at \(clip.start) seconds, duration \(clip.duration) seconds")
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
            func quantize(_ value: Double) -> Double { snap ? value.rounded() : value }
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
