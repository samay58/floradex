import SwiftUI
import SwiftData

struct FloradexHomeScreen: View {
    @Environment(\.modelContext) private var modelContext
    
    // Query all DexEntry items, initially sorted by ID
    @Query(sort: [SortDescriptor(\DexEntry.id, order: .forward)]) private var allDexEntries: [DexEntry]
    
    // State for tag filtering
    @State private var selectedTags: Set<String> = []
    @State private var currentSortOrder: DexSortOption = .numberAsc // Default sort
    
    // Computed property for all unique tags from the entries
    private var availableTags: [String] {
        let allTagsNested = allDexEntries.flatMap { $0.tags }
        return Array(Set(allTagsNested)).sorted()
    }
    
    // Computed property for filtered and sorted entries
    private var filteredAndSortedEntries: [DexEntry] {
        var entriesToDisplay = allDexEntries
        
        // Apply tag filtering
        if !selectedTags.isEmpty {
            entriesToDisplay = allDexEntries.filter { entry in
                // Entry must contain at least one of the selected tags
                // For "AND" logic (must contain all selected tags):
                // selectedTags.isSubset(of: Set(entry.tags))
                !Set(entry.tags).isDisjoint(with: selectedTags) 
            }
        }
        
        // Apply sorting (already handled by @Query if only one sort is used)
        // If dynamic sort changes are needed beyond @Query, apply sort here.
        // For this example, @Query handles the initial sort. If currentSortOrder
        // was used to change sort dynamically, we'd re-sort `entriesToDisplay` here.
        // For now, we will stick to the @Query sort and add a picker later if needed.
        
        return entriesToDisplay
    }
    
    // For sort order picker - TODO: Implement a UI for this
    enum DexSortOption: String, CaseIterable, Identifiable {
        case numberAsc = "ID (Asc)"
        case newest = "Newest"
        case alpha = "Name (A-Z)"
        var id: String { self.rawValue }
        
        var sortDescriptor: [SortDescriptor<DexEntry>] {
            switch self {
            case .numberAsc: return [SortDescriptor(\DexEntry.id, order: .forward)]
            case .newest: return [SortDescriptor(\DexEntry.createdAt, order: .reverse)]
            case .alpha: return [SortDescriptor(\DexEntry.latinName, order: .forward)]
            }
        }
    }
    @State private var selectedSortOption: DexSortOption = .numberAsc

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if !availableTags.isEmpty {
                    TagFilterView(allTags: availableTags, selectedTags: $selectedTags)
                        .padding(.bottom, 8)
                }
                
                // TODO: Add Sort Picker UI here if dynamic sorting is desired
                // Picker("Sort by", selection: $selectedSortOption) { ... }
                // Then update the @Query or filteredAndSortedEntries accordingly.

                DexGrid(entries: filteredAndSortedEntries, onRefresh: {
                    // Perform refresh logic if needed
                    print("Refresh action triggered on FloradexHomeScreen")
                }, onDelete: { entry in
                    let repo = DexRepository(modelContext: modelContext)
                    repo.delete(entry)
                })
            }
            .navigationTitle("Floradex")
            .background(Theme.Colors.dexBackground)
            // TODO: Add toolbar items for adding new entries, settings, etc.
        }
    }
}

#if DEBUG
@MainActor
struct FloradexHomeScreen_Previews: PreviewProvider {
    static var previews: some View {
        let previewContainer: ModelContainer = {
            do {
                let config = ModelConfiguration(isStoredInMemoryOnly: true)
                let container = try ModelContainer(for: DexEntry.self, SpeciesDetails.self, configurations: config)
                
                // Insert sample DexEntry data
                let entries = PreviewHelper.sampleDexEntries
                for (index, entry) in entries.enumerated() {
                    var entryToInsert = entry
                    if index == 0 { // Add sprite & snapshot to the first sample for better preview
                        if let spriteData = UIImage(systemName: "leaf.fill")?.withTintColor(.systemGreen).pngData() {
                            entryToInsert.sprite = spriteData
                        }
                        if let snapshotData = UIImage(systemName: "photo.fill")?.jpegData(compressionQuality: 0.8) {
                            entryToInsert.snapshot = snapshotData
                        }
                    }
                    container.mainContext.insert(entryToInsert)
                }
                try container.mainContext.save()
                return container
            } catch {
                fatalError("Failed to create model container for preview: \(error)")
            }
        }()

        return FloradexHomeScreen()
            .modelContainer(previewContainer)
    }
}
#endif 