import UIKit

/// The hero loop's haptic map. Semantic boundaries only: shutter, reveal
/// stage, save, undo. Generators are prepared ahead of likely use and
/// re-prepared after firing.
@MainActor
enum HeroHaptics {
    private static let shutterImpact = UIImpactFeedbackGenerator(style: .medium)
    private static let stageSelection = UISelectionFeedbackGenerator()
    private static let outcome = UINotificationFeedbackGenerator()

    static func prepare() {
        shutterImpact.prepare()
        stageSelection.prepare()
        outcome.prepare()
    }

    static func shutter() {
        shutterImpact.impactOccurred()
        shutterImpact.prepare()
    }

    static func revealStage() {
        stageSelection.selectionChanged()
        stageSelection.prepare()
    }

    static func saveSuccess() {
        outcome.notificationOccurred(.success)
        outcome.prepare()
    }

    static func undo() {
        shutterImpact.impactOccurred(intensity: 0.6)
        shutterImpact.prepare()
    }
}
