import SwiftUI
import Combine

@Observable
class AppSettings {
    static let shared = AppSettings()

    // Feature Flags
    var isLiveActivityEnabled: Bool {
        didSet {
            UserDefaults.standard.set(isLiveActivityEnabled, forKey: "isLiveActivityEnabled")
        }
    }
    
    // Other settings from plan
    var soundEnabled: Bool {
        didSet {
            UserDefaults.standard.set(soundEnabled, forKey: "soundEnabled")
        }
    }
    
    enum HapticsLevel: String, CaseIterable, Codable {
        case off, minimal, full
    }
    var hapticsLevel: HapticsLevel {
        didSet {
            UserDefaults.standard.set(hapticsLevel.rawValue, forKey: "hapticsLevel")
        }
    }

    private init() {
        // Load saved values, defaulting if not found
        self.isLiveActivityEnabled = UserDefaults.standard.object(forKey: "isLiveActivityEnabled") as? Bool ?? true // Default to true
        self.soundEnabled = UserDefaults.standard.object(forKey: "soundEnabled") as? Bool ?? true // Defaults to true
        if let savedHaptics = UserDefaults.standard.string(forKey: "hapticsLevel"),
           let level = HapticsLevel(rawValue: savedHaptics) {
            self.hapticsLevel = level
        } else {
            self.hapticsLevel = .full // Default to full
        }
        
        // The plan mentions swift-data for these. This is a UserDefaults interim step.
        // When migrating to SwiftData, these properties would be backed by a SwiftData model.
    }
    
    // Example of how to expose this for a settings UI
    // func bindingForLiveActivity() -> Binding<Bool> {
    //     Binding<Bool>(
    //         get: { self.isLiveActivityEnabled },
    //         set: { self.isLiveActivityEnabled = $0 }
    //     )
    // }
} 