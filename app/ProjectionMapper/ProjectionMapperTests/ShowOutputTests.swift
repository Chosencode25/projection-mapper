import AppKit
import Foundation
import MetalKit
import Testing

struct ShowOutputStateTests {
    @Test func linearFadeCompletesWithoutMutatingItsSharedAnchor() {
        var output = ShowOutputState()
        #expect(output.gain(at: 100) == 1 && !output.isBlackout)
        output.fade(to: 0, duration: 4, at: 100)
        let snapshot = output
        #expect(output.gain(at: 99) == 1)
        #expect(output.gain(at: 101) == 0.75)
        #expect(output.gain(at: 102) == 0.5)
        #expect(output.isFading(at: 103.99))
        #expect(output.gain(at: 104) == 0 && !output.isFading(at: 104))
        #expect(output.gain(at: 10_000) == 0 && output == snapshot)
    }

    @Test func reversalStartsAtCurrentGainAndRepeatedTargetDoesNotRestart() {
        var output = ShowOutputState()
        output.fade(to: 0, duration: 4, at: 100)
        output.fade(to: 0, duration: 10, at: 101)
        #expect(output.gain(at: 102) == 0.5)
        output.restore(duration: 4, at: 102)
        #expect(output.gain(at: 102) == 0.5 && output.targetGain == 1)
        #expect(output.gain(at: 104) == 0.75)
        output.restore(duration: 30, at: 104)
        #expect(output.gain(at: 106) == 1 && !output.isFading(at: 106))
        output.fade(to: 0, duration: 2, at: 107)
        #expect(output.gain(at: 108) == 0.5 && output.gain(at: 109) == 0)
    }

    @Test func blackoutCancelsAndRestoreStartsFromBlackWithoutAFlash() {
        var output = ShowOutputState()
        output.fade(to: 0, duration: 4, at: 100)
        output.blackout()
        #expect(output.isBlackout && output.gain(at: 102) == 0)
        #expect(!output.isFading(at: 102))
        let latched = output
        output.blackout(); output.fade(to: 0, duration: 1, at: 102)
        output.fade(to: 1, duration: 1, at: 102)
        #expect(output == latched)
        output.restore(duration: 2, at: 103)
        #expect(!output.isBlackout && output.gain(at: 103) == 0)
        #expect(output.gain(at: 104) == 0.5 && output.gain(at: 105) == 1)
    }

    @Test func zeroDurationSettlesImmediatelyAndInvalidActionsPreserveState() {
        var output = ShowOutputState()
        output.fade(to: 0, duration: 0, at: 100)
        #expect(output.gain(at: 100) == 0 && !output.isFading(at: 100))
        output.restore(duration: 0, at: 101)
        #expect(output.gain(at: 101) == 1 && !output.isFading(at: 101))
        output.blackout()
        let original = output
        output.restore(duration: .nan, at: 102)
        output.restore(duration: 1, at: .infinity)
        output.restore(duration: 31, at: 102)
        output.restore(duration: 1, at: -1)
        #expect(output == original)
        output.restore(duration: 0, at: 103)
        let restored = output
        output.fade(to: .nan, duration: 1, at: 103)
        output.fade(to: -1, duration: 1, at: 103)
        output.fade(to: 0, duration: -1, at: 103)
        output.fade(to: 0, duration: 1, at: .nan)
        #expect(output == restored)
    }

    @Test func masterBrightnessChangesAttenuationWithoutRestartingFade() {
        var scene = RenderScene.diagnostic
        scene.showOutput.fade(to: 0, duration: 4, at: 100)
        scene.masterBrightness = 0.5
        #expect(scene.effectiveGain(at: 102) == 0.25)
        scene.masterBrightness = 0.8
        #expect(scene.effectiveGain(at: 102) == 0.4)
        #expect(scene.showOutput.gain(at: 104) == 0)
        scene.showOutput.blackout(); scene.masterBrightness = 1
        #expect(scene.effectiveGain(at: 103) == 0)
        scene.masterBrightness = 0; scene.showOutput.restore(duration: 0, at: 105)
        #expect(scene.effectiveGain(at: 105) == 0)
        scene.masterBrightness = .nan
        #expect(scene.effectiveGain(at: 105) == 0 && !scene.needsContinuousRendering(at: 105))
    }

    @Test func fadesRunForStaticAndPausedContentAndSettledBlackIdles() {
        var scene = RenderScene.diagnostic
        scene.showOutput.fade(to: 0, duration: 4, at: 100)
        #expect(scene.needsContinuousRendering(at: 102))
        #expect(!scene.needsContinuousRendering(at: 104))
        var animated = RenderSurface(geometry: .diagnostic, color: SIMD4(1, 0, 0, 1), content: .gradient)
        animated.playback.setPaused(true, at: 0)
        scene = RenderScene(surfaces: [animated], showOutput: scene.showOutput)
        scene.transport.setPlaying(true, at: 100)
        #expect(scene.needsContinuousRendering(at: 102))
        #expect(!scene.needsContinuousRendering(at: 104))
        scene.showOutput.restore(duration: 2, at: 105)
        #expect(scene.needsContinuousRendering(at: 105)) // First restored frame still starts black.
        #expect(!scene.needsContinuousRendering(at: 107)) // Paused source settles after restoration.
        scene.showOutput.blackout()
        #expect(!scene.needsContinuousRendering(at: 106))
    }

    @Test func generatorTransportCannotAlterSharedFadeClock() {
        var scene = RenderScene(geometry: .diagnostic, color: SIMD4(1, 0, 0, 1), content: .gradient)
        scene.showOutput.fade(to: 0, duration: 4, at: 100)
        scene.transport.setPlaying(true, at: 100)
        scene.transport.setSpeed(4, at: 101)
        scene.transport.seek(to: 800, at: 102)
        scene.transport.setPlaying(false, at: 102)
        #expect(scene.effectiveGain(at: 102) == 0.5 && scene.needsContinuousRendering(at: 102))
        #expect(scene.effectiveGain(at: 104) == 0 && !scene.needsContinuousRendering(at: 104))
        scene.showOutput.restore(duration: 1, at: 105)
        #expect(scene.effectiveGain(at: 105.5) == 0.5)
        scene.transport.setPlaying(true, at: 106)
        #expect(scene.needsContinuousRendering(at: 106))
        scene.masterBrightness = 0
        #expect(!scene.needsContinuousRendering(at: 106))
    }
}

@MainActor
@Suite(.serialized)
struct ShowOutputGPUTests {
    @Test func detachedFadeViewNeverEnablesContinuousOrDemandDrawing() throws {
        _ = NSApplication.shared
        var scene = RenderScene.diagnostic
        scene.showOutput.fade(to: 0, duration: 4, at: 100)
        let renderer = try MetalRenderer(scene: scene)
        let view = MetalSceneView(frame: CGRect(x: 0, y: 0, width: 640, height: 360), rendererFactory: { renderer })
        defer { view.stopRendering() }
        let metal = try #require(view.metalView)
        view.setRenderingActive(false, at: 101)
        renderer.updateRenderingDemand(at: 101)
        #expect(view.window == nil && !view.isRenderingActive && !renderer.isDrawingEnabled)
        #expect(metal.isPaused && !metal.enableSetNeedsDisplay)
        #expect(renderer.scene.showOutput.gain(at: 102) == 0.5)
        #expect(renderer.scene.showOutput.gain(at: 105) == 0)
    }

    @Test func productionViewDemandCallbackPausesOnlyAfterFinalBlackFrame() throws {
        _ = NSApplication.shared
        var scene = RenderScene.diagnostic
        scene.showOutput.fade(to: 0, duration: 4, at: 100)
        let renderer = try MetalRenderer(scene: scene)
        let view = MetalSceneView(frame: CGRect(x: 0, y: 0, width: 640, height: 360), rendererFactory: { renderer })
        defer { view.stopRendering() }
        let metal = try #require(view.metalView)
        view.setRenderingActive(true, at: 100) // Explicit availability probe, never attached or presented.
        renderer.updateRenderingDemand(at: 103.9)
        #expect(view.window == nil && view.isRenderingActive && renderer.isDrawingEnabled)
        #expect(!metal.isPaused && !metal.enableSetNeedsDisplay)
        try expectBlack(renderer, at: 104)
        renderer.updateRenderingDemand(at: 104)
        #expect(metal.isPaused && metal.enableSetNeedsDisplay)
        renderer.updateRenderingDemand(at: 105)
        #expect(metal.isPaused && metal.enableSetNeedsDisplay)
    }

    @Test func suspendedViewResumesAtElapsedGainAndSettledBlackRemainsPaused() throws {
        _ = NSApplication.shared
        var scene = RenderScene.diagnostic
        scene.showOutput.fade(to: 0, duration: 4, at: 100)
        let renderer = try MetalRenderer(scene: scene)
        let view = MetalSceneView(frame: CGRect(x: 0, y: 0, width: 640, height: 360), rendererFactory: { renderer })
        defer { view.stopRendering() }
        let metal = try #require(view.metalView)
        view.setRenderingActive(true, at: 100)
        view.isHidden = true
        view.updateRenderingAvailability()
        #expect(!view.isRenderingActive && !renderer.isDrawingEnabled && metal.isPaused)
        #expect(!metal.enableSetNeedsDisplay && renderer.scene.showOutput == scene.showOutput)
        view.isHidden = false
        view.setRenderingActive(true, at: 102)
        #expect(!metal.isPaused && renderer.scene.effectiveGain(at: 102) == 0.5)
        view.stopRendering()
        view.setRenderingActive(true, at: 105)
        #expect(metal.isPaused && metal.enableSetNeedsDisplay && renderer.scene.effectiveGain(at: 105) == 0)
        try expectBlack(renderer, at: 105)
    }

    @Test func cachedDemandAgreesWithSceneAcrossVisibilityPauseAndInvalidGeometry() throws {
        var transport = AnimationTransport(); transport.setPlaying(true, at: 100)
        var animated = RenderSurface(geometry: .diagnostic, color: SIMD4(1, 0, 0, 1), content: .noise)
        var invisible = animated; invisible.appearance.opacity = 0
        let invalid = RenderSurface(geometry: NormalizedRectangle(topLeft: .zero, topRight: .zero, bottomRight: .zero, bottomLeft: .zero),
                                    color: animated.color, content: .noise)
        animated.playback.setPaused(true, at: 0)
        var fading = ShowOutputState(); fading.fade(to: 0, duration: 4, at: 100)
        let renderer = try MetalRenderer()
        for surfaces in [[animated], [invisible], [invalid], [animated, invisible, invalid], []] {
            let scene = RenderScene(surfaces: surfaces, transport: transport, showOutput: fading)
            renderer.setScene(scene)
            var actual: Bool?
            renderer.renderDemandDidChange = { actual = $0 }
            renderer.updateRenderingDemand(at: 102)
            #expect(actual == scene.needsContinuousRendering(at: 102))
            renderer.updateRenderingDemand(at: 104)
            #expect(actual == scene.needsContinuousRendering(at: 104))
        }
    }

    @Test func everyContentTypeAttenuatesAndBlackoutIsExactlyBlack() throws {
        for content in SurfaceContent.allCases.filter({ $0 != .image }) {
            let face = RenderSurface(geometry: .diagnostic, color: SIMD4(0.8, 0.2, 0.4, 1), content: content)
            var scene = RenderScene(surfaces: [face])
            let renderer = try MetalRenderer(scene: scene)
            let normal = try pixels(renderer, at: 100)
            scene.masterBrightness = 0.5
            scene.showOutput.fade(to: 0, duration: 4, at: 100)
            renderer.setScene(scene)
            let dimmed = try pixels(renderer, at: 102)
            for i in stride(from: 0, to: normal.count, by: 4) {
                for channel in 0..<3 {
                    #expect(abs(Int(dimmed[i + channel]) - Int((Float(normal[i + channel]) * 0.25).rounded())) <= 1)
                }
                #expect(dimmed[i + 3] == normal[i + 3] && dimmed[i + 3] == 255)
            }
            scene.showOutput.blackout(); renderer.setScene(scene)
            try expectBlack(renderer, at: 102)
            scene.showOutput.restore(duration: 2, at: 103); renderer.setScene(scene)
            try expectBlack(renderer, at: 103)
            #expect(try pixels(renderer, at: 105) == pixels(try MetalRenderer(scene: RenderScene(surfaces: [face], masterBrightness: 0.5)), at: 105))
        }
    }

    @Test func masterAttenuatesAfterFaceClippingWithoutChangingOverlapAlpha() throws {
        var front = RenderSurface(geometry: .diagnostic, color: SIMD4(0.8, 0.6, 0.1, 1))
        front.appearance.brightness = 2
        var scene = RenderScene(surfaces: [front], masterBrightness: 0.25)
        let renderer = try MetalRenderer(scene: scene)
        let clipped = try pixels(renderer, at: 100)
        let center = (8 * 16 + 8) * 4
        #expect(abs(Int(clipped[center]) - 13) <= 1)
        #expect(abs(Int(clipped[center + 1]) - 64) <= 1 && abs(Int(clipped[center + 2]) - 64) <= 1)
        let back = RenderSurface(geometry: .diagnostic, color: SIMD4(0.1, 0.4, 1, 1))
        front.appearance.opacity = 0.35
        scene = RenderScene(surfaces: [back, front]); renderer.setScene(scene)
        let full = try pixels(renderer, at: 100)
        scene.masterBrightness = 0.5; renderer.setScene(scene)
        let half = try pixels(renderer, at: 100)
        for i in stride(from: 0, to: full.count, by: 4) {
            for channel in 0..<3 { #expect(abs(Int(half[i + channel]) - Int((Float(full[i + channel]) * 0.5).rounded())) <= 2) }
            #expect(half[i + 3] == full[i + 3])
        }
    }

    @Test func sharedRendererSnapshotsMatchDuringFadeAndAfterOutputReopen() throws {
        var scene = RenderScene(geometry: .diagnostic, color: SIMD4(1, 0.1, 0.3, 1), content: .noise)
        scene.masterBrightness = 0.7
        scene.showOutput.fade(to: 0, duration: 4, at: 100)
        let preview = try MetalRenderer(scene: scene)
        let output = try MetalRenderer(scene: scene)
        #expect(try pixels(preview, at: 102) == pixels(output, at: 102))
        let reopened = try MetalRenderer(scene: scene)
        try expectBlack(reopened, at: 105)
        #expect(!reopened.scene.needsContinuousRendering(at: 105))
    }

    @Test func demandCallbackSettlesAfterTheFinalFadeFrameAndDoesNotRepeat() throws {
        var scene = RenderScene.diagnostic
        scene.showOutput.fade(to: 0, duration: 4, at: 100)
        let renderer = try MetalRenderer(scene: scene)
        var changes: [Bool] = []
        renderer.renderDemandDidChange = { changes.append($0) }
        renderer.updateRenderingDemand(at: 100)
        renderer.updateRenderingDemand(at: 102)
        #expect(changes == [true])
        try expectBlack(renderer, at: 104)
        renderer.updateRenderingDemand(at: 104)
        renderer.updateRenderingDemand(at: 105)
        #expect(changes == [true, false])
        scene.showOutput.restore(duration: 2, at: 106); renderer.setScene(scene)
        renderer.isDrawingEnabled = false
        renderer.updateRenderingDemand(at: 107)
        #expect(changes.last == false)
        renderer.isDrawingEnabled = true
        renderer.updateRenderingDemand(at: 107)
        #expect(changes.last == true)
        renderer.updateRenderingDemand(at: 108)
        #expect(changes.last == false)
    }

    private func expectBlack(_ renderer: MetalRenderer, at uptime: TimeInterval) throws {
        let data = try pixels(renderer, at: uptime)
        for i in stride(from: 0, to: data.count, by: 4) {
            #expect(data[i] == 0 && data[i + 1] == 0 && data[i + 2] == 0 && data[i + 3] == 255)
        }
    }

    private func pixels(_ renderer: MetalRenderer, at uptime: TimeInterval) throws -> [UInt8] {
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .bgra8Unorm, width: 16, height: 16, mipmapped: false)
        descriptor.storageMode = .shared; descriptor.usage = .renderTarget
        let texture = try #require(renderer.device.makeTexture(descriptor: descriptor))
        let pass = MTLRenderPassDescriptor(); pass.colorAttachments[0].texture = texture
        let command = try #require(renderer.encodeScene(to: pass, evaluationTime: 0.375, evaluationUptime: uptime))
        command.commit(); command.waitUntilCompleted()
        #expect(command.status == .completed && command.error == nil)
        var data = [UInt8](repeating: 0, count: 16 * 16 * 4)
        data.withUnsafeMutableBytes { texture.getBytes($0.baseAddress!, bytesPerRow: 16 * 4, from: MTLRegionMake2D(0, 0, 16, 16), mipmapLevel: 0) }
        return data
    }
}
