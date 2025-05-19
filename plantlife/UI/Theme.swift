import SwiftUI

/// Central theme definition for the application
struct Theme {
    // MARK: - Colors
    struct Colors {
        // Base Colors
        static let primary = Color.primary        // Label color adapts light/dark
        static let secondary = Color.secondary    // Secondary label
        static let background = Color(.systemBackground) // Main surface
        static let surface = Color(.secondarySystemBackground)
        
        // Additional Text / Surface aliases for gauges & components
        static let text = primary
        static let textSecondary = secondary
        static let textDisabled = Color.gray.opacity(0.5)
        static let surfaceVariant = surface
        
        // Plant Type Colors
        static let flower = Color.pink
        static let tree = Color.green
        static let succulent = Color.teal
        static let herb = Color.mint
        static let shrub = Color.orange
        static let vine = Color.indigo
        static let grass = Color.lime
        
        // Floradex Specific Colors
        static let dexBackground = Color(.systemGroupedBackground)
        static let dexCardSurface = Color(.secondarySystemBackground)
        static let dexCardSurfaceDark = Color(.tertiarySystemBackground)
        static let dexShadow = Color.black.opacity(0.08)
        
        /// Return appropriate accent color for a plant species
        /// - Parameter species: The latin name of the species or nil
        /// - Returns: A Color appropriate for the plant type
        static func accent(for species: String?) -> Color {
            guard let species = species?.lowercased() else { return primary }
            
            // Map species family/genus to appropriate colors
            if species.contains("rosa") || species.contains("flower") || species.contains("lili") {
                return flower
            } else if species.contains("quercus") || species.contains("maple") || species.contains("tree") {
                return tree
            } else if species.contains("aloe") || species.contains("cactus") || species.contains("succulent") {
                return succulent
            } else if species.contains("mentha") || species.contains("mint") || species.contains("herb") {
                return herb
            } else if species.contains("cistus") || species.contains("shrub") {
                return shrub
            } else if species.contains("hedera") || species.contains("vine") {
                return vine
            } else if species.contains("festuca") || species.contains("grass") {
                return grass
            }
            
            return primary
        }
    }
    
    // MARK: - Typography
    struct Typography {
        // Title Styles
        static let largeTitle = Font.largeTitle.weight(.bold)
        static let title = Font.title.weight(.semibold)
        static let title2 = Font.title2.weight(.semibold)
        static let title3 = Font.title3.weight(.semibold)
        
        // Body Styles
        static let body = Font.jetBrainsMono(size: 16)
        static let bodyMedium = Font.jetBrainsMono(size: 16).weight(.medium)
        static let bodyBold = Font.jetBrainsMono(size: 16).weight(.bold)
        
        // Caption Styles
        static let caption = Font.jetBrainsMono(size: 12)
        static let captionMedium = Font.jetBrainsMono(size: 12).weight(.medium)
        
        // Button Styles
        static let button = Font.jetBrainsMono(size: 16).weight(.medium)
    }
    
    // MARK: - Animations
    struct Animations {
        // Standard Springs
        static let snappy = Animation.spring(response: 0.3, dampingFraction: 0.7, blendDuration: 0.3)
        static let smooth = Animation.spring(response: 0.6, dampingFraction: 0.8, blendDuration: 0.5)
        static let bouncy = Animation.spring(response: 0.5, dampingFraction: 0.6, blendDuration: 0.3)
        
        // Delays
        static func staggered(index: Int, baseDelay: Double = 0.1) -> Animation {
            return smooth.delay(baseDelay * Double(index))
        }

        // Floradex Specific Animations
        static let floradexDefaultAnimation: Animation = .easeInOut
        static let floradexFastAnimation: Animation = .easeInOut(duration: 0.2)
    }
    
    // MARK: - Metrics
    struct Metrics {
        static let cornerRadius: CGFloat = 12
        static let iconSize: CGFloat = 24
        static let buttonSize: CGFloat = 52
        
        // Floradex Specific Corner Radii
        static let floradexLargeCardRadius: CGFloat = 32.0
        static let floradexSmallCardRadius: CGFloat = 20.0

        struct Padding {
            static let small: CGFloat = 8
            static let medium: CGFloat = 16
            static let large: CGFloat = 24
        }
        
        struct Card {
            static let cornerRadius: CGFloat = 16
            static let shadowRadius: CGFloat = 10
            static let shadowOpacity: Double = 0.1
        }
    }
}

// MARK: - View Extensions
extension View {
    /// Apply the theme to a view
    /// - Returns: A view with theme styles applied
    func themed() -> some View {
        self
            .font(Theme.Typography.body)
            .foregroundStyle(Theme.Colors.primary)
    }
    
    /// Apply a theme animation
    /// - Parameter animation: The animation to apply
    /// - Returns: A view with the animation applied
    func themeAnimation(_ animation: Animation) -> some View {
        self.animation(animation, value: UUID())
    }
}

// Add a convenient Color extension for lime color (missing in SwiftUI)
extension Color {
    static let lime = Color(red: 0.7, green: 0.9, blue: 0.3)
}

// Helper for hex color initialization (optional, can be moved to Color extension)
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0) // Invalid format, return clear
        }

        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
} 