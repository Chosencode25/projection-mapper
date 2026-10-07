import Foundation
import Testing

struct CalibrationStateTests {
    @Test func configurationDefaultsBoundsAndShaderContract() {
        let defaults = CalibrationState()
        #expect(defaults.pattern == .normal && defaults.columns == 8 && defaults.rows == 8 && defaults.lineWidth == 1 && defaults.isValid)
        #expect(defaults.shaderParameters == SIMD4(0,8,8,1))
        for pattern in CalibrationPattern.allCases {
            var value = defaults; value.pattern = pattern
            #expect(value.isValid && value.shaderParameters.x == Float(pattern.rawValue))
        }
        for count in [2,64] { #expect(CalibrationState(columns: count,rows: count,lineWidth: 4).isValid) }
        for count in [-1,0,1,65,Int.max] { #expect(!CalibrationState(columns: count).isValid && !CalibrationState(rows: count).isValid) }
        for width: Float in [0,0.5,4.1,.nan,.infinity] { #expect(!CalibrationState(lineWidth: width).isValid) }
    }
    @Test func calibrationCopiesAppearanceButPreservesEveryOtherRenderValue() {
        var face = RenderSurface(geometry: .diagnostic,color: SIMD4(0.2,0.4,1,0.3),content: .particles)
        face.inputMap = FaceInputMap(origin: SIMD2(0.25,0),size: SIMD2(0.5,1),quarterTurns: 2,mirrored: true)
        face.appearance = SurfaceAppearance(opacity: 0,brightness: 0.1,crop: ContentCrop(origin: SIMD2(0.2,0),size: SIMD2(0.5,1)),flipHorizontal: true)
        face.playback.frozenTime = 99; face.sourceID = UUID()
        var scene = RenderScene(surfaces: [face])
        #expect(scene.effectiveSurfaces == [face])
        scene.calibration.pattern = .grid
        let copy = scene.effectiveSurfaces[0]
        #expect(scene.surfaces[0] == face && copy.appearance == .defaults)
        #expect(copy.geometry == face.geometry && copy.inputMap == face.inputMap && copy.generator == face.generator)
        #expect(copy.sourceID == face.sourceID && copy.playback == face.playback && copy.color == face.color && copy.content == face.content)
    }
    @Test func calibrationSchedulingHonorsFadeAndFailsClosedForInvalidState() {
        var scene = RenderScene(geometry: .diagnostic,color: SIMD4(1,0,0,1),content: .particles)
        scene.transport.setPlaying(true,at: 100)
        #expect(scene.needsContinuousRendering(at: 100))
        for pattern in CalibrationPattern.allCases where pattern.isActive {
            scene.calibration.pattern = pattern
            #expect(!scene.needsContinuousRendering(at: 100))
            scene.showOutput.fade(to: 0,duration: 4,at: 100)
            #expect(scene.needsContinuousRendering(at: 102) == (pattern != .black))
            #expect(!scene.needsContinuousRendering(at: 104))
            scene.showOutput = ShowOutputState()
        }
        scene.calibration.columns = -1
        #expect(scene.effectiveSurfaces.isEmpty && !scene.needsContinuousRendering(at: 100))
    }
}
