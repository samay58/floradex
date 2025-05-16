import SwiftUI
import SwiftData

@main
struct PlantLifeApp: App {
    // State properties for ModelContainer and SpeciesRepository
    let modelContainer: ModelContainer
    let speciesRepository: SpeciesRepository

    init() {
        do {
            // Define the schema including all SwiftData @Model classes
            let schema = Schema([
                SpeciesDetails.self
                // Add any other @Model classes here in the future
            ])

            // Configure the ModelContainer (e.g., for iCloud, App Groups, or just local storage)
            // isStoredInMemoryOnly: false for persistent storage, true for temporary in-memory (e.g., for previews or testing)
            let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

            // Initialize the ModelContainer
            modelContainer = try ModelContainer(for: schema, configurations: [modelConfiguration])

            // Initialize the SpeciesRepository with the main context from the container
            speciesRepository = SpeciesRepository(modelContext: modelContainer.mainContext)
            
            print("SwiftData ModelContainer and SpeciesRepository initialized successfully.")

        } catch {
            // If the container fails to initialize, it's a critical error.
            // Consider more robust error handling or user feedback in a production app.
            fatalError("Failed to initialize SwiftData ModelContainer: \(error.localizedDescription)")
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView(viewModel: ClassificationViewModel(speciesRepository: self.speciesRepository))
                .environmentObject(ImageSelectionService.shared)
        }
        .modelContainer(modelContainer) // Make the ModelContainer available to the scene
    }
} 