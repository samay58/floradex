import SwiftUI

struct TagChip: View {
    let tagName: String
    var isSelected: Bool = false
    var action: (() -> Void)? = nil

    @Environment(\.colorScheme) private var colorScheme

    private var chipFont: Font { .caption.weight(.semibold) }

    var body: some View {
        Button(action: { action?() }) {
            Text(tagName)
                .font(chipFont)
                .padding(.horizontal, 14)
                .padding(.vertical, 6)
                .foregroundStyle(isSelected ? Color.white : Theme.Colors.primary)
                .background(
                    Capsule()
                        .fill(isSelected ? AnyShapeStyle(Color.accentColor) : AnyShapeStyle(Material.ultraThin))
                )
                .overlay(
                    Capsule()
                        .stroke(Color.accentColor.opacity(isSelected ? 0 : 0.25), lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }
}

#if DEBUG
struct TagChip_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 10) {
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
                TagChip(tagName: "P O I S O N O U S", isSelected: false, action: { print("Tapped Poisonous") })
                    .environment(\.sizeCategory, .extraSmall) // Test with smaller text
                TagChip(tagName: "Retro Font Test", isSelected: true, action: { print("Tapped Retro") })
            }
            
            // Test with a dark background to ensure visibility
            HStack {
                TagChip(tagName: "Dark Mode Test", isSelected: false)
                TagChip(tagName: "Selected Dark", isSelected: true)
            }
            .padding()
            .background(Color.black)

        }
        .padding()
        .background(Theme.Colors.dexBackground) // Use Floradex theme background for preview
    }
}
#endif 