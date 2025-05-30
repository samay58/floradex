import SwiftUI
import SwiftData

@main
struct PlantLifeApp: App {
    // State properties for ModelContainer and SpeciesRepository
    let modelContainer: ModelContainer
    let speciesRepository: SpeciesRepository
    let dexRepository: DexRepository

    init() {
        do {
            // Define the schema including all SwiftData @Model classes
            let schema = Schema([
                SpeciesDetails.self,
                DexEntry.self
                // Add any other @Model classes here in the future
            ])

            // Configure the ModelContainer (e.g., for iCloud, App Groups, or just local storage)
            // isStoredInMemoryOnly: false for persistent storage, true for temporary in-memory (e.g., for previews or testing)
            let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

            // Initialize the ModelContainer
            modelContainer = try ModelContainer(for: schema, configurations: [modelConfiguration])

            // Initialize the SpeciesRepository with the main context from the container
            speciesRepository = SpeciesRepository(modelContext: modelContainer.mainContext)
            dexRepository = DexRepository(modelContext: modelContainer.mainContext)
            
            print("SwiftData ModelContainer, SpeciesRepository, and DexRepository initialized successfully.")

        } catch {
            // If the container fails to initialize, it's a critical error.
            // Consider more robust error handling or user feedback in a production app.
            fatalError("Failed to initialize SwiftData ModelContainer: \(error.localizedDescription)")
        }
    }

    var body: some Scene {
        WindowGroup {
            PlantLifeContentView(
                speciesRepository: speciesRepository,
                dexRepository: dexRepository
            )
        }
        .modelContainer(modelContainer)
    }
}

// Separate view to properly manage @StateObject instances
struct PlantLifeContentView: View {
    let speciesRepository: SpeciesRepository
    let dexRepository: DexRepository
    
    @StateObject private var imageService = ImageSelectionService.shared
    @StateObject private var classificationViewModel: ClassificationViewModel
    @StateObject private var floradexViewModel: FloradexCollectionViewModel
    @State private var selectedTab = 0
    
    init(speciesRepository: SpeciesRepository, dexRepository: DexRepository) {
        self.speciesRepository = speciesRepository
        self.dexRepository = dexRepository
        
        // Initialize StateObjects in init
        self._classificationViewModel = StateObject(wrappedValue: ClassificationViewModel(
            speciesRepository: speciesRepository,
            dexRepository: dexRepository
        ))
        self._floradexViewModel = StateObject(wrappedValue: FloradexCollectionViewModel(
            dexRepository: dexRepository
        ))
    }
    
    var body: some View {
        LiquidTabView(
            selection: $selectedTab,
            tabs: [
                ("magnifyingglass", "Identify"),
                ("leaf.fill", "Floradex"),
                ("person.fill", "Profile")
            ]
        ) {
            ZStack {
                // Removed print to avoid constant re-rendering logs
                switch selectedTab {
                case 0:
                    IdentifyLandingView(viewModel: classificationViewModel)
                        .transition(.asymmetric(
                            insertion: .move(edge: .trailing).combined(with: .opacity),
                            removal: .move(edge: .leading).combined(with: .opacity)
                        ))
                case 1:
                    FloradexCollectionView(viewModel: floradexViewModel)
                        .transition(.asymmetric(
                            insertion: .move(edge: selectedTab > 1 ? .leading : .trailing).combined(with: .opacity),
                            removal: .move(edge: selectedTab > 1 ? .trailing : .leading).combined(with: .opacity)
                        ))
                case 2:
                    ProfileView()
                        .transition(.asymmetric(
                            insertion: .move(edge: .leading).combined(with: .opacity),
                            removal: .move(edge: .trailing).combined(with: .opacity)
                        ))
                default:
                    EmptyView()
                }
            }
            .animation(AnimationConstants.signatureSpring, value: selectedTab)
        }
        .environmentObject(imageService)
        .onChange(of: selectedTab) { oldValue, newValue in
            print("[PlantLifeContentView] Tab changed from \(oldValue) to \(newValue)")
            // When switching away from the Identify tab, cancel any ongoing processing
            if oldValue == 0 && newValue != 0 {
                classificationViewModel.cleanup()
                // Clear the selected image to prevent re-processing
                imageService.selectedImage = nil
            }
            // When switching to Floradex, refresh the entries
            if newValue == 1 {
                print("[PlantLifeContentView] Fetching Floradex entries")
                floradexViewModel.fetchEntries()
            }
        }
    }
}