import Foundation
import Testing
@testable import FloradexKit
import FloradexKitFixtures

@Suite struct FixtureCatalogTests {
    private let catalog = FixtureCatalog.standard

    @Test func containsAllSixteenCases() {
        #expect(catalog.count == 16)
    }

    @Test func idsAreUnique() {
        #expect(Set(catalog.map(\.id)).count == catalog.count)
    }

    @Test func everyCategoryAppearsExactlyOnce() {
        let categories = catalog.map(\.category)
        #expect(Set(categories).count == FixtureCategory.allCases.count)
    }

    @Test func logicCasesHaveScriptsOrAreOffline() {
        for fixture in catalog where fixture.expected != .uiFixture {
            #expect(
                !fixture.scripts.isEmpty || !fixture.isOnline,
                "\(fixture.id) has no scripted providers and is not the offline case"
            )
        }
    }

    @Test func uiCasesCarryNoPipelineScripts() {
        for fixture in catalog where fixture.expected == .uiFixture {
            #expect(fixture.scripts.isEmpty)
        }
    }
}

/// Replays every logic-reachable fixture through the real escalation engine,
/// with scripted behaviors standing in for live providers. This is the corpus
/// gate: a fixture whose expected outcome stops matching fails the build.
@Suite struct FixtureReplayTests {
    private func replay(
        _ fixture: FixtureCase,
        policy: EscalationPolicy = .standard
    ) -> (reason: FinishReason, result: IdentificationResult?) {
        let engine = EscalationEngine(policy: policy)
        var context = EscalationContext(outcomes: [], isOnline: fixture.isOnline)

        // The engine never revisits a provider, so this terminates.
        while true {
            switch engine.decide(context) {
            case .run(let step):
                let outcome: ProviderOutcome
                switch fixture.scripts[step.provider]?.first {
                case .candidates(let candidates, _):
                    outcome = .candidates(step.provider, candidates)
                case .failure(let error, _):
                    outcome = .failed(step.provider, error)
                case .hang:
                    outcome = .timedOut(step.provider)
                case nil:
                    outcome = .failed(step.provider, .invalidResponse("unscripted"))
                }
                context.outcomes.append(outcome)
            case .finish(let reason):
                return (reason, AgreementScorer().score(context.allCandidates))
            }
        }
    }

    @Test func everyLogicFixtureReplaysToItsExpectedOutcome() {
        for fixture in FixtureCatalog.standard {
            let (reason, result) = replay(fixture)

            switch fixture.expected {
            case .commits(let latinName), .duplicatePrompt(let latinName):
                #expect(result != nil, "\(fixture.id): expected a result")
                #expect(result?.species.latinName == latinName, "\(fixture.id): wrong winner")
                #expect(result?.band != .unsure, "\(fixture.id): should not band unsure")

            case .unsure(let topLatinName):
                #expect(result?.species.latinName == topLatinName, "\(fixture.id): wrong top candidate")
                #expect(result?.band == .unsure, "\(fixture.id): should band unsure")

            case .failure:
                // The engine reports noCandidates either way; the orchestrator
                // layers the no-plant vs providers-down distinction on top.
                #expect(reason == .noCandidates, "\(fixture.id): expected no candidates")
                #expect(result == nil)

            case .queuedOffline:
                #expect(reason == .queuedOffline, "\(fixture.id): expected offline queueing")

            case .uiFixture:
                continue
            }
        }
    }

    @Test func duplicateFixtureTripsDuplicateDetection() async throws {
        let fixture = try #require(FixtureCatalog.standard.first { $0.category == .duplicatePlant })
        let (_, result) = replay(fixture)
        let identified = try #require(result)

        let store = InMemoryDexStore()
        _ = try await store.commit(ProvisionalEntry(
            captureID: CaptureID(),
            result: IdentificationResult(species: FixtureFlora.monstera, confidence: 0.9, agreement: .single),
            createdAt: Date(timeIntervalSince1970: 1_700_000_000)
        ))

        let existing = await store.existingEntry(for: identified.species)
        #expect(existing != nil, "duplicate fixture should match the seeded entry")
    }

    @Test func disagreementFixtureActuallySplitsMidPipeline() throws {
        // Regression guard: the disagreement fixture must produce a genuine
        // split after two providers, or it stops exercising the reasoner path.
        let fixture = try #require(FixtureCatalog.standard.first { $0.category == .providerDisagreement })
        guard case .candidates(let kindwise, _)? = fixture.scripts[.kindwise]?.first,
              case .candidates(let plantNet, _)? = fixture.scripts[.plantNet]?.first else {
            Issue.record("disagreement fixture is missing its two primary scripts")
            return
        }
        let partial = AgreementScorer().score(kindwise + plantNet)
        #expect(partial?.agreement == .split)
    }
}
