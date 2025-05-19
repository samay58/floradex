import SwiftUI

struct CareCard: View, DexDetailCard {
    let id: Int = 1 // Second card
    let details: SpeciesDetails?
    
    // State for interactive DropletLevelView
    @State private var currentMoisture: Double = 0.5 // Default, will be updated

    var accentColor: Color {
        Theme.Colors.accent(for: "Care")
    }
    
    var body: some View {
        ScrollView {
            // Main VStack for all content in the card
            VStack(alignment: .leading, spacing: Theme.Metrics.Padding.large) { // Consistent large spacing between sections
                Text("Care Guide") // Card's main title
                    .font(Font.pressStart2P(size: 16))
                    .padding(.bottom, Theme.Metrics.Padding.small) // Space after main title
                
                // Sunlight Section
                if details?.sunlight != nil || details?.parsedSunlightLevel != nil {
                    VStack(alignment: .leading, spacing: Theme.Metrics.Padding.small) {
                        Text("Sunlight")
                            .font(Font.pressStart2P(size: 14)) // Sub-section title size
                            .foregroundColor(Theme.Colors.accent(for: "Sunlight"))
                        SunlightGaugeView(currentSunlightLevel: details?.parsedSunlightLevel ?? .partialSun)
                    }
                } else {
                    PlantInfo.InfoRow(label: "Sunlight", value: "N/A", accentColor: Theme.Colors.accent(for: "Sunlight"))
                }
                
                // Water Section
                if details?.water != nil || details?.parsedWaterRequirement != nil {
                    VStack(alignment: .leading, spacing: Theme.Metrics.Padding.small) {
                        Text("Water")
                            .font(Font.pressStart2P(size: 14))
                            .foregroundColor(Theme.Colors.accent(for: "Water"))
                        DropletLevelView(currentMoisture: $currentMoisture, optimalMoisture: details?.parsedWaterRequirement)
                            // Consider removing fixed height if DropletLevelView can size intrinsically
                            // or ensure this height is sufficient for its content (incl. percentage text)
                            // .frame(height: 150) // Adjusted based on previous iteration, review
                    }
                } else {
                    PlantInfo.InfoRow(label: "Water", value: "N/A", accentColor: Theme.Colors.accent(for: "Water"))
                }

                // Temperature Section
                if let tempRange = details?.parsedTemperatureRange {
                    VStack(alignment: .leading, spacing: Theme.Metrics.Padding.small) {
                        Text("Temperature")
                            .font(Font.pressStart2P(size: 14))
                            .foregroundColor(Theme.Colors.accent(for: "Temperature"))
                        ThermoRangeView(optimalRange: tempRange, currentTemp: nil)
                            // Similar to DropletLevelView, review if fixed height is best
                            // .frame(height: 120) // Adjusted, review
                    }
                } else {
                    PlantInfo.InfoRow(label: "Temperature", value: details?.temperature ?? "N/A", accentColor: Theme.Colors.accent(for: "Temperature"))
                }

                // Soil Section (using InfoRow as PixelGauge for pH is in GrowthCard)
                VStack(alignment: .leading, spacing: Theme.Metrics.Padding.small) {
                    Text("Soil")
                        .font(Font.pressStart2P(size: 14))
                        .foregroundColor(Theme.Colors.accent(for: "Soil"))
                    PlantInfo.InfoRow(label: "Details", value: details?.soil ?? "N/A", accentColor: Theme.Colors.accent(for: "Soil"))
                }

            }
            .padding() // Outer padding for the whole ScrollView content
            .onAppear {
                // Initialize currentMoisture when details are available
                currentMoisture = details?.parsedWaterRequirement ?? 0.5
            }
            .onChange(of: details?.latinName) { _ in // Update if details object changes
                currentMoisture = details?.parsedWaterRequirement ?? 0.5
            }
        }
        .background(Theme.Colors.surface) // Background for the whole card
        .cornerRadius(Theme.Metrics.Card.cornerRadius) // Consistent corner radius
        .shadow(color: Theme.Colors.dexShadow.opacity(Theme.Metrics.Card.shadowOpacity), 
                radius: Theme.Metrics.Card.shadowRadius, y: 2) // Consistent shadow
        .padding(.horizontal) // Padding for the card itself against the pager edges
    }
} 