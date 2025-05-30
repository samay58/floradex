import Foundation

/// Generates meaningful tags for plants based on their characteristics
struct TagGenerator {
    
    /// Generate tags based on species details
    static func generateTags(from details: SpeciesDetails) -> [String] {
        var tags: [String] = []
        
        // Light requirement tags
        if let sunlight = details.sunlight?.lowercased() {
            switch sunlight {
            case let s where s.contains("low") || s.contains("shade") || s.contains("indirect"):
                tags.append("Low Light")
            case let s where s.contains("bright") || s.contains("full"):
                tags.append("Bright Light")
            case let s where s.contains("medium") || s.contains("partial"):
                tags.append("Medium Light")
            default:
                break
            }
            
            // Indoor/Outdoor tags
            if sunlight.contains("indoor") {
                tags.append("Indoor")
            } else if sunlight.contains("outdoor") || sunlight.contains("full sun") {
                tags.append("Outdoor")
            }
        }
        
        // Water requirement tags
        if let water = details.water?.lowercased() {
            switch water {
            case let w where w.contains("low") || w.contains("drought"):
                tags.append("Low Water")
                tags.append("Easy Care")
            case let w where w.contains("high") || w.contains("frequent"):
                tags.append("High Water")
            case let w where w.contains("moderate") || w.contains("medium"):
                tags.append("Moderate Water")
            default:
                break
            }
        }
        
        // Growth habit tags
        if let growth = details.growthHabit?.lowercased() {
            switch growth {
            case let g where g.contains("succulent"):
                tags.append("Succulent")
                tags.append("Easy Care")
            case let g where g.contains("tree"):
                tags.append("Tree")
            case let g where g.contains("shrub"):
                tags.append("Shrub")
            case let g where g.contains("vine") || g.contains("climbing"):
                tags.append("Vine")
                tags.append("Climbing")
            case let g where g.contains("herb"):
                tags.append("Herb")
            case let g where g.contains("groundcover") || g.contains("ground cover"):
                tags.append("Groundcover")
            default:
                break
            }
        }
        
        // Bloom time tags
        if let bloom = details.bloomTime?.lowercased(), !bloom.isEmpty && bloom != "unknown" {
            tags.append("Flowering")
            
            // Seasonal tags
            if bloom.contains("spring") {
                tags.append("Spring Bloomer")
            } else if bloom.contains("summer") {
                tags.append("Summer Bloomer")
            } else if bloom.contains("fall") || bloom.contains("autumn") {
                tags.append("Fall Bloomer")
            } else if bloom.contains("winter") {
                tags.append("Winter Bloomer")
            } else if bloom.contains("year") {
                tags.append("Year-round Bloomer")
            }
        } else {
            tags.append("Foliage")
        }
        
        // Temperature tags
        if let temp = details.temperature?.lowercased() {
            if temp.contains("tropical") || temp.contains("warm") {
                tags.append("Tropical")
            } else if temp.contains("hardy") || temp.contains("cold") {
                tags.append("Cold Hardy")
            }
        }
        
        // Special care tags based on combinations
        if tags.contains("Succulent") || (tags.contains("Low Water") && tags.contains("Bright Light")) {
            if !tags.contains("Easy Care") {
                tags.append("Easy Care")
            }
        }
        
        // Common name as a tag if available and different from latin name
        if let commonName = details.commonName, 
           !commonName.isEmpty,
           commonName.lowercased() != details.latinName.lowercased() {
            // Only add if it's a reasonable length
            if commonName.count <= 20 {
                tags.append(commonName)
            }
        }
        
        // Remove duplicates and sort
        let uniqueTags = Array(Set(tags)).sorted()
        
        // Limit to reasonable number of tags
        return Array(uniqueTags.prefix(5))
    }
    
    /// Generate a single display tag for the card (most relevant)
    static func primaryTag(from tags: [String], for details: SpeciesDetails?) -> String {
        // Priority order for display
        let priorityTags = [
            "Easy Care",
            "Low Light",
            "Flowering",
            "Succulent",
            "Indoor",
            "Herb",
            "Tree"
        ]
        
        // Check if we have a common name that's short enough
        if let commonName = details?.commonName,
           !commonName.isEmpty,
           commonName.count <= 15,
           commonName.lowercased() != details?.latinName.lowercased() {
            return commonName
        }
        
        // Find the highest priority tag
        for priority in priorityTags {
            if tags.contains(priority) {
                return priority
            }
        }
        
        // Return first tag if available
        return tags.first ?? "Plant"
    }
}