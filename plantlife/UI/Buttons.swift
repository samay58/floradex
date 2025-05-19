import SwiftUI

/// A collection of button styles for the app
struct Buttons {
    // MARK: - Button Styles
    
    /// A floating circular button style
    struct CircularButtonStyle: ButtonStyle {
        let size: CGFloat
        let backgroundColor: Color
        let foregroundColor: Color
        let hasBorder: Bool
        
        init(
            size: CGFloat = 56,
            backgroundColor: Color = .white,
            foregroundColor: Color = .black,
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
                        .shadow(color: .black.opacity(0.15), radius: 4, x: 0, y: 2)
                )
                .overlay(
                    Group {
                        if hasBorder {
                            Circle()
                                .stroke(backgroundColor, lineWidth: 3)
                                .scaleEffect(1.15)
                        }
                    }
                )
                .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
                .animation(.spring(response: 0.3, dampingFraction: 0.6), value: configuration.isPressed)
        }
    }
    
    /// A pill-shaped button style
    struct PillButtonStyle: ButtonStyle {
        let backgroundColor: Color
        let foregroundColor: Color
        
        init(backgroundColor: Color = Theme.Colors.primary, foregroundColor: Color = .white) {
            self.backgroundColor = backgroundColor
            self.foregroundColor = foregroundColor
        }
        
        func makeBody(configuration: Configuration) -> some View {
            configuration.label
                .font(Theme.Typography.button)
                .foregroundStyle(foregroundColor)
                .padding(.vertical, 12)
                .padding(.horizontal, 20)
                .background(
                    Capsule()
                        .fill(backgroundColor)
                        .opacity(configuration.isPressed ? 0.8 : 1.0)
                        .shadow(color: backgroundColor.opacity(0.3), radius: 4, x: 0, y: 2)
                )
                .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
                .animation(.spring(response: 0.3, dampingFraction: 0.6), value: configuration.isPressed)
        }
    }
    
    /// A glass button style
    struct GlassButtonStyle: ButtonStyle {
        let tint: Color?
        
        init(tint: Color? = nil) {
            self.tint = tint
        }
        
        func makeBody(configuration: Configuration) -> some View {
            configuration.label
                .font(Theme.Typography.button)
                .padding(.vertical, 12)
                .padding(.horizontal, 20)
                .background {
                    Group {
                        if let tint = tint {
                            ZStack {
                                Rectangle()
                                    .fill(Material.regularMaterial)
                                    .opacity(0.7)
                                Rectangle()
                                    .fill(tint)
                                    .opacity(0.1)
                            }
                        } else {
                            Rectangle()
                                .fill(Material.regularMaterial)
                                .opacity(0.7)
                        }
                    }
                    .opacity(configuration.isPressed ? 0.7 : 1.0)
                }
                .clipShape(RoundedRectangle(cornerRadius: Theme.Metrics.cornerRadius))
                .shadow(color: .black.opacity(0.1), radius: 3, x: 0, y: 1)
                .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
                .animation(.spring(response: 0.3, dampingFraction: 0.6), value: configuration.isPressed)
        }
    }
}

// MARK: - View Extensions
extension View {
    /// Apply a circular button style to a button
    /// - Parameters:
    ///   - size: The diameter of the button
    ///   - backgroundColor: The background color of the button
    ///   - foregroundColor: The foreground color of the button
    ///   - hasBorder: Whether the button has a border
    /// - Returns: A button with the circular style applied
    func circularButton(
        size: CGFloat = 56,
        backgroundColor: Color = .white,
        foregroundColor: Color = .black,
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
    
    /// Apply a pill button style to a button
    /// - Parameters:
    ///   - backgroundColor: The background color of the button
    ///   - foregroundColor: The foreground color of the button
    /// - Returns: A button with the pill style applied
    func pillButton(backgroundColor: Color = Theme.Colors.primary, foregroundColor: Color = .white) -> some View {
        self.buttonStyle(Buttons.PillButtonStyle(backgroundColor: backgroundColor, foregroundColor: foregroundColor))
    }
    
    /// Apply a glass button style to a button
    /// - Parameter tint: An optional tint color for the button
    /// - Returns: A button with the glass style applied
    func glassButton(tint: Color? = nil) -> some View {
        self.buttonStyle(Buttons.GlassButtonStyle(tint: tint))
    }
}

// MARK: - Previews
#Preview("Button Styles") {
    VStack(spacing: 40) {
        Button(action: {}) {
            Image(systemName: "camera.fill")
        }
        .circularButton(size: 80)
        
        Button("Pill Button") {}
            .pillButton()
        
        Button("Glass Button") {}
            .glassButton(tint: Theme.Colors.primary)
        
        Button(action: {}) {
            Image(systemName: "arrow.right")
                .font(.system(size: 16, weight: .bold))
        }
        .circularButton(size: 48, backgroundColor: .black, foregroundColor: .white, hasBorder: false)
    }
    .padding()
    .background(Color.gray.opacity(0.1))
}

struct PixelButton: View {
    enum Style {
        case primary
        case secondary
        
        var backgroundColor: Color {
            switch self {
            case .primary:
                return Theme.Colors.primary
            case .secondary:
                return Theme.Colors.secondary
            }
        }
        
        var foregroundColor: Color {
            switch self {
            case .primary, .secondary:
                return .white
            }
        }
        
        var strokeColor: Color {
            switch self {
            case .primary:
                return Color("#8BAC0F")
            case .secondary:
                return Color.gray.opacity(0.8)
            }
        }
    }
    
    let style: Style
    let icon: String
    var action: () -> Void
    
    @State private var isPressed = false
    
    var body: some View {
        Button(action: {
            let impactGenerator = UIImpactFeedbackGenerator(style: .heavy)
            impactGenerator.prepare()
            
            // Provide haptic feedback
            impactGenerator.impactOccurred()
            
            action()
        }) {
            Image(systemName: icon)
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(style.foregroundColor)
                .frame(width: 72, height: 72)
                .background(style.backgroundColor)
                .clipShape(Circle())
                .overlay(
                    Circle()
                        .strokeBorder(style.strokeColor, lineWidth: 2)
                        .padding(4)
                )
                .shadow(color: Color("#0F380F").opacity(0.5), radius: 2, x: 0, y: 2)
                .scaleEffect(isPressed ? 0.95 : 1.0)
        }
        .buttonStyle(PlainButtonStyle())
        .pressEvents(onPress: { isPressed = true }, onRelease: { isPressed = false })
    }
}

// Add a helper for press events
extension View {
    func pressEvents(onPress: @escaping () -> Void, onRelease: @escaping () -> Void) -> some View {
        self.simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in onPress() }
                .onEnded { _ in onRelease() }
        )
    }
} 