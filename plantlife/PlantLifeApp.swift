import SwiftUI
import SwiftData
import FloradexKit

@main
struct PlantLifeApp: App {
    let modelContainer: ModelContainer
    let store: SwiftDataDexStore
    let media: FileMediaStore

    init() {
        do {
            let schema = Schema(versionedSchema: FloradexSchemaV2.self)
            modelContainer = try ModelContainer(
                for: schema,
                migrationPlan: FloradexMigrationPlan.self,
                configurations: [ModelConfiguration(schema: schema)]
            )
        } catch {
            fatalError("Failed to initialize SwiftData ModelContainer: \(error)")
        }
        store = SwiftDataDexStore(modelContext: modelContainer.mainContext)
        media = FileMediaStore(root: MediaLocations.root)
    }

    var body: some Scene {
        WindowGroup {
            RootTabView(store: store, media: media)
        }
        .modelContainer(modelContainer)
    }
}

struct RootTabView: View {
    enum TabID: String {
        case identify, dex, profile
    }

    let store: SwiftDataDexStore
    let media: FileMediaStore
    @State private var captureModel: CaptureFlowModel
    @State private var selection: TabID = .identify

    init(store: SwiftDataDexStore, media: FileMediaStore) {
        self.store = store
        self.media = media
        self._captureModel = State(initialValue: CaptureComposition.makeModel(store: store, media: media))
        #if DEBUG
        // Demo and UI-test harness: FLORADEX_TAB=dex lands on the collection.
        if let raw = DebugFlags.initialTab, let tab = TabID(rawValue: raw) {
            self._selection = State(initialValue: tab)
        }
        #endif
    }

    var body: some View {
        // An in-flight identification keeps running across tab switches;
        // the reveal card is waiting when the user comes back.
        TabView(selection: $selection) {
            Tab("Identify", systemImage: "camera.viewfinder", value: TabID.identify) {
                CaptureHomeView(model: captureModel)
            }
            Tab("Floradex", systemImage: "leaf.fill", value: TabID.dex) {
                DexGridView(store: store, media: media)
            }
            Tab("Profile", systemImage: "person.crop.circle", value: TabID.profile) {
                ProfileView()
            }
        }
        .tint(Color.floraGreen)
    }
}
