import SwiftUI

// Enum to represent sunlight levels
enum SunlightLevel: String, CaseIterable, Identifiable {
    case fullSun = "Full Sun"
    case partialSun = "Partial Sun"
    case shade = "Shade"
    // Could add more granular levels if needed e.g. fullShade, dappledSun
    
    var id: String { self.rawValue }
    
    var iconName: String {
        switch self {
        case .fullSun: return "sun.max.fill"
        case .partialSun: return "cloud.sun.fill"
        case .shade: return "cloud.fill" // Or perhaps a tree icon if available
        }
    }
    
    // Example: Could store an associated value like hours of sun
    // var hours: Int {
    //    switch self {
    //    case .fullSun: return 6
    //    case .partialSun: return 4
    //    case .shade: return 2
    //    }
    // }
}

struct SunlightGaugeView: View {
    // Input: The current sunlight requirement for the plant
    let currentSunlightLevel: SunlightLevel // From SpeciesDetails.sunlight (needs parsing)
    // Input: Optional: if the gauge is interactive, this would be a @Binding
    // @Binding var selectedLevel: SunlightLevel 
    
    // For display purposes, we might just highlight the required level.
    // Or, if it's for user input, we'd have a @State for the selection.
    @State private var highlightedLevel: SunlightLevel? = nil // For tap interaction feedback
    
    // Static array of all levels for creating segments
    private let allLevels = SunlightLevel.allCases
    
    // TODO: Parse `SpeciesDetails.sunlight` string into a `SunlightLevel` enum.
    // This parsing logic might live in SpeciesDetails or a utility.
    // For now, the view expects a direct SunlightLevel enum.

    var body: some View {
        HStack(spacing: 10) {
            ForEach(allLevels) { level in
                Button(action: {
                    print("Tapped on sunlight level: \(level.rawValue)")
                    highlightedLevel = level
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        if highlightedLevel == level { highlightedLevel = nil }
                    }
                }) {
                    VStack(spacing: 4) {
                        Image(systemName: level.iconName)
                            .font(.system(size: 24))
                            .foregroundColor(iconColor(for: level))
                            .frame(width: 35, height: 35)
                            .padding(8)
                            .background(
                                Circle()
                                    .fill(backgroundColor(for: level))
                                    .shadow(color: .black.opacity(isHighlighted(level) ? 0.3 : 0.1), radius: isHighlighted(level) ? 3 : 1, y: 1)
                            )
                            .scaleEffect(isHighlighted(level) ? 1.1 : 1.0)
                        
                        Text(level.rawValue.split(separator: " ").first ?? "")
                            .font(.system(size: 8, weight: .bold, design: .monospaced))
                            .foregroundColor(Theme.Colors.textSecondary)
                            .lineLimit(1)
                    }
                }
                .buttonStyle(PlainButtonStyle())
                .animation(.spring(response: 0.3, dampingFraction: 0.6), value: highlightedLevel)
            }
        }
    }
    
    private func iconColor(for level: SunlightLevel) -> Color {
        if level == currentSunlightLevel {
            return Color.yellow
        } else if level == highlightedLevel {
            return Color.orange
        }
        return Theme.Colors.textDisabled
    }
    
    private func backgroundColor(for level: SunlightLevel) -> Color {
        if level == currentSunlightLevel {
            return Color.yellow.opacity(0.2)
        } else if level == highlightedLevel {
            return Color.orange.opacity(0.2)
        }
        return Theme.Colors.surface
    }
    
    private func isHighlighted(_ level: SunlightLevel) -> Bool {
        return level == highlightedLevel || level == currentSunlightLevel
    }
}

#if DEBUG
struct SunlightGaugeView_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 20) {
            VStack {
                Text("Sunlight Requirements").font(.headline)
                SunlightGaugeView(currentSunlightLevel: .fullSun)
            }
            .padding()
            .background(Color.gray.opacity(0.2))
            .cornerRadius(10)

            SunlightGaugeView(currentSunlightLevel: .partialSun)
            SunlightGaugeView(currentSunlightLevel: .shade)
        }
        .padding()
        .background(Color.gray.opacity(0.1))
    }
}
#endif 