import Foundation

public struct Species: Hashable, Sendable, Codable {
    public var latinName: String
    public var commonName: String?
    public var family: String?

    public init(latinName: String, commonName: String? = nil, family: String? = nil) {
        self.latinName = latinName
        self.commonName = commonName
        self.family = family
    }

    /// What the UI and prompts lead with: common name when known.
    public var displayName: String {
        commonName ?? latinName
    }

    /// Comparison key used by the agreement scorer so that provider spelling
    /// variants and author citations don't split the vote.
    public var normalizedKey: String {
        Species.normalizeLatinName(latinName)
    }

    /// Reduces a Latin name to genus + epithet, keeping infraspecific rank
    /// pairs ("var. borsigiana") and dropping author citations ("Liebm.").
    public static func normalizeLatinName(_ raw: String) -> String {
        let rankMarkers: Set<String> = ["var.", "subsp.", "ssp.", "f.", "cv."]
        let tokens = raw.split(whereSeparator: { $0.isWhitespace }).map(String.init)
        guard !tokens.isEmpty else { return "" }

        var kept: [String] = []
        var index = 0

        // Hybrid marker attaches to the genus.
        if tokens[index] == "×" || tokens[index] == "x", tokens.count > 1 {
            kept.append("×")
            index += 1
        }

        // Genus and epithet.
        for _ in 0..<2 where index < tokens.count {
            let lowered = tokens[index].lowercased()
            if rankMarkers.contains(lowered) { break }
            kept.append(lowered)
            index += 1
        }

        // Infraspecific rank pairs; anything else after the epithet is an
        // author citation and is dropped.
        while index + 1 < tokens.count {
            let marker = tokens[index].lowercased()
            guard rankMarkers.contains(marker) else { break }
            kept.append(marker)
            kept.append(tokens[index + 1].lowercased())
            index += 2
        }

        return kept.joined(separator: " ")
    }
}
