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
                        NavigationLink(destination: PlantDetailsView(entry: entry, namespace: heroNamespace)) {
                            DexCard(entry: entry, namespace: heroNamespace) { onDelete?(entry) }
                        }
                        .buttonStyle(PlainButtonStyle())
                        .frame(height: 200)
                    }
                }
                .padding(.horizontal, 10)
            }
        }
        .refreshable {
            onRefresh()
        }
        .background(Theme.Colors.systemBackground)
    }
    
    private var emptyStateView: some View {
        VStack(spacing: Theme.Metrics.Padding.large) {
            Image(systemName: "leaf.circle")
                .font(.system(size: 64))
                .foregroundColor(Theme.Colors.iconSecondary)
            
            Text("No Plants Found")
                .font(Theme.Typography.title2.weight(.bold))
                .foregroundColor(Theme.Colors.textPrimary)
            
            Text("Capture or select a plant photo to start your collection!")
                .font(Theme.Typography.body)
                .foregroundColor(Theme.Colors.textSecondary)
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