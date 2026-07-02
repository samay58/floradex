import Foundation
import FloradexKit

/// The fifteen-case corpus from the rewrite spec. Every real-world failure
/// later joins this catalog; a field bug's fix does not merge without its
/// fixture. Confidences are tuned against `EscalationPolicy.standard` so each
/// case exercises the pipeline path its category names.
public enum FixtureCatalog {
    public static let standard: [FixtureCase] = [
        FixtureCase(
            id: "easy-common-plant",
            category: .easyCommonPlant,
            summary: "Sharp photo of a monstera; primary provider is confident.",
            scripts: [
                .kindwise: [.candidates(
                    [IdentificationCandidate(species: FixtureFlora.monstera, confidence: 0.96, provider: .kindwise)],
                    delay: .zero
                )],
            ],
            expected: .commits(latinName: "Monstera deliciosa")
        ),
        FixtureCase(
            id: "ambiguous-plant",
            category: .ambiguousPlant,
            summary: "Heartleaf philodendron vs pothos; every provider hedges.",
            scripts: [
                .kindwise: [.candidates([
                    IdentificationCandidate(species: FixtureFlora.heartleaf, confidence: 0.45, provider: .kindwise),
                    IdentificationCandidate(species: FixtureFlora.pothos, confidence: 0.40, provider: .kindwise),
                ], delay: .zero)],
                .plantNet: [.candidates([
                    IdentificationCandidate(species: FixtureFlora.pothos, confidence: 0.42, provider: .plantNet),
                    IdentificationCandidate(species: FixtureFlora.heartleaf, confidence: 0.39, provider: .plantNet),
                ], delay: .zero)],
                .visionReasoner: [.candidates([
                    IdentificationCandidate(species: FixtureFlora.heartleaf, confidence: 0.45, provider: .visionReasoner),
                ], delay: .zero)],
            ],
            expected: .unsure(topLatinName: "Philodendron hederaceum")
        ),
        FixtureCase(
            id: "blurred-photo",
            category: .blurredPhoto,
            summary: "Motion blur; nothing crosses the likely threshold.",
            scripts: [
                .kindwise: [.candidates(
                    [IdentificationCandidate(species: FixtureFlora.monstera, confidence: 0.22, provider: .kindwise)],
                    delay: .zero
                )],
                .plantNet: [.candidates(
                    [IdentificationCandidate(species: FixtureFlora.fiddleLeaf, confidence: 0.25, provider: .plantNet)],
                    delay: .zero
                )],
                .visionReasoner: [.candidates(
                    [IdentificationCandidate(species: FixtureFlora.fiddleLeaf, confidence: 0.30, provider: .visionReasoner)],
                    delay: .zero
                )],
            ],
            expected: .unsure(topLatinName: "Ficus lyrata")
        ),
        FixtureCase(
            id: "duplicate-plant",
            category: .duplicatePlant,
            summary: "Confident match for a species already in the dex.",
            scripts: [
                .kindwise: [.candidates(
                    [IdentificationCandidate(species: FixtureFlora.monstera, confidence: 0.95, provider: .kindwise)],
                    delay: .zero
                )],
            ],
            expected: .duplicatePrompt(latinName: "Monstera deliciosa")
        ),
        FixtureCase(
            id: "no-plant-in-image",
            category: .noPlantInImage,
            summary: "A photo of a coffee mug; every provider reports no plant.",
            scripts: [
                .kindwise: [.failure(.noPlantDetected, delay: .zero)],
                .plantNet: [.failure(.noPlantDetected, delay: .zero)],
                .visionReasoner: [.failure(.noPlantDetected, delay: .zero)],
            ],
            expected: .failure(.noPlantDetected)
        ),
        FixtureCase(
            id: "provider-timeout",
            category: .providerTimeout,
            summary: "Primary hangs; secondary answers confidently.",
            scripts: [
                .kindwise: [.hang],
                .plantNet: [.candidates(
                    [IdentificationCandidate(species: FixtureFlora.monstera, confidence: 0.82, provider: .plantNet)],
                    delay: .zero
                )],
            ],
            expected: .commits(latinName: "Monstera deliciosa")
        ),
        FixtureCase(
            id: "provider-disagreement",
            category: .providerDisagreement,
            summary: "Primary and secondary split; the reasoner arbitrates.",
            scripts: [
                .kindwise: [.candidates(
                    [IdentificationCandidate(species: FixtureFlora.monstera, confidence: 0.65, provider: .kindwise)],
                    delay: .zero
                )],
                .plantNet: [.candidates(
                    [IdentificationCandidate(species: FixtureFlora.pothos, confidence: 0.68, provider: .plantNet)],
                    delay: .zero
                )],
                .visionReasoner: [.candidates(
                    [IdentificationCandidate(species: FixtureFlora.monstera, confidence: 0.70, provider: .visionReasoner)],
                    delay: .zero
                )],
            ],
            expected: .commits(latinName: "Monstera deliciosa")
        ),
        FixtureCase(
            id: "offline-capture",
            category: .offlineCapture,
            summary: "No network; capture queues for later identification.",
            isOnline: false,
            expected: .queuedOffline
        ),
        FixtureCase(
            id: "low-confidence",
            category: .lowConfidence,
            summary: "Unanimous but weak; the app leads with alternatives.",
            scripts: [
                .kindwise: [.candidates(
                    [IdentificationCandidate(species: FixtureFlora.snakePlant, confidence: 0.35, provider: .kindwise)],
                    delay: .zero
                )],
                .plantNet: [.candidates(
                    [IdentificationCandidate(species: FixtureFlora.snakePlant, confidence: 0.38, provider: .plantNet)],
                    delay: .zero
                )],
                .visionReasoner: [.candidates(
                    [IdentificationCandidate(species: FixtureFlora.snakePlant, confidence: 0.40, provider: .visionReasoner)],
                    delay: .zero
                )],
            ],
            expected: .unsure(topLatinName: "Dracaena trifasciata")
        ),
        FixtureCase(
            id: "missing-details",
            category: .missingDetails,
            summary: "Identification succeeds; the details provider fails.",
            scripts: [
                .kindwise: [.candidates(
                    [IdentificationCandidate(species: FixtureFlora.pothos, confidence: 0.90, provider: .kindwise)],
                    delay: .zero
                )],
            ],
            detailsBehavior: .failure(.timeout),
            expected: .commits(latinName: "Epipremnum aureum")
        ),
        FixtureCase(
            id: "corrupted-sprite",
            category: .corruptedSprite,
            summary: "Sprite generation returns unusable data; entry survives.",
            scripts: [
                .kindwise: [.candidates(
                    [IdentificationCandidate(species: FixtureFlora.monstera, confidence: 0.90, provider: .kindwise)],
                    delay: .zero
                )],
            ],
            spriteBehavior: .corrupted,
            expected: .commits(latinName: "Monstera deliciosa")
        ),
        FixtureCase(
            id: "long-care-text",
            category: .longCareText,
            summary: "Details arrive with pathologically long care text.",
            scripts: [
                .kindwise: [.candidates(
                    [IdentificationCandidate(species: FixtureFlora.fiddleLeaf, confidence: 0.92, provider: .kindwise)],
                    delay: .zero
                )],
            ],
            detailsBehavior: .succeed(
                summary: String(repeating: "Fiddle-leaf figs prefer bright, indirect light and consistent watering. ", count: 40),
                funFacts: [String(repeating: "Its leaves can grow to half a meter long. ", count: 20)]
            ),
            expected: .commits(latinName: "Ficus lyrata")
        ),
        FixtureCase(
            id: "small-screen",
            category: .smallScreen,
            summary: "Layout fixture for mini-class widths; driven by UI tests.",
            expected: .uiFixture
        ),
        FixtureCase(
            id: "large-dynamic-type",
            category: .largeDynamicType,
            summary: "Accessibility layout fixture at AX5; driven by UI tests.",
            expected: .uiFixture
        ),
        FixtureCase(
            id: "permission-denied",
            category: .permissionDenied,
            summary: "Camera permission denied; Settings route flow; UI-driven.",
            expected: .uiFixture
        ),
    ]
}
