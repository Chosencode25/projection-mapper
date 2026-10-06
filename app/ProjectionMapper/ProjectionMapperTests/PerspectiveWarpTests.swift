import AppKit
import MetalKit
import Testing
import SwiftUI
import simd

@MainActor
struct PerspectiveWarpTests {
    // Independent reference: x=(.45u+.12v+.1)/(.6u-.25v+1), y=(.03u+.55v+.1)/denominator.
    private func reference(_ uv: SIMD2<Double>) -> SIMD2<Double> {
        let denominator = 0.6 * uv.x - 0.25 * uv.y + 1
        return SIMD2(0.45 * uv.x + 0.12 * uv.y + 0.1, 0.03 * uv.x + 0.55 * uv.y + 0.1) / denominator
    }
    private var skew: NormalizedRectangle {
        NormalizedRectangle(topLeft: SIMD2<Float>(reference(SIMD2(0,0))),
            topRight: SIMD2<Float>(reference(SIMD2(1,0))),
            bottomRight: SIMD2<Float>(reference(SIMD2(1,1))), bottomLeft: SIMD2<Float>(reference(SIMD2(0,1))))
    }
    @Test func knownProjectiveTransformMatchesInteriorAndCorners() throws {
        let transform = try #require(PerspectiveTransform(skew))
        for y in 0...10 { for x in 0...10 {
            let uv = SIMD2(Double(x)/10, Double(y)/10)
            #expect(simd_length(transform.project(uv) - reference(uv)) < 1e-6)
            let homogeneous = transform.inverse * SIMD3(reference(uv).x, reference(uv).y, 1)
            #expect(simd_length(SIMD2(homogeneous.x, homogeneous.y)/homogeneous.z - uv) < 1e-6)
        } }
        // An affine UV mapping would put this at the arithmetic average; perspective does not.
        let midpoint = (reference(SIMD2(0,0)) + reference(SIMD2(1,1))) / 2
        #expect(simd_length(transform.project(SIMD2(0.5,0.5)) - midpoint) > 0.02)
    }
    @Test func affineAndReversedWindingRemainValid() throws {
        let transform = try #require(PerspectiveTransform(.diagnostic))
        #expect(simd_length(transform.project(SIMD2(0.2,0.6)) - SIMD2(0.35,0.55)) < 1e-12)
        let reversed = NormalizedRectangle(topLeft: SIMD2(0.75,0.25), topRight: SIMD2(0.25,0.25),
            bottomRight: SIMD2(0.25,0.75), bottomLeft: SIMD2(0.75,0.75))
        let flipped = try #require(PerspectiveTransform(reversed))
        #expect(simd_length(flipped.project(SIMD2(0.2,0.6)) - SIMD2(0.65,0.55)) < 1e-12)
    }
    @Test func rejectsCrossedConcaveCollapsedThinAndNonfiniteCorners() {
        let base = NormalizedRectangle.diagnostic
        let invalid = [base.replacing(.topLeft, with: base.bottomRight),
            base.replacing(.topLeft, with: SIMD2(0.7,0.7)),
            base.replacing(.topLeft, with: base.topRight),
            base.replacing(.topLeft, with: SIMD2(.nan,0.2)),
            base.replacing(.bottomLeft, with: SIMD2(0.25,.infinity)),
            base.replacing(.topLeft, with: SIMD2(-0.1,0.25)),
            NormalizedRectangle(topLeft: SIMD2(0.1,0.1), topRight: SIMD2(0.9,0.9),
                bottomRight: SIMD2(0.9,0.1), bottomLeft: SIMD2(0.1,0.9)),
            NormalizedRectangle(topLeft: SIMD2(0.2,0.2), topRight: SIMD2(0.8,0.2),
                bottomRight: SIMD2(0.8,0.2000001), bottomLeft: SIMD2(0.2,0.2000001))]
        for geometry in invalid { #expect(PerspectiveTransform(geometry) == nil) }
    }
    @Test func stronglySkewedValidShapePreservesStraightLines() throws {
        let geometry = NormalizedRectangle(topLeft: SIMD2(0.05,0.05), topRight: SIMD2(0.95,0.06),
            bottomRight: SIMD2(0.51,0.95), bottomLeft: SIMD2(0.49,0.94))
        let transform = try #require(PerspectiveTransform(geometry))
        for u in [0.1,0.5,0.9] {
            let start = transform.project(SIMD2(u,0)), end = transform.project(SIMD2(u,1))
            for v in [0.1,0.4,0.7,0.9] {
                let offset = transform.project(SIMD2(u,v)) - start, direction = end - start
                #expect(abs(offset.x * direction.y - offset.y * direction.x) < 1e-10)
            }
        }
    }
    @Test func textureOrientationAndMipChainReachGPU() throws {
        let renderer = try MetalRenderer(scene: .diagnosticGrid)
        #expect(renderer.diagnosticTexture.mipmapLevelCount == 10)
        let texture = try render(renderer, width: 1024, height: 1024)
        let transform = try #require(renderer.scene.perspective)
        let markers: [(SIMD2<Double>, [UInt8])] = [(SIMD2(0.035,0.035),[0,0,255,255]),
            (SIMD2(0.965,0.035),[0,255,0,255]), (SIMD2(0.965,0.965),[255,0,0,255]),
            (SIMD2(0.035,0.965),[0,255,255,255])]
        for (uv, expected) in markers {
            let p = transform.project(uv)
            #expect(pixel(texture, x: Int(p.x*1024), y: Int(p.y*1024)) == expected)
        }
        #expect(pixel(texture, x: 0,y: 0) == [0,0,0,255])
    }
    @Test func warpedGPUGridMatchesIndependentOracleAcrossTriangleJoin() throws {
        let renderer = try MetalRenderer(scene: RenderScene(geometry: skew, color: .zero, content: .diagnosticGrid))
        let texture = try render(renderer, width: 1600,height: 1000)
        // Cell centers plus samples just either side of the shared BL–TR diagonal.
        var samples: [SIMD2<Double>] = []
        for y in 0..<8 { for x in 0..<8 {
            if (x == 0 || x == 7) && (y == 0 || y == 7) { continue } // Colored corner markers.
            samples.append(SIMD2((Double(x)+0.5)/8,(Double(y)+0.5)/8)) } }
        for u in [0.19,0.31,0.44,0.56,0.69,0.81] {
            samples.append(SIMD2(u,1-u-0.01)); samples.append(SIMD2(u,1-u+0.01))
        }
        for uv in samples {
            let position = reference(uv)
            let actual = pixel(texture,x: Int(position.x*1600),y: Int(position.y*1000))
            let shade: UInt8 = (Int(uv.x*8)+Int(uv.y*8)).isMultiple(of: 2) ? 220 : 30
            #expect(actual == [shade,shade,shade,255])
        }
    }
    @Test func invalidGeometryClearsPreviousFrameAndRecoversForBothContents() throws {
        let renderer = try MetalRenderer(scene: .diagnosticGrid)
        #expect(pixel(try render(renderer),x: 155,y: 155) != [0,0,0,255])
        let invalid = NormalizedRectangle.diagnostic.replacing(.topLeft,with: SIMD2(0.7,0.7))
        for content in SurfaceContent.allCases {
            renderer.setScene(RenderScene(geometry: invalid,color: SIMD4(1,0,0,1),content: content))
            let texture = try render(renderer)
            for y in stride(from: 0,to: 512,by: 17) { for x in stride(from: 0,to: 512,by: 17) {
                #expect(pixel(texture,x: x,y: y) == [0,0,0,255])
            } }
        }
        renderer.setScene(.diagnosticGrid)
        #expect(pixel(try render(renderer),x: 155,y: 155) != [0,0,0,255])
    }
    @Test func contentEditsAndInvalidRecoveryUpdateExistingOutputAndReset() throws {
        let session = EditorSession(presentOutput: { _ in })
        session.testOutput.open(for: .testWindow)
        defer { session.testOutput.close() }
        let renderer = try #require((session.testOutput.window?.contentView as? TestOutputView)?.metalView?.delegate as? MetalRenderer)
        let timestamp = session.project.modifiedAt
        session.setSurfaceContent(.diagnosticGrid)
        #expect(session.project.modifiedAt == timestamp && !session.hasUserChanges)
        session.setSurfaceContent(.solid)
        #expect(renderer.scene.content == .solid && session.hasUserChanges)
        session.selectCorner(.topLeft)
        session.moveSelectedCorner(to: SIMD2(0.7,0.7),surfaceID: session.project.surfaces[0].id)
        #expect(session.scene.perspective == nil && renderer.scene == session.scene)
        session.moveSelectedCorner(to: SIMD2(0.25,0.25),surfaceID: session.project.surfaces[0].id)
        #expect(session.scene.perspective != nil && renderer.scene == session.scene)
        session.selectSurface(nil); session.setSurfaceContent(.diagnosticGrid)
        #expect(session.scene.content == .solid) // Deselecting prevents inspector edits.
        session.resetProject()
        #expect(renderer.scene == .diagnosticGrid && !session.hasUserChanges && session.selectedCorner == nil)
    }
    @Test func warpedGridRendersAtEveryPresetWithoutChangingScene() throws {
        let scene = RenderScene(geometry: skew,color: .zero,content: .diagnosticGrid)
        let renderer = try MetalRenderer(scene: scene)
        let position = reference(SIMD2(0.4375,0.5625))
        for preset in TestResolution.allCases {
            let texture = try render(renderer,width: Int(preset.size.width),height: Int(preset.size.height))
            let actual = pixel(texture,x: Int(position.x*Double(Int(preset.size.width))),y: Int(position.y*Double(Int(preset.size.height))))
            #expect(actual == [30,30,30,255])
            #expect(renderer.scene == scene)
        }
    }
    @Test func inspectorSelectionCanRecoverOverlappingHandlesWithNativeDrag() throws {
        _ = NSApplication.shared
        let session = EditorSession(presentOutput: { _ in })
        session.selectCorner(.topLeft)
        session.moveSelectedCorner(to: session.project.surfaces[0].corners.topRight, surfaceID: session.project.surfaces[0].id)
        #expect(session.scene.perspective == nil)
        // Top right must win the shared hit point even though top left occurs first in the corner list.
        session.selectCorner(.topRight)
        let view = CornerOverlayView(frame: CGRect(x: 0, y: 0, width: 424, height: 424))
        let window = NSWindow(contentRect: view.frame, styleMask: [.titled], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false; window.contentView = view
        defer { window.contentView = nil; window.close() }
        view.configure(surfaceID: session.project.surfaces[0].id, corners: session.project.surfaces[0].corners,
            activeCorner: session.selectedCorner, select: { session.selectCorner($0) },
            move: { session.moveSelectedCorner(to: $0, surfaceID: session.project.surfaces[0].id) }, nudge: { _, _ in })
        let point = SurfaceCoordinates.position(session.project.surfaces[0].corners.topRight, in: view.previewRect)
        func event(_ type: NSEvent.EventType, at point: CGPoint) throws -> NSEvent {
            try #require(NSEvent.mouseEvent(with: type, location: view.convert(point, to: nil),
                modifierFlags: [], timestamp: 0, windowNumber: window.windowNumber,
                context: nil, eventNumber: 1, clickCount: 1, pressure: 1))
        }
        view.mouseDown(with: try event(.leftMouseDown, at: point))
        #expect(session.selectedCorner == .topRight && window.firstResponder === view)
        view.mouseDragged(with: try event(.leftMouseDragged, at: CGPoint(x: point.x + 80, y: point.y)))
        #expect(session.project.surfaces[0].corners.topLeft == SIMD2(0.75, 0.25))
        #expect(session.project.surfaces[0].corners.topRight == SIMD2(0.95, 0.25))
        #expect(session.scene.perspective != nil)
    }

    @Test func invalidWarningDoesNotMoveFittedCanvasOrHandles() throws {
        _ = NSApplication.shared
        let session = EditorSession(presentOutput: { _ in })
        let host = NSHostingView(rootView: EditorCanvasView(session: session))
        host.frame = CGRect(x: 0, y: 0, width: 800, height: 600)
        func layout() {
            host.layoutSubtreeIfNeeded()
            RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.03))
            host.layoutSubtreeIfNeeded()
        }
        func find<T: NSView>(_ type: T.Type, in view: NSView) -> T? {
            if let match = view as? T { return match }
            return view.subviews.lazy.compactMap { find(type, in: $0) }.first
        }
        layout()
        let preview = try #require(find(MetalSceneView.self, in: host))
        let handles = try #require(find(CornerOverlayView.self, in: host))
        let originalPreview = preview.convert(preview.outputFrame, to: host)
        let originalHandles = handles.convert(handles.previewRect, to: host)
        #expect(originalPreview.width > 0 && originalPreview.height > 0)
        session.selectCorner(.topLeft)
        session.moveSelectedCorner(to: SIMD2(0.7,0.7), surfaceID: session.project.surfaces[0].id)
        layout()
        #expect(session.scene.perspective == nil)
        #expect(find(MetalSceneView.self, in: host) === preview)
        #expect(preview.convert(preview.outputFrame, to: host) == originalPreview)
        #expect(handles.convert(handles.previewRect, to: host) == originalHandles)
        session.moveSelectedCorner(to: SIMD2(0.25,0.25), surfaceID: session.project.surfaces[0].id)
        layout()
        #expect(session.scene.perspective != nil)
        #expect(preview.convert(preview.outputFrame, to: host) == originalPreview)
    }

    private func render(_ renderer: MetalRenderer,width: Int = 512,height: Int = 512) throws -> any MTLTexture {
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: MetalRenderer.pixelFormat,
            width: width,height: height,mipmapped: false)
        descriptor.storageMode = .shared; descriptor.usage = .renderTarget
        let texture = try #require(renderer.device.makeTexture(descriptor: descriptor))
        let pass = MTLRenderPassDescriptor(); pass.colorAttachments[0].texture = texture
        let command = try #require(renderer.encodeScene(to: pass))
        command.commit(); command.waitUntilCompleted()
        #expect(command.status == .completed && command.error == nil)
        return texture
    }
    private func pixel(_ texture: any MTLTexture,x: Int,y: Int) -> [UInt8] {
        var bytes = [UInt8](repeating: 0,count: 4)
        bytes.withUnsafeMutableBytes { texture.getBytes($0.baseAddress!,bytesPerRow: 4,
            from: MTLRegionMake2D(x,y,1,1),mipmapLevel: 0) }
        return bytes
    }
}
