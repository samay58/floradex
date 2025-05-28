import SwiftUI

struct CareCard: View, DexDetailCard {
    let id: Int = 1 // Second card
    let details: SpeciesDetails?
    
    var accentColor: Color {
        Theme.Colors.primaryGreen // Use consistent primary green
    }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Metrics.Padding.large) {
                // Card Title
                Text("Care")
                    .font(Theme.Typography.title3.weight(.bold))
                    .foregroundColor(Theme.Colors.textPrimary)
                    .padding(.bottom, Theme.Metrics.Padding.small)

                // Care Information using modern PlantInfoRowView
                VStack(alignment: .leading, spacing: Theme.Metrics.Padding.medium) {
                    if let details = details {
                        PlantInfoRowView.sunlight(details.sunlight ?? "N/A")
                        PlantInfoRowView.water(details.water ?? "N/A") 
                        PlantInfoRowView.temperature(details.temperature ?? "N/A")
                        PlantInfoRowView.humidity(details.parsedHumidity() ?? "N/A")
                        PlantInfoRowView.soil(details.soil ?? "N/A")
                        PlantInfoRowView.fertilizer(details.parsedFertilizer() ?? "N/A")
                    } else {
                        // Fallback when no details available
                    VStack(alignment: .leading, spacing: Theme.Metrics.Padding.small) {
                            PlantInfoRowView.sunlight("N/A")
                            PlantInfoRowView.water("N/A")
                            PlantInfoRowView.temperature("N/A")
                            PlantInfoRowView.humidity("N/A")
                            PlantInfoRowView.soil("N/A")
                            PlantInfoRowView.fertilizer("N/A")
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

// MARK: - SpeciesDetails Extensions for New Fields
// Add placeholder parsing methods for new care information fields
extension SpeciesDetails {
    /// Parse or provide humidity information
    func parsedHumidity() -> String? {
        // For now, return a placeholder. In a real implementation, this would:
        // 1. Check if there's a dedicated humidity field in the model
        // 2. Parse humidity info from existing text fields
        // 3. Provide intelligent defaults based on plant type
        
        // Placeholder logic - replace with actual field or parsing
        if let sunlight = self.sunlight?.lowercased() {
            if sunlight.contains("humid") || sunlight.contains("moist") {
                return "High"
            } else if sunlight.contains("dry") || sunlight.contains("arid") {
                return "Low"
            }
        }
        
        return "Moderate" // Safe default
    }
    
    /// Parse or provide fertilizer information  
    func parsedFertilizer() -> String? {
        // Placeholder logic - replace with actual field or parsing
        // In practice, this might parse from description, soil info, or care instructions
        
        if let soil = self.soil?.lowercased() {
            if soil.contains("rich") || soil.contains("fertile") {
                return "Monthly during growing season"
            } else if soil.contains("poor") || soil.contains("sandy") {
                return "Bi-weekly during growing season"
            }
        }
        
        return "Monthly during growing season" // Safe default
    }
}

#if DEBUG
struct CareCard_Previews: PreviewProvider {
    static var previews: some View {
        // Preview with sample data
        let sampleDetails = PreviewHelper.sampleSpeciesDetails
        
        VStack(spacing: 20) {
            Text("Modern CareCard")
                .font(Theme.Typography.title2)
            
            CareCard(details: sampleDetails)
                .frame(height: 400)
                .padding()
        }
        .background(Theme.Colors.systemGroupedBackground)
        .previewLayout(.sizeThatFits)
    }
}
#endif 