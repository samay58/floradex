import Foundation

public struct ProviderCredential: Hashable, Sendable {
    public var apiKey: String

    public init(apiKey: String) {
        self.apiKey = apiKey
    }
}

/// The seam between provider clients and wherever keys actually live.
/// Development uses `StaticCredentialBroker`; release swaps in a proxy-backed
/// broker (Cloudflare Workers + App Attest) without touching provider code.
public protocol CredentialBroker: Sendable {
    func credential(for provider: ProviderID) async throws -> ProviderCredential
}

public struct StaticCredentialBroker: CredentialBroker {
    private let keys: [ProviderID: String]

    public init(keys: [ProviderID: String]) {
        self.keys = keys
    }

    /// Reads keys from process environment variables, the existing
    /// development mechanism (`OPENAI_API_KEY`, etc.).
    public init(environment: [String: String], mapping: [ProviderID: String]) {
        var keys: [ProviderID: String] = [:]
        for (provider, variable) in mapping {
            if let value = environment[variable], !value.isEmpty {
                keys[provider] = value
            }
        }
        self.keys = keys
    }

    public func credential(for provider: ProviderID) async throws -> ProviderCredential {
        guard let key = keys[provider], !key.isEmpty else {
            throw ProviderError.credentialMissing(provider)
        }
        return ProviderCredential(apiKey: key)
    }
}
