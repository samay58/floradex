import Foundation

public struct DexNumber: Hashable, Comparable, Sendable, Codable {
    public let value: Int

    public init(_ value: Int) {
        precondition(value >= 1, "Dex numbers start at 1")
        self.value = value
    }

    public static func < (lhs: DexNumber, rhs: DexNumber) -> Bool {
        lhs.value < rhs.value
    }
}

public struct CaptureID: Hashable, Sendable, Codable {
    public let rawValue: UUID

    public init(rawValue: UUID = UUID()) {
        self.rawValue = rawValue
    }
}

public struct EntryID: Hashable, Sendable, Codable {
    public let rawValue: UUID

    public init(rawValue: UUID = UUID()) {
        self.rawValue = rawValue
    }
}
