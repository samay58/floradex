import Foundation
import FloradexKit
import os

/// Signpost-backed perceived-quality recorder. Metrics land as instruments
/// signposts for profiling and as debug log lines for the dev HUD; the
/// budgets they are judged against live in `RevealBudget`.
struct SignpostQualityRecorder: PerceivedQualityRecorder {
    private static let logger = Logger(subsystem: "samayd.floradex", category: "perceived-quality")
    private static let signposter = OSSignposter(subsystem: "samayd.floradex", category: "hero-loop")

    func record(_ event: MetricEvent) {
        let name = String(describing: event)
        Self.signposter.emitEvent("hero-metric", "\(name, privacy: .public)")
        Self.logger.debug("metric \(name, privacy: .public)")
    }
}
