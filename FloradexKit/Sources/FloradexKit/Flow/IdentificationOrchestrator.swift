import Foundation

public enum OrchestratorEvent: Sendable {
    /// Emitted after each provider round that yields a scoreable result.
    case progressed(IdentificationResult)
    /// Terminal.
    case finished(FinishReason, IdentificationResult?)
    /// Terminal; a missing key must never masquerade as "no plant found".
    case failed(FlowFailure)
}

/// Drives the escalation loop end to end: asks the engine what to run next,
/// executes providers with per-step timeouts, and folds outcomes back into
/// the next decision. Outcomes accumulate per call, so one orchestrator can
/// serve many identifications.
public actor IdentificationOrchestrator {
    private let providers: [ProviderID: any PlantIdentificationProvider]
    private let engine: EscalationEngine
    private let scorer: AgreementScorer
    private let recorder: any PerceivedQualityRecorder

    public init(
        providers: [any PlantIdentificationProvider],
        policy: EscalationPolicy = .standard,
        scorer: AgreementScorer = AgreementScorer(),
        recorder: any PerceivedQualityRecorder = NoopQualityRecorder()
    ) {
        self.providers = Dictionary(
            providers.map { ($0.id, $0) },
            uniquingKeysWith: { _, last in last }
        )
        self.engine = EscalationEngine(policy: policy, scorer: scorer)
        self.scorer = scorer
        self.recorder = recorder
    }

    /// Runs the escalation loop to completion. Emits progress via the handler
    /// (called on no particular actor; it is @Sendable). Returns the terminal
    /// event, which is also delivered to the handler.
    public func identify(
        _ image: ImagePayload,
        isOnline: Bool = true,
        onEvent: (@Sendable (OrchestratorEvent) -> Void)? = nil
    ) async -> OrchestratorEvent {
        var outcomes: [ProviderOutcome] = []

        while true {
            if Task.isCancelled {
                return .failed(.cancelled)
            }

            let context = EscalationContext(outcomes: outcomes, isOnline: isOnline)
            switch engine.decide(context) {
            case .run(let step):
                switch await execute(step, image: image) {
                case .outcome(let outcome):
                    outcomes.append(outcome)
                    let candidates = EscalationContext(outcomes: outcomes, isOnline: isOnline).allCandidates
                    if let result = scorer.score(candidates) {
                        onEvent?(.progressed(result))
                    }
                case .cancelled:
                    return .failed(.cancelled)
                }

            case .finish(let reason):
                recorder.record(.identificationSettled(reason))
                let result = scorer.score(context.allCandidates)
                let terminal = terminalEvent(reason: reason, result: result, outcomes: outcomes)
                onEvent?(terminal)
                return terminal
            }
        }
    }

    private enum StepResult {
        case outcome(ProviderOutcome)
        case cancelled
    }

    private func execute(_ step: EscalationStep, image: ImagePayload) async -> StepResult {
        guard let provider = providers[step.provider] else {
            return .outcome(.failed(step.provider, .invalidResponse("unregistered provider")))
        }
        recorder.record(.identificationRequested(step.provider))

        do {
            if let candidates = try await race(provider, image: image, timeout: step.timeout) {
                return .outcome(.candidates(step.provider, candidates))
            }
            return .outcome(.timedOut(step.provider))
        } catch let error as ProviderError {
            return .outcome(.failed(step.provider, error))
        } catch is CancellationError {
            return .cancelled
        } catch {
            return .outcome(.failed(step.provider, .invalidResponse(String(describing: error))))
        }
    }

    /// Races the provider call against the step timeout. Returns nil on
    /// timeout; the losing task is cancelled either way. Errors from the
    /// cancelled loser are discarded by the group on normal return.
    private func race(
        _ provider: any PlantIdentificationProvider,
        image: ImagePayload,
        timeout: Duration
    ) async throws -> [IdentificationCandidate]? {
        try await withThrowingTaskGroup(of: [IdentificationCandidate]?.self) { group in
            group.addTask {
                try await provider.identify(image)
            }
            group.addTask {
                try await Task.sleep(for: timeout)
                return nil
            }
            guard let first = try await group.next() else {
                return nil
            }
            group.cancelAll()
            return first
        }
    }

    private func terminalEvent(
        reason: FinishReason,
        result: IdentificationResult?,
        outcomes: [ProviderOutcome]
    ) -> OrchestratorEvent {
        if result == nil {
            for outcome in outcomes {
                if case .failed(_, .credentialMissing(let provider)) = outcome {
                    return .failed(.credentialMissing(provider))
                }
            }
        }
        return .finished(reason, result)
    }
}
