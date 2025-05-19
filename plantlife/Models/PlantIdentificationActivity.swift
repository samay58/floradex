import ActivityKit
import SwiftUI

struct PlantIdentificationActivityAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        // Dynamic data for the Live Activity.
        var phase: IdentificationPhase
        var confidence: Double? // Optional, only relevant in 'done' phase maybe?
        var currentStatusMessage: String
        var scientificName: String? // Moved from static for dynamic update
        var commonName: String?     // Moved from static for dynamic update
        var spritePNGData: Data?    // Added here for dynamic update
    }

    // Static data for the Live Activity.
    // These are less critical if updated in ContentState, but can be used for initial setup if available
    // var scientificName: String? // Known after identification
    // var commonName: String?     // Known after identification
    // var spritePNGData: Data?    // Optional, if we have a sprite
    var initialPlaceholderMessage: String // Example of truly static data
}

enum IdentificationPhase: String, Codable, Hashable {
    case searching = "Searching"
    case analyzing = "Analyzing"
    case processing = "Processing" // Added based on typical flows
    case almostDone = "Almost Done" // Added for more granular feedback
    case done = "Done"
    case failed = "Failed"

    var defaultMessage: String {
        switch self {
        case .searching:
            return "Searching for plant..."
        case .analyzing:
            return "Analyzing image..."
        case .processing:
            return "Processing details..."
        case .almostDone:
            return "Finalizing results..."
        case .done:
            return "Identification complete!"
        case .failed:
            return "Could not identify plant."
        }
    }
} 