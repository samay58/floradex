import Foundation
import SwiftData

actor SpeciesRepository {
    private var modelContext: ModelContext

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    func fetchSpeciesDetails(latinName: String) -> SpeciesDetails? {
        let predicate = #Predicate<SpeciesDetails> { $0.latinName == latinName }
        var descriptor = FetchDescriptor(predicate: predicate)
        descriptor.fetchLimit = 1 // We expect at most one match due to @Attribute(.unique)

        do {
            let results = try modelContext.fetch(descriptor)
            return results.first
        } catch {
            print("Failed to fetch species details for \(latinName): \(error)")
            return nil
        }
    }

    func saveSpeciesDetails(_ details: SpeciesDetails) {
        // Check if an entry with this latinName already exists
        if let existingDetails = fetchSpeciesDetails(latinName: details.latinName) {
            // Update existing record.
            // Note: This requires SpeciesDetails properties to be 'var'
            existingDetails.commonName = details.commonName
            existingDetails.summary = details.summary
            existingDetails.growthHabit = details.growthHabit
            existingDetails.sunlight = details.sunlight
            existingDetails.water = details.water
            existingDetails.soil = details.soil
            existingDetails.temperature = details.temperature
            existingDetails.bloomTime = details.bloomTime
            existingDetails.funFacts = details.funFacts
            existingDetails.lastUpdated = details.lastUpdated // Or Date() for current timestamp
            
            // SwiftData automatically tracks changes to managed objects,
            // so a separate save call might not be strictly needed if autosave is on.
            // However, explicit save can be good practice or required depending on context configuration.
            // For now, assuming changes are automatically persisted or will be handled by a higher-level save.
            print("Updated species details for \(details.latinName).")
        } else {
            // Insert new record
            modelContext.insert(details)
            print("Saved new species details for \(details.latinName).")
        }
        
        // It's good practice to explicitly save the context if autosave is not enabled or to ensure immediate persistence.
        // However, this might be better handled at a higher level (e.g., when the app goes to background).
        // For now, we'll rely on the context's autosave or a manual save elsewhere.
        // If issues arise, add `try? modelContext.save()` here.
    }

    func fetchAllSpecies() -> [SpeciesDetails] {
        let descriptor = FetchDescriptor<SpeciesDetails>(sortBy: [SortDescriptor(\SpeciesDetails.latinName)])
        do {
            return try modelContext.fetch(descriptor)
        } catch {
            print("Failed to fetch all species: \(error)")
            return []
        }
    }

    func deleteSpeciesDetails(latinName: String) {
        if let detailsToDelete = fetchSpeciesDetails(latinName: latinName) {
            modelContext.delete(detailsToDelete)
            print("Deleted species details for \(latinName).")
            // Again, explicit save might be needed here depending on configuration.
        } else {
            print("Could not find species details for \(latinName) to delete.")
        }
    }

    // Example of how you might update specific fields if needed
    func updateFunFacts(for latinName: String, funFacts: [String]?) {
        if let details = fetchSpeciesDetails(latinName: latinName) {
            details.funFacts = funFacts
            details.lastUpdated = Date() // Update timestamp
            // Context will track this change. Save explicitly if needed.
            print("Updated fun facts for \(latinName).")
        }
    }
} 