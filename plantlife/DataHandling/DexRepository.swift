import Foundation
import SwiftData
import UIKit
import os

enum DexRepositoryError: Error {
    case entryNotFound(Int)
}

@MainActor
final class DexRepository {
    private let modelContext: ModelContext
    private static let logger = Logger(subsystem: "samayd.floradex", category: "dex-repository")

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    enum DexSort {
        case numberAsc
        case newest
        case alpha
        case tag(String)
    }

    /// Persists a new entry under the next dex number. A failed save throws:
    /// the hero loop must report commit failure, never show a number that
    /// was not persisted.
    func addEntry(latinName: String, snapshot: UIImage?, tags: [String]) async throws -> DexEntry {
        let nextId = try (fetchMaxId() ?? 0) + 1
        let snapshotData = snapshot.flatMap { $0.resized(maxSide: 1024).jpegData(compressionQuality: 0.8) }
        let newEntry = DexEntry(id: nextId, latinName: latinName, snapshot: snapshotData, tags: tags)
        modelContext.insert(newEntry)
        try modelContext.save()
        return newEntry
    }

    func all(sort: DexSort = .numberAsc) -> [DexEntry] {
        do {
            switch sort {
            case .numberAsc:
                return try fetch([SortDescriptor(\DexEntry.id, order: .forward)])
            case .newest:
                return try fetch([SortDescriptor(\DexEntry.createdAt, order: .reverse)])
            case .alpha:
                return try fetch([SortDescriptor(\DexEntry.latinName, order: .forward)])
            case .tag(let tagValue):
                // Filter in memory: a #Predicate containment over the [String]
                // tags attribute is not translatable by the SwiftData store and
                // crashes at fetch time on iOS 26.
                return try fetch([SortDescriptor(\DexEntry.id)]).filter { $0.tags.contains(tagValue) }
            }
        } catch {
            Self.logger.error("fetch entries: \(error, privacy: .public)")
            return []
        }
    }

    func update(_ entry: DexEntry, tags: [String], notes: String?) {
        entry.tags = tags
        entry.notes = notes
    }

    /// The entry's number is retired, never reassigned: dex numbers are
    /// permanent, and the old renumbering pass also crashed on iOS 26 (a
    /// detached task reassigning unique ids raced context teardown).
    func delete(_ entry: DexEntry) {
        modelContext.delete(entry)
        do {
            try modelContext.save()
        } catch {
            Self.logger.error("save after delete: \(error, privacy: .public)")
        }
    }

    func updateSprite(for entryId: Int, spriteData: Data) async throws {
        let entry = try entry(withId: entryId)
        entry.sprite = spriteData
        entry.spriteGenerationFailed = false
        try modelContext.save()
    }

    func markSpriteGenerationFailed(for entryId: Int) async throws {
        let entry = try entry(withId: entryId)
        entry.spriteGenerationFailed = true
        try modelContext.save()
    }

    private func entry(withId entryId: Int) throws -> DexEntry {
        let predicate = #Predicate<DexEntry> { $0.id == entryId }
        var descriptor = FetchDescriptor(predicate: predicate)
        descriptor.fetchLimit = 1
        guard let entry = try modelContext.fetch(descriptor).first else {
            throw DexRepositoryError.entryNotFound(entryId)
        }
        return entry
    }

    private func fetch(_ sortBy: [SortDescriptor<DexEntry>]) throws -> [DexEntry] {
        try modelContext.fetch(FetchDescriptor<DexEntry>(sortBy: sortBy))
    }

    /// Highest dex number ever assigned; deletions leave gaps, so this is
    /// max(id), not a count.
    private func fetchMaxId() throws -> Int? {
        var descriptor = FetchDescriptor<DexEntry>(sortBy: [SortDescriptor(\DexEntry.id, order: .reverse)])
        descriptor.fetchLimit = 1
        return try modelContext.fetch(descriptor).first?.id
    }
}
