import UIKit

/// The hero loop's haptic map. Semantic boundaries only: shutter, reveal
/// stage, stamp (number assignment), undo. Generators are prepared ahead
/// of likely use and re-prepared after firing.
@MainActor
enum HeroHaptics {
    private static let shutterImpact = UIImpactFeedbackGenerator(style: .medium)
    private static let stageSelection = UISelectionFeedbackGenerator()
    private static let stampImpact = UIImpactFeedbackGenerator(style: .rigid)

    static func prepare() {
        shutterImpact.prepare()
        stageSelection.prepare()
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

    /// The dex number landing: one decisive rigid hit, because a stamp
    /// strikes once. Replaced the two-tap success notification at commit.
    static func stamp() {
        stampImpact.impactOccurred()
        stampImpact.prepare()
    }

    static func undo() {
        shutterImpact.impactOccurred(intensity: 0.6)
        shutterImpact.prepare()
    }
}
