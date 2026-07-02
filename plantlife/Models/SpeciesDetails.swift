import Foundation
import SwiftData

@Model
final class SpeciesDetails: Identifiable, Sendable {
    @Attribute(.unique) var latinName: String
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

    var id: String { latinName }
}

/// Sunlight requirement parsed from the free-text `sunlight` field;
/// PlantDetailsView renders its gauge from this.
enum SunlightLevel {
    case fullSun
    case partialSun
    case shade

    var gaugeValue: Int {
        switch self {
        case .shade: return 1
        case .partialSun: return 3
        case .fullSun: return 5
        }
    }
}

// MARK: - Parsed properties for the legacy detail gauges

extension SpeciesDetails {
    // Fields the old detail screen renders but no current source populates;
    // the v2 schema either supplies or drops them.
    var family: String? { nil }
    var nativeRegion: String? { nil }
    var careDifficulty: Int? { nil }

    var minTemp: Int? {
        parsedTemperatureRange.map { Int($0.lowerBound) }
    }

    var maxTemp: Int? {
        parsedTemperatureRange.map { Int($0.upperBound) }
    }

    var parsedSunlightLevel: SunlightLevel {
        guard let sunlightString = sunlight?.lowercased() else { return .partialSun }
        if sunlightString.contains("full sun") {
            return .fullSun
        } else if sunlightString.contains("shade") {
            return .shade
        }
        return .partialSun
    }

    /// Normalized 0.0 to 1.0.
    var parsedWaterRequirement: Double {
        guard let waterString = water?.lowercased() else { return 0.5 }
        if waterString.contains("high") || waterString.contains("keep moist") || waterString.contains("frequent") {
            return 0.8
        } else if waterString.contains("low") || waterString.contains("dry out") || waterString.contains("infrequent") {
            return 0.2
        }
        return 0.5
    }

    var parsedTemperatureRange: ClosedRange<Double>? {
        guard let tempString = temperature else { return nil }

        let regex = try! NSRegularExpression(pattern: #"(\d+(?:\.\d+)?)"#)
        let nsRange = NSRange(tempString.startIndex..<tempString.endIndex, in: tempString)
        let numbers = regex.matches(in: tempString, options: [], range: nsRange)
            .compactMap { match -> Double? in
                guard let range = Range(match.range(at: 1), in: tempString) else { return nil }
                return Double(String(tempString[range]))
            }

        if numbers.count == 1 {
            return numbers[0]...numbers[0]
        } else if numbers.count >= 2 {
            let sorted = numbers.sorted()
            return sorted[0]...sorted[1]
        }
        return nil
    }
}
