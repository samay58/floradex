import Foundation
import FloradexKit

/// One scripted behavior per call; the last behavior repeats if the provider
/// is called more times than the script covers.
public enum ProviderScriptBehavior: Sendable {
    case candidates([IdentificationCandidate], delay: Duration)
    case failure(ProviderError, delay: Duration)
    /// Never returns (until cancelled); models a hung provider so callers
    /// must enforce their own timeouts.
    case hang
}

public actor ScriptedIdentificationProvider: PlantIdentificationProvider {
    public nonisolated let id: ProviderID
    private let script: [ProviderScriptBehavior]
    private var callCount = 0

    public init(id: ProviderID, script: [ProviderScriptBehavior]) {
        self.id = id
        self.script = script
    }

    public var calls: Int { callCount }

    public func identify(_ image: ImagePayload) async throws -> [IdentificationCandidate] {
        guard !script.isEmpty else {
            throw ProviderError.invalidResponse("unscripted provider \(id)")
        }
        let behavior = script[min(callCount, script.count - 1)]
        callCount += 1
        switch behavior {
        case .candidates(let candidates, let delay):
            if delay > .zero { try await Task.sleep(for: delay) }
            return candidates
        case .failure(let error, let delay):
            if delay > .zero { try await Task.sleep(for: delay) }
            throw error
        case .hang:
            try await Task.sleep(for: .seconds(3600))
            throw ProviderError.timeout
        }
    }
}

public enum DetailsScriptBehavior: Sendable {
    case succeed(summary: String, funFacts: [String])
    case failure(ProviderError)
}

public struct ScriptedDetailsProvider: SpeciesDetailsProvider {
    public let id: ProviderID
    public let behavior: DetailsScriptBehavior
    /// Injected so fixtures stay deterministic.
    public let generatedAt: Date

    public init(id: ProviderID = .visionReasoner, behavior: DetailsScriptBehavior, generatedAt: Date) {
        self.id = id
        self.behavior = behavior
        self.generatedAt = generatedAt
    }

    public func details(for species: Species) async throws -> SpeciesDetailsContent {
        switch behavior {
        case .succeed(let summary, let funFacts):
            return SpeciesDetailsContent(
                species: species,
                summary: summary,
                funFacts: funFacts,
                source: ContentSource(provider: id, generatedAt: generatedAt)
            )
        case .failure(let error):
            throw error
        }
    }
}

public enum SpriteScriptBehavior: Sendable {
    case succeed
    /// Returns empty data, which readers must treat as an unusable sprite.
    case corrupted
    case failure(ProviderError)
}

public struct ScriptedSpriteProvider: SpriteGenerationProvider {
    public let id: ProviderID
    public let behavior: SpriteScriptBehavior

    public init(id: ProviderID = .spriteGenerator, behavior: SpriteScriptBehavior) {
        self.id = id
        self.behavior = behavior
    }

    public func sprite(for species: Species) async throws -> Data {
        switch behavior {
        case .succeed:
            // Minimal valid PNG header; enough for "non-empty data arrived".
            return Data([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A])
        case .corrupted:
            return Data()
        case .failure(let error):
            throw error
        }
    }
}
