import Foundation

public enum ProviderError: Error, Hashable, Sendable {
    /// The credential for this provider is absent or empty. Surfaced as a
    /// first-run diagnostic; never allowed to decay into a silent no-op.
    case credentialMissing(ProviderID)
    case network(String)
    case timeout
    case rateLimited(retryAfter: Duration?)
    case invalidResponse(String)
    case noPlantDetected
}
