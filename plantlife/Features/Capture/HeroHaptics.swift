import UIKit

/// The hero loop's haptic map. Semantic boundaries only: shutter, reveal
/// stage, save, undo. Generators are prepared ahead of likely use and
/// re-prepared after firing.
@MainActor
enum HeroHaptics {
    private static let shutterImpact = UIImpactFeedbackGenerator(style: .medium)
    private static let stageSelection = UISelectionFeedbackGenerator()
    private static let outcome = UINotificationFeedbackGenerator()
    private static let stampImpact = UIImpactFeedbackGenerator(style: .rigid)

    static func prepare() {
        shutterImpact.prepare()
        stageSelection.prepare()
        outcome.prepare()
        stampImpact.prepare()
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

    /// The dex number landing: one decisive hit, distinct from the two-tap
    /// success pattern, because a stamp strikes once.
    static func stamp() {
        stampImpact.impactOccurred()
        stampImpact.prepare()
    }

    static func undo() {
        shutterImpact.impactOccurred(intensity: 0.6)
        shutterImpact.prepare()
    }
}
