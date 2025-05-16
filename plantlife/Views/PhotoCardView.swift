import SwiftUI

struct PhotoCardView: View {
    let image: UIImage
    let species: String?

    var body: some View {
        Image(uiImage: image)
            .resizable()
            .scaledToFit()
            .frame(maxHeight: 300)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.accent(for: species), lineWidth: 4)
            )
            .shadow(radius: 6)
            .padding(.bottom, 8)
    }
} 