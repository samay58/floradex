import SwiftUI

/// Modern page indicator with smooth animations and clean capsule design
/// Replaces the deprecated PixelPageDots component
struct ModernPageIndicator: View {
    let count: Int
    let currentIndex: Int // Using direct value instead of Binding for simplicity
    
    var body: some View {
        HStack(spacing: 8) {
            ForEach(0..<count, id: \.self) { index in
                Capsule()
                    .fill(index == currentIndex ? Theme.Colors.primaryGreen : Theme.Colors.iconSecondary.opacity(0.3))
                    .frame(width: index == currentIndex ? 20 : 8, height: 8)
                    .animation(Theme.Animations.snappy, value: currentIndex)
            }
        }
        .padding(.vertical, Theme.Metrics.Padding.small)
    }
}

#if DEBUG
struct ModernPageIndicator_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: Theme.Metrics.Padding.large) {
            Text("Modern Page Indicators")
                .font(Theme.Typography.title2)
            
            ModernPageIndicator(count: 3, currentIndex: 0)
            ModernPageIndicator(count: 3, currentIndex: 1)
            ModernPageIndicator(count: 3, currentIndex: 2)
            
            ModernPageIndicator(count: 5, currentIndex: 2)
        }
        .padding()
        .background(Theme.Colors.systemBackground)
        .previewLayout(.sizeThatFits)
    }
}
#endif 