import Foundation
import SwiftData
import os

@MainActor
final class SpeciesRepository {
    private let modelContext: ModelContext
    private static let logger = Logger(subsystem: "samayd.floradex", category: "species-repository")

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    func fetchSpeciesDetails(latinName: String) -> SpeciesDetails? {
        do {
            let predicate = #Predicate<SpeciesDetails> { $0.latinName == latinName }
            var descriptor = FetchDescriptor(predicate: predicate)
            descriptor.fetchLimit = 1
            return try modelContext.fetch(descriptor).first
        } catch {
            Self.logger.error("fetch details for \(latinName, privacy: .public): \(error, privacy: .public)")
            return nil
        }
    }

    /// Upsert keyed on `latinName` (unique attribute): fresh provider content
    /// overwrites the stored record field by field.
    func saveSpeciesDetails(_ details: SpeciesDetails) {
        if let existing = fetchSpeciesDetails(latinName: details.latinName) {
            existing.commonName = details.commonName
            existing.summary = details.summary
            existing.growthHabit = details.growthHabit
            existing.sunlight = details.sunlight
            existing.water = details.water
            existing.soil = details.soil
            existing.temperature = details.temperature
            existing.bloomTime = details.bloomTime
            existing.funFacts = details.funFacts
            existing.lastUpdated = details.lastUpdated
        } else {
            modelContext.insert(details)
        }
        do {
            try modelContext.save()
        } catch {
            Self.logger.error("save details for \(details.latinName, privacy: .public): \(error, privacy: .public)")
        }
    }
}
