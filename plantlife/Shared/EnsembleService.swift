import Foundation
import Combine

final class EnsembleService {
    static func vote(_ results: [ClassifierResult]) -> (species: String, confidence: Double) {
        let grouped = Dictionary(grouping: results, by: { $0.species })
        // Majority vote by count, break ties with average confidence.
        let winner = grouped.max { lhs, rhs in
            if lhs.value.count == rhs.value.count {
                let lhsConf = lhs.value.map(\.confidence).reduce(0, +) / Double(lhs.value.count)
                let rhsConf = rhs.value.map(\.confidence).reduce(0, +) / Double(rhs.value.count)
                return lhsConf < rhsConf
            }
            return lhs.value.count < rhs.value.count
        }
        if let (species, votes) = winner {
            let avgConfidence = votes.map(\.confidence).reduce(0, +) / Double(votes.count)
            return (species, avgConfidence)
        }
        return ("Unknown", 0.0)
    }
} 