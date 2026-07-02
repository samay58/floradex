import Foundation
import SwiftData

/// Media lives on disk, keyed by each entry's `mediaID`; only that key is
/// persisted, so container-path changes across reinstalls can't orphan files.
nonisolated enum MediaLocations {
    static var root: URL {
        URL.applicationSupportDirectory.appending(path: "FloradexMedia", directoryHint: .isDirectory)
    }
}

// MARK: - v1 (the shipped shape; exists only so the migration can read it)

enum FloradexSchemaV1: VersionedSchema {
    static let versionIdentifier = Schema.Version(1, 0, 0)
    static var models: [any PersistentModel.Type] {
        [DexEntry.self, SpeciesDetails.self]
    }

    @Model
    final class DexEntry {
        @Attribute(.unique) var id: Int
        var createdAt: Date
        var latinName: String
        var snapshot: Data?
        var sprite: Data?
        var tags: [String]
        var notes: String?
        var spriteGenerationFailed: Bool

        init(id: Int,
             createdAt: Date = .now,
             latinName: String,
             snapshot: Data? = nil,
             sprite: Data? = nil,
             tags: [String] = [],
             notes: String? = nil,
             spriteGenerationFailed: Bool = false) {
            self.id = id
            self.createdAt = createdAt
            self.latinName = latinName
            self.snapshot = snapshot
            self.sprite = sprite
            self.tags = tags
            self.notes = notes
            self.spriteGenerationFailed = spriteGenerationFailed
        }
    }

    @Model
    final class SpeciesDetails {
        @Attribute(.unique) var latinName: String
        var commonName: String?
        var summary: String?
        var growthHabit: String?
        var sunlight: String?
        var water: String?
        var soil: String?
        var temperature: String?
        var bloomTime: String?
        var funFacts: [String]?
        var lastUpdated: Date

        init(latinName: String,
             commonName: String? = nil,
             summary: String? = nil,
             growthHabit: String? = nil,
             sunlight: String? = nil,
             water: String? = nil,
             soil: String? = nil,
             temperature: String? = nil,
             bloomTime: String? = nil,
             funFacts: [String]? = nil,
             lastUpdated: Date = Date()) {
            self.latinName = latinName
            self.commonName = commonName
            self.summary = summary
            self.growthHabit = growthHabit
            self.sunlight = sunlight
            self.water = water
            self.soil = soil
            self.temperature = temperature
            self.bloomTime = bloomTime
            self.funFacts = funFacts
            self.lastUpdated = lastUpdated
        }
    }
}

// MARK: - v2 (real relationship, media on disk, persisted number ledger)

enum FloradexSchemaV2: VersionedSchema {
    static let versionIdentifier = Schema.Version(2, 0, 0)
    static var models: [any PersistentModel.Type] {
        [DexEntry.self, SpeciesRecord.self, DexLedger.self]
    }

    @Model
    final class DexEntry {
        /// Permanent dex number; deletions retire it in the ledger, never reassign.
        @Attribute(.unique, originalName: "id") var number: Int
        var createdAt: Date
        /// Key into `MediaLocations.root` via `MediaPathPolicy`; media is
        /// never stored in the database. The stored default exists so
        /// migration can materialize the column; didMigrate assigns the
        /// real per-entry values immediately after.
        var mediaID: UUID = UUID()
        var species: SpeciesRecord?
        var tags: [String]
        var notes: String?
        /// 0 = no sprite yet; readers ask the media store for the newest
        /// version at or below this.
        var spriteVersion: Int = 0
        @Attribute(originalName: "spriteGenerationFailed") var spriteFailed: Bool
        /// JSON-encoded `IdentificationResult`: which providers said what,
        /// at what confidence, and whether the user corrected it.
        var provenance: Data?
        var latitude: Double?
        var longitude: Double?

        init(number: Int,
             createdAt: Date = .now,
             mediaID: UUID = UUID(),
             species: SpeciesRecord? = nil,
             tags: [String] = [],
             notes: String? = nil,
             spriteVersion: Int = 0,
             spriteFailed: Bool = false,
             provenance: Data? = nil,
             latitude: Double? = nil,
             longitude: Double? = nil) {
            self.number = number
            self.createdAt = createdAt
            self.mediaID = mediaID
            self.species = species
            self.tags = tags
            self.notes = notes
            self.spriteVersion = spriteVersion
            self.spriteFailed = spriteFailed
            self.provenance = provenance
            self.latitude = latitude
            self.longitude = longitude
        }
    }

    @Model
    final class SpeciesRecord {
        @Attribute(.unique) var latinName: String
        var commonName: String?
        var family: String?
        var summary: String?
        var sunlight: String?
        var water: String?
        var soil: String?
        var temperature: String?
        var bloomTime: String?
        var funFacts: [String]
        var contentProvider: String?
        var contentGeneratedAt: Date?
        @Relationship(deleteRule: .nullify, inverse: \DexEntry.species)
        var entries: [DexEntry]

        init(latinName: String,
             commonName: String? = nil,
             family: String? = nil,
             summary: String? = nil,
             sunlight: String? = nil,
             water: String? = nil,
             soil: String? = nil,
             temperature: String? = nil,
             bloomTime: String? = nil,
             funFacts: [String] = [],
             contentProvider: String? = nil,
             contentGeneratedAt: Date? = nil) {
            self.latinName = latinName
            self.commonName = commonName
            self.family = family
            self.summary = summary
            self.sunlight = sunlight
            self.water = water
            self.soil = soil
            self.temperature = temperature
            self.bloomTime = bloomTime
            self.funFacts = funFacts
            self.contentProvider = contentProvider
            self.contentGeneratedAt = contentGeneratedAt
            self.entries = []
        }
    }

    /// One row. Persists the Kit's `DexNumberLedger` invariants: numbers
    /// come from a high-water mark and retired numbers are never reissued.
    @Model
    final class DexLedger {
        var highWaterMark: Int
        var retired: [Int]

        init(highWaterMark: Int = 0, retired: [Int] = []) {
            self.highWaterMark = highWaterMark
            self.retired = retired
        }
    }
}

typealias DexEntryV2 = FloradexSchemaV2.DexEntry
typealias SpeciesRecord = FloradexSchemaV2.SpeciesRecord
typealias DexLedger = FloradexSchemaV2.DexLedger
