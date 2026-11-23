import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct ShowDeliveryView: View {
    let session: EditorSession
    let action: ShowDeliveryAction
    @Environment(\.dismiss) private var dismiss
    @State private var options: VideoExportOptions
    @State private var job: Task<Void, Never>?
    @State private var choosing = false
    @State private var progress = 0.0
    @State private var status = ""
    @State private var failure: String?
    @State private var saved: URL?

    init(session: EditorSession, action: ShowDeliveryAction) {
        self.session = session
        self.action = action
        let size = session.output.testResolution.size
        var options = VideoExportOptions(width: Int(size.width), height: Int(size.height),
                                          end: session.project.timelineContentEnd > 0 ? session.project.timelineContentEnd : 10,
                                          includeSong: session.project.song != nil)
        if let display = session.projectorOutput.activeDisplay ?? session.output.selectedDisplay,
           let width = display.renderWidth, let height = display.renderHeight {
            var candidate = options
            candidate.width = width
            candidate.height = height
            if candidate.issue == nil { options = candidate }
        }
        options.owner = session.selectedSource?.id ?? session.project.exportOwners.first?.id
        _options = State(initialValue: options)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label(action.title, systemImage: action == .video ? "film" : "folder")
                .font(.title2.weight(.semibold))
            Text(session.project.name).foregroundStyle(.secondary)
                .lineLimit(1)
            Divider()
            if let saved {
                Label("Saved \(saved.lastPathComponent)", systemImage: "checkmark.circle")
                    .lineLimit(2).accessibilityAddTraits(.updatesFrequently)
            } else if job != nil {
                ProgressView(status, value: progress)
                    .accessibilityLabel(action.title)
            } else {
                if action == .video { videoOptions } else { collectionDetails }
                if let issue = failure ?? readiness {
                    Label(issue, systemImage: "exclamationmark.circle").foregroundStyle(.orange)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Divider()
            HStack {
                if let saved {
                    Button("Show in Finder") { NSWorkspace.shared.activateFileViewerSelecting([saved]) }
                    Spacer()
                    Button("Done") { dismiss() }.keyboardShortcut(.defaultAction)
                } else if let job {
                    Spacer()
                    Button("Cancel") {
                        job.cancel()
                        status = "Cancelling…"
                    }
                } else {
                    Spacer()
                    Button("Cancel") { dismiss() }.keyboardShortcut(.cancelAction)
                    Button(action == .video ? "Export…" : "Collect…", action: chooseDestination)
                        .keyboardShortcut(.defaultAction)
                        .disabled(choosing || readiness != nil)
                }
            }
        }
        .padding(22)
        .frame(width: 520)
        .interactiveDismissDisabled(job != nil || choosing)
        .onDisappear { job?.cancel() }
    }

    private var readiness: String? {
        guard action == .video else { return nil }
        if let issue = options.issue { return issue }
        if options.mode == .mapped {
            let scene = session.project.renderScene
            if scene.surfaces.isEmpty || scene.invalidCount > 0 {
                return "Show at least one mapped surface and fix invalid geometry or masks before exporting."
            }
        } else if !session.project.exportOwners.contains(where: { $0.id == options.owner }) {
            return "Choose a face or object to export."
        }
        return nil
    }

    private var videoOptions: some View {
        Grid(alignment: .leading, horizontalSpacing: 14, verticalSpacing: 10) {
            GridRow {
                Text("Output").gridColumnAlignment(.trailing)
                Picker("Output", selection: $options.mode) {
                    ForEach(VideoExportMode.allCases) { Text($0.title).tag($0) }
                }.labelsHidden()
            }
            if options.mode == .canvas {
                GridRow {
                    Text("Content")
                    Picker("Content", selection: $options.owner) {
                        Text("Select a face or object").tag(nil as UUID?)
                        ForEach(session.project.exportOwners) { Text($0.name).tag(Optional($0.id)) }
                    }.labelsHidden()
                }
            }
            GridRow {
                Text("Resolution")
                HStack {
                    TextField("Width", value: $options.width, format: .number.grouping(.never))
                    Text("×").foregroundStyle(.secondary)
                    TextField("Height", value: $options.height, format: .number.grouping(.never))
                    Menu("Presets") {
                        ForEach(TestResolution.allCases) { preset in
                            Button(preset.label) {
                                options.width = Int(preset.size.width)
                                options.height = Int(preset.size.height)
                            }
                        }
                    }.fixedSize()
                }
            }
            GridRow {
                Text("Frame rate")
                Picker("Frame rate", selection: $options.framesPerSecond) {
                    ForEach(VideoExportOptions.frameRates, id: \.self) { fps in
                        Text("\(fps) fps").tag(fps)
                    }
                }.labelsHidden()
            }
            GridRow {
                Text("Time range")
                HStack {
                    TextField("Start", value: $options.start, format: .number.precision(.fractionLength(0...5)))
                    Text("to").foregroundStyle(.secondary)
                    TextField("End", value: $options.end, format: .number.precision(.fractionLength(0...5)))
                    Text("sec").foregroundStyle(.secondary)
                }
            }
            GridRow {
                Text("Audio")
                Toggle("Include project song", isOn: $options.includeSong)
                    .disabled(session.project.song == nil)
            }
            GridRow {
                Color.clear.frame(width: 0, height: 0)
                if options.issue == nil {
                    Text("MP4 · H.264 · \(options.frameCount) frames · about \(sizeLabel(options.estimatedBytes))")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
        }
        .disabled(choosing)
    }

    private var collectionDetails: some View {
        let project = session.project
        return VStack(alignment: .leading, spacing: 8) {
            Text("Save an editable show package with its images, videos, soundtrack, reference photo, and programming.")
            Text("\(project.imageAssets.count) images · \(project.videoAssets.count) videos · \(project.song == nil ? "No soundtrack" : "1 soundtrack")")
                .font(.subheadline)
            Text("Allow about \(sizeLabel(Int64(DeliverySnapshot.mediaBytes(for: project)))) for media. Reconnect fixtures and confirm output settings on another Mac.")
                .font(.caption).foregroundStyle(.secondary)
            if project.visualTracks.contains(where: { $0.kind == .text && !$0.text.font.isEmpty }) {
                Text("Install the fonts used by your text layers on the other Mac to keep their appearance.")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }.fixedSize(horizontal: false, vertical: true)
    }

    private func sizeLabel(_ bytes: Int64) -> String {
        ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
    }

    private func chooseDestination() {
        guard !choosing, job == nil, readiness == nil else { return }
        failure = nil
        choosing = true
        let panel = NSSavePanel()
        panel.title = action.title
        panel.prompt = action == .video ? "Export" : "Collect"
        panel.allowedContentTypes = [action == .video ? .mpeg4Movie : ProjectPackageStore.contentType]
        let base = session.project.name.replacingOccurrences(of: "/", with: "-")
        panel.nameFieldStringValue = action == .video ? "\(base).mp4" : "\(base) - Collected.projectionmap"
        panel.directoryURL = session.documentURL?.deletingLastPathComponent()
        panel.begin { response in
            choosing = false
            guard response == .OK, let destination = panel.url else { return }
            start(destination)
        }
    }

    private func start(_ destination: URL) {
        let requested = options
        status = "Checking show media…"
        progress = 0
        job = Task { @MainActor in
            defer { job = nil }
            do {
                try await session.withDeliverySnapshot { snapshot in
                    if action == .video {
                        try await ShowVideoExport.write(snapshot: snapshot, options: requested, to: destination, progress: report)
                    } else {
                        let worker = Task.detached(priority: .userInitiated) {
                            try await snapshot.collect(to: destination, progress: report)
                        }
                        try await withTaskCancellationHandler { try await worker.value } onCancel: { worker.cancel() }
                    }
                }
                saved = destination
            } catch is CancellationError {
                failure = nil
            } catch {
                if !Task.isCancelled { failure = error.localizedDescription }
            }
        }
    }

    @MainActor private func report(_ value: Double, _ message: String) {
        guard !Task.isCancelled else { return }
        progress = value
        status = message
    }
}
