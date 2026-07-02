import Foundation
import SwiftData
import UIKit // For UIImage

@MainActor // To ensure modelContext access is on the main thread
class DexRepository {
    private var modelContext: ModelContext

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    enum DexSort {
        case numberAsc
        case newest
        case alpha
        case tag(String)
    }

    /// Adds a new DexEntry to the store.
    /// ID is auto-incremented.
    func addEntry(latinName: String, snapshot: UIImage?, tags: [String]) async throws -> DexEntry {
        let nextId = ((try? fetchMaxId()) ?? 0) + 1
        
        var snapshotData: Data? = nil
        if let img = snapshot {
            // Assuming UIImage.resized(maxSide:) exists and handles compression for ≤1MB
            // And that it returns JPEG data
            snapshotData = img.resized(maxSide: 1024).jpegData(compressionQuality: 0.8) // Adjust params as needed
        }

        let newEntry = DexEntry(id: nextId, 
                                latinName: latinName, 
                                snapshot: snapshotData, 
                                tags: tags)
        modelContext.insert(newEntry)
        do {
            try modelContext.save()
        } catch {
            print("DexRepository: failed to save context after insert: \(error)")
        }
        return newEntry
    }

    /// Fetches all DexEntry items, sorted as specified.
    func all(sort: DexSort = .numberAsc) -> [DexEntry] {
        var sortDescriptors: [SortDescriptor<DexEntry>] = []

        switch sort {
        case .numberAsc:
            sortDescriptors.append(SortDescriptor(\DexEntry.id, order: .forward))
        case .newest:
            sortDescriptors.append(SortDescriptor(\DexEntry.createdAt, order: .reverse))
        case .alpha:
            sortDescriptors.append(SortDescriptor(\DexEntry.latinName, order: .forward))
        case .tag(let tagValue):
            // Filter in memory: a #Predicate containment over the [String]
            // tags attribute is not translatable by the SwiftData store and
            // crashes at fetch time on iOS 26.
            let fetchDescriptor = FetchDescriptor<DexEntry>(sortBy: [SortDescriptor(\DexEntry.id)])
            do {
                return try modelContext.fetch(fetchDescriptor).filter { $0.tags.contains(tagValue) }
            } catch {
                print("Error fetching entries by tag: \(error)")
                return []
            }
        }
        
        let fetchDescriptor = FetchDescriptor<DexEntry>(sortBy: sortDescriptors)
        do {
            return try modelContext.fetch(fetchDescriptor)
        } catch {
            print("Error fetching all entries: \(error)")
            return []
        }
    }

    /// Updates an existing DexEntry.
    func update(_ entry: DexEntry, tags: [String], notes: String?) {
        // SwiftData tracks changes to managed objects automatically.
        // We just need to modify the properties of the 'entry' instance.
        entry.tags = tags
        entry.notes = notes
        // entry.createdAt = Date() // Optionally update timestamp on modification
        // try? modelContext.save() // if explicit save is desired
    }

    /// Deletes a specific DexEntry from the store. The entry's number is
    /// retired, never reassigned: dex numbers are permanent, and the old
    /// renumbering pass also crashed on iOS 26 (a detached task reassigning
    /// unique ids raced context teardown).
    func delete(_ entry: DexEntry) {
        modelContext.delete(entry)
        do {
            try modelContext.save()
        } catch {
            print("DexRepository: failed to save context after delete: \(error)")
        }
    }
    
    /// Updates the sprite data for a specific DexEntry.
    func updateSprite(for entryId: Int, spriteData: Data) async throws {
        let predicate = #Predicate<DexEntry> { $0.id == entryId }
        var fetchDescriptor = FetchDescriptor(predicate: predicate)
        fetchDescriptor.fetchLimit = 1
        
        guard let entryToUpdate = try modelContext.fetch(fetchDescriptor).first else {
            print("[DexRepository] Error: DexEntry with ID \(entryId) not found for sprite update.")
            enum UpdateError: Error { case entryNotFound }
            throw UpdateError.entryNotFound
        }
        entryToUpdate.sprite = spriteData
        entryToUpdate.spriteGenerationFailed = false // Reset failure flag on successful update
        print("[DexRepository] Attempting to save sprite for DexEntry ID: \(entryId). Sprite data size: \(spriteData.count)")
        do {
            try modelContext.save()
            print("[DexRepository] Successfully saved sprite for DexEntry ID: \(entryId) to context.")
        } catch {
            print("[DexRepository] Failed to save context after sprite update for ID \(entryId): \(error)")
            throw error // Re-throw
        }
    }

    /// Marks sprite generation as failed for a specific DexEntry.
    func markSpriteGenerationFailed(for entryId: Int) async throws {
        let predicate = #Predicate<DexEntry> { $0.id == entryId }
        var fetchDescriptor = FetchDescriptor(predicate: predicate)
        fetchDescriptor.fetchLimit = 1
        
        guard let entryToUpdate = try modelContext.fetch(fetchDescriptor).first else {
            print("[DexRepository] Error: DexEntry with ID \(entryId) not found to mark sprite generation failed.")
            enum UpdateError: Error { case entryNotFound }
            throw UpdateError.entryNotFound
        }
        entryToUpdate.spriteGenerationFailed = true
        do {
            try modelContext.save()
            print("[DexRepository] Marked sprite generation failed for DexEntry ID: \(entryId)")
        } catch {
            print("[DexRepository] Failed to save context after marking failure: \(error)")
            throw error
        }
    }

    /// Fetches the maximum ID currently in use.
    private func fetchMaxId() throws -> Int? {
        let descriptor = FetchDescriptor<DexEntry>(sortBy: [SortDescriptor(\DexEntry.id, order: .reverse)])
        // No, we need to use .max aggregation for this not fetch descriptor!
        // This is wrong. How to get max id in swiftdata?
        // Actually, fetching all and taking last is inefficient.
        // Let's try another approach if a direct max aggregate isn't straightforward
        // for a simple property or if we want to avoid complex predicates for now.
        
        // A simple way, though potentially inefficient for very large datasets:
        let allEntries = try modelContext.fetch(FetchDescriptor<DexEntry>(sortBy: [SortDescriptor(\DexEntry.id, order: .reverse)]))
        return allEntries.first?.id

        // A more SwiftData-idiomatic way would involve aggregates if available and simple,
        // or ensuring IDs are generated in a way that doesn't require querying max each time
        // (e.g. UUIDs, or server-generated if applicable, or a separate sequence object).
        // For now, the above sort and pick first is a common workaround for auto-incrementing style IDs.
    }

}