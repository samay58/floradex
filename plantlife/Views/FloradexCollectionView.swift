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
        print("[FloradexCollectionViewModel] Fetched \(entries.count) entries from repository")
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

// Card for the user's collection grid (uses DexEntry)
struct CollectionPlantCard: View {
    let entry: DexEntry
    
    // Determine background color based on tags or use default
    var cardBackgroundColor: Color {
        // Consistent with DexCard logic for plant types
        if entry.tags.contains("Succulent") || entry.tags.contains("succulent") {
            return Theme.Colors.succulentCardBackground
        } else if entry.tags.contains("Flower") || entry.tags.contains("flower") {
            return Theme.Colors.flowerCardBackground
        } else if entry.tags.contains("Tree") || entry.tags.contains("tree") {
            return Theme.Colors.treeCardBackground
        }
        return Theme.Colors.cardBackground // Use dark-mode-aware default
    }

    var body: some View {
        VStack(alignment: .center, spacing: Theme.Metrics.Padding.small) {
            // Beautiful Plant Sprite with Organic Border
            Group {
                if let spriteData = entry.sprite, let uiImage = UIImage(data: spriteData) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .interpolation(.none) // For pixel art style
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 70, height: 70)
                } else if let snapshotData = entry.snapshot, let uiImage = UIImage(data: snapshotData) {
                    Image(uiImage: uiImage) // Fallback to snapshot
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 70, height: 70)
                        .clipped()
                } else if entry.spriteGenerationFailed {
                    VStack(spacing: 2) {
                        Image(systemName: "leaf.circle.fill")
                            .font(.system(size: 28))
                            .foregroundColor(Theme.Colors.primaryGreen.opacity(0.6))
                        Text("Retry")
                            .font(.system(size: 8))
                            .foregroundColor(Theme.Colors.textSecondary)
                    }
                    .frame(width: 70, height: 70)
                } else {
                    VStack(spacing: 2) {
                        ProgressView()
                            .scaleEffect(0.7)
                            .tint(Theme.Colors.primaryGreen)
                        Text("Generating...")
                            .font(.system(size: 8))
                            .foregroundColor(Theme.Colors.textSecondary)
                    }
                    .frame(width: 70, height: 70)
                }
            }
            .background(
                // Gorgeous organic background gradient
                RadialGradient(
                    colors: [
                        cardBackgroundColor.opacity(0.3),
                        cardBackgroundColor.opacity(0.1),
                        Color.clear
                    ],
                    center: .center,
                    startRadius: 15,
                    endRadius: 50
                )
            )
            .overlay(
                // Beautiful organic border
                ZStack {
                    // Outer organic ring
                    Circle()
                        .stroke(
                            LinearGradient(
                                colors: [
                                    Theme.Colors.primaryGreen.opacity(0.5),
                                    cardBackgroundColor.opacity(0.7),
                                    Theme.Colors.primaryGreen.opacity(0.3)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1.5
                        )
                        .frame(width: 78, height: 78)
                    
                    // Inner highlight
                    Circle()
                        .stroke(Color.white.opacity(0.3), lineWidth: 0.5)
                        .frame(width: 75, height: 75)
                    
                    // Organic texture dots (smaller for collection view)
                    ForEach(0..<6, id: \.self) { i in
                        Circle()
                            .fill(Theme.Colors.primaryGreen.opacity(0.15))
                            .frame(width: 1.5, height: 1.5)
                            .offset(
                                x: 36 * cos(Double(i) * .pi / 3),
                                y: 36 * sin(Double(i) * .pi / 3)
                            )
                    }
                }
            )
            .frame(width: 85, height: 85)

            VStack(alignment: .center, spacing: Theme.Metrics.Padding.micro / 2) {
                Text(entry.latinName) // Primary name
                    .font(Theme.Typography.caption.weight(.semibold))
                    .foregroundColor(Theme.Colors.textPrimary)
                    .lineLimit(1)
                    .multilineTextAlignment(.center)

                Text(entry.tags.first?.capitalized ?? "Plant") // Category preview
                    .font(.system(size: 10))
                    .foregroundColor(Theme.Colors.textSecondary)
                    .lineLimit(1)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 1)
                    .background(
                        Capsule()
                            .fill(cardBackgroundColor.opacity(0.25))
                    )
            }
            .padding(.horizontal, Theme.Metrics.Padding.extraSmall)
        }
        .padding(Theme.Metrics.Padding.small)
        .background(
            // Modern card background with subtle gradient
            RoundedRectangle(cornerRadius: Theme.Metrics.cornerRadiusMedium)
                .fill(
                    LinearGradient(
                        colors: [
                            cardBackgroundColor.opacity(0.1),
                            cardBackgroundColor.opacity(0.05),
                            Color.white.opacity(0.9)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: Theme.Metrics.cornerRadiusMedium)
                        .stroke(
                            LinearGradient(
                                colors: [
                                    cardBackgroundColor.opacity(0.25),
                                    cardBackgroundColor.opacity(0.1)
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            ),
                            lineWidth: 0.5
                        )
                )
        )
        .shadow(
            color: cardBackgroundColor.opacity(0.15),
            radius: 6,
            x: 0,
            y: 3
        )
    }
}

#if DEBUG
struct FloradexCollectionView_Previews: PreviewProvider {
    static var previews: some View {
        // Note: This preview may not show actual data without proper ModelContainer setup
        NavigationView {
            VStack(spacing: Theme.Metrics.Padding.large) {
                Spacer()
                
                Image(systemName: "leaf.circle")
                    .font(.system(size: 60))
                    .foregroundColor(Theme.Colors.iconSecondary)
                
                Text("Preview: My Floradex")
                    .font(Theme.Typography.title2)
                    .foregroundColor(Theme.Colors.textPrimary)
                
                Text("Collection view for user's identified plants")
                    .font(Theme.Typography.body)
                    .foregroundColor(Theme.Colors.textSecondary)
                    .multilineTextAlignment(.center)
                
                Spacer()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Theme.Colors.systemBackground)
            .navigationTitle("My Floradex")
        }
        .navigationViewStyle(.stack)
    }
}
#endif 