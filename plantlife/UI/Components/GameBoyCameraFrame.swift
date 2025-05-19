import SwiftUI

struct GameBoyCameraFrame<Content: View>: View {
    @Environment(\.colorScheme) private var colorScheme
    var content: Content
    
    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }
    
    var body: some View {
        VStack {
            content
                .aspectRatio(4/3, contentMode: .fit)
                .overlay(vignetteOverlay)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(lineWidth: 2)
                        .foregroundColor(Theme.Colors.accent(for: "camera"))
                )
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Theme.Colors.surface)
                )
                .shadow(color: .black.opacity(0.2), radius: 4, x: 0, y: 2)
        }
        .padding()
    }
    
    private var vignetteOverlay: some View {
        ZStack {
            // Edge vignette
            RoundedRectangle(cornerRadius: 10)
                .fill(
                    RadialGradient(
                        gradient: Gradient(colors: [
                            .clear,
                            colorScheme == .dark ? .black.opacity(0.3) : .black.opacity(0.2)
                        ]),
                        center: .center,
                        startRadius: 0,
                        endRadius: 300
                    )
                )
                .blendMode(.multiply)
            
            // Subtle noise texture
            Color.black.opacity(0.05)
                .blendMode(.overlay)
                .allowsHitTesting(false)
        }
    }
}

#Preview {
    GameBoyCameraFrame {
        Color.gray
            .overlay(
                Text("Camera Preview")
                    .foregroundColor(.white)
            )
    }
} 