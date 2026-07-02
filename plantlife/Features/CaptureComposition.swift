import Foundation
import FloradexKit
import UIKit

/// Composition root for the hero loop. Real providers resolve keys through
/// the CredentialBroker (environment variables in development; the proxy
/// broker replaces this before release). `FLORADEX_FIXTURES=1` swaps in
/// canned providers so the full loop runs with no keys and no network,
/// which is also how the simulator demo works.
@MainActor
enum CaptureComposition {
    static func makeModel(
        dexRepository: DexRepository,
        speciesRepository: SpeciesRepository
    ) -> CaptureFlowModel {
        #if DEBUG
        if ProcessInfo.processInfo.environment["FLORADEX_FIXTURES"] == "1" {
            return fixtureModel(dexRepository: dexRepository, speciesRepository: speciesRepository)
        }
        #endif

        let broker = StaticCredentialBroker(
            environment: ProcessInfo.processInfo.environment,
            mapping: [
                .kindwise: "KINDWISE_API_KEY",
                .plantNet: "PLANTNET_API_KEY",
                .visionReasoner: "OPENAI_API_KEY",
                .spriteGenerator: "OPENAI_API_KEY",
            ]
        )
        let orchestrator = IdentificationOrchestrator(
            providers: [
                KindwiseProvider(broker: broker),
                PlantNetProvider(broker: broker),
                OpenAIVisionProvider(broker: broker),
            ],
            recorder: SignpostQualityRecorder()
        )
        return CaptureFlowModel(
            orchestrator: orchestrator,
            detailsProvider: OpenAIDetailsProvider(broker: broker),
            spriteProvider: OpenAISpriteProvider(broker: broker),
            dexRepository: dexRepository,
            speciesRepository: speciesRepository
        )
    }

    #if DEBUG
    private static func fixtureModel(
        dexRepository: DexRepository,
        speciesRepository: SpeciesRepository
    ) -> CaptureFlowModel {
        let monstera = Species(
            latinName: "Monstera deliciosa",
            commonName: "Swiss cheese plant",
            family: "Araceae"
        )
        let pothos = Species(
            latinName: "Epipremnum aureum",
            commonName: "Golden pothos",
            family: "Araceae"
        )
        let orchestrator = IdentificationOrchestrator(
            providers: [
                CannedIdentificationProvider(
                    id: .kindwise,
                    candidates: [
                        IdentificationCandidate(species: monstera, confidence: 0.93, provider: .kindwise),
                        IdentificationCandidate(species: pothos, confidence: 0.31, provider: .kindwise),
                    ],
                    delay: .milliseconds(900)
                ),
            ],
            recorder: SignpostQualityRecorder()
        )
        return CaptureFlowModel(
            orchestrator: orchestrator,
            detailsProvider: CannedDetailsProvider(species: monstera),
            spriteProvider: CannedSpriteProvider(),
            dexRepository: dexRepository,
            speciesRepository: speciesRepository
        )
    }
    #endif
}

#if DEBUG
struct CannedIdentificationProvider: PlantIdentificationProvider {
    let id: ProviderID
    let candidates: [IdentificationCandidate]
    let delay: Duration

    func identify(_ image: ImagePayload) async throws -> [IdentificationCandidate] {
        try await Task.sleep(for: delay)
        return candidates
    }
}

struct CannedDetailsProvider: SpeciesDetailsProvider {
    let id: ProviderID = .visionReasoner
    let species: Species

    func details(for requested: Species) async throws -> SpeciesDetailsContent {
        try await Task.sleep(for: .milliseconds(1400))
        return SpeciesDetailsContent(
            species: requested,
            summary: "A hardy climbing aroid with dramatic split leaves. Happiest with something to climb.",
            care: CareProfile(
                sunlight: "Bright, indirect light",
                water: "Water when the top soil dries",
                soil: "Chunky, well-draining mix",
                temperature: "18-27 C"
            ),
            funFacts: ["Its leaf holes are called fenestrations."],
            source: ContentSource(provider: id, generatedAt: Date())
        )
    }
}

struct CannedSpriteProvider: SpriteGenerationProvider {
    let id: ProviderID = .spriteGenerator

    func sprite(for species: Species) async throws -> Data {
        try await Task.sleep(for: .seconds(2))
        let sprite = await MainActor.run { Self.pixelSprite() }
        guard let data = sprite.pngData() else {
            throw ProviderError.invalidResponse("could not encode canned sprite")
        }
        return data
    }

    /// An 8x8 pixel plant blown up with no interpolation, echoing the
    /// retro identity without any network dependency.
    @MainActor
    private static func pixelSprite() -> UIImage {
        let grid: [[Int]] = [
            [0, 0, 1, 0, 0, 1, 0, 0],
            [0, 1, 1, 1, 1, 1, 1, 0],
            [1, 1, 2, 1, 1, 2, 1, 1],
            [0, 1, 1, 1, 1, 1, 1, 0],
            [0, 0, 1, 1, 1, 1, 0, 0],
            [0, 0, 0, 3, 3, 0, 0, 0],
            [0, 0, 3, 3, 3, 3, 0, 0],
            [0, 3, 3, 3, 3, 3, 3, 0],
        ]
        let colors: [UIColor] = [.clear, .systemGreen, .white, UIColor.brown]
        let scale: CGFloat = 16
        let size = CGSize(width: 8 * scale, height: 8 * scale)
        return UIGraphicsImageRenderer(size: size).image { context in
            for (y, row) in grid.enumerated() {
                for (x, value) in row.enumerated() where value > 0 {
                    colors[value].setFill()
                    context.fill(CGRect(x: CGFloat(x) * scale, y: CGFloat(y) * scale, width: scale, height: scale))
                }
            }
        }
    }
}
#endif
