import SwiftUI

extension Color {
    static func accent(for species: String?) -> Color {
        guard let species, !species.isEmpty else { return .accentColor }
        let hash = abs(species.hashValue)
        let hue = Double(hash % 256) / 255.0
        // low saturation, high brightness pastel
        return Color(hue: hue, saturation: 0.35, brightness: 0.95)
    }
} 