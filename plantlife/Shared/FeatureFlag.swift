import Foundation

enum Feature {
    case liveActivity
    // Add other feature flags here as needed
}

// Simple static checker, can be expanded to use AppSettings
class FeatureFlags {
    static func isEnabled(_ feature: Feature) -> Bool {
        switch feature {
        case .liveActivity:
            // This will eventually read from AppSettings
            return AppSettings.shared.isLiveActivityEnabled
        }
    }
} 