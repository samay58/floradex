import Foundation
import SwiftData

@Model
final class DexEntry: Sendable {
    /// Permanent dex number; deletions leave gaps, never reassigned.
    @Attribute(.unique) var id: Int
    var createdAt: Date
    /// Joins SpeciesDetails by string; the v2 schema makes this a real relationship.
    var latinName: String
    var snapshot: Data?
    var sprite: Data?
    var tags: [String]
    var notes: String?
    var spriteGenerationFailed: Bool

    /// Always nil in the v1 schema (no relationship yet); collection search
    /// references it, so it stays until v2.
    var commonName: String? {
        nil
    }

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