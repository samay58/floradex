import Foundation
import Testing
import os
import FloradexKit
import FloradexKitFixtures

private let testImage = ImagePayload(format: .jpeg, data: Data([0x01]))

/// The standard cascade with every step's timeout shortened so hang fixtures
/// resolve in tens of milliseconds instead of seconds.
private func shortStandardPolicy(timeout: Duration = .milliseconds(40)) -> EscalationPolicy {
    let standard = EscalationPolicy.standard
    let steps = standard.steps.map { step in
        EscalationStep(
            provider: step.provider,
            timeout: timeout,
            cost: step.cost,
            condition: step.condition,
            requiresNetwork: step.requiresNetwork
        )
    }
    return EscalationPolicy(
        steps: steps,
        satisfactionThreshold: standard.satisfactionThreshold,
        costBudget: standard.costBudget
    )
}

private func scriptedProviders(for fixture: FixtureCase) -> [any PlantIdentificationProvider] {
    fixture.scripts.map { ScriptedIdentificationProvider(id: $0.key, script: $0.value) }
}

private final class QualityRecorderSpy: PerceivedQualityRecorder, Sendable {
    private let state = OSAllocatedUnfairLock(initialState: [MetricEvent]())

    func record(_ event: MetricEvent) {
        state.withLock { $0.append(event) }
    }

    var events: [MetricEvent] {
        state.withLock { $0 }
    }

    var requestedProviders: [ProviderID] {
        events.compactMap { event -> ProviderID? in
            if case .identificationRequested(let provider) = event { return provider }
            return nil
        }
    }
}

private final class EventCollector: Sendable {
    private let state = OSAllocatedUnfairLock(initialState: [OrchestratorEvent]())

    func append(_ event: OrchestratorEvent) {
        state.withLock { $0.append(event) }
    }

    var events: [OrchestratorEvent] {
        state.withLock { $0 }
    }

    var progressedResults: [IdentificationResult] {
        events.compactMap { event -> IdentificationResult? in
            if case .progressed(let result) = event { return result }
            return nil
        }
    }
}

@Suite struct IdentificationOrchestratorTests {

    @Test func everyLogicFixtureRunsToItsExpectedOutcome() async {
        for fixture in FixtureCatalog.standard where fixture.expected != .uiFixture {
            let orchestrator = IdentificationOrchestrator(
                providers: scriptedProviders(for: fixture),
                policy: shortStandardPolicy()
            )
            let terminal = await orchestrator.identify(testImage, isOnline: fixture.isOnline)

            switch fixture.expected {
            case .commits(let latinName), .duplicatePrompt(let latinName):
                guard case .finished(_, let result) = terminal, let result else {
                    Issue.record("\(fixture.id): expected a finished result, got \(terminal)")
                    continue
                }
                #expect(result.species.latinName == latinName, "\(fixture.id): wrong winner")
                #expect(result.band != .unsure, "\(fixture.id): should not band unsure")

            case .unsure(let topLatinName):
                guard case .finished(_, let result) = terminal, let result else {
                    Issue.record("\(fixture.id): expected a finished result, got \(terminal)")
                    continue
                }
                #expect(result.species.latinName == topLatinName, "\(fixture.id): wrong top candidate")
                #expect(result.band == .unsure, "\(fixture.id): should band unsure")

            case .failure:
                guard case .finished(let reason, let result) = terminal else {
                    Issue.record("\(fixture.id): expected finished(noCandidates), got \(terminal)")
                    continue
                }
                #expect(reason == .noCandidates, "\(fixture.id): expected no candidates")
                #expect(result == nil, "\(fixture.id): expected no result")

            case .queuedOffline:
                guard case .finished(let reason, _) = terminal else {
                    Issue.record("\(fixture.id): expected finished(queuedOffline), got \(terminal)")
                    continue
                }
                #expect(reason == .queuedOffline, "\(fixture.id): expected offline queueing")

            case .uiFixture:
                continue
            }
        }
    }

    @Test func hangingProviderTimesOutAndEscalationProceeds() async {
        let spy = QualityRecorderSpy()
        let providers: [any PlantIdentificationProvider] = [
            ScriptedIdentificationProvider(id: .kindwise, script: [.hang]),
            ScriptedIdentificationProvider(id: .plantNet, script: [.candidates(
                [IdentificationCandidate(species: FixtureFlora.monstera, confidence: 0.9, provider: .plantNet)],
                delay: .zero
            )]),
        ]
        let orchestrator = IdentificationOrchestrator(
            providers: providers,
            policy: shortStandardPolicy(),
            recorder: spy
        )
        let terminal = await orchestrator.identify(testImage)

        guard case .finished(let reason, let result) = terminal else {
            Issue.record("expected a finished event, got \(terminal)")
            return
        }
        #expect(reason == .confident)
        #expect(result?.species.latinName == "Monstera deliciosa")
        #expect(result?.contributing.allSatisfy { $0.provider == .plantNet } == true)
        #expect(spy.requestedProviders == [.kindwise, .plantNet])
    }

    @Test func credentialMissingDominatesNoCandidates() async {
        let ids: [ProviderID] = [.kindwise, .plantNet, .visionReasoner]
        let providers: [any PlantIdentificationProvider] = ids.map { id in
            ScriptedIdentificationProvider(id: id, script: [.failure(.credentialMissing(id), delay: .zero)])
        }
        let orchestrator = IdentificationOrchestrator(providers: providers, policy: shortStandardPolicy())
        let terminal = await orchestrator.identify(testImage)

        guard case .failed(let failure) = terminal else {
            Issue.record("expected a failed event, got \(terminal)")
            return
        }
        #expect(failure == .credentialMissing(.kindwise))
    }

    @Test func progressEventsArriveInOrderAndLastMatchesTerminal() async {
        let policy = EscalationPolicy(steps: [
            EscalationStep(provider: .kindwise, timeout: .milliseconds(40), cost: .cheap, condition: .always),
            EscalationStep(provider: .plantNet, timeout: .milliseconds(40), cost: .cheap, condition: .confidenceBelow(0.7)),
        ])
        let providers: [any PlantIdentificationProvider] = [
            ScriptedIdentificationProvider(id: .kindwise, script: [.candidates(
                [IdentificationCandidate(species: FixtureFlora.monstera, confidence: 0.4, provider: .kindwise)],
                delay: .zero
            )]),
            ScriptedIdentificationProvider(id: .plantNet, script: [.candidates(
                [IdentificationCandidate(species: FixtureFlora.monstera, confidence: 0.95, provider: .plantNet)],
                delay: .zero
            )]),
        ]
        let collector = EventCollector()
        let orchestrator = IdentificationOrchestrator(providers: providers, policy: policy)
        let terminal = await orchestrator.identify(testImage) { collector.append($0) }

        let progressed = collector.progressedResults
        #expect(progressed.count >= 2)
        #expect(progressed.first.map { $0.confidence < 0.7 } == true, "first round should be the low-confidence read")

        guard case .finished(let reason, let result) = terminal else {
            Issue.record("expected a finished event, got \(terminal)")
            return
        }
        #expect(reason == .bestEffort)
        #expect(progressed.last == result)
        if case .finished = collector.events.last {
        } else {
            Issue.record("terminal event should be delivered to the handler last")
        }
    }

    @Test func cancellationReturnsPromptly() async throws {
        let providers: [any PlantIdentificationProvider] = [
            ScriptedIdentificationProvider(id: .kindwise, script: [.hang]),
        ]
        let policy = EscalationPolicy(steps: [
            EscalationStep(provider: .kindwise, timeout: .seconds(10), cost: .cheap, condition: .always),
        ])
        let orchestrator = IdentificationOrchestrator(providers: providers, policy: policy)

        let clock = ContinuousClock()
        let start = clock.now
        let task = Task {
            await orchestrator.identify(testImage)
        }
        try await Task.sleep(for: .milliseconds(20))
        task.cancel()
        let terminal = await task.value
        let elapsed = clock.now - start

        guard case .failed(let failure) = terminal else {
            Issue.record("expected a failed event, got \(terminal)")
            return
        }
        #expect(failure == .cancelled)
        #expect(elapsed < .seconds(2), "identify should return promptly after cancellation, took \(elapsed)")
    }

    @Test func recorderSeesOneRequestPerExecutedStepInOrder() async {
        let spy = QualityRecorderSpy()
        let providers: [any PlantIdentificationProvider] = [
            ScriptedIdentificationProvider(id: .kindwise, script: [.candidates(
                [IdentificationCandidate(species: FixtureFlora.monstera, confidence: 0.65, provider: .kindwise)],
                delay: .zero
            )]),
            ScriptedIdentificationProvider(id: .plantNet, script: [.candidates(
                [IdentificationCandidate(species: FixtureFlora.pothos, confidence: 0.68, provider: .plantNet)],
                delay: .zero
            )]),
            ScriptedIdentificationProvider(id: .visionReasoner, script: [.candidates(
                [IdentificationCandidate(species: FixtureFlora.monstera, confidence: 0.70, provider: .visionReasoner)],
                delay: .zero
            )]),
        ]
        let orchestrator = IdentificationOrchestrator(
            providers: providers,
            policy: shortStandardPolicy(),
            recorder: spy
        )
        _ = await orchestrator.identify(testImage)

        #expect(spy.requestedProviders == [.kindwise, .plantNet, .visionReasoner])
        #expect(spy.events.last == .identificationSettled(.bestEffort))
    }
}
