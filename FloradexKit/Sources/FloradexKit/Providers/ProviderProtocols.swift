import Foundation

public protocol PlantIdentificationProvider: Sendable {
    var id: ProviderID { get }
    func identify(_ image: ImagePayload) async throws -> [IdentificationCandidate]
}

public protocol SpeciesDetailsProvider: Sendable {
    var id: ProviderID { get }
    func details(for species: Species) async throws -> SpeciesDetailsContent
}

public protocol SpriteGenerationProvider: Sendable {
    var id: ProviderID { get }
    /// Returns encoded PNG data for the pixel-art sprite.
    func sprite(for species: Species) async throws -> Data
}
