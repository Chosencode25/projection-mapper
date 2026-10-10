import Foundation
import simd

/// A color reference belongs to a content owner, independently of its playback identity.
struct ColorBinding: Equatable, Sendable, Codable {
    var paletteID: UUID
    var slotID: UUID
}

enum ColorChannel: String, CaseIterable, Identifiable, Sendable, Codable {
    case primary, secondary
    var id: Self { self }
    var title: String { rawValue.capitalized }
}

struct PaletteSlot: Identifiable, Equatable, Sendable, Codable {
    var id = UUID()
    var name: String
    var color: SIMD4<Float>
}

struct ColorPalette: Identifiable, Equatable, Sendable, Codable {
    var id = UUID()
    var name: String
    var slots: [PaletteSlot]
}

/// Saved configuration. Fade progress and blackout are separate session runtime state.
struct MasterOutputSettings: Equatable, Sendable, Codable {
    var brightness: Float = 1
    var fadeDuration: Double = 1
    static let defaults = Self()
    var isValid: Bool {
        brightness.isFinite && (0...1).contains(brightness) &&
        fadeDuration.isFinite && (0...30).contains(fadeDuration)
    }
}

/// Only content values are recalled; the existing owner's source ID and clock survive.
struct SourceLook: Equatable, Sendable, Codable {
    var content: SurfaceContent
    var generator: GeneratorSettings
    var color: SIMD4<Float>
    var image: ImageContent?
    var video: VideoContent?
    var primaryBinding: ColorBinding?
    var secondaryBinding: ColorBinding?
    var isValid: Bool {
        generator.isValid && (0..<4).allSatisfy { color[$0].isFinite && (0...1).contains(color[$0]) }
    }

    init(source: SurfaceSource) {
        video = source.video; image = source.image; content = source.content; generator = source.generator; color = source.color
        primaryBinding = source.primaryBinding; secondaryBinding = source.secondaryBinding
    }
    func applying(to source: SurfaceSource) -> SurfaceSource {
        var copy = source
        copy.video = video; copy.image = image; copy.content = content; copy.generator = generator; copy.color = color
        copy.primaryBinding = primaryBinding; copy.secondaryBinding = secondaryBinding
        return copy
    }
}

enum LookTargetKind: String, Sendable, Codable {
    case object, standaloneFace, memberFace
}

struct LookEntry: Equatable, Sendable, Codable {
    var targetID: UUID
    var kind: LookTargetKind
    var expectedObjectID: UUID?
    var source: SourceLook?
    /// For member faces, nil explicitly recalls inheritance from the object.
    var appearance: SurfaceAppearance?
}

struct ProjectLook: Identifiable, Equatable, Sendable, Codable {
    var id = UUID()
    var name: String
    var entries: [LookEntry]
}
