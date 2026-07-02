import Foundation
import Testing
@testable import FloradexKit

@Suite struct LatinNameNormalizationTests {
    @Test func dropsAuthorCitations() {
        #expect(Species.normalizeLatinName("Monstera deliciosa Liebm.") == "monstera deliciosa")
    }

    @Test func keepsInfraspecificRankPairs() {
        #expect(
            Species.normalizeLatinName("Monstera deliciosa var. borsigiana Engl.")
                == "monstera deliciosa var. borsigiana"
        )
    }

    @Test func lowercasesAndCollapsesWhitespace() {
        #expect(Species.normalizeLatinName("  EPIPREMNUM   AUREUM ") == "epipremnum aureum")
    }

    @Test func preservesHybridMarker() {
        #expect(Species.normalizeLatinName("× Fatshedera lizei") == "× fatshedera lizei")
    }
}

@Suite struct AgreementScorerTests {
    private let scorer = AgreementScorer()

    private func candidate(_ species: Species, _ confidence: Double, _ provider: ProviderID) -> IdentificationCandidate {
        IdentificationCandidate(species: species, confidence: confidence, provider: provider)
    }

    private let monstera = Species(latinName: "Monstera deliciosa")
    private let pothos = Species(latinName: "Epipremnum aureum")

    @Test func emptyInputScoresNil() {
        #expect(scorer.score([]) == nil)
    }

    @Test func singleProviderIsMarkedSingle() throws {
        let result = try #require(scorer.score([candidate(monstera, 0.9, .kindwise)]))
        #expect(result.agreement == .single)
        #expect(result.species.normalizedKey == "monstera deliciosa")
        #expect(result.confidence == 0.9)
        #expect(result.dissent == 0)
        #expect(result.alternatives.isEmpty)
    }

    @Test func spellingVariantsMergeIntoUnanimous() throws {
        let result = try #require(scorer.score([
            candidate(Species(latinName: "Monstera deliciosa"), 0.9, .kindwise),
            candidate(Species(latinName: "Monstera deliciosa Liebm."), 0.8, .plantNet),
        ]))
        #expect(result.agreement == .unanimous)
        #expect(abs(result.confidence - 0.85) < 0.0001)
        #expect(result.dissent == 0)
    }

    @Test func majorityWhenMostProvidersAgree() throws {
        let result = try #require(scorer.score([
            candidate(monstera, 0.7, .kindwise),
            candidate(monstera, 0.6, .visionReasoner),
            candidate(pothos, 0.8, .plantNet),
        ]))
        #expect(result.agreement == .majority)
        #expect(result.species.normalizedKey == "monstera deliciosa")
        #expect(result.alternatives.count == 1)
        #expect(result.alternatives[0].species.normalizedKey == "epipremnum aureum")
    }

    @Test func evenSplitIsSplitWithDissent() throws {
        let result = try #require(scorer.score([
            candidate(monstera, 0.6, .kindwise),
            candidate(pothos, 0.6, .plantNet),
        ]))
        #expect(result.agreement == .split)
        #expect(abs(result.dissent - 0.5) < 0.0001)
    }

    @Test func tieBreaksOnStrongestSingleVote() throws {
        // Equal total weight (0.8 vs 0.5 + 0.3); the single stronger vote wins.
        let result = try #require(scorer.score([
            candidate(monstera, 0.8, .kindwise),
            candidate(pothos, 0.5, .plantNet),
            candidate(pothos, 0.3, .visionReasoner),
        ]))
        #expect(result.species.normalizedKey == "monstera deliciosa")
    }

    @Test func providerWeightsShiftTheVote() throws {
        let weighted = AgreementScorer(providerWeights: [.kindwise: 2.0])
        let result = try #require(weighted.score([
            candidate(monstera, 0.6, .kindwise),
            candidate(pothos, 0.9, .plantNet),
        ]))
        // 0.6 × 2.0 = 1.2 beats 0.9.
        #expect(result.species.normalizedKey == "monstera deliciosa")
    }

    @Test func contributingPreservesAllRawCandidates() throws {
        let inputs = [
            candidate(monstera, 0.7, .kindwise),
            candidate(pothos, 0.4, .kindwise),
            candidate(monstera, 0.6, .plantNet),
        ]
        let result = try #require(scorer.score(inputs))
        #expect(result.contributing == inputs)
    }
}
