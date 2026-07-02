import Foundation
import Testing
@testable import FloradexKit

@Suite struct DexNumberLedgerTests {
    @Test func assignsMonotonically() {
        var ledger = DexNumberLedger()
        #expect(ledger.assignNext() == DexNumber(1))
        #expect(ledger.assignNext() == DexNumber(2))
        #expect(ledger.assignNext() == DexNumber(3))
        #expect(ledger.highWaterMark == 3)
    }

    /// The anti-renumbering regression: deleting an entry must never cause
    /// its number to be reassigned, and must not shift anyone else's.
    @Test func neverReusesRetiredNumbers() {
        var ledger = DexNumberLedger()
        _ = ledger.assignNext()
        let second = ledger.assignNext()
        _ = ledger.assignNext()

        ledger.retire(second)
        let next = ledger.assignNext()

        #expect(next == DexNumber(4))
        #expect(ledger.isRetired(second))
        #expect(!ledger.isRetired(next))
    }

    @Test func activeCountExcludesTombstones() {
        var ledger = DexNumberLedger()
        for _ in 1...5 { _ = ledger.assignNext() }
        ledger.retire(DexNumber(2))
        ledger.retire(DexNumber(4))
        #expect(ledger.activeCount == 3)
    }

    @Test func retiringUnassignedNumberIsIgnored() {
        var ledger = DexNumberLedger()
        _ = ledger.assignNext()
        ledger.retire(DexNumber(99))
        #expect(!ledger.isRetired(DexNumber(99)))
        #expect(ledger.assignNext() == DexNumber(2))
    }

    @Test func survivesCodableRoundTrip() throws {
        var ledger = DexNumberLedger()
        for _ in 1...3 { _ = ledger.assignNext() }
        ledger.retire(DexNumber(2))

        let data = try JSONEncoder().encode(ledger)
        let decoded = try JSONDecoder().decode(DexNumberLedger.self, from: data)

        #expect(decoded == ledger)
        var mutable = decoded
        #expect(mutable.assignNext() == DexNumber(4))
    }
}

@Suite struct InMemoryDexStoreTests {
    private func provisional(_ species: Species, at date: Date) -> ProvisionalEntry {
        ProvisionalEntry(
            captureID: CaptureID(),
            result: IdentificationResult(species: species, confidence: 0.9, agreement: .single),
            createdAt: date
        )
    }

    @Test func commitAssignsSequentialNumbers() async throws {
        let store = InMemoryDexStore()
        let now = Date(timeIntervalSince1970: 1_700_000_000)

        let first = try await store.commit(provisional(Species(latinName: "Monstera deliciosa"), at: now))
        let second = try await store.commit(provisional(Species(latinName: "Ficus lyrata"), at: now))

        #expect(first.number == DexNumber(1))
        #expect(second.number == DexNumber(2))
    }

    @Test func deleteLeavesGapAndNextCommitContinues() async throws {
        let store = InMemoryDexStore()
        let now = Date(timeIntervalSince1970: 1_700_000_000)

        _ = try await store.commit(provisional(Species(latinName: "Monstera deliciosa"), at: now))
        let second = try await store.commit(provisional(Species(latinName: "Ficus lyrata"), at: now))
        _ = try await store.commit(provisional(Species(latinName: "Epipremnum aureum"), at: now))

        try await store.delete(second.number)
        let fourth = try await store.commit(provisional(Species(latinName: "Dracaena trifasciata"), at: now))

        #expect(fourth.number == DexNumber(4))
        let numbers = await store.entries().map(\.number.value)
        #expect(numbers == [1, 3, 4])
    }

    @Test func duplicateDetectionMatchesNormalizedNames() async throws {
        let store = InMemoryDexStore()
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        _ = try await store.commit(provisional(Species(latinName: "Monstera deliciosa"), at: now))

        let withCitation = Species(latinName: "Monstera deliciosa Liebm.")
        let existing = await store.existingEntry(for: withCitation)

        #expect(existing != nil)
        #expect(existing?.number == DexNumber(1))
    }

    @Test func deletingUnknownNumberThrows() async throws {
        let store = InMemoryDexStore()
        await #expect(throws: DexStoreError.unknownNumber(DexNumber(7))) {
            try await store.delete(DexNumber(7))
        }
    }
}
