import SwiftUI
import SwiftData

struct DexCard: View {
    let entry: DexEntry
    var onDelete: (() -> Void)? = nil
    // We might need SpeciesDetails later if commonName or other info is directly on the card
    // let speciesDetails: SpeciesDetails? 

    private let corner: CGFloat = 20
    private let idFont = Font.pressStart2P(size: 10)

    var body: some View {
        GeometryReader { geo in
            let side = geo.size.width
            ZStack(alignment: .topLeading) {
                // Background
                RoundedRectangle(cornerRadius: corner)
                    .fill(
                        LinearGradient(
                            colors: [Theme.Colors.accent(for: entry.latinName).opacity(0.4),
                                     Theme.Colors.accent(for: entry.latinName).opacity(0.9)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing)
                    )

                // Sprite (center)
                Group {
                    if let spriteData = entry.sprite, let uiImage = UIImage(data: spriteData) {
                        Image(uiImage: uiImage)
                            .resizable()
                            .interpolation(.none)
                            .aspectRatio(contentMode: .fit)
                            .frame(width: side * 0.7, height: side * 0.7)
                    } else if entry.spriteGenerationFailed {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: side * 0.35))
                            .foregroundColor(.yellow)
                    } else {
                        ProgressView()
                            .scaleEffect(1.2)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)

                // ID label top-left
                Text(String(format: "#%03d", entry.id))
                    .font(idFont)
                    .foregroundColor(.white)
                    .shadow(radius: 1)
                    .padding(6)
            }
        }
        .aspectRatio(1, contentMode: .fit)
        .cornerRadius(corner)
        .shadow(color: Theme.Colors.dexShadow, radius: 4, x: 0, y: 2)
        .contextMenu {
            Button(role: .destructive) { onDelete?() } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }
}

#if DEBUG
@MainActor
struct DexCard_Previews: PreviewProvider {
    static var previews: some View {
        let container: ModelContainer = {
            let cfg = ModelConfiguration(isStoredInMemoryOnly: true)
            return try! ModelContainer(for: DexEntry.self, configurations: cfg)
        }()
        let sample = PreviewHelper.sampleDexEntry
        if let data = UIImage(systemName: "leaf")?.pngData() { sample.sprite = data }
        container.mainContext.insert(sample)
        return DexCard(entry: sample)
            .modelContainer(container)
            .padding()
            .previewLayout(.sizeThatFits)
    }
}
#endif 