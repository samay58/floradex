import Foundation
import SwiftData

@Model
final class SpeciesDetails: Identifiable, Codable, Sendable {
    @Attribute(.unique) var latinName: String // latinName acts as ID
    var commonName: String?
    var summary: String?
    var growthHabit: String?
    var sunlight: String?
    var water: String?
    var soil: String?
    var temperature: String?
    var bloomTime: String?
    var funFacts: [String]?
    var lastUpdated: Date

    // SwiftData requires an initializer.
    // We'll provide a default one that matches the old struct's memberwise initializer.
    init(latinName: String,
         commonName: String? = nil,
         summary: String? = nil,
         growthHabit: String? = nil,
         sunlight: String? = nil,
         water: String? = nil,
         soil: String? = nil,
         temperature: String? = nil,
         bloomTime: String? = nil,
         funFacts: [String]? = nil,
         lastUpdated: Date = Date()) {
        self.latinName = latinName
        self.commonName = commonName
        self.summary = summary
        self.growthHabit = growthHabit
        self.sunlight = sunlight
        self.water = water
        self.soil = soil
        self.temperature = temperature
        self.bloomTime = bloomTime
        self.funFacts = funFacts
        self.lastUpdated = lastUpdated
    }
    
    // The 'id' property for Identifiable can be derived from latinName.
    // Or, if you prefer a stable UUID, you could add a separate `let id: UUID = UUID()` property.
    // For now, let's assume latinName is sufficient for Identifiable needs.
    var id: String { latinName }

    var missingFieldRatio: Double {
        let total = 9.0 // fields excluding id/latin/lastUpdated
        let missing = [commonName, summary, growthHabit, sunlight, water, soil, temperature, bloomTime, funFacts?.first].filter { $0 == nil }.count
        return Double(missing) / total
    }

    static func empty(latin: String) -> SpeciesDetails {
        SpeciesDetails(latinName: latin, lastUpdated: Date())
    }

    // The 'with(funFacts:)' method is less common with classes as you can mutate properties directly.
    // However, if you prefer an immutable style update, it can be kept or adapted.
    // For now, let's remove it, as direct mutation is idiomatic for classes.
    // If needed, we can re-add a similar method or use direct property assignment.

    // MARK: - Codable
    enum CodingKeys: String, CodingKey {
        case latinName, commonName, summary, growthHabit, sunlight, water, soil, temperature, bloomTime, funFacts, lastUpdated
    }

    // Decodable
    required convenience init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let latinName = try container.decode(String.self, forKey: .latinName)
        let commonName = try container.decodeIfPresent(String.self, forKey: .commonName)
        let summary = try container.decodeIfPresent(String.self, forKey: .summary)
        let growthHabit = try container.decodeIfPresent(String.self, forKey: .growthHabit)
        let sunlight = try container.decodeIfPresent(String.self, forKey: .sunlight)
        let water = try container.decodeIfPresent(String.self, forKey: .water)
        let soil = try container.decodeIfPresent(String.self, forKey: .soil)
        let temperature = try container.decodeIfPresent(String.self, forKey: .temperature)
        let bloomTime = try container.decodeIfPresent(String.self, forKey: .bloomTime)
        let funFacts = try container.decodeIfPresent([String].self, forKey: .funFacts)
        let lastUpdated = try container.decodeIfPresent(Date.self, forKey: .lastUpdated) ?? Date()

        self.init(latinName: latinName,
                       commonName: commonName,
                       summary: summary,
                       growthHabit: growthHabit,
                       sunlight: sunlight,
                       water: water,
                       soil: soil,
                       temperature: temperature,
                       bloomTime: bloomTime,
                       funFacts: funFacts,
                       lastUpdated: lastUpdated)
    }

    // Encodable
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(latinName, forKey: .latinName)
        try container.encodeIfPresent(commonName, forKey: .commonName)
        try container.encodeIfPresent(summary, forKey: .summary)
        try container.encodeIfPresent(growthHabit, forKey: .growthHabit)
        try container.encodeIfPresent(sunlight, forKey: .sunlight)
        try container.encodeIfPresent(water, forKey: .water)
        try container.encodeIfPresent(soil, forKey: .soil)
        try container.encodeIfPresent(temperature, forKey: .temperature)
        try container.encodeIfPresent(bloomTime, forKey: .bloomTime)
        try container.encodeIfPresent(funFacts, forKey: .funFacts)
        try container.encode(lastUpdated, forKey: .lastUpdated)
    }
}

// MARK: - Parsed Properties for Gauges
extension SpeciesDetails {
    var parsedSunlightLevel: SunlightLevel {
        guard let sunlightString = sunlight?.lowercased() else { return .partialSun } // Default
        if sunlightString.contains("full sun") {
            return .fullSun
        } else if sunlightString.contains("partial") {
            return .partialSun
        } else if sunlightString.contains("shade") {
            return .shade
        }
        return .partialSun // Default
    }

    var parsedWaterRequirement: Double { // Normalized 0.0 to 1.0
        guard let waterString = water?.lowercased() else { return 0.5 } // Default
        if waterString.contains("high") || waterString.contains("keep moist") || waterString.contains("frequent") {
            return 0.8
        } else if waterString.contains("moderate") || waterString.contains("average") {
            return 0.5
        } else if waterString.contains("low") || waterString.contains("dry out") || waterString.contains("infrequent") {
            return 0.2
        }
        return 0.5 // Default
    }

    var parsedTemperatureRange: ClosedRange<Double>? {
        guard let tempString = temperature else { return nil }

        // Regex to find numbers, can be X, X-Y, X - Y
        let regex = try! NSRegularExpression(pattern: #"(\d+(?:\.\d+)?)"#)
        let nsRange = NSRange(tempString.startIndex..<tempString.endIndex, in: tempString)
        let matches = regex.matches(in: tempString, options: [], range: nsRange)
        
        let numbers = matches.compactMap { match -> Double? in
            if let range = Range(match.range(at: 1), in: tempString) {
                return Double(String(tempString[range]))
            }
            return nil
        }

        if numbers.count == 1 {
            return numbers[0]...numbers[0] // Or perhaps a small range like numbers[0]-2...numbers[0]+2
        } else if numbers.count >= 2 {
            let sortedNumbers = numbers.sorted()
            return sortedNumbers[0]...sortedNumbers[1]
        }
        
        return nil // Default if parsing fails
    }
    
    // Example for a "current" temperature if we had such data. For now, ThermoRangeView might not use it.
    // var currentTemperature: Double? { return nil }


    var parsedSoilPH: Double? { // Normalized 0.0 to 1.0 for pH 0-14 scale
        guard let soilString = soil?.lowercased() else { return 0.5 } // Default to neutral pH 7

        // Regex to find pH values like "pH 6.0", "ph 5.5-6.5"
        let regex = try! NSRegularExpression(pattern: #"ph\s*(\d+(?:\.\d+)?)(?:\s*-\s*(\d+(?:\.\d+)?))?"#)
        let nsRange = NSRange(soilString.startIndex..<soilString.endIndex, in: soilString)
        
        if let match = regex.firstMatch(in: soilString, options: [], range: nsRange) {
            var phValues: [Double] = []
            if let range1 = Range(match.range(at: 1), in: soilString), let val1 = Double(String(soilString[range1])) {
                phValues.append(val1)
            }
            if match.numberOfRanges > 2, let range2 = Range(match.range(at: 2), in: soilString), let val2 = Double(String(soilString[range2])) {
                phValues.append(val2)
            }

            if phValues.isEmpty {
                return 0.5 // Neutral
            }
            
            let averagePh = phValues.reduce(0, +) / Double(phValues.count)
            return (averagePh / 14.0).clamped(to: 0.0...1.0) // Normalize to 0-14 scale
        }
        
        return 0.5 // Default to neutral pH 7 if no pH found
    }
}