import Foundation
import SwiftData

@Model
final class DexEntry: Sendable {
    @Attribute(.unique) var id: Int      // Floradex number, e.g., 1, 2, 3
    var createdAt: Date
    var latinName: String                // Foreign Key to SpeciesDetails
    var snapshot: Data?                  // Original JPEG image, scaled to ≤1MB
    var sprite: Data?                    // Generated 64x64 PNG sprite
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