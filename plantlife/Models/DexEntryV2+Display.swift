import Foundation

extension DexEntryV2 {
    /// Grid tiles, list rows, and the detail header all lead with the same
    /// name, mirroring the Kit's `Species.displayName` preference, so a
    /// future precedence change lands everywhere at once.
    var displayName: String {
        species.map { $0.commonName ?? $0.latinName } ?? "Unknown"
    }
}
