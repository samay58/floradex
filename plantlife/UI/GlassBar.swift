import SwiftUI

/// A view modifier that applies a glass-like material background effect
struct GlassBar: ViewModifier {
    enum BarStyle {
        case top
        case bottom
        case floating
        
        var material: Material {
            switch self {
            case .top, .bottom: return .thinMaterial
            case .floating: return .regularMaterial
            }
        }
        
        var cornerRadius: CGFloat {
            switch self {
            case .top, .bottom: return 0
            case .floating: return 16
            }
        }
        
        var shadowOpacity: Double {
            switch self {
            case .top: return 0.1
            case .bottom: return 0.1
            case .floating: return 0.15
            }
        }
        
        var verticalPadding: CGFloat {
            switch self {
            case .top, .bottom: return 12
            case .floating: return 16
            }
        }
    }
    
    let style: BarStyle
    let tint: Color?
    
    init(style: BarStyle = .top, tint: Color? = nil) {
        self.style = style
        self.tint = tint
    }
    
    func body(content: Content) -> some View {
        content
            .padding(.vertical, style.verticalPadding)
            .background {
                if let tint = tint {
                    style.material
                        .opacity(0.7)
                        .background(tint.opacity(0.1))
                } else {
                    style.material
                        .opacity(0.7)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: style.cornerRadius))
            .shadow(color: .black.opacity(style.shadowOpacity), radius: 5, x: 0, y: style.style == .top ? 2 : -2)
    }
}

// MARK: - View Extension
extension View {
    /// Apply a glass bar effect to a view
    /// - Parameters:
    ///   - style: The style of the glass bar (.top, .bottom, or .floating)
    ///   - tint: Optional tint color to apply to the background
    /// - Returns: A view with the glass bar effect applied
    func glassBar(style: GlassBar.BarStyle = .top, tint: Color? = nil) -> some View {
        modifier(GlassBar(style: style, tint: tint))
    }
}

// MARK: - Reusable Glass Components
struct GlassToolbar<Content: View>: View {
    let style: GlassBar.BarStyle
    let tint: Color?
    let content: Content
    
    init(style: GlassBar.BarStyle = .top, tint: Color? = nil, @ViewBuilder content: () -> Content) {
        self.style = style
        self.tint = tint
        self.content = content()
    }
    
    var body: some View {
        content
            .glassBar(style: style, tint: tint)
    }
}

// MARK: - Previews
#Preview("Glass Bar Styles") {
    VStack(spacing: 20) {
        GlassToolbar(style: .top) {
            HStack {
                Button(action: {}) {
                    Image(systemName: "arrow.left")
                }
                Spacer()
                Text("Top Bar")
                Spacer()
                Button(action: {}) {
                    Image(systemName: "gear")
                }
            }
            .padding(.horizontal)
        }
        
        Spacer()
        
        Text("Different Glass Styles")
            .padding()
            .glassBar(style: .floating)
        
        Spacer()
        
        GlassToolbar(style: .bottom) {
            HStack {
                Button(action: {}) {
                    Image(systemName: "camera.fill")
                        .font(.system(size: 24))
                }
            }
            .padding(.horizontal)
        }
    }
    .background(
        LinearGradient(
            colors: [.blue.opacity(0.3), .purple.opacity(0.3)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    )
}

#Preview("With Tint") {
    VStack {
        GlassToolbar(style: .top, tint: .green) {
            Text("Green Tinted Glass")
                .padding()
        }
        
        Spacer()
        
        GlassToolbar(style: .floating, tint: .blue) {
            Text("Blue Tinted Glass")
                .padding()
        }
    }
} 