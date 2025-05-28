import SwiftUI

/// Modern tag chip component with capsule design
struct TagChip: View {
    let tagName: String
    var isSelected: Bool = false
    var action: (() -> Void)? = nil

    @Environment(\.colorScheme) private var colorScheme

    private var chipFont: Font { Theme.Typography.caption.weight(.semibold) }

    var body: some View {
        Button(action: { action?() }) {
            Text(tagName)
                .font(chipFont)
                .padding(.horizontal, Theme.Metrics.Padding.small)
                .padding(.vertical, Theme.Metrics.Padding.extraSmall)
                .foregroundStyle(isSelected ? Color.white : Theme.Colors.primaryGreen)
                .background(
                    Capsule()
                        .fill(isSelected ? 
                              AnyShapeStyle(Theme.Colors.primaryGreen) : 
                              AnyShapeStyle(Theme.Colors.surfaceLight)
                        )
                )
                .overlay(
                    Capsule()
                        .stroke(
                            Theme.Colors.primaryGreen.opacity(isSelected ? 0 : 0.3), 
                            lineWidth: 1
                        )
                )
                .shadow(
                    color: Theme.Colors.dexShadow.opacity(0.1), 
                    radius: 2, 
                    x: 0, 
                    y: 1
                )
        }
        .buttonStyle(.plain)
        .animation(Theme.Animations.snappy, value: isSelected)
    }
}

#if DEBUG
struct TagChip_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 20) {
            Text("Modern TagChip Component")
                .font(Theme.Typography.title2)
                .padding(.bottom)
            
            VStack(spacing: 15) {
            HStack {
                TagChip(tagName: "Indoor", isSelected: false) { print("Tapped Indoor") }
                TagChip(tagName: "Foliage", isSelected: true) { print("Tapped Foliage") }
                TagChip(tagName: "Easy Care", isSelected: false) { print("Tapped Easy Care") }
            }
                
            HStack {
                TagChip(tagName: "Succulent", action: { print("Tapped Succulent") })
                TagChip(tagName: "Needs Bright Light", isSelected: true, action: { print("Tapped Bright Light") })
            }
                
                HStack {
                    TagChip(tagName: "Low Maintenance", isSelected: false, action: { print("Tapped Low Maintenance") })
                    TagChip(tagName: "Pet Safe", isSelected: true, action: { print("Tapped Pet Safe") })
                }
                
                // Test with different sizes
            HStack {
                    TagChip(tagName: "XS", isSelected: false)
                        .environment(\.sizeCategory, .extraSmall)
                    TagChip(tagName: "Small", isSelected: true)
                        .environment(\.sizeCategory, .small)
                    TagChip(tagName: "Large", isSelected: false)
                        .environment(\.sizeCategory, .large)
                }
            }
            
            // Dark mode test
            VStack(spacing: 10) {
                Text("Dark Background Test")
                    .font(Theme.Typography.caption)
                    .foregroundColor(.white)
                
            HStack {
                    TagChip(tagName: "Dark Mode", isSelected: false)
                    TagChip(tagName: "Selected", isSelected: true)
                }
            }
            .padding()
            .background(Color.black)
            .cornerRadius(Theme.Metrics.cornerRadiusMedium)
        }
        .padding()
        .background(Theme.Colors.systemBackground)
        .previewLayout(.sizeThatFits)
    }
}
#endif 