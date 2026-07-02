import Foundation

/// Ledger for dex number assignment. Invariants: numbers are assigned
/// monotonically from a high-water mark, and a number is never reused or
/// reassigned, even after its entry is deleted. Deletions leave tombstones so
/// the collection can show gaps honestly.
///
/// This deliberately inverts the old app's `renumberEntries()` behavior,
/// which rewrote every entry's number on delete.
public struct DexNumberLedger: Hashable, Sendable, Codable {
    public private(set) var highWaterMark: Int
    public private(set) var retired: Set<Int>

    public init(highWaterMark: Int = 0, retired: Set<Int> = []) {
        self.highWaterMark = max(0, highWaterMark)
        self.retired = retired
    }

    public mutating func assignNext() -> DexNumber {
        highWaterMark += 1
        return DexNumber(highWaterMark)
    }

    public mutating func retire(_ number: DexNumber) {
        guard number.value <= highWaterMark else { return }
        retired.insert(number.value)
    }

    public func isRetired(_ number: DexNumber) -> Bool {
        retired.contains(number.value)
    }

    public var activeCount: Int {
        highWaterMark - retired.count
    }
}
