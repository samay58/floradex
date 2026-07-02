import Foundation

public enum CostClass: Int, Hashable, Sendable, Codable, Comparable, CaseIterable {
    case free = 0
    case cheap = 1
    case expensive = 3

    public static func < (lhs: CostClass, rhs: CostClass) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

public enum EscalationCondition: Hashable, Sendable {
    case always
    case confidenceBelow(Double)
    case disagreement
    case confidenceBelowOrDisagreement(Double)

    /// With no result yet, confidence conditions match (treated as zero) and
    /// disagreement-only conditions do not.
    func matches(_ result: IdentificationResult?) -> Bool {
        switch self {
        case .always:
            return true
        case .confidenceBelow(let threshold):
            guard let result else { return true }
            return result.confidence < threshold
        case .disagreement:
            guard let result else { return false }
            return result.agreement == .split
        case .confidenceBelowOrDisagreement(let threshold):
            guard let result else { return true }
            return result.confidence < threshold || result.agreement == .split
        }
    }
}

public struct EscalationStep: Hashable, Sendable {
    public var provider: ProviderID
    public var timeout: Duration
    public var cost: CostClass
    public var condition: EscalationCondition
    public var requiresNetwork: Bool

    public init(
        provider: ProviderID,
        timeout: Duration,
        cost: CostClass,
        condition: EscalationCondition,
        requiresNetwork: Bool = true
    ) {
        self.provider = provider
        self.timeout = timeout
        self.cost = cost
        self.condition = condition
        self.requiresNetwork = requiresNetwork
    }
}

/// The identification cascade as data. The engine walks `steps` in order;
/// hardcoded threshold chains are a regression.
public struct EscalationPolicy: Hashable, Sendable {
    public var steps: [EscalationStep]
    /// At or above this combined confidence (and not split), stop escalating.
    public var satisfactionThreshold: Double
    /// Cap on summed `CostClass` raw values per identification.
    public var costBudget: Int

    public init(steps: [EscalationStep], satisfactionThreshold: Double = 0.85, costBudget: Int = 6) {
        self.steps = steps
        self.satisfactionThreshold = satisfactionThreshold
        self.costBudget = costBudget
    }

    public static let standard = EscalationPolicy(steps: [
        EscalationStep(
            provider: .kindwise,
            timeout: .seconds(8),
            cost: .cheap,
            condition: .always
        ),
        EscalationStep(
            provider: .plantNet,
            timeout: .seconds(8),
            cost: .cheap,
            condition: .confidenceBelowOrDisagreement(0.7)
        ),
        EscalationStep(
            provider: .visionReasoner,
            timeout: .seconds(15),
            cost: .expensive,
            condition: .confidenceBelowOrDisagreement(0.5)
        ),
    ])
}

public enum ProviderOutcome: Hashable, Sendable {
    case candidates(ProviderID, [IdentificationCandidate])
    case failed(ProviderID, ProviderError)
    case timedOut(ProviderID)

    public var provider: ProviderID {
        switch self {
        case .candidates(let id, _), .failed(let id, _), .timedOut(let id):
            return id
        }
    }
}

public struct EscalationContext: Sendable {
    public var outcomes: [ProviderOutcome]
    public var isOnline: Bool

    public init(outcomes: [ProviderOutcome] = [], isOnline: Bool = true) {
        self.outcomes = outcomes
        self.isOnline = isOnline
    }

    public var allCandidates: [IdentificationCandidate] {
        outcomes.flatMap { outcome in
            if case .candidates(_, let candidates) = outcome { return candidates }
            return []
        }
    }

    public func hasRun(_ provider: ProviderID) -> Bool {
        outcomes.contains { $0.provider == provider }
    }
}

public enum FinishReason: Hashable, Sendable, Codable {
    case confident
    case bestEffort
    case noCandidates
    case queuedOffline
}

public enum EscalationDecision: Hashable, Sendable {
    case run(EscalationStep)
    case finish(FinishReason)
}

public struct EscalationEngine: Sendable {
    public var policy: EscalationPolicy
    public var scorer: AgreementScorer

    public init(policy: EscalationPolicy = .standard, scorer: AgreementScorer = AgreementScorer()) {
        self.policy = policy
        self.scorer = scorer
    }

    public func decide(_ context: EscalationContext) -> EscalationDecision {
        let result = scorer.score(context.allCandidates)

        if let result,
           result.confidence >= policy.satisfactionThreshold,
           result.agreement != .split {
            return .finish(.confident)
        }

        let spent = policy.steps
            .filter { context.hasRun($0.provider) }
            .reduce(0) { $0 + $1.cost.rawValue }

        var skippedForNetwork = false
        for step in policy.steps where !context.hasRun(step.provider) {
            guard step.condition.matches(result) else { continue }
            if step.requiresNetwork && !context.isOnline {
                skippedForNetwork = true
                continue
            }
            guard spent + step.cost.rawValue <= policy.costBudget else { continue }
            return .run(step)
        }

        if skippedForNetwork && result == nil {
            return .finish(.queuedOffline)
        }
        if result != nil {
            return .finish(.bestEffort)
        }
        return .finish(.noCandidates)
    }
}
