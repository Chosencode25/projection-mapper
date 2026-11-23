import AVFoundation
import Darwin
import Foundation

enum ShowDeliveryAction: String, Identifiable {
    case video, collect
    var id: Self { self }
    var title: String { self == .video ? "Export Video" : "Collect Show Assets" }
}

enum DeliveryError: LocalizedError {
    case invalid(String), occupied, writing(String)

    var errorDescription: String? {
        switch self {
        case .invalid(let message), .writing(let message): message
        case .occupied: "A file already exists at that location. Choose a different name."
        }
    }
}

/// The last step of each delivery is an atomic publication on the destination volume.
enum DeliveryFile {
    static func requireVacant(_ url: URL) throws {
        let result = url.path.withCString { path in
            var attributes = stat()
            return lstat(path, &attributes)
        }
        if result == 0 { throw DeliveryError.occupied }
        if errno != ENOENT { throw DeliveryError.writing(String(cString: strerror(errno))) }
    }

    static func publish(_ staged: URL, to destination: URL) throws {
        try Task.checkCancellation()
        let result = staged.path.withCString { from in destination.path.withCString { to in
            renameatx_np(AT_FDCWD, from, AT_FDCWD, to, UInt32(RENAME_EXCL))
        } }
        guard result == 0 else {
            if errno == EEXIST { throw DeliveryError.occupied }
            throw DeliveryError.writing(String(cString: strerror(errno)))
        }
    }
}

struct DeliverySnapshot: Sendable {
    let document: Data
    let imageFiles: [UUID: Data]
    let imagePixels: [UUID: ImagePixels]
    let videoFiles: [UUID: URL]
    let songBytes: Data?

    static func mediaBytes(for project: MappingProject) -> UInt64 {
        let images = project.imageAssets.reduce(UInt64(0)) { $0 + UInt64($1.width) * UInt64($1.height) * 4 }
        let video = project.videoAssets.reduce(UInt64(0)) { $0 + UInt64($1.byteCount) }
        return images + video + UInt64(project.song?.byteCount ?? 0)
    }

    func validateVideo(_ asset: VideoAsset) async throws -> URL {
        guard let url = videoFiles[asset.id] else { throw DeliveryError.invalid("Relink the video “\(asset.name)” before delivery.") }
        let actual = try await VideoImportService.inspect(url, name: asset.name).0
        guard actual.byteCount == asset.byteCount, actual.duration >= asset.duration - 0.00001,
              actual.width == asset.width, actual.height == asset.height, actual.transform == asset.transform else {
            throw DeliveryError.invalid("The video “\(asset.name)” changed. Relink it before delivery.")
        }
        return url
    }

    func collect(to destination: URL, progress: @escaping @MainActor @Sendable (Double, String) -> Void) async throws {
        try DeliveryFile.requireVacant(destination)
        let document = try ProjectCodec.decode(document)
        let project = document.project
        for asset in project.imageAssets where imageFiles[asset.id] == nil {
            throw DeliveryError.invalid("Relink the image “\(asset.name)” before collecting.")
        }
        let count = project.videoAssets.count
        for (index, asset) in project.videoAssets.enumerated() {
            try Task.checkCancellation()
            await progress(0.1 + 0.55 * Double(index) / Double(max(1, count)), "Checking \(asset.name)…")
            _ = try await validateVideo(asset)
        }
        try Task.checkCancellation()
        if let song = project.song {
            guard let songBytes, songBytes.count == song.byteCount else {
                throw DeliveryError.invalid("Replace the missing soundtrack before collecting.")
            }
            let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: false)
            defer { try? FileManager.default.removeItem(at: folder) }
            let file = folder.appendingPathComponent(song.fileName)
            try songBytes.write(to: file)
            _ = try PreparedSong.read(file, expected: song)
        }
        await progress(0.68, "Collecting verified media…")
        try ProjectPackageStore().write(document, to: destination, imageFiles: imageFiles,
                                        videoFiles: videoFiles, songBytes: songBytes, replaceExisting: false)
    }
}
