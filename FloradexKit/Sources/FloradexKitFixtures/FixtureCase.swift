import Foundation
import FloradexKit

public enum FixtureCategory: String, CaseIterable, Hashable, Sendable {
    case easyCommonPlant
    case ambiguousPlant
    case blurredPhoto
    case duplicatePlant
    case noPlantInImage
    case providerTimeout
    case providerDisagreement
    case offlineCapture
    case lowConfidence
    case missingDetails
    case corruptedSprite
    case longCareText
    case smallScreen
    case largeDynamicType
    case permissionDenied
}

public enum ExpectedOutcome: Hashable, Sendable {
    case commits(latinName: String)
    /// A provisional result is shown but banded unsure, leading with alternatives.
    case unsure(topLatinName: String)
    case failure(FlowFailure)
    case queuedOffline
    /// Identification succeeds but the species already exists in the dex.
    case duplicatePrompt(latinName: String)
    /// Exercised at the UI/E2E layer (Maestro/XCUITest), not by Kit logic.
    case uiFixture
}

public struct FixtureCase: Identifiable, Sendable {
    public var id: String
    public var category: FixtureCategory
    public var summary: String
    public var isOnline: Bool
    /// Identification scripts keyed by provider.
    public var scripts: [ProviderID: [ProviderScriptBehavior]]
    public var detailsBehavior: DetailsScriptBehavior?
    public var spriteBehavior: SpriteScriptBehavior?
    public var expected: ExpectedOutcome

    public init(
        id: String,
        category: FixtureCategory,
        summary: String,
        isOnline: Bool = true,
        scripts: [ProviderID: [ProviderScriptBehavior]] = [:],
        detailsBehavior: DetailsScriptBehavior? = nil,
        spriteBehavior: SpriteScriptBehavior? = nil,
        expected: ExpectedOutcome
    ) {
        self.id = id
        self.category = category
        self.summary = summary
        self.isOnline = isOnline
        self.scripts = scripts
        self.detailsBehavior = detailsBehavior
        self.spriteBehavior = spriteBehavior
        self.expected = expected
    }
}

/// Canned taxa shared across fixtures.
public enum FixtureFlora {
    public static let monstera = Species(
        latinName: "Monstera deliciosa",
        commonName: "Swiss cheese plant",
        family: "Araceae"
    )
    public static let pothos = Species(
        latinName: "Epipremnum aureum",
        commonName: "Golden pothos",
        family: "Araceae"
    )
    public static let heartleaf = Species(
        latinName: "Philodendron hederaceum",
        commonName: "Heartleaf philodendron",
        family: "Araceae"
    )
    public static let fiddleLeaf = Species(
        latinName: "Ficus lyrata",
        commonName: "Fiddle-leaf fig",
        family: "Moraceae"
    )
    public static let snakePlant = Species(
        latinName: "Dracaena trifasciata",
        commonName: "Snake plant",
        family: "Asparagaceae"
    )
}
