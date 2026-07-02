import Foundation

public struct CareProfile: Hashable, Sendable, Codable {
    public var sunlight: String?
    public var water: String?
    public var soil: String?
    public var temperature: String?
    public var bloomTime: String?

    public init(
        sunlight: String? = nil,
        water: String? = nil,
        soil: String? = nil,
        temperature: String? = nil,
        bloomTime: String? = nil
    ) {
        self.sunlight = sunlight
        self.water = water
        self.soil = soil
        self.temperature = temperature
        self.bloomTime = bloomTime
    }

    public var isEmpty: Bool {
        sunlight == nil && water == nil && soil == nil && temperature == nil && bloomTime == nil
    }
}

public struct ContentSource: Hashable, Sendable, Codable {
    public var provider: ProviderID
    public var generatedAt: Date

    public init(provider: ProviderID, generatedAt: Date) {
        self.provider = provider
        self.generatedAt = generatedAt
    }
}

public struct SpeciesDetailsContent: Hashable, Sendable, Codable {
    public var species: Species
    public var summary: String?
    public var care: CareProfile
    public var funFacts: [String]
    public var source: ContentSource

    public init(
        species: Species,
        summary: String? = nil,
        care: CareProfile = CareProfile(),
        funFacts: [String] = [],
        source: ContentSource
    ) {
        self.species = species
        self.summary = summary
        self.care = care
        self.funFacts = funFacts
        self.source = source
    }
}

public struct ImagePayload: Hashable, Sendable {
    public enum Format: String, Hashable, Sendable, Codable {
        case heic, jpeg, png
    }

    public var format: Format
    public var data: Data

    public init(format: Format, data: Data) {
        self.format = format
        self.data = data
    }
}
