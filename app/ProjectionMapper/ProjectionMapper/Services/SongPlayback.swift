import AVFoundation
import Foundation

struct ShowSong: Codable, Equatable, Sendable {
    static let maximumBytes = 96 * 1024 * 1024
    static let formats = ["wav", "aiff", "aif", "caf", "m4a", "mp3", "flac"]
    var id = UUID()
    var name: String
    var fileExtension: String
    var byteCount: Int
    var duration: Double
    var loop: SongLoop?
    var fileName: String { id.uuidString + "." + fileExtension }
    func projectionPosition(at time: Double, compensationMilliseconds: Double) -> Double {
        let offset = compensationMilliseconds / 1000
        let limits: ClosedRange<Double>
        if let loop, (loop.start..<loop.end).contains(time) {
            limits = loop.start...max(loop.start, loop.end - 1.0 / 60_000)
        } else {
            limits = 0...duration
        }
        return min(limits.upperBound, max(limits.lowerBound, time + offset))
    }

    var isValid: Bool {
        !name.isEmpty && name.count <= 120 && Self.formats.contains(fileExtension) &&
            (1...Self.maximumBytes).contains(byteCount) && (0.1...3600).contains(duration) &&
            (loop?.isValid(for: duration) ?? true)
    }
}

struct SongLoop: Codable, Equatable, Sendable {
    var start: Double
    var end: Double

    func isValid(for duration: Double) -> Bool {
        start.isFinite && end.isFinite && start >= 0 && end <= duration && end - start >= 0.1
    }
}

struct PreparedSong: Sendable {
    let song: ShowSong
    let bytes: Data
    let peaks: [Float]

    static func read(_ url: URL, expected: ShowSong? = nil) throws -> Self {
        let ext = url.pathExtension.lowercased()
        guard ShowSong.formats.contains(ext) else { throw ProjectFileError.invalid("Unsupported soundtrack format.") }
        let fileSize = try VideoImportService.safeFile(url)
        guard fileSize <= ShowSong.maximumBytes else {
            throw ProjectFileError.invalid("Soundtracks must be at most 96 MB.")
        }
        let bytes = try Data(contentsOf: url)
        guard !bytes.isEmpty, Int64(bytes.count) == fileSize, expected.map({ $0.byteCount == bytes.count }) ?? true else {
            throw ProjectFileError.invalid("Soundtrack file is missing or changed.")
        }
        try Task.checkCancellation()
        let file = try AVAudioFile(forReading: url, commonFormat: .pcmFormatFloat32, interleaved: false)
        let duration = Double(file.length) / file.processingFormat.sampleRate
        let song = expected ?? ShowSong(name: String(url.deletingPathExtension().lastPathComponent.prefix(120)),
                                       fileExtension: ext, byteCount: bytes.count, duration: duration)
        guard song.isValid, duration.isFinite, abs(song.duration - duration) < 0.05,
              (1...8).contains(file.processingFormat.channelCount),
              let buffer = AVAudioPCMBuffer(pcmFormat: file.processingFormat, frameCapacity: 8192) else {
            throw ProjectFileError.invalid("Soundtrack duration or audio format is unsupported.")
        }
        let count = min(2048, Int(file.length))
        guard count > 0 else { throw ProjectFileError.invalid("Soundtrack is empty.") }
        var peaks = [Float](repeating: 0, count: count)
        var framesRead: Int64 = 0
        while framesRead < file.length {
            try Task.checkCancellation()
            try file.read(into: buffer, frameCount: AVAudioFrameCount(min(8192, file.length - framesRead)))
            guard buffer.frameLength > 0, let channels = buffer.floatChannelData else { break }
            for channel in 0..<Int(buffer.format.channelCount) {
                for frame in 0..<Int(buffer.frameLength) {
                    let bin = min(count - 1, Int((framesRead + Int64(frame)) * Int64(count) / file.length))
                    let sample = abs(channels[channel][frame])
                    if sample.isFinite { peaks[bin] = max(peaks[bin], min(1, sample)) }
                }
            }
            framesRead += Int64(buffer.frameLength)
        }
        guard framesRead == file.length else { throw ProjectFileError.invalid("Soundtrack decoding ended early.") }
        return Self(song: song, bytes: bytes, peaks: peaks)
    }
}
