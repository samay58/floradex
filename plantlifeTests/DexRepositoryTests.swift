import XCTest
import SwiftData
import UIKit // For UIImage if snapshot testing is done with actual images
@testable import plantlife // Replace with your app module name

@MainActor
final class DexRepositoryTests: XCTestCase {

    var modelContainer: ModelContainer!
    var repository: DexRepository!

    override func setUpWithError() throws {
        try super.setUpWithError()
        // Setup an in-memory container for testing
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        modelContainer = try ModelContainer(for: DexEntry.self, configurations: config)
        repository = DexRepository(modelContext: modelContainer.mainContext)
    }

    override func tearDownWithError() throws {
        repository = nil
        modelContainer = nil
        try super.tearDownWithError()
    }

    func testAddEntryAndAutoIncrementId() async throws {
        let entry1 = try await repository.addEntry(latinName: "Monstera deliciosa", snapshot: nil, tags: ["Indoor"])
        XCTAssertEqual(entry1.id, 1)
        XCTAssertEqual(entry1.latinName, "Monstera deliciosa")

        let entry2 = try await repository.addEntry(latinName: "Ficus lyrata", snapshot: nil, tags: ["Office"])
        XCTAssertEqual(entry2.id, 2)
        XCTAssertEqual(entry2.latinName, "Ficus lyrata")
        
        // Verify they are in the context
        let allEntries = repository.all()
        XCTAssertEqual(allEntries.count, 2)
    }

    func testGetAllEntriesSorted() async throws {
        // Add entries in a specific order
        _ = try await repository.addEntry(latinName: "Zamioculcas zamiifolia", snapshot: nil, tags: []) // ID 1, added first
        try await Task.sleep(for: .milliseconds(10)) // Ensure createdAt is different
        _ = try await repository.addEntry(latinName: "Aloe vera", snapshot: nil, tags: ["Medicinal"]) // ID 2, added second
        try await Task.sleep(for: .milliseconds(10))
        let entryC = try await repository.addEntry(latinName: "Crassula ovata", snapshot: nil, tags: ["Succulent"]) // ID 3, added third

        // Test sort by ID (numberAsc - default)
        var sortedEntries = repository.all()
        XCTAssertEqual(sortedEntries.map { $0.id }, [1, 2, 3])

        // Test sort by newest
        sortedEntries = repository.all(sort: .newest)
        XCTAssertEqual(sortedEntries.map { $0.id }, [3, 2, 1])

        // Test sort by alpha (latinName)
        sortedEntries = repository.all(sort: .alpha)
        XCTAssertEqual(sortedEntries.map { $0.latinName }, ["Aloe vera", "Crassula ovata", "Zamioculcas zamiifolia"])
        
        // Test sort by tag (which is filtering in current impl)
        let taggedEntries = repository.all(sort: .tag("Succulent"))
        XCTAssertEqual(taggedEntries.count, 1)
        XCTAssertEqual(taggedEntries.first?.id, entryC.id)
        XCTAssertEqual(taggedEntries.first?.latinName, "Crassula ovata")
        
        let taggedEntriesNonExistent = repository.all(sort: .tag("NonExistentTag"))
        XCTAssertTrue(taggedEntriesNonExistent.isEmpty)
    }

    func testUpdateEntry() async throws {
        let initialEntry = try await repository.addEntry(latinName: "Sansevieria trifasciata", snapshot: nil, tags: ["Bedroom"], notes: "Original note")
        let entryId = initialEntry.id

        let newTags = ["Bedroom", "Low Light"]
        let newNotes = "Updated care instructions."
        
        // Fetch the entry to update it (simulating a real scenario where you'd fetch then update)
        var fetchedEntry = repository.all().first { $0.id == entryId }!
        
        repository.update(fetchedEntry, tags: newTags, notes: newNotes)
        try modelContainer.mainContext.save() // Explicitly save to ensure changes are written for re-fetch

        // Re-fetch to verify changes
        fetchedEntry = repository.all().first { $0.id == entryId }!
        XCTAssertEqual(fetchedEntry.tags, newTags)
        XCTAssertEqual(fetchedEntry.notes, newNotes)
    }

    func testDeleteEntry() async throws {
        let entryToDelete = try await repository.addEntry(latinName: "Pothos aureus", snapshot: nil, tags: ["Easy Care"])
        _ = try await repository.addEntry(latinName: "Monstera deliciosa", snapshot: nil, tags: ["Indoor"])
        
        var allEntries = repository.all()
        XCTAssertEqual(allEntries.count, 2)

        repository.delete(entryToDelete)
        try modelContainer.mainContext.save() // Explicitly save to ensure changes are written
        
        allEntries = repository.all()
        XCTAssertEqual(allEntries.count, 1)
        XCTAssertNil(allEntries.first { $0.latinName == "Pothos aureus" })
        XCTAssertNotNil(allEntries.first { $0.latinName == "Monstera deliciosa" })
    }
    
    func testAddEntryWithSnapshot() async throws {
        // Create a dummy UIImage
        let rect = CGRect(x: 0, y: 0, width: 1, height: 1)
        UIGraphicsBeginImageContextWithOptions(rect.size, false, 0.0)
        UIColor.red.setFill()
        UIRectFill(rect)
        let image = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        XCTAssertNotNil(image, "Dummy image creation failed")

        let entry = try await repository.addEntry(latinName: "Test Plant with Image", snapshot: image, tags: ["Test"])
        XCTAssertNotNil(entry.snapshot, "Snapshot data should not be nil")
        XCTAssertTrue((entry.snapshot?.count ?? 0) > 0, "Snapshot data should not be empty")
        
        // You could also try to re-initialize a UIImage from entry.snapshot to verify integrity if needed
        // let rehydratedImage = UIImage(data: entry.snapshot!)
        // XCTAssertNotNil(rehydratedImage)
    }
} 