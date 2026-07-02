import Foundation

public enum Agreement: String, Hashable, Sendable, Codable {
    /// Only one provider contributed.
    case single
    case unanimous
    case majority
    case split
}

public enum ConfidenceBand: String, Hashable, Sendable, Codable {
    case confident
    case likely
    case unsure

    public static let confidentThreshold = 0.75
    public static let likelyThreshold = 0.5

    public init(_ value: Double) {
        if value >= Self.confidentThreshold {
            self = .confident
        } else if value >= Self.likelyThreshold {
            self = .likely
        } else {
            self = .unsure
        }
    }
}

public enum ResultOrigin: String, Hashable, Sendable, Codable {
    case pipeline
    case userCorrection
}

public struct IdentificationResult: Hashable, Sendable, Codable {
    public var species: Species
    public var confidence: Double
    public var agreement: Agreement
    /// Share of total vote weight held by non-winning candidates, in 0...1.
    public var dissent: Double
    /// Best candidate per non-winning species, strongest first.
    public var alternatives: [IdentificationCandidate]
    /// Every raw candidate that fed the vote, for provenance.
    public var contributing: [IdentificationCandidate]
    public var origin: ResultOrigin

    public init(
        species: Species,
        confidence: Double,
        agreement: Agreement,
        dissent: Double = 0,
        alternatives: [IdentificationCandidate] = [],
        contributing: [IdentificationCandidate] = [],
        origin: ResultOrigin = .pipeline
    ) {
        self.species = species
        self.confidence = confidence
        self.agreement = agreement
        self.dissent = dissent
        self.alternatives = alternatives
        self.contributing = contributing
        self.origin = origin
    }

    public var band: ConfidenceBand { ConfidenceBand(confidence) }

    /// Distinct providers that contributed any candidate.
    public var contributingProviderCount: Int {
        Set(contributing.map(\.provider)).count
    }

    /// Distinct providers with a candidate for the winning species; with
    /// `contributingProviderCount` this backs the "2 of 3 sources agree"
    /// trust line.
    public var agreeingProviderCount: Int {
        let key = species.normalizedKey
        return Set(contributing.filter { $0.species.normalizedKey == key }.map(\.provider)).count
    }

    /// The same result re-asserted by the user; correction is authoritative
    /// but keeps the pipeline's provenance for the fixture loop.
    public func corrected(to species: Species) -> IdentificationResult {
        var copy = self
        copy.species = species
        copy.origin = .userCorrection
        return copy
    }
}
