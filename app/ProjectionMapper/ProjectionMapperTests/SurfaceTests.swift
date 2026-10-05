import AppKit
import MetalKit
import SwiftUI
import Testing

@MainActor
struct SurfaceTests {
    @Test func freshProjectsOwnDistinctDefaultSurfaces() {
        let first = MappingProject(), second = MappingProject()
        #expect(first.surface.id != second.surface.id)
        #expect(first.surface.name == "Surface 1")
        #expect(first.surface.corners.topLeft == SIMD2<Float>(0.25, 0.25))
        #expect(first.surface.corners.topRight == SIMD2<Float>(0.75, 0.25))
        #expect(first.surface.corners.bottomRight == SIMD2<Float>(0.75, 0.75))
        #expect(first.surface.corners.bottomLeft == SIMD2<Float>(0.25, 0.75))
        #expect(first.surface.renderScene == .diagnosticGrid)
        let copy = first
        #expect(copy.surface.id == first.surface.id)
        let session = EditorSession(project: first)
        #expect(session.selectedSurfaceID == first.surface.id && !session.hasUserChanges)
    }

    @Test func selectionIsValidatedAndDoesNotModifyProjectOrScene() {
        let session = EditorSession()
        let project = session.project, scene = session.scene
        session.selectSurface(nil)
        #expect(session.selectedSurface == nil)
        session.selectSurface(UUID())
        #expect(session.selectedSurfaceID == nil)
        session.selectSurface(project.surface.id)
        #expect(session.selectedSurface == project.surface)
        session.selectSurface(UUID())
        #expect(session.selectedSurfaceID == project.surface.id)
        #expect(session.project == project && session.scene == scene && !session.hasUserChanges)
    }

    @Test func presetsAndOutputReopenPreserveSurfaceAndSelection() throws {
        let session = EditorSession(presentOutput: { _ in })
        let project = session.project
        defer { session.testOutput.close() }
        session.selectSurface(nil)
        for preset in TestResolution.allCases {
            session.setTestResolution(preset)
            #expect(session.testOutput.open(for: .testWindow, resolution: preset))
            let renderer = try #require((session.testOutput.window?.contentView as? TestOutputView)?.metalView?.delegate as? MetalRenderer)
            #expect(renderer.scene == project.surface.renderScene)
            session.testOutput.close()
            #expect(session.project == project && session.selectedSurface == nil && !session.hasUserChanges)
        }
        session.selectSurface(project.surface.id)
        #expect(session.selectedSurface == project.surface)
    }

    @Test func resetReplacesSurfaceAndSelectionButPreservesOutputAndPreferences() throws {
        let session = EditorSession(presentOutput: { _ in })
        let previous = session.project
        session.setTestResolution(.portrait)
        session.testOutput.open(for: .testWindow, resolution: .portrait)
        let window = try #require(session.testOutput.window)
        defer { session.testOutput.close() }
        session.selectSurface(nil)
        session.isSidebarVisible = false
        session.renameProject("House")
        session.resetProject()
        #expect(session.project.id != previous.id && session.project.surface.id != previous.surface.id)
        #expect(session.selectedSurfaceID == session.project.surface.id)
        session.selectSurface(previous.surface.id)
        #expect(session.selectedSurfaceID == session.project.surface.id)
        #expect(session.testOutput.window === window && session.output.testResolution == .portrait)
        #expect(!session.isSidebarVisible && !session.hasUserChanges && session.scene == .diagnosticGrid)
    }

    @Test func nondefaultSurfaceContentRequiresDiscardProtection() {
        let geometry = NormalizedRectangle(topLeft: SIMD2(0.1, 0.2), topRight: SIMD2(0.4, 0.2),
                                           bottomRight: SIMD2(0.4, 0.6), bottomLeft: SIMD2(0.1, 0.6))
        for surface in [MappingSurface(name: "Custom"), MappingSurface(corners: geometry),
                        MappingSurface(color: SIMD4(0, 1, 0, 1))] {
            let session = EditorSession(project: MappingProject(surface: surface))
            #expect(session.hasUserChanges)
            session.selectSurface(nil)
            #expect(session.hasUserChanges)
            session.resetProject()
            #expect(!session.hasUserChanges)
        }
    }

    @Test func projectGeometryAndResetReachBothExistingRenderers() throws {
        _ = NSApplication.shared
        let corners = NormalizedRectangle(topLeft: SIMD2(0.1, 0.2), topRight: SIMD2(0.4, 0.2),
                                          bottomRight: SIMD2(0.4, 0.6), bottomLeft: SIMD2(0.1, 0.6))
        let project = MappingProject(surface: MappingSurface(corners: corners, color: SIMD4(0, 1, 0, 1), content: .solid))
        let session = EditorSession(presentOutput: { _ in }, project: project)
        let host = NSHostingView(rootView: MetalScenePreview(scene: session.scene, aspectRatio: 16.0 / 9.0,
                                                           outputDescription: "HD"))
        let window = NSWindow(contentRect: CGRect(x: 0, y: 0, width: 600, height: 400),
                              styleMask: [.titled, .resizable], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        window.contentView = host
        defer { window.contentView = nil; window.close(); session.testOutput.close() }
        host.layoutSubtreeIfNeeded()
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.03))
        let preview = try #require(findSceneView(host))
        let previewRenderer = try #require(preview.metalView?.delegate as? MetalRenderer)
        session.testOutput.open(for: .testWindow)
        let output = try #require(session.testOutput.window?.contentView as? TestOutputView)
        let outputRenderer = try #require(output.metalView?.delegate as? MetalRenderer)
        for renderer in [previewRenderer, outputRenderer] {
            #expect(renderer.scene == project.surface.renderScene)
            #expect(try pixels(renderer) == [[0,255,0,255],[0,0,0,255],[0,0,0,255]])
        }
        session.selectSurface(nil)
        #expect(previewRenderer.scene == outputRenderer.scene && previewRenderer.geometry == corners)
        session.resetProject()
        host.rootView = MetalScenePreview(scene: session.scene, aspectRatio: 16.0 / 9.0, outputDescription: "HD")
        host.layoutSubtreeIfNeeded()
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.03))
        #expect(findSceneView(host) === preview)
        #expect(session.testOutput.window?.contentView === output)
        for renderer in [previewRenderer, outputRenderer] {
            #expect(renderer.scene == .diagnosticGrid)
            let resetPixels = try pixels(renderer)
            #expect(resetPixels[0] != [0,0,0,255] && resetPixels[1] != [0,0,0,255])
            #expect(resetPixels[2] == [0,0,0,255]) // Mip-filtered grid; exact texels checked in warp GPU tests.
        }
        #expect(!preview.isRenderingActive && !output.isRenderingActive) // No onscreen window presentation.
        session.testOutput.close()
        session.testOutput.open(for: .testWindow)
        let reopened = try #require((session.testOutput.window?.contentView as? TestOutputView)?.metalView?.delegate as? MetalRenderer)
        #expect(reopened.scene == .diagnosticGrid)
    }

    @Test func cornerEditsReachLivePreviewAndOutputGPU() throws {
        _ = NSApplication.shared
        let session = EditorSession(presentOutput: { _ in })
        let host = NSHostingView(rootView: MetalScenePreview(scene: session.scene, aspectRatio: 1, outputDescription: "Test"))
        host.frame = CGRect(x: 0,y: 0,width: 300,height: 300)
        host.layoutSubtreeIfNeeded()
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.03))
        let preview = try #require(findSceneView(host))
        let renderer = try #require(preview.metalView?.delegate as? MetalRenderer)
        session.testOutput.open(for: .testWindow)
        defer { session.testOutput.close() }
        let output = try #require((session.testOutput.window?.contentView as? TestOutputView)?.metalView?.delegate as? MetalRenderer)
        session.selectCorner(.topLeft)
        session.moveSelectedCorner(to: SIMD2(0.35,0.4), surfaceID: session.project.surface.id)
        host.rootView = MetalScenePreview(scene: session.scene, aspectRatio: 1, outputDescription: "Test")
        host.layoutSubtreeIfNeeded()
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.03))
        for item in [renderer, output] {
            #expect(item.scene == session.scene)
            #expect(try pixels(item).first == [0,0,0,255]) // Former interior pixel is outside the edited quadrilateral.
        }
        #expect(session.scene.perspective != nil && session.scene.content == .diagnosticGrid)
        #expect(try pixels(renderer) == pixels(output))
        session.selectSurface(nil)
        #expect(renderer.scene == output.scene && session.hasUserChanges)
    }

    private func findSceneView(_ view: NSView) -> MetalSceneView? {
        if let scene = view as? MetalSceneView { return scene }
        return view.subviews.lazy.compactMap { findSceneView($0) }.first
    }
    private func pixels(_ renderer: MetalRenderer) throws -> [[UInt8]] {
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: MetalRenderer.pixelFormat,
                                                                  width: 80, height: 80, mipmapped: false)
        descriptor.storageMode = .shared; descriptor.usage = .renderTarget
        let texture = try #require(renderer.device.makeTexture(descriptor: descriptor))
        let pass = MTLRenderPassDescriptor(); pass.colorAttachments[0].texture = texture
        let command = try #require(renderer.encodeScene(to: pass))
        command.commit(); command.waitUntilCompleted()
        #expect(command.status == .completed && command.error == nil)
        return [(24,32),(40,40),(0,0)].map { x,y in
            var pixel = [UInt8](repeating: 0, count: 4)
            pixel.withUnsafeMutableBytes { texture.getBytes($0.baseAddress!, bytesPerRow: 4,
                from: MTLRegionMake2D(x,y,1,1), mipmapLevel: 0) }
            return pixel
        }
    }
}
