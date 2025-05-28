import SwiftUI

/// Central theme definition for the application
struct Theme {
    // MARK: - Colors (Updated for Modern Design)
    struct Colors {
        // New Primary Palette
        static let primaryGreen = Color(hex: "#2EB875") // Vibrant green accent
        static let backgroundLight = Color(hex: "#F7F7F8") // Off-white/Light Gray - will be overridden by asset
        static let surfaceLight = Color.white // For cards and surfaces - will be overridden by asset

        static let textPrimary = Color.primary // Use system primary for automatic dark mode
        static let textSecondary = Color.secondary // Use system secondary for automatic dark mode  
        static let textDisabled = Color.primary.opacity(0.38)

        static let iconPrimary = Color.primary.opacity(0.70)
        static let iconSecondary = Color.primary.opacity(0.50)

        // System-adaptive colors (automatically handle dark mode)
        static let systemBackground = Color(.systemBackground)
        static let systemGroupedBackground = Color(.systemGroupedBackground)
        static let systemFill = Color(.systemFill)
        static let systemSecondaryFill = Color(.secondarySystemFill)
        
        // Asset catalog colors (automatically handle dark mode)
        static let backgroundFromAsset = Color("BackgroundColor")
        static let accentFromAsset = Color("AccentColor")

        // Semantic colors that adapt to dark mode
        static let cardBackground = Color(.secondarySystemBackground)
        static let separatorColor = Color(.separator)
        static let labelColor = Color(.label)
        static let secondaryLabelColor = Color(.secondaryLabel)
        
        // Semantic Card Background Colors for Plant Types
        static let succulentCardBackground = Color(hex: "#E0F2F7")
        static let flowerCardBackground = Color(hex: "#FFF0F5")
        static let treeCardBackground = Color(hex: "#F0FFF0")
        
        // Enhanced icon colors
        static let iconDisabled = Color.primary.opacity(0.3)

        // Legacy aliases for backward compatibility during transition
        @available(*, deprecated, message: "Use textPrimary instead")
        static let primary = Color.primary
        @available(*, deprecated, message: "Use textSecondary instead") 
        static let secondary = Color.secondary
        @available(*, deprecated, message: "Use systemBackground instead")
        static let background = Color(.systemBackground)
        @available(*, deprecated, message: "Use cardBackground instead")
        static let surface = Color(.secondarySystemBackground)
        
        // Additional Text / Surface aliases for backward compatibility
        @available(*, deprecated, message: "Use textPrimary instead")
        static let text = textPrimary
        @available(*, deprecated, message: "Use cardBackground instead")
        static let surfaceVariant = cardBackground
        
        // Plant Type Colors (retained but may be simplified in new design)
        static let flower = Color.pink
        static let tree = Color.green
        static let succulent = Color.teal
        static let herb = Color.mint
        static let shrub = Color.orange
        static let vine = Color.indigo
        static let grass = Color.lime
        
        // Floradex Specific Colors (Updated for dark mode)
        static let dexBackground = systemBackground // Use system background instead of custom
        static let dexCardSurface = cardBackground // Use semantic card background
        static let dexCardSurfaceDark = Color(.tertiarySystemBackground) // Keep for specific dark needs
        static let dexShadow = Color.primary.opacity(0.08) // Shadow that adapts to dark mode
        
        /// Return appropriate accent color for a plant species
        /// - Parameter species: The latin name of the species or nil
        /// - Returns: A Color appropriate for the plant type
        static func accent(for species: String?) -> Color {
            // For the new design, consistent accent (primaryGreen) might be better
            // than per-species colors, unless specified by detailed designs.
            // For now, defaulting to primaryGreen for consistency
            return primaryGreen
            
            // Legacy per-species logic preserved but commented for potential future use
            /*
            guard let species = species?.lowercased() else { return primaryGreen }
            
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
            
            return primaryGreen
            */
        }
    }
    
    // MARK: - Typography (Updated to System Fonts)
    struct Typography {
        // Title Styles - Using system fonts
        static let largeTitle = Font.system(.largeTitle, design: .default).weight(.bold)
        static let title = Font.system(.title, design: .default).weight(.semibold)
        static let title2 = Font.system(.title2, design: .default).weight(.semibold)
        static let title3 = Font.system(.title3, design: .default).weight(.semibold)
        
        static let headline = Font.system(.headline, design: .default).weight(.semibold)
        static let body = Font.system(.body, design: .default)
        static let bodyMedium = Font.system(.body, design: .default).weight(.medium)
        static let bodyBold = Font.system(.body, design: .default).weight(.bold)
        
        static let callout = Font.system(.callout, design: .default)
        static let subheadline = Font.system(.subheadline, design: .default)

        static let caption = Font.system(.caption, design: .default)
        static let captionMedium = Font.system(.caption, design: .default).weight(.medium)
        static let caption2 = Font.system(.caption2, design: .default)
        
        // Button Styles
        static let button = Font.system(.body, design: .default).weight(.semibold)
        
        // Legacy font aliases removed - use system fonts from Typography
    }
    
    // MARK: - Animations (Updated with faster defaults)
    struct Animations {
        static let snappy = Animation.spring(response: 0.35, dampingFraction: 0.75, blendDuration: 0)
        static let smooth = Animation.spring(response: 0.5, dampingFraction: 0.8, blendDuration: 0)
        static let bouncy = Animation.spring(response: 0.5, dampingFraction: 0.65, blendDuration: 0)
        
        static func staggered(index: Int, baseDelay: Double = 0.05) -> Animation { // Faster base delay
            return smooth.delay(baseDelay * Double(index))
        }

        // Legacy animations for backward compatibility
        @available(*, deprecated, message: "Use snappy, smooth, or bouncy instead")
        static let floradexDefaultAnimation: Animation = .easeInOut
        @available(*, deprecated, message: "Use snappy instead")
        static let floradexFastAnimation: Animation = .easeInOut(duration: 0.2)
    }
    
    // MARK: - Metrics (Updated for Modern Design)
    struct Metrics {
        // Corner Radii
        static let cornerRadiusSmall: CGFloat = 8
        static let cornerRadiusMedium: CGFloat = 12 // Common for buttons, inputs
        static let cornerRadiusLarge: CGFloat = 16 // Common for cards

        // Icon Sizes
        static let iconSizeSmall: CGFloat = 20
        static let iconSizeMedium: CGFloat = 24
        static let iconSizeLarge: CGFloat = 28

        // Legacy aliases
        @available(*, deprecated, message: "Use cornerRadiusMedium instead")
        static let cornerRadius: CGFloat = 12
        @available(*, deprecated, message: "Use iconSizeMedium instead")
        static let iconSize: CGFloat = 24
        static let buttonSize: CGFloat = 52

        struct Padding {
            static let micro: CGFloat = 4
            static let extraSmall: CGFloat = 8
            static let small: CGFloat = 12
            static let medium: CGFloat = 16
            static let large: CGFloat = 24
            static let extraLarge: CGFloat = 32
        }
        
        struct Card {
            static let cornerRadius: CGFloat = 16
            static let shadowRadius: CGFloat = 10
            static let shadowOpacity: Double = 0.1
        }
        
        // Legacy Floradex specific metrics (may be consolidated)
        @available(*, deprecated, message: "Use cornerRadiusLarge instead")
        static let floradexLargeCardRadius: CGFloat = 32.0
        @available(*, deprecated, message: "Use cornerRadiusMedium instead")
        static let floradexSmallCardRadius: CGFloat = 20.0
    }
}

// MARK: - View Extensions
extension View {
    /// Apply the modern theme to a view
    /// - Returns: A view with theme styles applied
    func themed() -> some View {
        self
            .font(Theme.Typography.body)
            .foregroundStyle(Theme.Colors.textPrimary)
    }
    
    /// Apply a theme animation
    /// - Parameter animation: The animation to apply
    /// - Returns: A view with the animation applied
    func themeAnimation(_ animation: Animation) -> some View {
        self.animation(animation, value: UUID())
    }
    
    /// Conditionally apply a modifier
    /// - Parameters:
    ///   - condition: The condition to check
    ///   - transform: The transform to apply if condition is true
    /// - Returns: The view with or without the transform applied
    @ViewBuilder
    func `if`<Content: View>(_ condition: Bool, transform: (Self) -> Content) -> some View {
        if condition {
            transform(self)
        } else {
            self
        }
    }
}

// Add a convenient Color extension for lime color (missing in SwiftUI)
extension Color {
    static let lime = Color(red: 0.7, green: 0.9, blue: 0.3)
}

// Helper for hex color initialization
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