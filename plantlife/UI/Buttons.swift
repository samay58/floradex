import SwiftUI

/// A collection of modern button styles for the app
struct Buttons {
    // MARK: - Modern Button Styles
    
    /// A floating circular button style for action buttons
    struct CircularButtonStyle: ButtonStyle {
        let size: CGFloat
        let backgroundColor: Color
        let foregroundColor: Color
        let hasBorder: Bool
        
        init(
            size: CGFloat = 56,
            backgroundColor: Color = Theme.Colors.surfaceLight,
            foregroundColor: Color = Theme.Colors.textPrimary,
            hasBorder: Bool = true
        ) {
            self.size = size
            self.backgroundColor = backgroundColor
            self.foregroundColor = foregroundColor
            self.hasBorder = hasBorder
        }
        
        func makeBody(configuration: Configuration) -> some View {
            configuration.label
                .font(.system(size: size * 0.4, weight: .medium))
                .foregroundStyle(foregroundColor)
                .frame(width: size, height: size)
                .background(
                    Circle()
                        .fill(backgroundColor)
                        .opacity(configuration.isPressed ? 0.8 : 1.0)
                        .shadow(color: Theme.Colors.dexShadow, radius: 4, x: 0, y: 2)
                )
                .overlay(
                    Group {
                        if hasBorder {
                            Circle()
                                .stroke(backgroundColor, lineWidth: 2)
                                .scaleEffect(1.1)
                        }
                    }
                )
                .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
                .animation(Theme.Animations.snappy, value: configuration.isPressed)
        }
    }
    
    /// Modern pill-shaped button style with full width option
    struct PillButtonStyle: ButtonStyle {
        let backgroundColor: Color
        let foregroundColor: Color
        let fullWidth: Bool
        
        init(
            backgroundColor: Color = Theme.Colors.primaryGreen, 
            foregroundColor: Color = .white,
            fullWidth: Bool = false
        ) {
            self.backgroundColor = backgroundColor
            self.foregroundColor = foregroundColor
            self.fullWidth = fullWidth
        }
        
        func makeBody(configuration: Configuration) -> some View {
            configuration.label
                .font(Theme.Typography.button)
                .foregroundStyle(foregroundColor)
                .padding(.vertical, Theme.Metrics.Padding.small)
                .padding(.horizontal, Theme.Metrics.Padding.medium)
                .if(fullWidth) { view in
                    view.frame(maxWidth: .infinity)
                }
                .background(
                    Capsule()
                        .fill(backgroundColor)
                        .opacity(configuration.isPressed ? 0.8 : 1.0)
                )
                .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
                .animation(Theme.Animations.snappy, value: configuration.isPressed)
        }
    }
    
    /// Primary action button style for main CTAs
    struct PrimaryActionButtonStyle: ButtonStyle {
        let isEnabled: Bool
        
        init(isEnabled: Bool = true) {
            self.isEnabled = isEnabled
        }
        
        func makeBody(configuration: Configuration) -> some View {
            configuration.label
                .font(Theme.Typography.button)
                .foregroundStyle(.white)
                .padding(.vertical, Theme.Metrics.Padding.small + 2) // Slightly larger for primary actions
                .frame(maxWidth: .infinity)
                .background(
                    RoundedRectangle(cornerRadius: Theme.Metrics.cornerRadiusLarge)
                        .fill(isEnabled ? Theme.Colors.primaryGreen : Theme.Colors.iconSecondary)
                        .opacity(configuration.isPressed ? 0.8 : 1.0)
                )
                .scaleEffect(configuration.isPressed && isEnabled ? 0.98 : 1.0)
                .animation(Theme.Animations.snappy, value: configuration.isPressed)
        }
    }
    
    /// Modern glass button style with material background
    struct GlassButtonStyle: ButtonStyle {
        let tint: Color?
        
        init(tint: Color? = nil) {
            self.tint = tint
        }
        
        func makeBody(configuration: Configuration) -> some View {
            configuration.label
                .font(Theme.Typography.button)
                .padding(.vertical, Theme.Metrics.Padding.small)
                .padding(.horizontal, Theme.Metrics.Padding.medium)
                .background {
                    Group {
                        if let tint = tint {
                            ZStack {
                                Rectangle()
                                    .fill(Material.regularMaterial)
                                    .opacity(0.9)
                                Rectangle()
                                    .fill(tint)
                                    .opacity(0.1)
                            }
                        } else {
                            Rectangle()
                                .fill(Material.regularMaterial)
                                .opacity(0.9)
                        }
                    }
                    .opacity(configuration.isPressed ? 0.7 : 1.0)
                }
                .clipShape(RoundedRectangle(cornerRadius: Theme.Metrics.cornerRadiusMedium))
                .shadow(color: Theme.Colors.dexShadow, radius: 3, x: 0, y: 1)
                .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
                .animation(Theme.Animations.snappy, value: configuration.isPressed)
        }
    }
}

// MARK: - View Extensions
extension View {
    /// Apply a circular button style to a button
    func circularButton(
        size: CGFloat = 56,
        backgroundColor: Color = Theme.Colors.surfaceLight,
        foregroundColor: Color = Theme.Colors.textPrimary,
        hasBorder: Bool = true
    ) -> some View {
        self.buttonStyle(
            Buttons.CircularButtonStyle(
                size: size,
                backgroundColor: backgroundColor,
                foregroundColor: foregroundColor,
                hasBorder: hasBorder
            )
        )
    }
    
    /// Apply a modern pill button style to a button
    func pillButton(
        backgroundColor: Color = Theme.Colors.primaryGreen, 
        foregroundColor: Color = .white,
        fullWidth: Bool = false
    ) -> some View {
        self.buttonStyle(
            Buttons.PillButtonStyle(
                backgroundColor: backgroundColor, 
                foregroundColor: foregroundColor,
                fullWidth: fullWidth
            )
        )
    }
    
    /// Apply primary action button style (full width, prominent)
    func primaryActionButton(isEnabled: Bool = true) -> some View {
        self.buttonStyle(Buttons.PrimaryActionButtonStyle(isEnabled: isEnabled))
    }
    
    /// Apply a glass button style to a button
    func glassButton(tint: Color? = nil) -> some View {
        self.buttonStyle(Buttons.GlassButtonStyle(tint: tint))
    }
}

// MARK: - Helper Extensions
// Extension removed to avoid redeclaration - available in Theme or other shared location

// Deprecated components removed - use modern button styles instead

// MARK: - Previews
#Preview("Modern Button Styles") {
    VStack(spacing: 30) {
        Text("Modern Button Styles")
            .font(Theme.Typography.title2)
            .padding(.bottom)
        
        // Circular button
        Button(action: {}) {
            Image(systemName: "camera.fill")
        }
        .circularButton(size: 64, backgroundColor: Theme.Colors.primaryGreen, foregroundColor: .white)
        
        // Standard pill button
        Button("Pill Button") {}
            .pillButton()
        
        // Full width pill button
        Button("Full Width Pill") {}
            .pillButton(fullWidth: true)
        
        // Primary action button
        Button("Primary Action") {}
            .primaryActionButton()
        
        // Glass button
        Button("Glass Button") {}
            .glassButton(tint: Theme.Colors.primaryGreen)
        
        // Small circular navigation button
        Button(action: {}) {
            Image(systemName: "arrow.right")
                .font(.system(size: 16, weight: .bold))
        }
        .circularButton(size: 40, backgroundColor: Theme.Colors.textPrimary, foregroundColor: .white, hasBorder: false)
    }
    .padding()
    .background(Theme.Colors.systemBackground)
} 