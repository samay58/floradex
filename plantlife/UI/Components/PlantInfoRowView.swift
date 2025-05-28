import SwiftUI

/// Modern component for displaying plant information as label-value pairs
/// Replaces complex gauges and GameBoy-style info displays with clean typography
struct PlantInfoRowView: View {
    let label: String
    let value: String
    var isToxic: Bool = false // Special handling for toxicity warnings
    var icon: String? = nil // Optional SF Symbol icon

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: Theme.Metrics.Padding.small) {
            // Optional icon
            if let iconName = icon {
                SFSymbolHelper.systemSymbol(iconName)
                    .font(.system(size: Theme.Metrics.iconSizeSmall))
                    .foregroundColor(Theme.Colors.primaryGreen)
                    .frame(width: Theme.Metrics.iconSizeSmall)
                    .accessibilityHidden(true) // Icon is decorative, label provides context
            }
            
            // Label
            Text(label)
                .font(Theme.Typography.subheadline.weight(.medium))
                .foregroundColor(Theme.Colors.textSecondary)
                .frame(width: 80, alignment: .leading) // Consistent label width for alignment
                .accessibilityHidden(true) // Will be part of combined accessibility label
            
            // Value with special handling for toxicity
            if isToxic && (value.lowercased().contains("toxic") || value.lowercased().contains("poison")) {
                HStack(spacing: Theme.Metrics.Padding.extraSmall) {
                    SFSymbolHelper.exclamationTriangleFill
                        .font(.system(size: 14))
                        .foregroundColor(.orange)
                        .accessibilityHidden(true) // Will be part of combined accessibility label
                    Text(value)
                        .font(Theme.Typography.body)
                        .foregroundColor(Theme.Colors.textPrimary)
                        .accessibilityHidden(true) // Will be part of combined accessibility label
                }
            } else {
                Text(value.isEmpty ? "N/A" : value)
                    .font(Theme.Typography.body)
                    .foregroundColor(value.isEmpty ? Theme.Colors.textDisabled : Theme.Colors.textPrimary)
                    .accessibilityHidden(true) // Will be part of combined accessibility label
            }
            
            Spacer() // Push content to left
        }
        .padding(.vertical, Theme.Metrics.Padding.extraSmall / 2) // Subtle vertical spacing
        .accessibilityElement(children: .ignore) // Combine all elements into one
        .accessibilityLabel(accessibilityLabel)
        .accessibilityValue(accessibilityValue)
    }
    
    // MARK: - Accessibility Helpers
    
    private var accessibilityLabel: String {
        return label
    }
    
    private var accessibilityValue: String {
        let displayValue = value.isEmpty ? "Not available" : value
        
        if isToxic && (value.lowercased().contains("toxic") || value.lowercased().contains("poison")) {
            return "Warning: \(displayValue)"
        }
        
        return displayValue
    }
}

// MARK: - Convenience Initializers for Common Plant Info Types

extension PlantInfoRowView {
    /// Creates a sunlight info row with appropriate icon
    static func sunlight(_ value: String) -> PlantInfoRowView {
        PlantInfoRowView(label: "Light", value: value, icon: "sun.max.fill")
    }
    
    /// Creates a water info row with appropriate icon
    static func water(_ value: String) -> PlantInfoRowView {
        PlantInfoRowView(label: "Water", value: value, icon: "drop.fill")
    }
    
    /// Creates a temperature info row with appropriate icon
    static func temperature(_ value: String) -> PlantInfoRowView {
        PlantInfoRowView(label: "Temperature", value: value, icon: "thermometer")
    }
    
    /// Creates a humidity info row with appropriate icon
    static func humidity(_ value: String) -> PlantInfoRowView {
        PlantInfoRowView(label: "Humidity", value: value, icon: "cloud.fill")
    }
    
    /// Creates a soil info row with appropriate icon
    static func soil(_ value: String) -> PlantInfoRowView {
        PlantInfoRowView(label: "Soil", value: value, icon: "mountain.2.fill")
    }
    
    /// Creates a fertilizer info row with appropriate icon
    static func fertilizer(_ value: String) -> PlantInfoRowView {
        PlantInfoRowView(label: "Fertilizer", value: value, icon: "leaf.fill")
    }
    
    /// Creates a height info row with appropriate icon
    static func height(_ value: String) -> PlantInfoRowView {
        PlantInfoRowView(label: "Height", value: value, icon: "arrow.up.and.down")
    }
    
    /// Creates a spread info row with appropriate icon
    static func spread(_ value: String) -> PlantInfoRowView {
        PlantInfoRowView(label: "Spread", value: value, icon: "arrow.left.and.right")
    }
    
    /// Creates a growth rate info row with appropriate icon
    static func growthRate(_ value: String) -> PlantInfoRowView {
        PlantInfoRowView(label: "Growth Rate", value: value, icon: "chart.line.uptrend.xyaxis")
    }
    
    /// Creates a toxicity info row with warning styling
    static func toxicity(_ value: String) -> PlantInfoRowView {
        PlantInfoRowView(label: "Toxicity", value: value, isToxic: true, icon: "exclamationmark.shield.fill")
    }
}

#if DEBUG
struct PlantInfoRowView_Previews: PreviewProvider {
    static var previews: some View {
        VStack(alignment: .leading, spacing: Theme.Metrics.Padding.small) {
            Text("Plant Care Information")
                .font(Theme.Typography.title3)
                .padding(.bottom)
            
            VStack(alignment: .leading, spacing: Theme.Metrics.Padding.extraSmall) {
                PlantInfoRowView.sunlight("Bright, indirect")
                PlantInfoRowView.water("Moderate")
                PlantInfoRowView.temperature("65-80°F")
                PlantInfoRowView.humidity("High")
                PlantInfoRowView.soil("Well-draining")
                PlantInfoRowView.fertilizer("Monthly during growing season")
                
                Divider()
                    .padding(.vertical, Theme.Metrics.Padding.small)
                
                PlantInfoRowView.height("3-6 ft")
                PlantInfoRowView.spread("2-3 ft")
                PlantInfoRowView.growthRate("Moderate")
                PlantInfoRowView.toxicity("Toxic to pets")
                
                // Example with empty value
                PlantInfoRowView(label: "Notes", value: "")
            }
        }
        .padding()
        .background(Theme.Colors.surfaceLight)
        .cornerRadius(Theme.Metrics.cornerRadiusLarge)
        .padding()
        .background(Theme.Colors.systemBackground)
        .previewLayout(.sizeThatFits)
    }
}
#endif 