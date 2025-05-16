import SwiftUI

/// Central theme definition for the application
struct Theme {
    // MARK: - Colors
    struct Colors {
        // Base Colors
        static let primary = Color("AccentColor")
        static let secondary = Color.secondary
        static let background = Color(.systemBackground)
        static let surface = Color(.secondarySystemBackground)
        
        // Plant Type Colors
        static let flower = Color.pink
        static let tree = Color.green
        static let succulent = Color.teal
        static let herb = Color.mint
        static let shrub = Color.orange
        static let vine = Color.indigo
        static let grass = Color.lime
        
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
        static let body = Font.system(.body, design: .rounded)
        static let bodyMedium = Font.system(.body, design: .rounded).weight(.medium)
        static let bodyBold = Font.system(.body, design: .rounded).weight(.bold)
        
        // Caption Styles
        static let caption = Font.system(.caption, design: .rounded)
        static let captionMedium = Font.system(.caption, design: .rounded).weight(.medium)
        
        // Button Styles
        static let button = Font.system(.body, design: .rounded).weight(.medium)
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
    }
    
    // MARK: - Metrics
    struct Metrics {
        static let cornerRadius: CGFloat = 12
        static let iconSize: CGFloat = 24
        static let buttonSize: CGFloat = 52
        
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