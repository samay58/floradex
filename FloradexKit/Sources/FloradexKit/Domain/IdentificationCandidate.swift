import Foundation

public struct ProviderID: RawRepresentable, Hashable, Sendable, Codable, ExpressibleByStringLiteral, CustomStringConvertible {
    public let rawValue: String

    public init(rawValue: String) {
        self.rawValue = rawValue
    }

    public init(stringLiteral value: String) {
        self.init(rawValue: value)
    }

    public var description: String { rawValue }

    public static let kindwise: ProviderID = "kindwise.plant-id"
    public static let plantNet: ProviderID = "plantnet"
    public static let visionReasoner: ProviderID = "openai.vision-reasoner"
    public static let localML: ProviderID = "local.core-ml"
    public static let spriteGenerator: ProviderID = "openai.gpt-image"
}

public struct IdentificationCandidate: Hashable, Sendable, Codable {
    public var species: Species
    /// Provider-reported confidence in 0...1.
    public var confidence: Double
    public var provider: ProviderID

    public init(species: Species, confidence: Double, provider: ProviderID) {
        self.species = species
        self.confidence = min(max(confidence, 0), 1)
        self.provider = provider
    }
}
