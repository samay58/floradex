import SwiftUI
import SwiftData

/// Modern PlantDetailsView for the UI refresh
/// Replaces the complex DexDetailView with a clean, framed header and modern card layout
struct PlantDetailsView: View {
    @ObservedObject var viewModel: ClassificationViewModel
    let identifiedImage: UIImage?
    let existingEntry: DexEntry?
    
    @State private var speciesDetails: SpeciesDetails?
    @State private var currentEntry: DexEntry?
    
    // Query for SpeciesDetails if an existing entry is provided
    @Query var queriedSpeciesDetails: [SpeciesDetails]
    
    // Initialize for new identifications
    init(viewModel: ClassificationViewModel, identifiedImage: UIImage, namespace: Namespace.ID? = nil) {
        self._viewModel = ObservedObject(wrappedValue: viewModel)
        self.identifiedImage = identifiedImage
        self.existingEntry = nil
        // Query will be empty initially, details come from viewModel
        self._queriedSpeciesDetails = Query(filter: #Predicate<SpeciesDetails> { _ in false })
    }

    // Initialize for existing entries from Floradex
    init(entry: DexEntry, namespace: Namespace.ID? = nil) {
        // Create a placeholder viewModel for existing entries (not used for identification)
        let dummyImageService = ImageSelectionService.shared
        let container = try! ModelContainer(for: SpeciesDetails.self, DexEntry.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let dummySpeciesRepo = SpeciesRepository(modelContext: container.mainContext)
        let dummyDexRepo = DexRepository(modelContext: container.mainContext)

        self._viewModel = ObservedObject(wrappedValue: ClassificationViewModel(imageService: dummyImageService, speciesRepository: dummySpeciesRepo, dexRepository: dummyDexRepo))
        self.identifiedImage = nil
        self.existingEntry = entry
        let latinName = entry.latinName
        self._queriedSpeciesDetails = Query(filter: #Predicate<SpeciesDetails> { $0.latinName == latinName })
        self._currentEntry = State(initialValue: entry)
    }

    var body: some View {
        VStack(spacing: 0) {
            // Modern header with framed image
            PlantDetailHeaderView(
                image: displayedImage,
                spriteData: currentEntry?.sprite,
                commonName: speciesDetails?.commonName ?? currentEntry?.latinName,
                latinName: currentEntry?.latinName ?? viewModel.species,
                entryNumber: currentEntry?.id
            )
            .padding(.bottom, Theme.Metrics.Padding.small)

            // Card Pager for details
            if let entryForPager = currentEntry, let detailsForPager = speciesDetails {
                DexCardPager(cards: [
                    AnyDexDetailCard(OverviewCard(entry: entryForPager, details: detailsForPager)),
                    AnyDexDetailCard(CareCard(details: detailsForPager)),
                    AnyDexDetailCard(GrowthCard(details: detailsForPager))
                ])
                .background(Theme.Colors.systemGroupedBackground)
            } else if viewModel.isLoading && identifiedImage != nil {
                VStack(spacing: Theme.Metrics.Padding.large) {
                    ProgressView("Identifying and fetching details...")
                        .font(Theme.Typography.body)
                        .foregroundColor(Theme.Colors.textSecondary)
                    
                    if let image = identifiedImage {
                        Image(uiImage: image)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(height: 200)
                            .cornerRadius(Theme.Metrics.cornerRadiusMedium)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding()
            } else {
                VStack(spacing: Theme.Metrics.Padding.large) {
                    Image(systemName: "leaf.circle")
                        .font(.system(size: 60))
                        .foregroundColor(Theme.Colors.iconSecondary)
                    
                    Text("Details not available")
                        .font(Theme.Typography.title2)
                        .foregroundColor(Theme.Colors.textSecondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .background(Theme.Colors.systemBackground)
        .navigationTitle(speciesDetails?.commonName ?? currentEntry?.latinName ?? "Plant Details")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                if existingEntry != nil {
                    Button("Edit") { 
                        // TODO: Implement edit functionality
                        print("Edit tapped")
                    }
                    .foregroundColor(Theme.Colors.primaryGreen)
                }
            }
        }
        .onAppear {
            if let entry = existingEntry {
                currentEntry = entry
                speciesDetails = queriedSpeciesDetails.first
            } else if identifiedImage != nil {
                // For new identifications, start the processing
                Task {
                    await viewModel.processSelectedImage()
                }
            }
        }
        .onChange(of: viewModel.details) { newDetails in
            if existingEntry == nil { // Only update if this view is for a new identification
                self.speciesDetails = newDetails
            }
        }
        .onChange(of: viewModel.currentDexEntry) { newEntry in
            if existingEntry == nil {
                self.currentEntry = newEntry
            }
        }
    }

    private var displayedImage: UIImage? {
        if let identified = identifiedImage { return identified }
        if let snapshotData = existingEntry?.snapshot, let img = UIImage(data: snapshotData) { return img }
        return nil
    }
}

/// Modern header component with framed plant image and clean typography
struct PlantDetailHeaderView: View {
    let image: UIImage?
    let spriteData: Data?
    let commonName: String?
    let latinName: String?
    let entryNumber: Int?
    
    var body: some View {
        VStack(alignment: .center, spacing: Theme.Metrics.Padding.medium) {
            // Framed Plant Image
            Group {
                if let img = image {
                    Image(uiImage: img)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 200, height: 200)
                        .clipped()
                } else if let data = spriteData, let uiImage = UIImage(data: data) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .interpolation(.none)
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 160, height: 160)
                } else {
                    Image(systemName: "photo.fill")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 180, height: 180)
                        .foregroundColor(Theme.Colors.iconSecondary.opacity(0.3))
                        .padding(Theme.Metrics.Padding.small)
                        .background(Theme.Colors.systemFill)
        }
    }
            .padding(Theme.Metrics.Padding.extraSmall) // Inner padding (matting)
            .background(Theme.Colors.cardBackground) // Use dark-mode-aware matting color
            .cornerRadius(Theme.Metrics.cornerRadiusSmall)
            .padding(Theme.Metrics.Padding.extraSmall) // Gap for frame effect
            .background(Theme.Colors.systemFill) // Neutral frame color that adapts to dark mode
            .cornerRadius(Theme.Metrics.cornerRadiusMedium)
            .shadow(color: .black.opacity(0.15), radius: 6, y: 3)

            // Plant Names
            VStack(spacing: Theme.Metrics.Padding.extraSmall) {
                Text(commonName ?? latinName ?? "Unknown Plant")
                    .font(Theme.Typography.title.weight(.bold))
                    .foregroundColor(Theme.Colors.textPrimary)
                    .multilineTextAlignment(.center)

                if let commonName = commonName, let latinName = latinName, commonName != latinName {
                    Text(latinName)
                        .font(Theme.Typography.callout)
                        .italic()
                        .foregroundColor(Theme.Colors.textSecondary)
                    }
                    
                if let entryNumber = entryNumber {
                    Text("#\(String(format: "%03d", entryNumber))")
                        .font(Theme.Typography.caption.weight(.medium))
                        .foregroundColor(Theme.Colors.primaryGreen)
                        .padding(.horizontal, Theme.Metrics.Padding.small)
                        .padding(.vertical, Theme.Metrics.Padding.extraSmall)
                        .background(Theme.Colors.primaryGreen.opacity(0.1))
                        .cornerRadius(Theme.Metrics.cornerRadiusSmall)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.top, Theme.Metrics.Padding.small)
        .padding(.bottom, Theme.Metrics.Padding.medium)
        .background(Theme.Colors.systemBackground)
    }
}

// MARK: - Legacy DexDetailView (kept for backward compatibility during transition)
struct DexDetailView: View {
    let entry: DexEntry
    var namespace: Namespace.ID? = nil
    
    @Query var speciesDetailItems: [SpeciesDetails]
    @AppStorage("experimentalPager") private var useExperimentalPager: Bool = true

    init(entry: DexEntry, namespace: Namespace.ID? = nil) {
        self.entry = entry
        self.namespace = namespace
        let latinName = entry.latinName
        self._speciesDetailItems = Query(filter: #Predicate<SpeciesDetails> { $0.latinName == latinName }, sort: [SortDescriptor(\SpeciesDetails.latinName)])
    }
    
    private var speciesDetails: SpeciesDetails? {
        speciesDetailItems.first 
        }
        
        var body: some View {
        // Redirect to new modern PlantDetailsView
        PlantDetailsView(entry: entry, namespace: namespace)
    }
}

#if DEBUG
struct PlantDetailsView_Previews: PreviewProvider {
    static var previews: some View {
        let container = try! ModelContainer(for: SpeciesDetails.self, DexEntry.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        
        NavigationStack {
            PlantDetailsView(entry: PreviewHelper.sampleDexEntry)
        }
        .modelContainer(container)
    }
}
#endif 