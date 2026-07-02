import SwiftUI
import SwiftData
import FloradexKit
import os

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

            // Linkage proof for the FloradexKit package (rewrite phase 3);
            // the hero-loop rebuild replaces this with real orchestrator use.
            Logger(subsystem: "samayd.floradex", category: "rewrite")
                .debug("FloradexKit linked; standard escalation steps: \(EscalationPolicy.standard.steps.count)")

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
    
    @StateObject private var floradexViewModel: FloradexCollectionViewModel
    @State private var captureModel: CaptureFlowModel
    @State private var selectedTab = 0

    init(speciesRepository: SpeciesRepository, dexRepository: DexRepository) {
        self.speciesRepository = speciesRepository
        self.dexRepository = dexRepository

        self._floradexViewModel = StateObject(wrappedValue: FloradexCollectionViewModel(
            dexRepository: dexRepository
        ))
        self._captureModel = State(initialValue: CaptureComposition.makeModel(
            dexRepository: dexRepository,
            speciesRepository: speciesRepository
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
                    CaptureHomeView(model: captureModel)
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
        .onChange(of: selectedTab) { _, newValue in
            // An in-flight identification keeps running across tab switches;
            // the reveal card is waiting when the user comes back.
            if newValue == 1 {
                floradexViewModel.fetchEntries()
            }
        }
    }
}