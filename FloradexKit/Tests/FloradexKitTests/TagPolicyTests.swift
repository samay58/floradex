import Foundation
import Testing
@testable import FloradexKit

@Suite struct TagPolicyTests {
    private func content(
        summary: String? = nil,
        sunlight: String? = nil,
        water: String? = nil,
        temperature: String? = nil,
        bloomTime: String? = nil
    ) -> SpeciesDetailsContent {
        SpeciesDetailsContent(
            species: Species(latinName: "Monstera deliciosa"),
            summary: summary,
            care: CareProfile(
                sunlight: sunlight,
                water: water,
                temperature: temperature,
                bloomTime: bloomTime
            ),
            funFacts: [],
            source: ContentSource(provider: .visionReasoner, generatedAt: Date(timeIntervalSince1970: 0))
        )
    }

    @Test func brightClimberGetsLightAndHabitTags() {
        let tags = TagPolicy.tags(for: content(
            summary: "A hardy climbing aroid with dramatic split leaves.",
            sunlight: "Bright, indirect light",
            water: "Water when the top soil dries"
        ))
        #expect(tags.contains("Climbing"))
        #expect(tags.contains("Foliage"))
        // "indirect" wins over "bright": the low-light branch matches first.
        #expect(tags.contains("Low Light"))
    }

    @Test func droughtToleranceImpliesEasyCare() {
        let tags = TagPolicy.tags(for: content(summary: "A drought-loving succulent.", water: "Low; drought tolerant"))
        #expect(tags.contains("Low Water"))
        #expect(tags.contains("Easy Care"))
        #expect(tags.contains("Succulent"))
    }

    @Test func bloomTimeYieldsSeasonalTagInsteadOfFoliage() {
        let tags = TagPolicy.tags(for: content(bloomTime: "Late spring"))
        #expect(tags.contains("Flowering"))
        #expect(tags.contains("Spring Bloomer"))
        #expect(!tags.contains("Foliage"))
    }

    @Test func neverExceedsTheCapAndStaysDeterministic() {
        let rich = content(
            summary: "A tropical climbing tree-like shrub succulent herb.",
            sunlight: "Bright full sun",
            water: "High, keep moist",
            temperature: "Warm tropical",
            bloomTime: "Year-round"
        )
        let once = TagPolicy.tags(for: rich)
        #expect(once.count <= TagPolicy.maxTags)
        #expect(once == TagPolicy.tags(for: rich))
    }
}
