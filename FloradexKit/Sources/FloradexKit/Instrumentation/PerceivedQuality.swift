import Foundation

public enum MetricEvent: Hashable, Sendable, Codable {
    case shutterPressed
    case frameFrozen
    case firstRevealShown
    case provisionalShown
    case identificationRequested(ProviderID)
    case identificationSettled(FinishReason)
    case spriteShown
    case committed
    case undone
    case corrected
}

/// Perceived-quality seam. The app provides a signpost-backed recorder;
/// tests provide a spy that asserts ordering invariants (the optimistic
/// frame-frozen response must be recorded before any provider request).
public protocol PerceivedQualityRecorder: Sendable {
    func record(_ event: MetricEvent)
}

public struct NoopQualityRecorder: PerceivedQualityRecorder {
    public init() {}
    public func record(_ event: MetricEvent) {}
}

/// Budgets from the spec's hero-loop definition of done. Sprite latency is
/// deliberately absent: sprites are off the reveal's critical path.
public enum RevealBudget {
    public static let freezeFrame: Duration = .milliseconds(100)
    public static let provisionalEntry: Duration = .seconds(1)
    public static let firstReveal: Duration = .milliseconds(2500)
}
