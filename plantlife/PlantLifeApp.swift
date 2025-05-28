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
        TabView(selection: $selectedTab) {
            IdentifyLandingView(viewModel: classificationViewModel)
                .tabItem { Label("Identify", systemImage: "camera.fill") }
                .tag(0)

            FloradexCollectionView(viewModel: floradexViewModel)
                .tabItem { Label("My Floradex", systemImage: "leaf.fill") }
                .tag(1)

            ProfileView()
                .tabItem { Label("Profile", systemImage: "person.fill") }
                .tag(2)
        }
        .tint(Theme.Colors.primaryGreen) // Set active tab icon color
        .environmentObject(imageService)
        .onChange(of: selectedTab) { oldValue, newValue in
            // When switching away from the Identify tab, cancel any ongoing processing
            if oldValue == 0 && newValue != 0 {
                classificationViewModel.cleanup()
                // Clear the selected image to prevent re-processing
                imageService.selectedImage = nil
            }
            // When switching to Floradex, refresh the entries
            if newValue == 1 {
                floradexViewModel.fetchEntries()
            }
        }
        .onAppear {
            let appearance = UITabBarAppearance()
            appearance.configureWithDefaultBackground() // Modern blurred background
            // For a solid color background, uncomment below and use .configureWithOpaqueBackground()
            // appearance.backgroundColor = UIColor(Theme.Colors.systemBackground)

            UITabBar.appearance().standardAppearance = appearance
            if #available(iOS 15.0, *) {
                UITabBar.appearance().scrollEdgeAppearance = appearance
            }
            UITabBar.appearance().isTranslucent = true // Required for blur effect
            // Optional: Set unselected item color if needed, e.g.:
            // UITabBar.appearance().unselectedItemTintColor = UIColor(Theme.Colors.iconSecondary)
        }
    }
}