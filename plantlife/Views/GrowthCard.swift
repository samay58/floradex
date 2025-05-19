import SwiftUI

struct GrowthCard: View, DexDetailCard {
    let id: Int = 2 // Third card
    let details: SpeciesDetails?
    
    var accentColor: Color {
        Theme.Colors.accent(for: "Growth")
    }

    // Placeholder logic for care difficulty - replace with actual data/logic
    private var careDifficulty: (value: Double, label: String) {
        guard let details = details else { return (0.5, "Unknown") }
        // Example: Deriving from commonName length for visual variety in preview
        // In a real app, this would come from SpeciesDetails or be a more complex heuristic.
        let nameLength = details.commonName?.count ?? 10
        if nameLength < 15 {
            return (0.8, "Easy") // Higher value = easier
        } else if nameLength < 25 {
            return (0.5, "Moderate")
        } else {
            return (0.2, "Hard")
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Metrics.Padding.large) {
                Text("Growth & Habit")
                    .font(Font.pressStart2P(size: 16))
                    .padding(.bottom, Theme.Metrics.Padding.small)

                VStack(alignment: .leading, spacing: Theme.Metrics.Padding.small) {
                    Text("Growth Habit")
                        .font(Font.pressStart2P(size: 14))
                        .foregroundColor(Theme.Colors.accent(for: "Growth"))
                    PlantInfo.InfoRow(label: "Details", value: details?.growthHabit ?? "N/A", accentColor: Theme.Colors.accent(for: "Growth"))
                }

                VStack(alignment: .leading, spacing: Theme.Metrics.Padding.small) {
                    Text("Bloom Time")
                        .font(Font.pressStart2P(size: 14))
                        .foregroundColor(Theme.Colors.accent(for: "Bloom"))
                    PlantInfo.InfoRow(label: "Details", value: details?.bloomTime ?? "N/A", accentColor: Theme.Colors.accent(for: "Bloom"))
                }
                
                if let soilPH = details?.parsedSoilPH {
                    VStack(alignment: .leading, spacing: Theme.Metrics.Padding.small) {
                        Text("Soil pH")
                            .font(Font.pressStart2P(size: 14))
                            .foregroundColor(Theme.Colors.accent(for: "Soil"))
                        PixelGaugeView(
                            label: String(format: "pH %.1f", soilPH * 14), // Display actual pH
                            value: soilPH, // Normalized value (0-1)
                            color: Theme.Colors.accent(for: "Soil"),
                            numberOfSegments: 14
                        )
                    }
                } else {
                     PlantInfo.InfoRow(label: "Soil pH", value: "N/A", accentColor: Theme.Colors.accent(for: "Soil"))
                }
                
                VStack(alignment: .leading, spacing: Theme.Metrics.Padding.small) {
                    Text("Care Difficulty")
                        .font(Font.pressStart2P(size: 14))
                        .foregroundColor(Theme.Colors.accent(for: "Difficulty"))
                    
                    if #available(iOS 16.0, *) {
                        Gauge(value: careDifficulty.value, label: {
                            Text(careDifficulty.label)
                        }) {
                            // Current value text can be part of the label or omitted if redundant
                        }
                        .gaugeStyle(.accessoryCircular)
                        .tint(careDifficulty.value > 0.6 ? .green : (careDifficulty.value > 0.3 ? .orange : .red))
                    } else {
                        PlantInfo.InfoRow(label: "Level", value: careDifficulty.label, accentColor: Theme.Colors.accent(for: "Difficulty"))
                    }
                }
            }
            .padding()
        }
        .background(Theme.Colors.surface)
        .cornerRadius(Theme.Metrics.Card.cornerRadius)
        .shadow(color: Theme.Colors.dexShadow.opacity(Theme.Metrics.Card.shadowOpacity), 
                radius: Theme.Metrics.Card.shadowRadius, y: 2)
        .padding(.horizontal)
    }
} 