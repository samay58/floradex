import Foundation

/// Derives collection tags from provider care content. Pure string rules;
/// the tag vocabulary is deliberately small so the dex filter stays useful.
public enum TagPolicy {
    public static let maxTags = 5

    public static func tags(for content: SpeciesDetailsContent) -> [String] {
        var tags: Set<String> = []

        if let sunlight = content.care.sunlight?.lowercased() {
            if sunlight.contains("low") || sunlight.contains("shade") || sunlight.contains("indirect") {
                tags.insert("Low Light")
            } else if sunlight.contains("bright") || sunlight.contains("full") {
                tags.insert("Bright Light")
            } else if sunlight.contains("medium") || sunlight.contains("partial") {
                tags.insert("Medium Light")
            }
        }

        if let water = content.care.water?.lowercased() {
            if water.contains("low") || water.contains("drought") {
                tags.insert("Low Water")
                tags.insert("Easy Care")
            } else if water.contains("high") || water.contains("frequent") || water.contains("moist") {
                tags.insert("High Water")
            } else if water.contains("moderate") || water.contains("medium") {
                tags.insert("Moderate Water")
            }
        }

        if let summary = content.summary?.lowercased() {
            if summary.contains("succulent") {
                tags.insert("Succulent")
                tags.insert("Easy Care")
            }
            if summary.contains("tree") { tags.insert("Tree") }
            if summary.contains("shrub") { tags.insert("Shrub") }
            if summary.contains("vine") || summary.contains("climb") { tags.insert("Climbing") }
            if summary.contains("herb") { tags.insert("Herb") }
        }

        if let bloom = content.care.bloomTime?.lowercased(), !bloom.isEmpty, bloom != "unknown" {
            tags.insert("Flowering")
            if bloom.contains("spring") { tags.insert("Spring Bloomer") }
            else if bloom.contains("summer") { tags.insert("Summer Bloomer") }
            else if bloom.contains("fall") || bloom.contains("autumn") { tags.insert("Fall Bloomer") }
            else if bloom.contains("winter") { tags.insert("Winter Bloomer") }
            else if bloom.contains("year") { tags.insert("Year-round Bloomer") }
        } else {
            tags.insert("Foliage")
        }

        if let temperature = content.care.temperature?.lowercased() {
            if temperature.contains("tropical") || temperature.contains("warm") {
                tags.insert("Tropical")
            } else if temperature.contains("hardy") || temperature.contains("cold") {
                tags.insert("Cold Hardy")
            }
        }

        return Array(tags.sorted().prefix(maxTags))
    }
}
