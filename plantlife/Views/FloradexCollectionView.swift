import SwiftUI
import SwiftData

// ViewModel for this screen
@MainActor
class FloradexCollectionViewModel: ObservableObject {
    private var dexRepository: DexRepository
    @Published var entries: [DexEntry] = []
    @Published var selectedTags: Set<String> = []

    var availableTags: [String] {
        Array(Set(entries.flatMap { $0.tags })).sorted()
    }

    var filteredEntries: [DexEntry] {
        if selectedTags.isEmpty {
            return entries
        } else {
            return entries.filter { entry in
                !Set(entry.tags).isDisjoint(with: selectedTags)
            }
        }
    }

    init(dexRepository: DexRepository) {
        self.dexRepository = dexRepository
        fetchEntries()
    }

    func fetchEntries() {
        // Default sort or apply user-selected sort
        self.entries = dexRepository.all(sort: .numberAsc)
        print("[FloradexCollectionViewModel] Fetched \(entries.count) entries from repository")
        for entry in entries {
            print("[FloradexCollectionViewModel] Entry ID: \(entry.id), has sprite: \(entry.sprite != nil), sprite size: \(entry.sprite?.count ?? 0), sprite failed: \(entry.spriteGenerationFailed)")
        }
    }
    
    func deleteEntry(_ entry: DexEntry) {
        dexRepository.delete(entry)
        fetchEntries() // Refresh list
    }
}

struct FloradexCollectionView: View {
    @StateObject var viewModel: FloradexCollectionViewModel

    private let columns = [
        GridItem(.flexible(), spacing: Theme.Metrics.Padding.medium),
        GridItem(.flexible(), spacing: Theme.Metrics.Padding.medium)
    ]

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Tag Filter Section (if there are tags available)
                if !viewModel.availableTags.isEmpty {
                    VStack(alignment: .leading, spacing: Theme.Metrics.Padding.small) {
                        Text("Filter by Category")
                            .font(Theme.Typography.subheadline.weight(.medium))
                            .foregroundColor(Theme.Colors.textSecondary)
                            .padding(.horizontal, Theme.Metrics.Padding.medium)
                        
                        ScrollView(.horizontal, showsIndicators: false) {
                            LazyHStack(spacing: Theme.Metrics.Padding.extraSmall) {
                                // "All" button to clear filters
                                TagChip(
                                    tagName: "All",
                                    isSelected: viewModel.selectedTags.isEmpty
                                ) {
                                    viewModel.selectedTags.removeAll()
                                }
                                
                                // Individual tag filters
                                ForEach(viewModel.availableTags, id: \.self) { tag in
                                    TagChip(
                                        tagName: tag,
                                        isSelected: viewModel.selectedTags.contains(tag)
                                    ) {
                                        if viewModel.selectedTags.contains(tag) {
                                            viewModel.selectedTags.remove(tag)
                                        } else {
                                            viewModel.selectedTags.insert(tag)
                                        }
                                    }
                                }
                            }
                            .padding(.horizontal, Theme.Metrics.Padding.medium)
                        }
                    }
                    .padding(.bottom, Theme.Metrics.Padding.small)
                    .background(Theme.Colors.systemBackground)
                }
                
                ScrollView {
                    if viewModel.filteredEntries.isEmpty {
                        VStack(spacing: Theme.Metrics.Padding.large) {
                            Spacer()
                            
                            Image(systemName: viewModel.selectedTags.isEmpty ? "leaf.circle" : "magnifyingglass")
                                .font(.system(size: 60))
                                .foregroundColor(Theme.Colors.iconSecondary)
                            
                            Text(viewModel.selectedTags.isEmpty ? "Your Floradex is empty" : "No plants match the selected filters")
                                .font(Theme.Typography.title2)
                                .foregroundColor(Theme.Colors.textPrimary)
                                .multilineTextAlignment(.center)
                            
                            Text(viewModel.selectedTags.isEmpty ? 
                                 "Identify some plants to add them to your collection!" :
                                 "Try selecting different categories or clear filters to see all plants.")
                                .font(Theme.Typography.body)
                                .foregroundColor(Theme.Colors.textSecondary)
                                .multilineTextAlignment(.center)
                            
                            if !viewModel.selectedTags.isEmpty {
                                Button("Clear Filters") {
                                    viewModel.selectedTags.removeAll()
                                }
                                .pillButton()
                                .padding(.top, Theme.Metrics.Padding.small)
                            }
                            
                            Spacer()
                        }
                        .frame(maxWidth: .infinity)
                        .padding(Theme.Metrics.Padding.extraLarge)
                    } else {
                        LazyVGrid(columns: columns, spacing: Theme.Metrics.Padding.medium) {
                            ForEach(viewModel.filteredEntries) { entry in
                                NavigationLink(destination: PlantDetailsView(entry: entry)) {
                                    CollectionPlantCard(entry: entry)
                                }
                                .buttonStyle(PlainButtonStyle())
                                .contextMenu { // Keep context menu for deletion
                                    Button(role: .destructive) {
                                        viewModel.deleteEntry(entry)
                                    } label: {
                                        Label("Delete", systemImage: "trash")
                                    }
                                }
                            }
                        }
                        .padding(Theme.Metrics.Padding.medium)
                    }
                }
            }
            .background(Theme.Colors.systemBackground)
            .navigationTitle("My Floradex")
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