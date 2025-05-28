import SwiftUI

struct GrowthCard: View, DexDetailCard {
    let id: Int = 2 // Third card
    let details: SpeciesDetails?
    
    var accentColor: Color {
        Theme.Colors.primaryGreen // Use consistent primary green
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Metrics.Padding.large) {
                // Card Title
                Text("Growth")
                    .font(Theme.Typography.title3.weight(.bold))
                    .foregroundColor(Theme.Colors.textPrimary)
                    .padding(.bottom, Theme.Metrics.Padding.small)

                // Growth Information using modern PlantInfoRowView
                VStack(alignment: .leading, spacing: Theme.Metrics.Padding.medium) {
                    if let details = details {
                        PlantInfoRowView.height(details.parsedHeight() ?? "N/A")
                        PlantInfoRowView.spread(details.parsedSpread() ?? "N/A")
                        PlantInfoRowView.growthRate(details.growthHabit ?? "N/A")
                        PlantInfoRowView.toxicity(details.parsedToxicity() ?? "N/A")
                        
                        // Additional growth info if available
                        if let bloomTime = details.bloomTime, !bloomTime.isEmpty {
                            HStack(spacing: Theme.Metrics.Padding.small) {
                                SFSymbolHelper.flowerFill
                                    .foregroundColor(Theme.Colors.primaryGreen)
                                    .frame(width: 20)
                    Text("Bloom Time")
                                    .font(Theme.Typography.body)
                                    .foregroundColor(Theme.Colors.textSecondary)
                                Spacer()
                                Text(bloomTime)
                                    .font(Theme.Typography.body.weight(.medium))
                                    .foregroundColor(Theme.Colors.textPrimary)
                            }
                            .padding(.vertical, Theme.Metrics.Padding.extraSmall)
                    }
                } else {
                        // Fallback when no details available
                VStack(alignment: .leading, spacing: Theme.Metrics.Padding.small) {
                            PlantInfoRowView.height("N/A")
                            PlantInfoRowView.spread("N/A")
                            PlantInfoRowView.growthRate("N/A")
                            PlantInfoRowView.toxicity("N/A")
                        }
                    }
                }
            }
            .padding(Theme.Metrics.Padding.large) // Padding for the content within the card
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity) // Ensure ScrollView takes full space
        .background(Theme.Colors.cardBackground) // Use dark-mode-aware card background
        .cornerRadius(Theme.Metrics.cornerRadiusLarge)
        // Note: Shadow is handled by DexCardPager, not individual cards
    }
}

// MARK: - SpeciesDetails Extensions for Growth Information
extension SpeciesDetails {
    /// Parse or provide height information
    func parsedHeight() -> String? {
        // Placeholder logic - in a real implementation, this would:
        // 1. Check for a dedicated height field
        // 2. Parse from description or other text fields
        // 3. Provide reasonable defaults based on plant type
        
        // For now, return a placeholder based on growth habit
        if let habit = self.growthHabit?.lowercased() {
            if habit.contains("tree") || habit.contains("tall") {
                return "15-30 ft"
            } else if habit.contains("shrub") || habit.contains("bush") {
                return "3-8 ft"
            } else if habit.contains("groundcover") || habit.contains("low") {
                return "6-12 in"
            } else if habit.contains("vine") || habit.contains("climbing") {
                return "10-20 ft"
            }
        }
        
        return "1-3 ft" // Safe default for most houseplants
    }
    
    /// Parse or provide spread information
    func parsedSpread() -> String? {
        // Placeholder logic based on plant characteristics
        if let habit = self.growthHabit?.lowercased() {
            if habit.contains("tree") {
                return "10-20 ft"
            } else if habit.contains("shrub") || habit.contains("bush") {
                return "2-6 ft"
            } else if habit.contains("groundcover") {
                return "3-6 ft"
            } else if habit.contains("vine") {
                return "Variable"
            }
        }
        
        return "1-2 ft" // Safe default
    }
    
    /// Parse or provide toxicity information
    func parsedToxicity() -> String? {
        // Placeholder logic - would ideally check dedicated toxicity fields
        // For now, provide some intelligent defaults
        
        if let commonName = self.commonName?.lowercased() {
            // Common toxic plants
            if commonName.contains("lily") || commonName.contains("oleander") || 
               commonName.contains("azalea") || commonName.contains("rhododendron") {
                return "Toxic to pets and humans"
            } else if commonName.contains("poinsettia") || commonName.contains("holly") {
                return "Mildly toxic to pets"
            } else if commonName.contains("aloe") || commonName.contains("snake plant") {
                return "Mildly toxic to pets"
            }
        }
        
        // Check latin name for known toxic families
        let latinName = self.latinName.lowercased()
        if latinName.contains("lilium") || latinName.contains("hemerocallis") {
            return "Highly toxic to cats"
        } else if latinName.contains("euphorbia") {
            return "Skin irritant, toxic if ingested"
        }
        
        return "Generally safe" // Conservative default
    }
}

#if DEBUG
struct GrowthCard_Previews: PreviewProvider {
    static var previews: some View {
        // Preview with sample data
        let sampleDetails = PreviewHelper.sampleSpeciesDetails
        
        VStack(spacing: 20) {
            Text("Modern GrowthCard")
                .font(Theme.Typography.title2)
            
            GrowthCard(details: sampleDetails)
                .frame(height: 400)
            .padding()
        }
        .background(Theme.Colors.systemGroupedBackground)
        .previewLayout(.sizeThatFits)
    }
}
#endif 