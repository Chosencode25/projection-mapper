import CoreGraphics
import Foundation
import ImageIO
import MetalKit
import UniformTypeIdentifiers

/// The phone requests this on demand. One small frame can be in flight per Mac.
@MainActor
final class PhonePreview {
    private struct Frame {
        let jpeg: Data
        let key: UUID
        let uptime: TimeInterval
        let seconds: Double
    }

    static let interval: TimeInterval = 1
    static let longestEdge = 480
    private var renderer: MetalRenderer?
    private var lastRequest: TimeInterval = -.infinity
    private var frame: Frame?
    private var requestID: UUID?
    private var visibleGeneration = UUID()
    private var lastFailure = false

    func clear() {
        renderer = nil
        frame = nil
        visibleGeneration = UUID()
        lastFailure = false
    }

    func request(scene: RenderScene, aspect: Double, key: UUID,
                 at uptime: TimeInterval = ProcessInfo.processInfo.systemUptime) -> PhoneResponse {
        if requestID == nil, uptime - lastRequest >= Self.interval {
            lastRequest = uptime
            lastFailure = false
            capture(scene: scene, aspect: aspect, key: key, at: uptime)
        }
        if let frame, frame.key == key, uptime - frame.uptime <= 4 {
            return .json(["jpeg": frame.jpeg.base64EncodedString(),
                          "time": frame.seconds, "age": max(0, uptime - frame.uptime)])
        }
        if lastFailure { return .json(["error": "The Mac could not render a preview."], status: "503 Service Unavailable") }
        return .json(["pending": true], status: "202 Accepted")
    }

    static func dimensions(aspect: Double) -> (width: Int, height: Int) {
        let aspect = aspect.isFinite ? min(4, max(0.25, aspect)) : 16.0 / 9.0
        return aspect >= 1 ? (longestEdge, Int((Double(longestEdge) / aspect).rounded())) :
            (Int((Double(longestEdge) * aspect).rounded()), longestEdge)
    }

    private func capture(scene: RenderScene, aspect: Double, key: UUID, at uptime: TimeInterval) {
        if renderer == nil { renderer = try? MetalRenderer(scene: scene) }
        guard let renderer else { lastFailure = true; return }
        renderer.setScene(scene)
        let (width, height) = Self.dimensions(aspect: aspect)
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: MetalRenderer.pixelFormat,
                                                                  width: width, height: height, mipmapped: false)
        descriptor.usage = .renderTarget
        descriptor.storageMode = .shared
        guard let texture = renderer.device.makeTexture(descriptor: descriptor) else { lastFailure = true; return }
        let pass = MTLRenderPassDescriptor()
        pass.colorAttachments[0].texture = texture
        let seconds = scene.transport.elapsed(at: uptime)
        guard let command = renderer.encodeScene(to: pass, viewIdentifier: "phone preview",
                                                  evaluationTime: seconds, evaluationUptime: uptime) else {
            lastFailure = true
            return
        }
        let id = UUID()
        let generation = visibleGeneration
        requestID = id
        command.addCompletedHandler { [weak self] command in
            let jpeg = command.status == .completed ? Self.encode(texture, width: width, height: height) : nil
            Task { @MainActor [weak self] in
                guard let self, self.requestID == id else { return }
                self.requestID = nil
                guard self.visibleGeneration == generation else { return }
                self.lastFailure = jpeg == nil
                if let jpeg { self.frame = Frame(jpeg: jpeg, key: key, uptime: uptime, seconds: seconds) }
            }
        }
        command.commit()
    }

    nonisolated private static func encode(_ texture: MTLTexture, width: Int, height: Int) -> Data? {
        var pixels = Data(count: width * height * 4)
        return pixels.withUnsafeMutableBytes { bytes in
            guard let base = bytes.baseAddress else { return nil }
            texture.getBytes(base, bytesPerRow: width * 4,
                             from: MTLRegionMake2D(0, 0, width, height), mipmapLevel: 0)
            let info = CGBitmapInfo.byteOrder32Little.rawValue | CGImageAlphaInfo.noneSkipFirst.rawValue
            guard let context = CGContext(data: base, width: width, height: height, bitsPerComponent: 8,
                                          bytesPerRow: width * 4, space: CGColorSpaceCreateDeviceRGB(),
                                          bitmapInfo: info),
                  let image = context.makeImage() else { return nil }
            let output = NSMutableData()
            guard let destination = CGImageDestinationCreateWithData(output, UTType.jpeg.identifier as CFString, 1, nil) else { return nil }
            CGImageDestinationAddImage(destination, image, [kCGImageDestinationLossyCompressionQuality: 0.62] as CFDictionary)
            guard CGImageDestinationFinalize(destination), output.length <= 144 * 1024 else { return nil }
            return output as Data
        }
    }
}
