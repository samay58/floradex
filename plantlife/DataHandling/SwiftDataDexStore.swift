import Foundation
import SwiftData
import FloradexKit
import os

/// SwiftData adapter behind the Kit's `DexStore` seam, plus the app-side
/// operations the hero loop needs (details enrichment, sprite bookkeeping).
/// Single writer for the v2 schema.
@MainActor
final class SwiftDataDexStore: DexStore {
    private let modelContext: ModelContext
    private static let logger = Logger(subsystem: "samayd.floradex", category: "dex-store")

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    // MARK: - DexStore

    func commit(_ entry: ProvisionalEntry) async throws -> CommittedEntry {
        let ledger = try ledgerRecord()
        let number = DexNumber(ledger.highWaterMark + 1)
        let model = DexEntryV2(
            number: number.value,
            createdAt: entry.createdAt,
            mediaID: entry.id.rawValue,
            species: try upsertSpecies(entry.result.species),
            tags: entry.tags,
            provenance: try? JSONEncoder().encode(entry.result)
        )
        modelContext.insert(model)
        ledger.highWaterMark = number.value
        try modelContext.save()
        return CommittedEntry(
            number: number,
            id: entry.id,
            species: entry.result.species,
            result: entry.result,
            createdAt: entry.createdAt,
            tags: entry.tags
        )
    }

    func entries() async -> [CommittedEntry] {
        allModels().compactMap { committed(from: $0) }
    }

    func entry(numbered number: DexNumber) async -> CommittedEntry? {
        model(numbered: number.value).flatMap { committed(from: $0) }
    }

    func existingEntry(for species: Species) async -> CommittedEntry? {
        let key = species.normalizedKey
        return allModels()
            .first { Species.normalizeLatinName($0.species?.latinName ?? "") == key }
            .flatMap { committed(from: $0) }
    }

    func delete(_ number: DexNumber) async throws {
        guard let model = model(numbered: number.value) else {
            throw DexStoreError.unknownNumber(number)
        }
        let ledger = try ledgerRecord()
        if !ledger.retired.contains(number.value) {
            ledger.retired.append(number.value)
        }
        modelContext.delete(model)
        try modelContext.save()
    }

    func ledger() async -> DexNumberLedger {
        guard let record = try? ledgerRecord() else { return DexNumberLedger() }
        return DexNumberLedger(highWaterMark: record.highWaterMark, retired: Set(record.retired))
    }

    // MARK: - App-side operations beyond the Kit seam

    /// Fresh provider content overwrites the species record field by field;
    /// entries pick it up through the relationship.
    func updateDetails(_ content: SpeciesDetailsContent) {
        do {
            let record = try upsertSpecies(content.species)
            if let commonName = content.species.commonName { record.commonName = commonName }
            if let family = content.species.family { record.family = family }
            record.summary = content.summary
            record.sunlight = content.care.sunlight
            record.water = content.care.water
            record.soil = content.care.soil
            record.temperature = content.care.temperature
            record.bloomTime = content.care.bloomTime
            record.funFacts = content.funFacts
            record.contentProvider = content.source.provider.rawValue
            record.contentGeneratedAt = content.source.generatedAt
            try modelContext.save()
        } catch {
            Self.logger.error("update details for \(content.species.latinName, privacy: .public): \(error, privacy: .public)")
        }
    }

    func setSpriteVersion(_ version: Int, for number: DexNumber) throws {
        guard let model = model(numbered: number.value) else {
            throw DexStoreError.unknownNumber(number)
        }
        model.spriteVersion = version
        model.spriteFailed = false
        try modelContext.save()
    }

    func markSpriteFailed(for number: DexNumber) throws {
        guard let model = model(numbered: number.value) else {
            throw DexStoreError.unknownNumber(number)
        }
        model.spriteFailed = true
        try modelContext.save()
    }

    // MARK: - Internals

    private func allModels() -> [DexEntryV2] {
        let descriptor = FetchDescriptor<DexEntryV2>(sortBy: [SortDescriptor(\.number)])
        do {
            return try modelContext.fetch(descriptor)
        } catch {
            Self.logger.error("fetch entries: \(error, privacy: .public)")
            return []
        }
    }

    private func model(numbered number: Int) -> DexEntryV2? {
        var descriptor = FetchDescriptor<DexEntryV2>(predicate: #Predicate { $0.number == number })
        descriptor.fetchLimit = 1
        return try? modelContext.fetch(descriptor).first
    }

    private func upsertSpecies(_ species: Species) throws -> SpeciesRecord {
        let latinName = species.latinName
        var descriptor = FetchDescriptor<SpeciesRecord>(predicate: #Predicate { $0.latinName == latinName })
        descriptor.fetchLimit = 1
        if let existing = try modelContext.fetch(descriptor).first {
            return existing
        }
        let record = SpeciesRecord(
            latinName: species.latinName,
            commonName: species.commonName,
            family: species.family
        )
        modelContext.insert(record)
        return record
    }

    private func ledgerRecord() throws -> DexLedger {
        var descriptor = FetchDescriptor<DexLedger>()
        descriptor.fetchLimit = 1
        if let existing = try modelContext.fetch(descriptor).first {
            return existing
        }
        let ledger = DexLedger()
        modelContext.insert(ledger)
        return ledger
    }

    private func committed(from model: DexEntryV2) -> CommittedEntry? {
        let species = model.species.map {
            Species(latinName: $0.latinName, commonName: $0.commonName, family: $0.family)
        } ?? Species(latinName: "Unknown")
        let result = model.provenance.flatMap { try? JSONDecoder().decode(IdentificationResult.self, from: $0) }
            ?? IdentificationResult(species: species, confidence: 0, agreement: .single)
        return CommittedEntry(
            number: DexNumber(model.number),
            id: EntryID(rawValue: model.mediaID),
            species: species,
            result: result,
            createdAt: model.createdAt,
            tags: model.tags,
            notes: model.notes
        )
    }
}
