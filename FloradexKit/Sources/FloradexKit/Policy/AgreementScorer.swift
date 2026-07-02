import Foundation

/// Turns raw candidates from any number of providers into a single result
/// with an honest agreement rating. Candidates are grouped by normalized
/// Latin name so spelling variants and author citations don't split votes.
public struct AgreementScorer: Sendable {
    /// Optional per-provider vote weights; unlisted providers weigh 1.0.
    public var providerWeights: [ProviderID: Double]

    public init(providerWeights: [ProviderID: Double] = [:]) {
        self.providerWeights = providerWeights
    }

    public func score(_ candidates: [IdentificationCandidate]) -> IdentificationResult? {
        guard !candidates.isEmpty else { return nil }

        let groups = Dictionary(grouping: candidates) { $0.species.normalizedKey }
        let weighted: [(key: String, weight: Double, members: [IdentificationCandidate])] = groups
            .map { key, members in
                let weight = members.reduce(0.0) { total, candidate in
                    total + candidate.confidence * (providerWeights[candidate.provider] ?? 1.0)
                }
                return (key, weight, members)
            }
            .sorted { lhs, rhs in
                if lhs.weight == rhs.weight {
                    // Tie-break on the strongest single vote, then key for determinism.
                    let lhsMax = lhs.members.map(\.confidence).max() ?? 0
                    let rhsMax = rhs.members.map(\.confidence).max() ?? 0
                    if lhsMax == rhsMax { return lhs.key < rhs.key }
                    return lhsMax > rhsMax
                }
                return lhs.weight > rhs.weight
            }

        let winner = weighted[0]
        let totalWeight = weighted.reduce(0.0) { $0 + $1.weight }
        let dissent = totalWeight > 0 ? 1.0 - (winner.weight / totalWeight) : 0.0

        let bestOfWinner = winner.members.max { $0.confidence < $1.confidence }!
        let winnerConfidence = winner.members.reduce(0.0) { $0 + $1.confidence } / Double(winner.members.count)

        let providersOverall = Set(candidates.map(\.provider))
        let providersAgreeing = Set(winner.members.map(\.provider))
        let agreement: Agreement
        if providersOverall.count == 1 {
            agreement = .single
        } else if providersAgreeing.count == providersOverall.count {
            agreement = .unanimous
        } else if providersAgreeing.count * 2 > providersOverall.count {
            agreement = .majority
        } else {
            agreement = .split
        }

        let alternatives = weighted.dropFirst().compactMap { group in
            group.members.max { $0.confidence < $1.confidence }
        }

        return IdentificationResult(
            species: bestOfWinner.species,
            confidence: winnerConfidence,
            agreement: agreement,
            dissent: dissent,
            alternatives: Array(alternatives),
            contributing: candidates
        )
    }
}
