import SwiftUI

// MARK: - Overview Content

struct OverviewContent: View {
    let entry: DexEntry
    let details: SpeciesDetails
    
    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Metrics.Padding.medium) {
            // Basic Info
            InfoCard(title: "Classification") {
                VStack(alignment: .leading, spacing: Theme.Metrics.Padding.small) {
                    if let commonName = details.commonName {
                        PlantInfo.InfoRow(label: "Common Name", value: commonName, accentColor: Theme.Colors.primaryGreen)
                    }
                    PlantInfo.InfoRow(label: "Scientific Name", value: details.latinName, accentColor: Theme.Colors.primaryGreen)
                    if let family = details.family {
                        PlantInfo.InfoRow(label: "Family", value: family, accentColor: Theme.Colors.primaryGreen)
                    }
                    PlantInfo.InfoRow(label: "Discovered", value: {
                        let formatter = DateFormatter()
                        formatter.dateStyle = .medium
                        return formatter.string(from: entry.createdAt)
                    }(), accentColor: Theme.Colors.primaryGreen)
                }
            }
            
            // Description
            if let description = details.parsedDescription, !description.isEmpty {
                InfoCard(title: "Description") {
                    Text(description)
                        .font(Theme.Typography.body)
                        .foregroundColor(Theme.Colors.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            
            // Tags
            if !entry.tags.isEmpty {
                InfoCard(title: "Categories") {
                    FlowLayout(spacing: Theme.Metrics.Padding.small) {
                        ForEach(entry.tags, id: \.self) { tag in
                            TagChip(tagName: tag, isSelected: false) {}
                                .disabled(true)
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Care Content

struct CareContent: View {
    let details: SpeciesDetails
    
    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Metrics.Padding.medium) {
            // Care gauges
            InfoCard(title: "Care Requirements") {
                VStack(spacing: Theme.Metrics.Padding.medium) {
                    // Watering
                    if details.water != nil {
                        CareGaugeRow(
                            icon: "drop.fill",
                            title: "Watering",
                            value: Int(details.parsedWaterRequirement * 5),
                            maxValue: 5,
                            color: .blue
                        )
                    }
                    
                    // Sunlight
                    if details.sunlight != nil {
                        CareGaugeRow(
                            icon: "sun.max.fill",
                            title: "Sunlight",
                            value: details.parsedSunlightLevel.gaugeValue,
                            maxValue: 5,
                            color: .orange
                        )
                    }
                    
                    // Difficulty
                    if let difficulty = details.careDifficulty {
                        CareGaugeRow(
                            icon: "star.fill",
                            title: "Difficulty",
                            value: difficulty,
                            maxValue: 5,
                            color: Theme.Colors.primaryGreen
                        )
                    }
                }
            }
            
            // Temperature range
            if details.minTemp != nil || details.maxTemp != nil {
                InfoCard(title: "Temperature Range") {
                    TemperatureRangeView(
                        minTemp: details.minTemp ?? 0,
                        maxTemp: details.maxTemp ?? 100
                    )
                }
            }
        }
    }
}

// MARK: - Growth Content

struct GrowthContent: View {
    let details: SpeciesDetails
    
    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Metrics.Padding.medium) {
            // Growth characteristics
            InfoCard(title: "Growth Information") {
                VStack(alignment: .leading, spacing: Theme.Metrics.Padding.small) {
                    if let growthHabit = details.growthHabit {
                        PlantInfo.InfoRow(label: "Growth Habit", value: growthHabit, accentColor: Theme.Colors.primaryGreen)
                    }
                    if let bloomTime = details.bloomTime {
                        PlantInfo.InfoRow(label: "Bloom Time", value: bloomTime, accentColor: Theme.Colors.primaryGreen)
                    }
                    if let temperature = details.temperature {
                        PlantInfo.InfoRow(label: "Temperature", value: temperature, accentColor: Theme.Colors.primaryGreen)
                    }
                    if let soil = details.soil {
                        PlantInfo.InfoRow(label: "Soil", value: soil, accentColor: Theme.Colors.primaryGreen)
                    }
                }
            }
            
            // Native region
            if let nativeRegion = details.nativeRegion {
                InfoCard(title: "Native Region") {
                    HStack {
                        Image(systemName: "globe.americas")
                            .font(.system(size: 20))
                            .foregroundColor(Theme.Colors.primaryGreen)
                        Text(nativeRegion)
                            .font(Theme.Typography.body)
                            .foregroundColor(Theme.Colors.textSecondary)
                    }
                }
            }
        }
    }
}

// MARK: - Supporting Views

struct InfoCard<Content: View>: View {
    let title: String
    @ViewBuilder let content: () -> Content
    
    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Metrics.Padding.small) {
            Text(title)
                .font(Theme.Typography.subheadline.weight(.semibold))
                .foregroundColor(Theme.Colors.textPrimary)
            
            content()
                .padding()
                .background(Theme.Colors.systemFill.opacity(0.5))
                .cornerRadius(Theme.Metrics.cornerRadiusSmall)
        }
    }
}

struct CareGaugeRow: View {
    let icon: String
    let title: String
    let value: Int
    let maxValue: Int
    let color: Color
    
    var body: some View {
        HStack(spacing: Theme.Metrics.Padding.medium) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundColor(color)
                .frame(width: 30)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(Theme.Typography.caption)
                    .foregroundColor(Theme.Colors.textSecondary)
                
                // Gauge bar
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Theme.Colors.systemFill)
                            .frame(height: 8)
                        
                        RoundedRectangle(cornerRadius: 4)
                            .fill(color)
                            .frame(
                                width: geometry.size.width * (CGFloat(value) / CGFloat(maxValue)),
                                height: 8
                            )
                            .animation(AnimationConstants.smoothSpring, value: value)
                    }
                }
                .frame(height: 8)
            }
            
            Text("\(value)/\(maxValue)")
                .font(Theme.Typography.caption.monospacedDigit())
                .foregroundColor(Theme.Colors.textSecondary)
        }
    }
}

struct TemperatureRangeView: View {
    let minTemp: Int
    let maxTemp: Int
    
    var body: some View {
        HStack(spacing: Theme.Metrics.Padding.medium) {
            VStack(alignment: .center) {
                Image(systemName: "thermometer.low")
                    .font(.system(size: 24))
                    .foregroundColor(.blue)
                Text("\(minTemp)°F")
                    .font(Theme.Typography.headline.monospacedDigit())
                    .foregroundColor(Theme.Colors.textPrimary)
                Text("Min")
                    .font(Theme.Typography.caption)
                    .foregroundColor(Theme.Colors.textSecondary)
            }
            
            Spacer()
            
            // Temperature gradient bar
            GeometryReader { geometry in
                LinearGradient(
                    gradient: Gradient(colors: [.blue, .green, .yellow, .orange, .red]),
                    startPoint: .leading,
                    endPoint: .trailing
                )
                .frame(height: 8)
                .cornerRadius(4)
                .overlay(
                    // Optimal range indicator
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.white)
                        .frame(width: 4, height: 12)
                        .offset(x: geometry.size.width * 0.5)
                )
            }
            .frame(height: 20)
            
            Spacer()
            
            VStack(alignment: .center) {
                Image(systemName: "thermometer.high")
                    .font(.system(size: 24))
                    .foregroundColor(.red)
                Text("\(maxTemp)°F")
                    .font(Theme.Typography.headline.monospacedDigit())
                    .foregroundColor(Theme.Colors.textPrimary)
                Text("Max")
                    .font(Theme.Typography.caption)
                    .foregroundColor(Theme.Colors.textSecondary)
            }
        }
        .padding(.vertical, Theme.Metrics.Padding.small)
    }
}

// Simple flow layout for tags
struct FlowLayout: Layout {
    var spacing: CGFloat = 8
    
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = FlowResult(
            in: proposal.replacingUnspecifiedDimensions().width,
            subviews: subviews,
            spacing: spacing
        )
        return result.size
    }
    
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = FlowResult(
            in: bounds.width,
            subviews: subviews,
            spacing: spacing
        )
        for (index, subview) in subviews.enumerated() {
            subview.place(at: CGPoint(x: result.positions[index].x + bounds.minX,
                                     y: result.positions[index].y + bounds.minY),
                         proposal: .unspecified)
        }
    }
    
    struct FlowResult {
        var size: CGSize = .zero
        var positions: [CGPoint] = []
        
        init(in maxWidth: CGFloat, subviews: Subviews, spacing: CGFloat) {
            var x: CGFloat = 0
            var y: CGFloat = 0
            var maxHeight: CGFloat = 0
            
            for subview in subviews {
                let size = subview.sizeThatFits(.unspecified)
                
                if x + size.width > maxWidth, x > 0 {
                    x = 0
                    y += maxHeight + spacing
                    maxHeight = 0
                }
                
                positions.append(CGPoint(x: x, y: y))
                x += size.width + spacing
                maxHeight = max(maxHeight, size.height)
            }
            
            self.size = CGSize(width: maxWidth, height: y + maxHeight)
        }
    }
}