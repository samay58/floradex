import XCTest
import SwiftData
@testable import plantlife // Or your actual app module name

final class DexEntryTests: XCTestCase {

    @MainActor
    func testDexEntryInitialization() {
        let id = 1
        let latinName = "Monstera deliciosa"
        let createdAt = Date()
        let tags = ["Indoor", "Foliage"]
        let notes = "A beautiful plant."
        let spriteGenerationFailed = false

        let entry = DexEntry(
            id: id,
            createdAt: createdAt,
            latinName: latinName,
            tags: tags,
            notes: notes,
            spriteGenerationFailed: spriteGenerationFailed
        )

        XCTAssertEqual(entry.id, id)
        XCTAssertEqual(entry.latinName, latinName)
        XCTAssertEqual(entry.createdAt, createdAt)
        XCTAssertNil(entry.snapshot)
        XCTAssertNil(entry.sprite)
        XCTAssertEqual(entry.tags, tags)
        XCTAssertEqual(entry.notes, notes)
        XCTAssertEqual(entry.spriteGenerationFailed, spriteGenerationFailed)
    }

    @MainActor
    func testDexEntryDefaultValues() {
        let id = 2
        let latinName = "Ficus lyrata"

        // Test initialization with minimal required values
        let entry = DexEntry(id: id, latinName: latinName)

        XCTAssertEqual(entry.id, id)
        XCTAssertEqual(entry.latinName, latinName)
        XCTAssertNotNil(entry.createdAt) // Should have a default value
        XCTAssertNil(entry.snapshot)
        XCTAssertNil(entry.sprite)
        XCTAssertTrue(entry.tags.isEmpty) // Default should be empty array
        XCTAssertNil(entry.notes)
        XCTAssertFalse(entry.spriteGenerationFailed) // Default should be false
    }
    
    @MainActor
    func testDexEntryInContainer() throws {
        // Setup an in-memory container for testing SwiftData interactions
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: DexEntry.self, configurations: config)
        let context = container.mainContext

        let id = 3
        let latinName = "Pilea peperomioides"
        let newEntry = DexEntry(id: id, latinName: latinName)
        
        context.insert(newEntry)
        try context.save()
        
        let fetchDescriptor = FetchDescriptor<DexEntry>(
            predicate: #Predicate { $0.id == id }
        )
        let fetchedEntries = try context.fetch(fetchDescriptor)
        
        XCTAssertEqual(fetchedEntries.count, 1)
        XCTAssertEqual(fetchedEntries.first?.latinName, latinName)
    }
} 