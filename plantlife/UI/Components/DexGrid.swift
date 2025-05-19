import SwiftUI
import SwiftData

struct DexGrid: View {
    let entries: [DexEntry]
    let onRefresh: () -> Void
    var onDelete: ((DexEntry) -> Void)? = nil
    
    @Namespace private var heroNamespace
    
    private let columns = [
        GridItem(.flexible(), spacing: 10),
        GridItem(.flexible(), spacing: 10)
    ]
    
    var body: some View {
        ScrollView {
            if entries.isEmpty {
                emptyStateView
            } else {
                LazyVGrid(columns: columns, spacing: 10) {
                    ForEach(entries) { entry in
                        GeometryReader { geo in
                            let frame = geo.frame(in: .global)
                            let cardMidY = frame.midY
                            
                            let screenHeight = UIScreen.main.bounds.height
                            let distanceFromCenter = cardMidY - (screenHeight / 2)
                            
                            let parallaxFactor = 0.05
                            let parallaxOffset = (distanceFromCenter * parallaxFactor) * -0.1

                            let normalizedDistance = abs(distanceFromCenter) / (screenHeight / 2)
                            let desaturationAmount = normalizedDistance.clamped(to: 0...0.6)

                            NavigationLink(destination: DexDetailView(entry: entry, namespace: heroNamespace)) {
                                DexCard(entry: entry, namespace: heroNamespace) { onDelete?(entry) }
                                    .offset(y: parallaxOffset)
                                    .saturation(1.0 - Double(desaturationAmount))
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                        .frame(height: 200)
                    }
                }
                .padding(.horizontal, 10)
            }
        }
        .refreshable {
            onRefresh()
        }
        .background(Theme.Colors.dexBackground)
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "leaf.circle")
                .font(.system(size: 64))
                .foregroundColor(.gray)
            
            Text("No Plants Found")
                .font(Font.pressStart2P(size: 16))
                .foregroundColor(.gray)
            
            Text("Capture or select a plant photo to start your collection!")
                .font(.subheadline)
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
}

#if DEBUG
struct DexGrid_Previews: PreviewProvider {
    static var previews: some View {
        let previewContainer: ModelContainer = {
            do {
                let config = ModelConfiguration(isStoredInMemoryOnly: true)
                let container = try ModelContainer(for: DexEntry.self, configurations: config)
                
                // Insert sample entries
                for entry in PreviewHelper.sampleDexEntries {
                    container.mainContext.insert(entry)
                }
                
                try container.mainContext.save()
                return container
            } catch {
                fatalError("Failed to create model container for preview: \(error)")
            }
        }()
        
        return NavigationStack {
            DexGrid(
                entries: PreviewHelper.sampleDexEntries,
                onRefresh: { print("Refresh triggered") },
                onDelete: nil
            )
        }
        .modelContainer(previewContainer)
    }
}
#endif 