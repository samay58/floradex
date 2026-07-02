import Foundation
import Testing
@testable import FloradexKit
import FloradexKitFixtures

@Suite struct MockProviderTests {
    private let monstera = Species(latinName: "Monstera deliciosa")
    private let image = ImagePayload(format: .png, data: Data())

    @Test func scriptedBehaviorsPlayInOrderAndLastRepeats() async throws {
        let first = [IdentificationCandidate(species: monstera, confidence: 0.5, provider: .kindwise)]
        let second = [IdentificationCandidate(species: monstera, confidence: 0.9, provider: .kindwise)]
        let provider = ScriptedIdentificationProvider(id: .kindwise, script: [
            .candidates(first, delay: .zero),
            .candidates(second, delay: .zero),
        ])

        let call1 = try await provider.identify(image)
        let call2 = try await provider.identify(image)
        let call3 = try await provider.identify(image)

        #expect(call1 == first)
        #expect(call2 == second)
        #expect(call3 == second)
        let calls = await provider.calls
        #expect(calls == 3)
    }

    @Test func failureBehaviorThrowsItsError() async {
        let provider = ScriptedIdentificationProvider(id: .plantNet, script: [
            .failure(.noPlantDetected, delay: .zero),
        ])
        await #expect(throws: ProviderError.noPlantDetected) {
            _ = try await provider.identify(image)
        }
    }

    @Test func hangBehaviorHonorsCancellation() async {
        let provider = ScriptedIdentificationProvider(id: .kindwise, script: [.hang])
        let task = Task {
            try await provider.identify(image)
        }
        task.cancel()
        let outcome = await task.result
        #expect(throws: (any Error).self) { try outcome.get() }
    }

    @Test func detailsProviderProducesDeterministicContent() async throws {
        let stamp = Date(timeIntervalSince1970: 1_700_000_000)
        let provider = ScriptedDetailsProvider(
            behavior: .succeed(summary: "A hardy climber.", funFacts: ["Its holes are called fenestrations."]),
            generatedAt: stamp
        )

        let content = try await provider.details(for: monstera)
        #expect(content.summary == "A hardy climber.")
        #expect(content.funFacts.count == 1)
        #expect(content.source.generatedAt == stamp)
    }

    @Test func corruptedSpriteBehaviorReturnsEmptyData() async throws {
        let provider = ScriptedSpriteProvider(behavior: .corrupted)
        let data = try await provider.sprite(for: monstera)
        #expect(data.isEmpty)
    }

    @Test func successfulSpriteBehaviorReturnsUsableData() async throws {
        let provider = ScriptedSpriteProvider(behavior: .succeed)
        let data = try await provider.sprite(for: monstera)
        #expect(!data.isEmpty)
    }
}
