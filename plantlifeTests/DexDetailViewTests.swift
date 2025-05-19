import XCTest
import SwiftUI
import SwiftData
import SnapshotTesting
@testable import plantlife

class DexDetailViewTests: XCTestCase {
    
    func testDexDetailView() throws {
        // Create a mock container
        let mockContainer = createMockModelContainer()
        
        // Create a mock version of DexDetailView for testing
        let mockView = MockDexDetailCardPagerView(entry: mockContainer.sampleEntry)
            .modelContainer(mockContainer.container)
            .frame(width: 390, height: 844) // iPhone 13 dimensions
        
        // Test the view with pager enabled
        let vc = UIHostingController(rootView: mockView)
        assertSnapshot(matching: vc, as: .image(on: .iPhoneX))
    }
    
    // Helper to create a mock ModelContainer with sample data
    private func createMockModelContainer() -> (container: ModelContainer, sampleEntry: DexEntry) {
        // Create a temporary in-memory container
        let container: ModelContainer
        do {
            let config = ModelConfiguration(isStoredInMemoryOnly: true)
            container = try ModelContainer(for: DexEntry.self, SpeciesDetails.self, configurations: config)
        } catch {
            fatalError("Failed to create model container: \(error)")
        }
        
        // Add sample data
        let entry = DexEntry(id: 1, latinName: "Monstera deliciosa", sprite: nil, dateAdded: Date(), notes: "Test notes")
        let details = SpeciesDetails(
            latinName: "Monstera deliciosa",
            commonName: "Swiss Cheese Plant",
            summary: "A popular houseplant with distinctive holes in its leaves.",
            growthHabit: "Climbing vine",
            sunlight: "Bright indirect light",
            water: "When top inch of soil is dry",
            soil: "Well-draining potting mix",
            temperature: "65-85°F (18-29°C)",
            bloomTime: "Rarely blooms indoors",
            funFacts: ["The holes in the leaves help it withstand tropical storms.", 
                       "The fruit is edible and tastes like a mix of pineapple and banana."],
            lastUpdated: Date()
        )
        
        container.mainContext.insert(entry)
        container.mainContext.insert(details)
        
        return (container, entry)
    }
    
    // Mock version of DexDetailView to control app state
    struct MockDexDetailCardPagerView: View {
        let entry: DexEntry
        @Query var speciesDetailItems: [SpeciesDetails]
        @State private var useExperimentalPager: Bool = true
        
        init(entry: DexEntry) {
            self.entry = entry
            let latinName = entry.latinName
            self._speciesDetailItems = Query(filter: #Predicate<SpeciesDetails> { 
                $0.latinName == latinName 
            })
        }
        
        private var speciesDetails: SpeciesDetails? {
            speciesDetailItems.first
        }
        
        var body: some View {
            VStack(spacing: 0) {
                // Header
                detailHeaderView
                    .padding()
                    .background(Material.thin)
                
                if useExperimentalPager {
                    // Card pager
                    DexCardPager(cards: [
                        AnyDexDetailCard(OverviewCard(entry: entry, details: speciesDetails)),
                        AnyDexDetailCard(CareCard(details: speciesDetails)),
                        AnyDexDetailCard(GrowthCard(details: speciesDetails))
                    ])
                } else {
                    // Fallback TabView (we're not testing this)
                    Text("Legacy Tab View")
                }
            }
            .navigationTitle(speciesDetails?.commonName ?? entry.latinName)
            .navigationBarTitleDisplayMode(.inline)
        }
        
        private var detailHeaderView: some View {
            HStack {
                // Placeholder sprite
                Image(systemName: "leaf.fill")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 80, height: 80)
                    .background(Theme.Colors.surface)
                    .cornerRadius(12)
                    .foregroundColor(.green)
                
                VStack(alignment: .leading) {
                    Text(speciesDetails?.commonName ?? entry.latinName)
                        .font(Font.pressStart2P(size: 18))
                    Text(entry.latinName)
                        .font(.callout)
                        .italic()
                        .foregroundColor(.secondary)
                    Text(String(format: "#%03d", entry.id))
                        .font(Font.pressStart2P(size: 14))
                        .foregroundColor(Theme.Colors.accent(for: entry.latinName))
                }
                Spacer()
            }
        }
    }
} 