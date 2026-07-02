import Foundation
import Testing
@testable import FloradexKit

@Suite struct EscalationEngineTests {
    private let engine = EscalationEngine()
    private let monstera = Species(latinName: "Monstera deliciosa")
    private let pothos = Species(latinName: "Epipremnum aureum")

    private func outcome(_ provider: ProviderID, _ species: Species, _ confidence: Double) -> ProviderOutcome {
        .candidates(provider, [IdentificationCandidate(species: species, confidence: confidence, provider: provider)])
    }

    @Test func freshContextRunsPrimaryFirst() {
        let decision = engine.decide(EscalationContext())
        guard case .run(let step) = decision else {
            Issue.record("expected a run decision, got \(decision)")
            return
        }
        #expect(step.provider == .kindwise)
    }

    @Test func satisfiedConfidenceFinishesEarly() {
        let context = EscalationContext(outcomes: [outcome(.kindwise, monstera, 0.9)])
        #expect(engine.decide(context) == .finish(.confident))
    }

    @Test func lowConfidenceEscalatesToSecondary() {
        let context = EscalationContext(outcomes: [outcome(.kindwise, monstera, 0.6)])
        guard case .run(let step) = engine.decide(context) else {
            Issue.record("expected escalation to plantNet")
            return
        }
        #expect(step.provider == .plantNet)
    }

    @Test func middlingAgreedConfidenceStopsWithBestEffort() {
        // 0.72 clears the secondary's 0.7 threshold but not satisfaction (0.85):
        // no step's condition matches, so the engine settles for best effort.
        let context = EscalationContext(outcomes: [outcome(.kindwise, monstera, 0.72)])
        #expect(engine.decide(context) == .finish(.bestEffort))
    }

    @Test func disagreementInvokesTheReasoner() {
        let context = EscalationContext(outcomes: [
            outcome(.kindwise, monstera, 0.65),
            outcome(.plantNet, pothos, 0.68),
        ])
        guard case .run(let step) = engine.decide(context) else {
            Issue.record("expected the reasoner to arbitrate the split")
            return
        }
        #expect(step.provider == .visionReasoner)
    }

    @Test func timeoutCountsAsRunAndEscalates() {
        let context = EscalationContext(outcomes: [.timedOut(.kindwise)])
        guard case .run(let step) = engine.decide(context) else {
            Issue.record("expected escalation past the hung provider")
            return
        }
        #expect(step.provider == .plantNet)
    }

    @Test func offlineWithNoCandidatesQueues() {
        let context = EscalationContext(outcomes: [], isOnline: false)
        #expect(engine.decide(context) == .finish(.queuedOffline))
    }

    @Test func offlineStillRunsLocalSteps() {
        let policy = EscalationPolicy(steps: [
            EscalationStep(provider: .localML, timeout: .seconds(2), cost: .free, condition: .always, requiresNetwork: false),
            EscalationStep(provider: .kindwise, timeout: .seconds(8), cost: .cheap, condition: .always),
        ])
        let offlineEngine = EscalationEngine(policy: policy)
        guard case .run(let step) = offlineEngine.decide(EscalationContext(outcomes: [], isOnline: false)) else {
            Issue.record("expected the local step to run offline")
            return
        }
        #expect(step.provider == .localML)
    }

    @Test func budgetCapBlocksExpensiveSteps() {
        let policy = EscalationPolicy(
            steps: [
                EscalationStep(provider: .kindwise, timeout: .seconds(8), cost: .cheap, condition: .always),
                EscalationStep(provider: .visionReasoner, timeout: .seconds(15), cost: .expensive, condition: .always),
            ],
            costBudget: 2
        )
        let cappedEngine = EscalationEngine(policy: policy)
        let context = EscalationContext(outcomes: [outcome(.kindwise, monstera, 0.4)])
        // Reasoner costs 3; 1 already spent against a budget of 2.
        #expect(cappedEngine.decide(context) == .finish(.bestEffort))
    }

    @Test func allProvidersFailedFinishesNoCandidates() {
        let context = EscalationContext(outcomes: [
            .failed(.kindwise, .noPlantDetected),
            .failed(.plantNet, .noPlantDetected),
            .failed(.visionReasoner, .noPlantDetected),
        ])
        #expect(engine.decide(context) == .finish(.noCandidates))
    }

    @Test func exhaustedStepsWithWeakCandidatesFinishBestEffort() {
        let context = EscalationContext(outcomes: [
            outcome(.kindwise, monstera, 0.3),
            outcome(.plantNet, monstera, 0.35),
            outcome(.visionReasoner, monstera, 0.4),
        ])
        #expect(engine.decide(context) == .finish(.bestEffort))
    }
}
