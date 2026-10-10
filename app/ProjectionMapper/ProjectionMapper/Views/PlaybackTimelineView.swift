import SwiftUI

/// Timeline controls and selection are runtime state; clips belong to the saved project.
struct PlaybackTimelineView: View {
    @Bindable var session: EditorSession
    @State private var pixelsPerSecond = 24.0
    @State private var snap = true
    @State private var follow = true
    private let laneHeight = 44.0
    private var tracks: [TimelineTrack] { session.project.timelineTracks }
    private var tickStep: Int { pixelsPerSecond >= 32 ? 1 : pixelsPerSecond >= 12 ? 5 : 10 }

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30, paused: !session.transport.isPlaying)) { _ in
            let time = session.transport.elapsed(at: ProcessInfo.processInfo.systemUptime)
            let horizon = min(3600.0, max(60, (max(time, session.project.timelineClips.map(\.end).max() ?? 0) / 30).rounded(.up) * 30 + 30))
            VStack(spacing: 0) {
                transportBar(time: time)
                Divider()
                ScrollView(.vertical) {
                    HStack(alignment: .top, spacing: 0) {
                        VStack(spacing: 0) {
                            Text("OBJECT / EFFECT").font(.caption2.weight(.semibold)).foregroundStyle(.secondary)
                                .frame(height: 28)
                            ForEach(tracks) { track in trackHeader(track) }
                        }.frame(width: 180)
                        Divider()
                        ScrollViewReader { proxy in
                            ScrollView(.horizontal) {
                                VStack(spacing: 0) {
                                    ruler(horizon: horizon)
                                    ForEach(tracks) { track in lane(track, time: time, horizon: horizon) }
                                }
                                .frame(width: horizon * pixelsPerSecond, alignment: .leading)
                                .overlay(alignment: .topLeading) {
                                    Rectangle().fill(Color.orange).frame(width: 2)
                                        .overlay(alignment: .top) {
                                            Image(systemName: "arrowtriangle.down.fill").font(.caption).foregroundStyle(.orange).offset(y: -1)
                                        }
                                        .offset(x: min(horizon, time) * pixelsPerSecond)
                                        .allowsHitTesting(false)
                                }
                            }
                            .onChange(of: Int(time / Double(tickStep))) { _, tick in
                                if follow && session.transport.isPlaying { proxy.scrollTo(tick * tickStep, anchor: .center) }
                            }
                        }
                    }
                }
                Divider()
                clipEditor
            }
            .background(Color(nsColor: .controlBackgroundColor))
        }
    }

    private func transportBar(time: Double) -> some View {
        HStack(spacing: 12) {
            Text("TIMELINE").font(.caption.weight(.bold)).foregroundStyle(.secondary)
            Button { session.setPlaying(false); session.restartPlayback() } label: { Image(systemName: "backward.end.fill") }
                .help("Stop and return to the beginning").accessibilityLabel("Stop and return to beginning")
            Button { session.seekPlayback(to: max(0, min(3600, time - 1))) } label: { Image(systemName: "backward.frame.fill") }
                .help("Back one second").accessibilityLabel("Back one second")
            Button { session.setPlaying(!session.transport.isPlaying) } label: {
                Image(systemName: session.transport.isPlaying ? "pause.fill" : "play.fill").frame(width: 20)
            }.buttonStyle(.borderedProminent).accessibilityLabel(session.transport.isPlaying ? "Pause playback" : "Play playback")
            Button { session.seekPlayback(to: min(3600, time + 1)) } label: { Image(systemName: "forward.frame.fill") }
                .help("Forward one second").accessibilityLabel("Forward one second")
            Text(timecode(time)).font(.system(.body, design: .monospaced).weight(.semibold)).foregroundStyle(.orange)
                .frame(width: 94).accessibilityLabel("Playhead " + timecode(time))
            Picker("Speed", selection: Binding(get: { session.transport.speed }, set: { session.setPlaybackSpeed($0) })) {
                ForEach([0.25, 0.5, 1.0, 2.0, 4.0], id: \.self) { Text($0.formatted() + "×").tag($0) }
            }.labelsHidden().frame(width: 70).help("Playback speed")
            Spacer(minLength: 0)
            Toggle("Snap", isOn: $snap).toggleStyle(.checkbox).help("Snap clip edits to whole seconds")
            Toggle("Follow", isOn: $follow).toggleStyle(.checkbox).help("Scroll to follow the playhead")
            Image(systemName: "minus.magnifyingglass").foregroundStyle(.secondary)
            Slider(value: $pixelsPerSecond, in: 4...80).frame(width: 90).accessibilityLabel("Timeline zoom")
            Image(systemName: "plus.magnifyingglass").foregroundStyle(.secondary)
        }.buttonStyle(.borderless).padding(.horizontal, 12).padding(.vertical, 7)
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
                .buttonStyle(.borderless).help("Add current effect at playhead").accessibilityLabel("Add effect for " + track.name)
        }
        .padding(.horizontal, 10).frame(height: laneHeight)
        .background(session.selectedSource?.id == track.id ? Color.purple.opacity(0.15) : Color.clear)
        .overlay(alignment: .bottom) { Divider() }
    }

    private func ruler(horizon: Double) -> some View {
        ZStack(alignment: .topLeading) {
            Color(nsColor: .windowBackgroundColor)
            ForEach(Array(stride(from: 0, through: Int(horizon), by: tickStep)), id: \.self) { tick in
                VStack(alignment: .leading, spacing: 2) {
                    Text(timecode(Double(tick))).font(.system(size: 9, design: .monospaced)).foregroundStyle(.secondary)
                    Rectangle().fill(Color.secondary).frame(width: 1, height: 7)
                }.offset(x: Double(tick) * pixelsPerSecond + 2).id(tick)
            }
        }.frame(height: 28).contentShape(Rectangle())
            .gesture(DragGesture(minimumDistance: 0).onChanged { value in
                session.setPlaying(false)
                session.seekPlayback(to: min(3600, max(0, value.location.x / pixelsPerSecond)))
            })
            .help("Click or drag to scrub playback")
    }

    private func lane(_ track: TimelineTrack, time: Double, horizon: Double) -> some View {
        let clips = session.project.timelineClips.filter { $0.sourceID == track.id }
        return ZStack(alignment: .leading) {
            Color.black.opacity(0.14)
            ForEach(Array(stride(from: 0, through: Int(horizon), by: tickStep)), id: \.self) { tick in
                Rectangle().fill(Color.white.opacity(0.07)).frame(width: 1).offset(x: Double(tick) * pixelsPerSecond)
            }
            if clips.isEmpty {
                HStack {
                    Image(systemName: "infinity")
                    Text(track.source.content.title + " · Live content").font(.caption)
                }.foregroundStyle(.secondary).padding(.horizontal, 12)
                    .frame(width: horizon * pixelsPerSecond, height: 30, alignment: .leading)
                    .background(Color.purple.opacity(0.08)).allowsHitTesting(false)
            }
            ForEach(clips) { clip in
                TimelineClipBlock(clip: clip, selected: session.selectedClipID == clip.id, active: clip.contains(time),
                    pixelsPerSecond: pixelsPerSecond, snap: snap,
                    poster: session.videoPosters[clip.source.video?.assetID ?? UUID()],
                    select: { session.selectedClipID = clip.id; session.selectTimelineTrack(track) },
                    commit: { _ = session.updateTimelineClip($0) })
                    .offset(x: clip.start * pixelsPerSecond)
                    .contextMenu {
                        Button("Capture Current Content") { session.captureTimelineClip(clip.id) }
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
                Text("CLIP").font(.caption.weight(.bold)).foregroundStyle(.secondary)
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
                Button("Capture Current") { session.captureTimelineClip(clip.id) }.help("Copy content settings and colors from this track's editor into the clip")
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
            Text("+ adds the current effect at the playhead · Double-click a row to add · Drag clips to move; drag their edges to trim")
                .font(.caption).foregroundStyle(.secondary).frame(maxWidth: .infinity, alignment: .leading).padding(8)
        }
        if let message = session.timelineMessage {
            Text(message).font(.caption).foregroundStyle(.orange).frame(maxWidth: .infinity, alignment: .leading).padding(.horizontal, 8).padding(.bottom, 5)
        }
    }
    private func snapped(_ time: Double) -> Double { snap ? time.rounded() : time }
    private func timecode(_ time: Double) -> String {
        let centiseconds = Int(max(0, min(360000, time * 100)))
        return String(format: "%02d:%02d.%02d", centiseconds / 6000, (centiseconds / 100) % 60, centiseconds % 100)
    }
}

private struct TimelineClipBlock: View {
    let clip: EffectClip
    let selected: Bool
    let active: Bool
    let pixelsPerSecond: Double
    let snap: Bool
    let poster: ImagePixels?
    let select: () -> Void
    let commit: (EffectClip) -> Void
    @State private var draft: EffectClip?
    private var displayed: EffectClip { draft ?? clip }

    private var blockContent: some View {
        HStack(spacing: 0) {
            trimHandle(leading: true)
            if clip.source.content == .video, clip.duration*pixelsPerSecond > 90 { VideoPoster(pixels: poster).frame(width: 36,height: 28).allowsHitTesting(false) }
            VStack(alignment: .leading, spacing: 2) {
                Text(clip.source.content.title).font(.caption.weight(.semibold)).lineLimit(1)
                Text("\(displayed.duration.formatted(.number.precision(.fractionLength(0...1))))s")
                    .font(.system(size: 9, design: .monospaced)).foregroundStyle(.white.opacity(0.7))
            }.padding(.horizontal, 4).frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle()).onTapGesture(perform: select)
                .gesture(drag(mode: 0))
            trimHandle(leading: false)
        }
    }
    var body: some View {
        blockContent
        .frame(width: max(12, displayed.duration * pixelsPerSecond), height: 34)
        .background(RoundedRectangle(cornerRadius: 5).fill(active ? Color.purple : Color.indigo.opacity(0.75)))
        .overlay { RoundedRectangle(cornerRadius: 5).stroke(selected ? Color.orange : Color.white.opacity(0.2), lineWidth: selected ? 2 : 1) }
        .offset(x: ((draft?.start ?? clip.start) - clip.start) * pixelsPerSecond)
        .help("\(clip.source.content.title): \(clip.start.formatted())–\(clip.end.formatted()) seconds")
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
