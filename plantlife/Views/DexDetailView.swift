import SwiftUI
import SwiftData

struct DexDetailView: View {
    let entry: DexEntry
    var namespace: Namespace.ID? = nil // Optional for previews/other uses
    
    @Query var speciesDetailItems: [SpeciesDetails]
    
    // AppSettings for experimental features
    @AppStorage("experimentalPager") private var useExperimentalPager: Bool = true

    init(entry: DexEntry, namespace: Namespace.ID? = nil) {
        self.entry = entry
        self.namespace = namespace // Store namespace
        let latinName = entry.latinName
        // Filter SpeciesDetails based on the latinName of the entry.
        // Note: Ensure latinName is unique in SpeciesDetails or handle multiple results.
        self._speciesDetailItems = Query(filter: #Predicate<SpeciesDetails> { $0.latinName == latinName }, sort: [SortDescriptor(\SpeciesDetails.latinName)])
    }
    
    private var speciesDetails: SpeciesDetails? {
        // Assuming latinName is a unique identifier for SpeciesDetails,
        // so we expect at most one result.
        speciesDetailItems.first 
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header (e.g., Plant Name, Sprite, basic info - can be designed later)
            detailHeaderView
                .padding()
                .background(Material.thin)
            
            if useExperimentalPager {
                // New card-peel pager
                DexCardPager(cards: [
                    AnyDexDetailCard(OverviewCard(entry: entry, details: speciesDetails)),
                    AnyDexDetailCard(CareCard(details: speciesDetails)),
                    AnyDexDetailCard(GrowthCard(details: speciesDetails))
                ])
                .transition(.opacity)
            } else {
                // Legacy TabView (for compatibility)
                LegacyTabView(entry: entry, details: speciesDetails)
            }
        }
        .navigationTitle(speciesDetails?.commonName ?? entry.latinName)
        .navigationBarTitleDisplayMode(.inline)
    }
    
    private var detailHeaderView: some View {
        HStack {
            if let spriteData = entry.sprite, let uiImage = UIImage(data: spriteData) {
                Image(uiImage: uiImage)
                    .resizable()
                    .interpolation(.none)
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 80, height: 80)
                    .background(Theme.Colors.surface)
                    .cornerRadius(12)
                    .if(namespace != nil) { view in // Conditionally apply if namespace is provided
                        view.matchedGeometryEffect(id: "sprite-\(entry.id)", in: namespace!, isSource: false)
                    }
            } else {
                Image(systemName: "photo.circle.fill") // Placeholder
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 80, height: 80)
                    .foregroundColor(.gray)
            }
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

// Legacy TabView for backward compatibility
private struct LegacyTabView: View {
    let entry: DexEntry
    let details: SpeciesDetails?
    @State private var selectedTab: Tab = .overview
    
    enum Tab {
        case overview
        case care
        case growth
    }
    
    var body: some View {
        TabView(selection: $selectedTab) {
            OverviewLegacyTab(entry: entry, details: details)
                .tabItem {
                    Label("Overview", systemImage: "doc.text")
                }
                .tag(Tab.overview)
            
            CareLegacyTab(details: details)
                .tabItem {
                    Label("Care", systemImage: "leaf.fill")
                }
                .tag(Tab.care)
            
            GrowthLegacyTab(details: details)
                .tabItem {
                    Label("Growth", systemImage: "chart.bar.xaxis")
                }
                .tag(Tab.growth)
        }
    }
    
    // Legacy tab views - these are private to avoid confusion with the new card views
    private struct OverviewLegacyTab: View {
        let entry: DexEntry
        let details: SpeciesDetails?
        
        private var wikipediaURL: URL? {
            guard let latinName = details?.latinName else { return nil }
            let formattedName = latinName.replacingOccurrences(of: " ", with: "_")
            return URL(string: "https://en.wikipedia.org/wiki/\(formattedName)")
        }
        
        var body: some View {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Summary")
                        .font(Font.pressStart2P(size: 16))
                    Text(details?.summary ?? "No summary available.")
                        .padding(.bottom)
                    
                    if let funFacts = details?.funFacts, !funFacts.isEmpty {
                        Text("Fun Facts")
                            .font(Font.pressStart2P(size: 16))
                        ForEach(funFacts, id: \.self) { fact in
                            Label(fact, systemImage: "sparkle")
                        }
                        .padding(.bottom)
                    }
                    
                    if let notes = entry.notes, !notes.isEmpty {
                        Text("My Notes")
                            .font(Font.pressStart2P(size: 16))
                            .padding(.top)
                        Text(notes)
                            .padding(.bottom)
                    }
                    
                    if let url = wikipediaURL {
                        Text("Learn More")
                            .font(Font.pressStart2P(size: 16))
                            .padding(.top)
                        Link("View on Wikipedia", destination: url)
                            .font(.callout)
                            .foregroundColor(Theme.Colors.accent(for: details?.latinName ?? "default"))
                    }
                }
                .padding()
            }
        }
    }
    
    private struct CareLegacyTab: View {
        let details: SpeciesDetails?
        
        var body: some View {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Care Guide")
                        .font(Font.pressStart2P(size: 16))
                    PlantInfo.InfoRow(label: "Sunlight", value: details?.sunlight, accentColor: Theme.Colors.accent(for: "Sunlight"))
                    PlantInfo.InfoRow(label: "Water", value: details?.water, accentColor: Theme.Colors.accent(for: "Water"))
                    PlantInfo.InfoRow(label: "Soil", value: details?.soil, accentColor: Theme.Colors.accent(for: "Soil"))
                    PlantInfo.InfoRow(label: "Temperature", value: details?.temperature, accentColor: Theme.Colors.accent(for: "Temperature"))
                }
                .padding()
            }
        }
    }
    
    private struct GrowthLegacyTab: View {
        let details: SpeciesDetails?
        
        private var careDifficulty: (value: Double, label: String) {
            guard let details = details else { return (0.5, "Unknown") }
            let nameLength = details.commonName?.count ?? 10
            if nameLength < 15 {
                return (0.8, "Easy")
            } else if nameLength < 25 {
                return (0.5, "Moderate")
            } else {
                return (0.2, "Hard")
            }
        }
        
        var body: some View {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Growth & Habit")
                        .font(Font.pressStart2P(size: 16))
                    PlantInfo.InfoRow(label: "Growth Habit", value: details?.growthHabit, accentColor: Theme.Colors.accent(for: "Growth"))
                    PlantInfo.InfoRow(label: "Bloom Time", value: details?.bloomTime, accentColor: Theme.Colors.accent(for: "Bloom"))
                    
                    if #available(iOS 16.0, *) {
                        Text("Care Difficulty")
                            .font(Font.pressStart2P(size: 14))
                            .padding(.top)
                        
                        Gauge(value: careDifficulty.value, label: {
                            Text(careDifficulty.label)
                        }) {
                            Text(String(format: "%.0f%% Easy", careDifficulty.value * 100))
                                .font(.caption)
                        }
                        .gaugeStyle(.accessoryCircular)
                        .tint(careDifficulty.value > 0.6 ? .green : (careDifficulty.value > 0.3 ? .orange : .red))
                        .padding(.bottom)
                    } else {
                        PlantInfo.InfoRow(label: "Care Difficulty", value: careDifficulty.label, accentColor: Theme.Colors.accent(for: "Difficulty"))
                    }
                }
                .padding()
            }
        }
    }
}

#if DEBUG
@MainActor
struct DexDetailView_Previews: PreviewProvider {
    static var previews: some View {
        let previewContainer: ModelContainer = {
            do {
                let config = ModelConfiguration(isStoredInMemoryOnly: true)
                let container = try ModelContainer(for: DexEntry.self, SpeciesDetails.self, configurations: config)
                
                // Insert sample DexEntry
                var sampleEntry = PreviewHelper.sampleDexEntry // This has latinName "Monstera deliciosa"
                if let spriteData = UIImage(systemName: "leaf.fill")?.withTintColor(.systemGreen).pngData() {
                     sampleEntry.sprite = spriteData
                }
                container.mainContext.insert(sampleEntry)
                
                // Insert sample SpeciesDetails that matches the sampleEntry's latinName
                container.mainContext.insert(PreviewHelper.sampleSpeciesDetailsMonstera) // Ensure this exists and matches
                
                // Example of a second entry for testing navigation/selection
                var anotherEntry = PreviewHelper.sampleDexEntryWithoutSprite // latinName "Ficus lyrata"
                 container.mainContext.insert(anotherEntry)
                 container.mainContext.insert(PreviewHelper.sampleSpeciesDetailsFicus)


                try container.mainContext.save()
                return container
            } catch {
                fatalError("Failed to create model container for preview: \(error)")
            }
        }()

        return NavigationStack {
            // Preview with the entry that has corresponding SpeciesDetails
            DexDetailView(entry: PreviewHelper.sampleDexEntry, namespace: nil)
        }
        .modelContainer(previewContainer)
    }
}

// Ensure PreviewHelper has the corresponding sample data
extension PreviewHelper {
    @MainActor // Keep original sampleSpeciesDetails if used elsewhere or rename
    static var sampleSpeciesDetailsMonstera: SpeciesDetails { // Renamed for clarity
        SpeciesDetails(
            latinName: "Monstera deliciosa", // Must match sampleDexEntry.latinName
            commonName: "Swiss Cheese Plant",
            summary: "A popular and easy-to-care-for houseplant known for its large, fenestrated leaves. It prefers bright, indirect light and moderate watering.",
            growthHabit: "Climbing vine, can grow very large",
            sunlight: "Bright, indirect light. Tolerates medium light.",
            water: "Water thoroughly when top 2 inches of soil are dry. Avoid overwatering.",
            soil: "Well-draining potting mix, rich in organic matter.",
            temperature: "18°C - 27°C (65°F - 80°F)",
            bloomTime: "Rarely blooms indoors, but can produce spathe-like flowers.",
            funFacts: [
                "Its fruit is edible and tastes like a mix of pineapple and banana.",
                "The holes in its leaves are called fenestrations and help it withstand strong winds in its native habitat.",
                "Can be easily propagated from stem cuttings."
            ],
            lastUpdated: Date()
        )
    }

    // Add another sample for Ficus Lyrata if needed for previews
    @MainActor
    static var sampleSpeciesDetailsFicus: SpeciesDetails {
        SpeciesDetails(
            latinName: "Ficus lyrata", // Must match sampleDexEntryWithoutSprite.latinName
            commonName: "Fiddle Leaf Fig",
            summary: "A popular but somewhat demanding indoor tree, known for its large, violin-shaped leaves.",
            growthHabit: "Upright tree",
            sunlight: "Bright, indirect light. Can take some direct morning sun.",
            water: "Water when the top inch of soil is dry. Likes consistency.",
            soil: "Well-draining potting mix.",
            temperature: "18°C - 24°C (65°F - 75°F)",
            bloomTime: "Rarely flowers indoors.",
            funFacts: [
                "Native to western Africa.",
                "Can be sensitive to drafts and changes in location."
            ],
            lastUpdated: Date()
        )
    }
}
#endif 