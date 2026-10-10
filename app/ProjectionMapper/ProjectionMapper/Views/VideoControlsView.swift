import SwiftUI

struct VideoRangeControls: View {
    let content: VideoContent
    let duration: Double
    let apply: (VideoContent) -> Void
    private func edit(_ body: (inout VideoContent)->Void) { var copy = content; body(&copy); apply(copy) }
    var body: some View {
        VStack(alignment: .leading,spacing: 8) {
            HStack {
                Text("Source In / Out").font(.caption)
                TextField("In",value: Binding(get: { content.inPoint },set: { value in edit { $0.inPoint = value; $0.loopOffset = nil } }),format: .number.precision(.fractionLength(0...3)))
                    .accessibilityLabel("Video source in point in seconds")
                TextField("Out",value: Binding(get: { content.outPoint },set: { value in edit { $0.outPoint = value; $0.loopOffset = nil } }),format: .number.precision(.fractionLength(0...3)))
                    .accessibilityLabel("Video source out point in seconds")
            }.textFieldStyle(.roundedBorder)
            HStack {
                Picker("Source speed",selection: Binding(get: { content.rate },set: { value in edit { $0.rate = value } })) {
                    ForEach([0.25,0.5,1.0,2.0,4.0],id: \.self) { Text($0.formatted()+"×").tag($0) }
                }
                Toggle("Loop",isOn: Binding(get: { content.loops },set: { value in edit { $0.loops = value; $0.loopOffset = nil } }))
                Toggle("Mute",isOn: Binding(get: { content.isMuted },set: { value in edit { $0.isMuted = value } }))
            }
            if content.loops, let phase = content.loopOffset { Text("Loop phase: " + phase.formatted() + " s").font(.caption).foregroundStyle(.secondary) }
            Picker("Placement",selection: Binding(get: { content.placement },set: { value in edit { $0.placement = value } })) {
                ForEach(ImagePlacement.allCases) { Text($0.title).tag($0) }
            }
            HStack {
                Text("Canvas aspect")
                TextField("Width / height",value: Binding(get: { Double(content.canvasAspect) },set: { value in edit { $0.canvasAspect = Float(value) } }),format: .number.precision(.fractionLength(0...3)))
            }.textFieldStyle(.roundedBorder).font(.caption)
            Text("Source \(duration.formatted(.number.precision(.fractionLength(0...2)))) s · Moving keeps footage; trimming changes its source range.")
                .font(.caption).foregroundStyle(.secondary)
        }
    }
}
struct VideoContentControls: View {
    let session: EditorSession
    var body: some View {
        if let source = session.selectedSource {
            VStack(alignment: .leading,spacing: 8) {
                Button("Import video…") { session.chooseVideo(target: .owner(source.id)) }.disabled(session.isImportingVideo)
                if let face = session.selectedSurface, face.layout.objectID != nil {
                    Button("Detach and import video on this face…") { session.chooseVideo(target: .detach(face.id)) }.disabled(session.isImportingVideo)
                }
                if source.content == .video, let video = source.video,
                   let asset = session.project.videoAssets.first(where: { $0.id == video.assetID }) {
                    VideoPoster(pixels: session.videoPosters[asset.id]).frame(height: 90)
                    Text(asset.name).font(.caption.weight(.semibold)).lineLimit(2)
                    Text("\(asset.codec) · \(asset.width)×\(asset.height) · \(asset.hasAudio ? "Contains audio" : "Silent video")")
                        .font(.caption).foregroundStyle(.secondary)
                    VideoRangeControls(content: video,duration: asset.duration,apply: session.setSelectedVideo)
                    HStack {
                        Button("Relink video…") { session.chooseVideo(target: .relink(asset.id)) }
                        Button("Remove video") { session.removeSelectedVideo() }
                    }
                    if !session.project.timelineClips.contains(where: { $0.sourceID == source.id }) {
                        HStack {
                            Button(session.selectedPlayback.isPaused ? "Resume owner" : "Pause owner") { session.setSelectedPaused(!session.selectedPlayback.isPaused) }
                            Button("Restart owner") { session.restartSelectedPlayback() }
                        }
                    }
                    if let problem = session.videoProblems[asset.id] ?? session.videoPlayback.problems[source.id] {
                        Text(problem).font(.caption).foregroundStyle(.orange)
                    }
                    Text("Use + in this object's timeline row to add the video. Audio also requires Enable Audio in Show.").font(.caption).foregroundStyle(.secondary)
                }
                if session.isImportingVideo {
                    ProgressView("Copying and inspecting video…").controlSize(.small)
                    Button("Cancel import") { session.cancelVideoImport() }
                }
            }
        }
    }
}
struct VideoPoster: View {
    let pixels: ImagePixels?
    var body: some View {
        if let image = pixels?.cgImage { Image(decorative: image,scale: 1).resizable().scaledToFit() }
        else { Image(systemName: "film").foregroundStyle(.secondary) }
    }
}
struct VideoAudioControls: View {
    let session: EditorSession
    @State private var devices: [AudioOutputDevice] = []
    var body: some View {
        DisclosureGroup("Video audio") {
            VStack(alignment: .leading,spacing: 8) {
                Toggle("Enable Audio",isOn: Binding(get: { session.videoAudioEnabled },set: session.enableVideoAudio))
                Slider(value: Binding(get: { Double(session.project.videoAudio.volume) },set: { value in
                    var settings = session.project.videoAudio; settings.volume = Float(value); session.setVideoAudio(settings)
                }),in: 0...1).accessibilityLabel("Master video audio volume")
                Picker("Output device",selection: Binding(get: { session.project.videoAudio.deviceUID },set: { value in
                    var settings = session.project.videoAudio; settings.deviceUID = value; session.setVideoAudio(settings)
                })) {
                    Text("System default").tag(Optional<String>.none)
                    ForEach(devices) { Text($0.name).tag(Optional($0.id)) }
                    if let uid = session.project.videoAudio.deviceUID, !devices.contains(where: { $0.id == uid }) {
                        Text("Unavailable saved device").tag(Optional(uid))
                    }
                }
                Button("Refresh devices") { devices = VideoAudioDevices.outputs() }
                Text("Muted on open. Unmute a video/clip and enable audio to hear it. Scrubbing is silent; visual blackout keeps audio. Audio supports 0.5×–2× effective speed.")
                    .font(.caption).foregroundStyle(.secondary)
            }.padding(.top,8)
        }.onAppear { devices = VideoAudioDevices.outputs() }
    }
}
