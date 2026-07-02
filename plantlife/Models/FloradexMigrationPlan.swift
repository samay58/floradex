import Foundation
import SwiftData
import FloradexKit

enum FloradexMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] {
        [FloradexSchemaV1.self, FloradexSchemaV2.self]
    }

    static var stages: [MigrationStage] {
        [v1ToV2]
    }

    /// Where the v1 image blobs land on disk. Overridable so the migration
    /// test can point at a temporary directory.
    nonisolated(unsafe) static var mediaRoot: URL = MediaLocations.root

    // Carried from willMigrate (reads v1, exports media) to didMigrate
    // (patches v2). Migration runs once, single-threaded, then clears these.
    nonisolated(unsafe) private static var mediaAssignments: [Int: (mediaID: UUID, hasSprite: Bool)] = [:]
    nonisolated(unsafe) private static var latinNameByNumber: [Int: String] = [:]
    nonisolated(unsafe) private static var speciesSnapshots: [String: SpeciesSnapshot] = [:]

    private struct SpeciesSnapshot {
        var commonName: String?
        var summary: String?
        var sunlight: String?
        var water: String?
        var soil: String?
        var temperature: String?
        var bloomTime: String?
        var funFacts: [String]
        var lastUpdated: Date
    }

    static let v1ToV2 = MigrationStage.custom(
        fromVersion: FloradexSchemaV1.self,
        toVersion: FloradexSchemaV2.self,
        willMigrate: { context in
            let paths = MediaPathPolicy(root: mediaRoot)
            let fileManager = FileManager.default

            for entry in try context.fetch(FetchDescriptor<FloradexSchemaV1.DexEntry>()) {
                let mediaID = UUID()
                let entryID = EntryID(rawValue: mediaID)
                if let snapshot = entry.snapshot {
                    try fileManager.createDirectory(at: paths.photoDirectory(for: entryID), withIntermediateDirectories: true)
                    try snapshot.write(to: paths.originalPhotoURL(for: entryID), options: .atomic)
                }
                var hasSprite = false
                if let sprite = entry.sprite {
                    try fileManager.createDirectory(at: paths.spriteDirectory(for: entryID), withIntermediateDirectories: true)
                    try sprite.write(to: paths.spriteURL(for: entryID, version: 1), options: .atomic)
                    hasSprite = true
                }
                mediaAssignments[entry.id] = (mediaID, hasSprite)
                latinNameByNumber[entry.id] = entry.latinName
            }

            for details in try context.fetch(FetchDescriptor<FloradexSchemaV1.SpeciesDetails>()) {
                speciesSnapshots[details.latinName] = SpeciesSnapshot(
                    commonName: details.commonName,
                    summary: details.summary,
                    sunlight: details.sunlight,
                    water: details.water,
                    soil: details.soil,
                    temperature: details.temperature,
                    bloomTime: details.bloomTime,
                    funFacts: details.funFacts ?? [],
                    lastUpdated: details.lastUpdated
                )
            }
        },
        didMigrate: { context in
            var records: [String: FloradexSchemaV2.SpeciesRecord] = [:]
            func record(for latinName: String) -> FloradexSchemaV2.SpeciesRecord {
                if let existing = records[latinName] { return existing }
                let snapshot = speciesSnapshots[latinName]
                let record = FloradexSchemaV2.SpeciesRecord(
                    latinName: latinName,
                    commonName: snapshot?.commonName,
                    summary: snapshot?.summary,
                    sunlight: snapshot?.sunlight,
                    water: snapshot?.water,
                    soil: snapshot?.soil,
                    temperature: snapshot?.temperature,
                    bloomTime: snapshot?.bloomTime,
                    funFacts: snapshot?.funFacts ?? [],
                    contentGeneratedAt: snapshot?.lastUpdated
                )
                context.insert(record)
                records[latinName] = record
                return record
            }

            let entries = try context.fetch(FetchDescriptor<FloradexSchemaV2.DexEntry>())
            for entry in entries {
                if let assignment = mediaAssignments[entry.number] {
                    entry.mediaID = assignment.mediaID
                    entry.spriteVersion = assignment.hasSprite ? 1 : 0
                }
                if let latinName = latinNameByNumber[entry.number] {
                    entry.species = record(for: latinName)
                }
            }

            // Cached care content for species with no surviving entries is
            // still worth carrying over.
            for latinName in speciesSnapshots.keys where records[latinName] == nil {
                _ = record(for: latinName)
            }

            // Existing numbers freeze as-is; gaps become tombstones so new
            // numbers continue from the high-water mark.
            let highWaterMark = entries.map(\.number).max() ?? 0
            let present = Set(entries.map(\.number))
            let retired = highWaterMark > 0 ? (1...highWaterMark).filter { !present.contains($0) } : []
            context.insert(FloradexSchemaV2.DexLedger(highWaterMark: highWaterMark, retired: retired))

            try context.save()
            mediaAssignments = [:]
            latinNameByNumber = [:]
            speciesSnapshots = [:]
        }
    )
}
