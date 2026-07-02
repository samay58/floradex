import XCTest
import SwiftData
import FloradexKit
@testable import plantlife

@MainActor
final class SwiftDataDexStoreTests: XCTestCase {
    private var container: ModelContainer!
    private var store: SwiftDataDexStore!

    override func setUp() async throws {
        let schema = Schema(versionedSchema: FloradexSchemaV2.self)
        container = try ModelContainer(
            for: schema,
            configurations: [ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)]
        )
        store = SwiftDataDexStore(modelContext: container.mainContext)
    }

    private func provisional(latinName: String, commonName: String? = nil, tags: [String] = []) -> ProvisionalEntry {
        ProvisionalEntry(
            captureID: CaptureID(),
            result: IdentificationResult(
                species: Species(latinName: latinName, commonName: commonName),
                confidence: 0.9,
                agreement: .single
            ),
            createdAt: Date(timeIntervalSince1970: 1_700_000_000),
            tags: tags
        )
    }

    func testCommitAssignsMonotonicNumbersAndSharesSpeciesRecords() async throws {
        let first = try await store.commit(provisional(latinName: "Monstera deliciosa", commonName: "Swiss cheese plant"))
        let second = try await store.commit(provisional(latinName: "Ficus lyrata"))
        let third = try await store.commit(provisional(latinName: "Monstera deliciosa"))

        XCTAssertEqual([first.number.value, second.number.value, third.number.value], [1, 2, 3])

        let records = try container.mainContext.fetch(FetchDescriptor<SpeciesRecord>())
        XCTAssertEqual(records.count, 2, "same species upserts into one record")
        let monstera = try XCTUnwrap(records.first { $0.latinName == "Monstera deliciosa" })
        XCTAssertEqual(monstera.entries.count, 2)
    }

    func testDeleteRetiresTheNumberForever() async throws {
        _ = try await store.commit(provisional(latinName: "Monstera deliciosa"))
        _ = try await store.commit(provisional(latinName: "Ficus lyrata"))

        try await store.delete(DexNumber(1))
        let afterDelete = try await store.commit(provisional(latinName: "Dracaena trifasciata"))

        XCTAssertEqual(afterDelete.number.value, 3, "a retired number is never reassigned")
        let ledger = await store.ledger()
        XCTAssertTrue(ledger.isRetired(DexNumber(1)))
        XCTAssertEqual(ledger.highWaterMark, 3)
        XCTAssertEqual(ledger.activeCount, 2)
        let remaining = await store.entries()
        XCTAssertEqual(remaining.map(\.number.value), [2, 3])
    }

    func testDeletingUnknownNumberThrows() async {
        do {
            try await store.delete(DexNumber(9))
            XCTFail("expected unknownNumber")
        } catch let error as DexStoreError {
            XCTAssertEqual(error, .unknownNumber(DexNumber(9)))
        } catch {
            XCTFail("unexpected error \(error)")
        }
    }

    func testDuplicateDetectionMatchesNormalizedLatinName() async throws {
        let committed = try await store.commit(provisional(latinName: "Monstera deliciosa"))

        // Author citation must not defeat the match.
        let existing = await store.existingEntry(for: Species(latinName: "Monstera deliciosa Liebm."))
        XCTAssertEqual(existing?.number, committed.number)

        let missing = await store.existingEntry(for: Species(latinName: "Ficus lyrata"))
        XCTAssertNil(missing)
    }

    func testDetailsUpdateEnrichesTheSpeciesRecord() async throws {
        _ = try await store.commit(provisional(latinName: "Monstera deliciosa"))

        store.updateDetails(SpeciesDetailsContent(
            species: Species(latinName: "Monstera deliciosa", commonName: "Swiss cheese plant", family: "Araceae"),
            summary: "A hardy climbing aroid.",
            care: CareProfile(sunlight: "Bright, indirect light", water: "When the top soil dries"),
            funFacts: ["Fenestrations!"],
            source: ContentSource(provider: .visionReasoner, generatedAt: Date(timeIntervalSince1970: 1_700_000_500))
        ))

        let entries = await store.entries()
        let record = try container.mainContext.fetch(FetchDescriptor<SpeciesRecord>()).first
        XCTAssertEqual(entries.count, 1)
        XCTAssertEqual(record?.commonName, "Swiss cheese plant")
        XCTAssertEqual(record?.family, "Araceae")
        XCTAssertEqual(record?.sunlight, "Bright, indirect light")
        XCTAssertEqual(record?.contentProvider, ProviderID.visionReasoner.rawValue)
    }

    func testSpriteBookkeeping() async throws {
        let committed = try await store.commit(provisional(latinName: "Monstera deliciosa"))

        try store.setSpriteVersion(1, for: committed.number)
        var model = try XCTUnwrap(container.mainContext.fetch(FetchDescriptor<DexEntryV2>()).first)
        XCTAssertEqual(model.spriteVersion, 1)
        XCTAssertFalse(model.spriteFailed)

        try store.markSpriteFailed(for: committed.number)
        model = try XCTUnwrap(container.mainContext.fetch(FetchDescriptor<DexEntryV2>()).first)
        XCTAssertTrue(model.spriteFailed)
    }
}
