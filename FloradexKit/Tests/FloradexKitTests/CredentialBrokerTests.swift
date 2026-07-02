import Foundation
import Testing
@testable import FloradexKit

@Suite struct CredentialBrokerTests {
    @Test func returnsConfiguredKey() async throws {
        let broker = StaticCredentialBroker(keys: [.kindwise: "test-key-123"])
        let credential = try await broker.credential(for: .kindwise)
        #expect(credential.apiKey == "test-key-123")
    }

    /// The typed error that replaces the old app's silent empty-key no-op.
    @Test func missingKeyThrowsTypedError() async {
        let broker = StaticCredentialBroker(keys: [:])
        await #expect(throws: ProviderError.credentialMissing(.plantNet)) {
            _ = try await broker.credential(for: .plantNet)
        }
    }

    @Test func emptyKeyCountsAsMissing() async {
        let broker = StaticCredentialBroker(keys: [.kindwise: ""])
        await #expect(throws: ProviderError.credentialMissing(.kindwise)) {
            _ = try await broker.credential(for: .kindwise)
        }
    }

    @Test func environmentInitReadsMappedVariables() async throws {
        let broker = StaticCredentialBroker(
            environment: ["OPENAI_API_KEY": "env-key", "PLANTNET_API_KEY": ""],
            mapping: [.visionReasoner: "OPENAI_API_KEY", .plantNet: "PLANTNET_API_KEY"]
        )

        let credential = try await broker.credential(for: .visionReasoner)
        #expect(credential.apiKey == "env-key")

        await #expect(throws: ProviderError.credentialMissing(.plantNet)) {
            _ = try await broker.credential(for: .plantNet)
        }
    }
}
