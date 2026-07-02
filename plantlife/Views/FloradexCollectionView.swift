import SwiftUI
import SwiftData

// ViewModel for this screen
@MainActor
class FloradexCollectionViewModel: ObservableObject {
    private var dexRepository: DexRepository
    @Published var entries: [DexEntry] = []
    @Published var selectedTags: Set<String> = []
    @Published var searchText: String = ""
    @Published var sortOption: DexSortOption = .numberAsc

    var availableTags: [String] {
        Array(Set(entries.flatMap { $0.tags })).sorted()
    }

    var filteredEntries: [DexEntry] {
        var filtered = entries
        
        // Apply search filter
        if !searchText.isEmpty {
            filtered = filtered.filter { entry in
                entry.latinName.localizedCaseInsensitiveContains(searchText) ||
                entry.commonName?.localizedCaseInsensitiveContains(searchText) ?? false ||
                entry.tags.contains { $0.localizedCaseInsensitiveContains(searchText) }
            }
        }
        
        // Apply tag filter
        if !selectedTags.isEmpty {
            filtered = filtered.filter { entry in
                !Set(entry.tags).isDisjoint(with: selectedTags)
            }
        }
        
        // Apply sort
        return dexRepository.sort(filtered, by: sortOption)
    }

    init(dexRepository: DexRepository) {
        self.dexRepository = dexRepository
        fetchEntries()
    }

    func fetchEntries() {
        // Fetch all entries (we'll sort in filteredEntries)
        self.entries = dexRepository.all(sort: .numberAsc)
    }
    
    func deleteEntry(_ entry: DexEntry) {
        dexRepository.delete(entry)
        fetchEntries() // Refresh list
    }
}

struct FloradexCollectionView: View {
    @StateObject var viewModel: FloradexCollectionViewModel
    @State private var isSelectionMode = false

    private let columns = [
        GridItem(.flexible(), spacing: Theme.Metrics.Padding.medium),
        GridItem(.flexible(), spacing: Theme.Metrics.Padding.medium)
    ]

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Enhanced Search & Filter UI
                SearchFilterView(
                    searchText: $viewModel.searchText,
                    selectedTags: $viewModel.selectedTags,
                    sortOption: $viewModel.sortOption,
                    availableTags: viewModel.availableTags,
                    onClear: {
                        viewModel.searchText = ""
                        viewModel.selectedTags.removeAll()
                        viewModel.sortOption = .numberAsc
                    }
                )
                
                // Use DexGrid instead of LazyVGrid for consistency
                DexGrid(
                    entries: viewModel.filteredEntries,
                    onRefresh: {
                        viewModel.fetchEntries()
                    },
                    onDelete: { entry in
                        viewModel.deleteEntry(entry)
                    },
                    isSelectionMode: $isSelectionMode
                )
            }
            .background(Theme.Colors.systemBackground)
            .navigationTitle("My Floradex")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        withAnimation(AnimationConstants.smoothSpring) {
                            isSelectionMode.toggle()
                        }
                        HapticManager.shared.tick()
                    } label: {
                        Text(isSelectionMode ? "Done" : "Select")
                            .font(Theme.Typography.body.weight(.medium))
                    }
                }
            }
            .onAppear {
                viewModel.fetchEntries()
            }
            .refreshable {
                viewModel.fetchEntries()
            }
        }
        .navigationViewStyle(.stack)
    }
}
