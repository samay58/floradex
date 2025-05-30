import SwiftUI
import SwiftData

/// Modern PlantDetailsView with immersive full-screen design
struct PlantDetailsView: View {
    @ObservedObject var viewModel: ClassificationViewModel
    let identifiedImage: UIImage?
    let existingEntry: DexEntry?
    
    @State private var speciesDetails: SpeciesDetails?
    @State private var currentEntry: DexEntry?
    @State private var showSkeleton = false
    @State private var scrollOffset: CGFloat = 0
    @State private var headerHeight: CGFloat = 400
    @State private var showFloatingHeader = false
    @State private var selectedTab = 0
    @State private var appeared = false
    @State private var contentAppeared = false
    
    @Environment(\.dismiss) private var dismiss
    @Namespace private var namespace
    
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
        ZStack {
            // Background
            Theme.Colors.systemBackground
                .ignoresSafeArea()
            
            // Main scrollable content
            ScrollView {
                VStack(spacing: 0) {
                    // Hero header with parallax
                    heroHeaderView
                        .frame(height: max(200, headerHeight + scrollOffset))
                        .clipped()
                        .overlay(alignment: .bottom) {
                            headerGradientOverlay
                        }
                    
                    // Main content
                    VStack(spacing: 0) {
                        // Plant info summary
                        plantInfoSummary
                            .padding(Theme.Metrics.Padding.large)
                            .opacity(contentAppeared ? 1 : 0)
                            .offset(y: contentAppeared ? 0 : 20)
                        
                        // Tab selector
                        DetailTabSelector(selectedTab: $selectedTab)
                            .padding(.horizontal, Theme.Metrics.Padding.large)
                            .opacity(contentAppeared ? 1 : 0)
                            .offset(y: contentAppeared ? 0 : 20)
                        
                        // Tab content
                        Group {
                            if let entry = currentEntry, let details = speciesDetails {
                                TabContentView(
                                    selectedTab: selectedTab,
                                    entry: entry,
                                    details: details
                                )
                                .padding(.horizontal, Theme.Metrics.Padding.large)
                                .padding(.vertical, Theme.Metrics.Padding.medium)
                                .opacity(contentAppeared ? 1 : 0)
                                .offset(y: contentAppeared ? 0 : 30)
                            } else if viewModel.isLoading && identifiedImage != nil {
                                MultiServiceProgressView(viewModel: viewModel)
                                    .padding()
                                    .frame(minHeight: 400)
                            } else {
                                emptyStateView
                                    .frame(minHeight: 400)
                            }
                        }
                        .animation(.easeInOut(duration: 0.2), value: selectedTab)
                        
                        // Bottom padding for safe area
                        Color.clear.frame(height: 100)
                    }
                    .background(
                        Theme.Colors.systemBackground
                            .cornerRadius(24, corners: [.topLeft, .topRight])
                            .ignoresSafeArea(edges: .bottom)
                    )
                    .offset(y: appeared ? 0 : 50)
                }
                .background(
                    GeometryReader { geometry in
                        Color.clear.preference(
                            key: ScrollOffsetPreferenceKey.self,
                            value: geometry.frame(in: .named("scroll")).minY
                        )
                    }
                )
            }
            .coordinateSpace(name: "scroll")
            .onPreferenceChange(ScrollOffsetPreferenceKey.self) { value in
                scrollOffset = value
                showFloatingHeader = scrollOffset < -200
            }
            .ignoresSafeArea(edges: .top)
            
            // Floating header
            if showFloatingHeader {
                floatingHeaderView
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
            
            // Top controls overlay
            topControlsOverlay
        }
        .navigationBarHidden(true)
        .statusBar(hidden: false)
        .onAppear {
            setupData()
            
            // Trigger entrance animations
            withAnimation(AnimationConstants.signatureSpring) {
                appeared = true
            }
            
            // Stagger content appearance
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                withAnimation(AnimationConstants.smoothSpring) {
                    contentAppeared = true
                }
            }
        }
        .onChange(of: viewModel.details) { newDetails in
            if existingEntry == nil {
                self.speciesDetails = newDetails
            }
        }
        .onChange(of: viewModel.currentDexEntry) { newEntry in
            if existingEntry == nil {
                self.currentEntry = newEntry
            }
        }
    }
    
    // MARK: - View Components
    
    private var heroHeaderView: some View {
        ZStack {
            // Background image with blur effect
            if let img = displayedImage {
                Image(uiImage: img)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(maxWidth: .infinity)
                    .overlay(Color.black.opacity(0.2))
                    .blur(radius: max(0, -scrollOffset / 20))
                    .scaleEffect(1 + max(0, scrollOffset / 1000))
            } else {
                LinearGradient(
                    gradient: Gradient(colors: [
                        Theme.Colors.primaryGreen.opacity(0.6),
                        Theme.Colors.primaryGreen.opacity(0.3)
                    ]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }
            
            // Centered plant image or sprite
            VStack {
                Spacer()
                
                if let spriteData = currentEntry?.sprite, let sprite = UIImage(data: spriteData) {
                    Image(uiImage: sprite)
                        .resizable()
                        .interpolation(.none)
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 120, height: 120)
                        .padding()
                        .background(
                            Circle()
                                .fill(.ultraThinMaterial)
                                .overlay(
                                    Circle()
                                        .stroke(Color.white.opacity(0.5), lineWidth: 2)
                                )
                        )
                        .shadow(color: .black.opacity(0.3), radius: 20, y: 10)
                } else if let img = displayedImage {
                    Image(uiImage: img)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 150, height: 150)
                        .clipShape(Circle())
                        .overlay(
                            Circle()
                                .stroke(Color.white.opacity(0.8), lineWidth: 3)
                        )
                        .shadow(color: .black.opacity(0.3), radius: 20, y: 10)
                }
                
                Spacer()
            }
        }
    }
    
    private var headerGradientOverlay: some View {
        LinearGradient(
            gradient: Gradient(colors: [
                Color.clear,
                Color.clear,
                Theme.Colors.systemBackground.opacity(0.8),
                Theme.Colors.systemBackground
            ]),
            startPoint: .top,
            endPoint: .bottom
        )
        .frame(height: 100)
    }
    
    private var plantInfoSummary: some View {
        VStack(spacing: Theme.Metrics.Padding.small) {
            // Common name
            Text(speciesDetails?.commonName ?? currentEntry?.latinName ?? "Unknown Plant")
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundColor(Theme.Colors.textPrimary)
                .multilineTextAlignment(.center)
            
            // Latin name
            if let latinName = currentEntry?.latinName,
               latinName != speciesDetails?.commonName {
                Text(latinName)
                    .font(.system(size: 18, weight: .medium))
                    .italic()
                    .foregroundColor(Theme.Colors.textSecondary)
            }
            
            // Entry number and tags
            HStack(spacing: Theme.Metrics.Padding.small) {
                if let id = currentEntry?.id {
                    Label("#\(String(format: "%03d", id))", systemImage: "number")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(Theme.Colors.primaryGreen)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(
                            Capsule()
                                .fill(Theme.Colors.primaryGreen.opacity(0.1))
                        )
                }
                
                if let firstTag = currentEntry?.tags.first {
                    Label(firstTag.capitalized, systemImage: "tag.fill")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(Theme.Colors.textSecondary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(
                            Capsule()
                                .fill(Theme.Colors.systemFill)
                        )
                }
            }
        }
    }
    
    private var floatingHeaderView: some View {
        HStack {
            Text(speciesDetails?.commonName ?? currentEntry?.latinName ?? "Plant")
                .font(.headline)
                .foregroundColor(Theme.Colors.textPrimary)
            
            Spacer()
        }
        .padding()
        .background(.ultraThinMaterial)
        .overlay(
            Rectangle()
                .fill(Color.gray.opacity(0.1))
                .frame(height: 1),
            alignment: .bottom
        )
    }
    
    private var topControlsOverlay: some View {
        VStack {
            HStack {
                // Back button
                Button(action: { 
                    HapticManager.shared.buttonTap()
                    dismiss() 
                }) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 40, height: 40)
                        .background(
                            Circle()
                                .fill(.ultraThinMaterial)
                        )
                }
                .scaleEffect(appeared ? 1 : 0.8)
                .opacity(appeared ? 1 : 0)
                
                Spacer()
                
                // Action buttons
                HStack(spacing: 12) {
                    Button(action: { 
                        HapticManager.shared.buttonTap()
                        /* TODO: Favorite */ 
                    }) {
                        Image(systemName: "heart")
                            .font(.system(size: 18))
                            .foregroundStyle(.white)
                            .frame(width: 40, height: 40)
                            .background(
                                Circle()
                                    .fill(.ultraThinMaterial)
                            )
                    }
                    .scaleEffect(appeared ? 1 : 0.8)
                    .opacity(appeared ? 1 : 0)
                    .animation(AnimationConstants.signatureSpring.delay(0.1), value: appeared)
                    
                    Button(action: { 
                        HapticManager.shared.buttonTap()
                        /* TODO: Share */ 
                    }) {
                        Image(systemName: "square.and.arrow.up")
                            .font(.system(size: 18))
                            .foregroundStyle(.white)
                            .frame(width: 40, height: 40)
                            .background(
                                Circle()
                                    .fill(.ultraThinMaterial)
                            )
                    }
                    .scaleEffect(appeared ? 1 : 0.8)
                    .opacity(appeared ? 1 : 0)
                    .animation(AnimationConstants.signatureSpring.delay(0.15), value: appeared)
                }
            }
            .padding()
            .padding(.top, 44) // Account for status bar
            
            Spacer()
        }
    }
    
    private var emptyStateView: some View {
        VStack(spacing: Theme.Metrics.Padding.large) {
            Image(systemName: "leaf.circle")
                .font(.system(size: 60))
                .foregroundColor(Theme.Colors.iconSecondary)
            
            Text("Details not available")
                .font(Theme.Typography.title2)
                .foregroundColor(Theme.Colors.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
    }
    
    // MARK: - Helper Methods
    
    private var displayedImage: UIImage? {
        if let identified = identifiedImage { return identified }
        if let snapshotData = existingEntry?.snapshot, let img = UIImage(data: snapshotData) { return img }
        return nil
    }
    
    private func setupData() {
        if let entry = existingEntry {
            currentEntry = entry
            speciesDetails = queriedSpeciesDetails.first
        } else if identifiedImage != nil {
            Task {
                await viewModel.processSelectedImage()
            }
        }
    }
}

// MARK: - Tab Selector

struct DetailTabSelector: View {
    @Binding var selectedTab: Int
    
    let tabs = ["Overview", "Care", "Growth"]
    
    var body: some View {
        HStack(spacing: 0) {
            ForEach(0..<tabs.count, id: \.self) { index in
                Button(action: { 
                    withAnimation(.easeInOut(duration: 0.2)) {
                        selectedTab = index
                    }
                }) {
                    VStack(spacing: 8) {
                        Text(tabs[index])
                            .font(.system(size: 16, weight: selectedTab == index ? .semibold : .regular))
                            .foregroundColor(selectedTab == index ? Theme.Colors.textPrimary : Theme.Colors.textSecondary)
                        
                        Rectangle()
                            .fill(selectedTab == index ? Theme.Colors.primaryGreen : Color.clear)
                            .frame(height: 3)
                            .cornerRadius(1.5)
                    }
                }
                .frame(maxWidth: .infinity)
            }
        }
        .padding(.vertical, 8)
        .background(
            Rectangle()
                .fill(Color.gray.opacity(0.1))
                .frame(height: 1),
            alignment: .bottom
        )
    }
}

// MARK: - Tab Content View

struct TabContentView: View {
    let selectedTab: Int
    let entry: DexEntry
    let details: SpeciesDetails
    
    var body: some View {
        ScrollView {
            VStack(spacing: Theme.Metrics.Padding.large) {
                switch selectedTab {
                case 0:
                    OverviewTabContent(entry: entry, details: details)
                case 1:
                    CareTabContent(details: details)
                case 2:
                    GrowthTabContent(details: details)
                default:
                    EmptyView()
                }
            }
            .padding(.vertical, Theme.Metrics.Padding.medium)
        }
        .frame(minHeight: 400)
    }
}

// MARK: - Tab Content Components

struct OverviewTabContent: View {
    let entry: DexEntry
    let details: SpeciesDetails
    
    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Metrics.Padding.large) {
            // Summary
            if let summary = details.summary {
                ModernInfoCard(title: "Summary", icon: "text.alignleft") {
                    Text(summary)
                        .font(Theme.Typography.body)
                        .foregroundColor(Theme.Colors.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            
            // Fun Facts
            if let funFacts = details.funFacts, !funFacts.isEmpty {
                ModernInfoCard(title: "Fun Facts", icon: "sparkles") {
                    VStack(alignment: .leading, spacing: Theme.Metrics.Padding.medium) {
                        ForEach(Array(funFacts.enumerated()), id: \.offset) { index, fact in
                            HStack(alignment: .top, spacing: 12) {
                                Image(systemName: "leaf.fill")
                                    .font(.system(size: 14))
                                    .foregroundColor(Theme.Colors.primaryGreen)
                                    .padding(.top, 2)
                                
                                Text(fact)
                                    .font(Theme.Typography.body)
                                    .foregroundColor(Theme.Colors.textPrimary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                    }
                }
            }
            
            // Classification
            ModernInfoCard(title: "Classification", icon: "text.badge.checkmark") {
                VStack(alignment: .leading, spacing: Theme.Metrics.Padding.small) {
                    InfoRow(label: "Scientific Name", value: details.latinName)
                    if let family = details.family {
                        InfoRow(label: "Family", value: family)
                    }
                    InfoRow(label: "Discovered", value: DateFormatter.localizedString(from: entry.createdAt, dateStyle: .medium, timeStyle: .none))
                }
            }
            
            // Tags
            if !entry.tags.isEmpty {
                ModernInfoCard(title: "Categories", icon: "tag") {
                    FlowLayout(spacing: Theme.Metrics.Padding.small) {
                        ForEach(entry.tags, id: \.self) { tag in
                            Text(tag.capitalized)
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(Theme.Colors.textSecondary)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .background(
                                    Capsule()
                                        .fill(Theme.Colors.systemFill)
                                )
                        }
                    }
                }
            }
        }
    }
}

struct CareTabContent: View {
    let details: SpeciesDetails
    
    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Metrics.Padding.large) {
            // Care Requirements
            ModernInfoCard(title: "Care Requirements", icon: "leaf") {
                VStack(spacing: Theme.Metrics.Padding.large) {
                    // Watering
                    if details.water != nil {
                        ModernGaugeView(
                            icon: "drop.fill",
                            title: "Watering",
                            value: Int(details.parsedWaterRequirement * 5),
                            maxValue: 5,
                            color: .blue
                        )
                    }
                    
                    // Sunlight
                    if details.sunlight != nil {
                        ModernGaugeView(
                            icon: "sun.max.fill",
                            title: "Sunlight",
                            value: details.parsedSunlightLevel.gaugeValue,
                            maxValue: 5,
                            color: .orange
                        )
                    }
                    
                    // Difficulty
                    if let difficulty = details.careDifficulty {
                        ModernGaugeView(
                            icon: "star.fill",
                            title: "Difficulty",
                            value: difficulty,
                            maxValue: 5,
                            color: Theme.Colors.primaryGreen
                        )
                    }
                }
            }
            
            // Temperature Range
            if details.minTemp != nil || details.maxTemp != nil {
                ModernInfoCard(title: "Temperature Range", icon: "thermometer") {
                    ModernTemperatureView(
                        minTemp: details.minTemp ?? 0,
                        maxTemp: details.maxTemp ?? 100
                    )
                }
            }
        }
    }
}

struct GrowthTabContent: View {
    let details: SpeciesDetails
    
    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Metrics.Padding.large) {
            // Growth Information
            ModernInfoCard(title: "Growth Information", icon: "arrow.up.circle") {
                VStack(alignment: .leading, spacing: Theme.Metrics.Padding.small) {
                    if let growthHabit = details.growthHabit {
                        InfoRow(label: "Growth Habit", value: growthHabit)
                    }
                    if let bloomTime = details.bloomTime {
                        InfoRow(label: "Bloom Time", value: bloomTime)
                    }
                    if let temperature = details.temperature {
                        InfoRow(label: "Temperature", value: temperature)
                    }
                    if let soil = details.soil {
                        InfoRow(label: "Soil", value: soil)
                    }
                }
            }
            
            // Native Region
            if let nativeRegion = details.nativeRegion {
                ModernInfoCard(title: "Native Region", icon: "globe.americas") {
                    HStack {
                        Image(systemName: "map")
                            .font(.system(size: 20))
                            .foregroundColor(Theme.Colors.primaryGreen)
                        Text(nativeRegion)
                            .font(Theme.Typography.body)
                            .foregroundColor(Theme.Colors.textPrimary)
                    }
                    .padding(.vertical, 8)
                }
            }
        }
    }
}

// MARK: - Supporting Views

struct ModernInfoCard<Content: View>: View {
    let title: String
    let icon: String
    @ViewBuilder let content: () -> Content
    
    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Metrics.Padding.medium) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(Theme.Colors.primaryGreen)
                
                Text(title)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(Theme.Colors.textPrimary)
                
                Spacer()
            }
            
            content()
                .padding(Theme.Metrics.Padding.medium)
                .background(
                    RoundedRectangle(cornerRadius: Theme.Metrics.cornerRadiusMedium)
                        .fill(Theme.Colors.systemFill.opacity(0.5))
                )
        }
    }
}

struct InfoRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Text(label)
                .font(.system(size: 14))
                .foregroundColor(Theme.Colors.textSecondary)
            
            Spacer()
            
            Text(value)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(Theme.Colors.textPrimary)
                .multilineTextAlignment(.trailing)
        }
        .padding(.vertical, 4)
    }
}

struct ModernGaugeView: View {
    let icon: String
    let title: String
    let value: Int
    let maxValue: Int
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 20))
                    .foregroundColor(color)
                
                Text(title)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(Theme.Colors.textPrimary)
                
                Spacer()
                
                Text("\(value)/\(maxValue)")
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundColor(Theme.Colors.textSecondary)
            }
            
            // Gauge bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(color.opacity(0.2))
                        .frame(height: 12)
                    
                    RoundedRectangle(cornerRadius: 6)
                        .fill(
                            LinearGradient(
                                gradient: Gradient(colors: [color, color.opacity(0.8)]),
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(
                            width: geometry.size.width * (CGFloat(value) / CGFloat(maxValue)),
                            height: 12
                        )
                        .animation(.spring(response: 0.5, dampingFraction: 0.8), value: value)
                }
            }
            .frame(height: 12)
        }
    }
}

struct ModernTemperatureView: View {
    let minTemp: Int
    let maxTemp: Int
    
    var body: some View {
        HStack(spacing: Theme.Metrics.Padding.large) {
            // Min temp
            VStack(spacing: 8) {
                Image(systemName: "thermometer.low")
                    .font(.system(size: 30))
                    .foregroundColor(.blue)
                
                Text("\(minTemp)°F")
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundColor(Theme.Colors.textPrimary)
                
                Text("Minimum")
                    .font(.system(size: 12))
                    .foregroundColor(Theme.Colors.textSecondary)
            }
            .frame(maxWidth: .infinity)
            
            // Temperature gradient
            VStack {
                Spacer()
                
                LinearGradient(
                    gradient: Gradient(colors: [.blue, .green, .yellow, .orange, .red]),
                    startPoint: .leading,
                    endPoint: .trailing
                )
                .frame(height: 8)
                .cornerRadius(4)
                .overlay(
                    GeometryReader { geometry in
                        Circle()
                            .fill(Color.white)
                            .frame(width: 16, height: 16)
                            .shadow(color: .black.opacity(0.2), radius: 2)
                            .offset(x: geometry.size.width * 0.5 - 8)
                    }
                )
                
                Spacer()
            }
            .frame(maxWidth: .infinity)
            
            // Max temp
            VStack(spacing: 8) {
                Image(systemName: "thermometer.high")
                    .font(.system(size: 30))
                    .foregroundColor(.red)
                
                Text("\(maxTemp)°F")
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundColor(Theme.Colors.textPrimary)
                
                Text("Maximum")
                    .font(.system(size: 12))
                    .foregroundColor(Theme.Colors.textSecondary)
            }
            .frame(maxWidth: .infinity)
        }
        .padding(.vertical, Theme.Metrics.Padding.medium)
    }
}

// MARK: - Corner Radius Extension

extension View {
    func cornerRadius(_ radius: CGFloat, corners: UIRectCorner) -> some View {
        clipShape(RoundedCorner(radius: radius, corners: corners))
    }
}

struct RoundedCorner: Shape {
    var radius: CGFloat = .infinity
    var corners: UIRectCorner = .allCorners
    
    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(
            roundedRect: rect,
            byRoundingCorners: corners,
            cornerRadii: CGSize(width: radius, height: radius)
        )
        return Path(path.cgPath)
    }
}

// MARK: - Legacy Support

struct DexDetailView: View {
    let entry: DexEntry
    var namespace: Namespace.ID? = nil
    
    var body: some View {
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