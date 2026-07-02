import Foundation

public struct ProvisionalEntry: Hashable, Sendable {
    public var id: EntryID
    public var captureID: CaptureID
    public var result: IdentificationResult
    public var createdAt: Date
    public var tags: [String]

    public init(
        id: EntryID = EntryID(),
        captureID: CaptureID,
        result: IdentificationResult,
        createdAt: Date,
        tags: [String] = []
    ) {
        self.id = id
        self.captureID = captureID
        self.result = result
        self.createdAt = createdAt
        self.tags = tags
    }
}

public struct CommittedEntry: Hashable, Sendable {
    public var number: DexNumber
    public var id: EntryID
    public var species: Species
    public var result: IdentificationResult
    public var createdAt: Date
    public var tags: [String]
    public var notes: String?

    public init(
        number: DexNumber,
        id: EntryID,
        species: Species,
        result: IdentificationResult,
        createdAt: Date,
        tags: [String] = [],
        notes: String? = nil
    ) {
        self.number = number
        self.id = id
        self.species = species
        self.result = result
        self.createdAt = createdAt
        self.tags = tags
        self.notes = notes
    }
}

public enum DexStoreError: Error, Hashable, Sendable {
    case unknownNumber(DexNumber)
}

/// Persistence seam. Phase 1 ships the in-memory actor; the app provides a
/// SwiftData-backed implementation when the schema stabilizes.
public protocol DexStore: Sendable {
    /// Persists the entry and assigns its dex number. Numbering happens here,
    /// at commit, never earlier: an undone provisional must not burn a number.
    func commit(_ entry: ProvisionalEntry) async throws -> CommittedEntry
    func entries() async -> [CommittedEntry]
    func entry(numbered number: DexNumber) async -> CommittedEntry?
    /// Duplicate detection: an active entry whose species matches by
    /// normalized Latin name.
    func existingEntry(for species: Species) async -> CommittedEntry?
    func delete(_ number: DexNumber) async throws
    func ledger() async -> DexNumberLedger
}

public actor InMemoryDexStore: DexStore {
    private var numberLedger: DexNumberLedger
    private var storage: [DexNumber: CommittedEntry] = [:]

    public init(ledger: DexNumberLedger = DexNumberLedger()) {
        self.numberLedger = ledger
    }

    public func commit(_ entry: ProvisionalEntry) async throws -> CommittedEntry {
        let number = numberLedger.assignNext()
        let committed = CommittedEntry(
            number: number,
            id: entry.id,
            species: entry.result.species,
            result: entry.result,
            createdAt: entry.createdAt,
            tags: entry.tags
        )
        storage[number] = committed
        return committed
    }

    public func entries() async -> [CommittedEntry] {
        storage.values.sorted { $0.number < $1.number }
    }

    public func entry(numbered number: DexNumber) async -> CommittedEntry? {
        storage[number]
    }

    public func existingEntry(for species: Species) async -> CommittedEntry? {
        let key = species.normalizedKey
        return storage.values
            .filter { $0.species.normalizedKey == key }
            .min { $0.number < $1.number }
    }

    public func delete(_ number: DexNumber) async throws {
        guard storage.removeValue(forKey: number) != nil else {
            throw DexStoreError.unknownNumber(number)
        }
        numberLedger.retire(number)
    }

    public func ledger() async -> DexNumberLedger {
        numberLedger
    }
}
