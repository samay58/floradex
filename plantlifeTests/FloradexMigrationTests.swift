import XCTest
import SwiftData
import FloradexKit
@testable import plantlife

/// Seeds a real on-disk v1 store, reopens it through the migration plan,
/// and asserts numbers, relationships, media, and the ledger survive.
@MainActor
final class FloradexMigrationTests: XCTestCase {
    private var workDirectory: URL!
    private var storeURL: URL!
    private var mediaRoot: URL!

    override func setUp() async throws {
        workDirectory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        try FileManager.default.createDirectory(at: workDirectory, withIntermediateDirectories: true)
        storeURL = workDirectory.appending(path: "floradex.store")
        mediaRoot = workDirectory.appending(path: "media")
        FloradexMigrationPlan.mediaRoot = mediaRoot
    }

    override func tearDown() async throws {
        FloradexMigrationPlan.mediaRoot = MediaLocations.root
        try? FileManager.default.removeItem(at: workDirectory)
    }

    private let snapshotBytes = Data("jpeg-bytes".utf8)
    private let spriteBytes = Data("png-bytes".utf8)

    private func seedV1() throws {
        let schema = Schema(versionedSchema: FloradexSchemaV1.self)
        let container = try ModelContainer(
            for: schema,
            configurations: [ModelConfiguration(schema: schema, url: storeURL)]
        )
        let context = container.mainContext
        context.insert(FloradexSchemaV1.DexEntry(
            id: 1,
            latinName: "Monstera deliciosa",
            snapshot: snapshotBytes,
            sprite: spriteBytes,
            tags: ["Indoor"]
        ))
        context.insert(FloradexSchemaV1.DexEntry(id: 2, latinName: "Ficus lyrata"))
        // Numbers 3 and 4 were deleted before migration; the gap must survive.
        context.insert(FloradexSchemaV1.DexEntry(id: 5, latinName: "Monstera deliciosa", notes: "second monstera"))
        context.insert(FloradexSchemaV1.SpeciesDetails(
            latinName: "Monstera deliciosa",
            commonName: "Swiss cheese plant",
            sunlight: "Bright, indirect light",
            funFacts: ["Leaf holes are called fenestrations."]
        ))
        try context.save()
    }

    func testV1ToV2PreservesNumbersRelationshipsMediaAndLedger() throws {
        try seedV1()

        let schema = Schema(versionedSchema: FloradexSchemaV2.self)
        let container = try ModelContainer(
            for: schema,
            migrationPlan: FloradexMigrationPlan.self,
            configurations: [ModelConfiguration(schema: schema, url: storeURL)]
        )
        let context = container.mainContext

        let entries = try context.fetch(
            FetchDescriptor<FloradexSchemaV2.DexEntry>(sortBy: [SortDescriptor(\.number)])
        )
        XCTAssertEqual(entries.map(\.number), [1, 2, 5], "numbers freeze as-is at migration")

        let first = try XCTUnwrap(entries.first)
        XCTAssertEqual(first.species?.latinName, "Monstera deliciosa")
        XCTAssertEqual(first.species?.commonName, "Swiss cheese plant", "care content carries over")
        XCTAssertEqual(first.species?.funFacts, ["Leaf holes are called fenestrations."])
        XCTAssertEqual(first.tags, ["Indoor"])
        XCTAssertEqual(first.spriteVersion, 1, "v1 sprite blob becomes sprite-v1 on disk")
        XCTAssertEqual(entries[1].spriteVersion, 0)
        XCTAssertEqual(entries[1].species?.latinName, "Ficus lyrata", "species without cached details get a bare record")
        XCTAssertEqual(entries[2].notes, "second monstera")
        XCTAssertEqual(
            entries[0].species?.persistentModelID,
            entries[2].species?.persistentModelID,
            "entries of one species share one record"
        )

        let ledgers = try context.fetch(FetchDescriptor<FloradexSchemaV2.DexLedger>())
        XCTAssertEqual(ledgers.count, 1)
        XCTAssertEqual(ledgers.first?.highWaterMark, 5)
        XCTAssertEqual(Set(ledgers.first?.retired ?? []), [3, 4], "gaps become tombstones")

        let paths = MediaPathPolicy(root: mediaRoot)
        let photoURL = paths.originalPhotoURL(for: EntryID(rawValue: first.mediaID))
        XCTAssertEqual(try Data(contentsOf: photoURL), snapshotBytes, "photo blob exported to disk")
        let spriteURL = paths.spriteURL(for: EntryID(rawValue: first.mediaID), version: 1)
        XCTAssertEqual(try Data(contentsOf: spriteURL), spriteBytes, "sprite blob exported to disk")
    }
}
