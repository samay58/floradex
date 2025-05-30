import SwiftUI
import SwiftData

struct DexGrid: View {
    let entries: [DexEntry]
    let onRefresh: () -> Void
    var onDelete: ((DexEntry) -> Void)? = nil
    @Binding var isSelectionMode: Bool
    
    @Namespace private var heroNamespace
    @State private var scrollOffset: CGFloat = 0
    @State private var scrollVelocity: CGFloat = 0
    @State private var lastScrollOffset: CGFloat = 0
    @State private var appearingCards: Set<Int> = []
    @State private var pullProgress: CGFloat = 0
    @State private var isRefreshing = false
    @State private var selectedEntry: DexEntry? = nil
    @State private var visibleRange: Range<Int> = 0..<0
    @State private var selectedEntries: Set<Int> = []
    
    // Image cache for prefetching
    @StateObject private var imageCache = ImageCacheManager.shared
    
    private let columns = [
        GridItem(.flexible(), spacing: 10),
        GridItem(.flexible(), spacing: 10)
    ]
    
    var body: some View {
        GeometryReader { geometry in
            scrollContent(geometry: geometry)
        }
        .refreshable {
            await performRefresh()
        }
        .background(Theme.Colors.systemBackground)
        .fullScreenCover(item: $selectedEntry) { entry in
            PlantDetailsView(entry: entry, namespace: heroNamespace)
        }
        .overlay(alignment: .bottom) {
            if isSelectionMode && !selectedEntries.isEmpty {
                selectionToolbar
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .onChange(of: isSelectionMode) { newValue in
            if !newValue {
                withAnimation(AnimationConstants.smoothSpring) {
                    selectedEntries.removeAll()
                }
            }
        }
    }
    
    @ViewBuilder
    private func scrollContent(geometry: GeometryProxy) -> some View {
        ScrollView {
            VStack(spacing: 0) {
                // Pull to refresh animation
                pullToRefreshView
                
                if entries.isEmpty {
                    emptyStateView
                        .frame(minHeight: geometry.size.height)
                } else {
                    gridContent
                        .padding(.horizontal, 10)
                        .background(scrollOffsetReader)
                }
            }
        }
        .coordinateSpace(name: "scroll")
        .onPreferenceChange(ScrollOffsetPreferenceKey.self) { value in
            handleScrollOffsetChange(value)
        }
    }
    
    private var pullToRefreshView: some View {
        Group {
            if pullProgress > 0 {
                PlantGrowthAnimation(progress: pullProgress)
                    .frame(height: max(0, pullProgress * 100))
                    .animation(AnimationConstants.smoothSpring, value: pullProgress)
            }
        }
    }
    
    private var gridContent: some View {
        LazyVGrid(columns: columns, spacing: 10) {
            ForEach(Array(entries.enumerated()), id: \.element.id) { index, entry in
                gridItem(for: entry, at: index)
                    .id("\(entry.id)-\(index)") // Force re-render on sort
                    .transition(.asymmetric(
                        insertion: .scale(scale: 0.8).combined(with: .opacity),
                        removal: .scale(scale: 1.2).combined(with: .opacity)
                    ))
            }
        }
        .animation(AnimationConstants.smoothSpring, value: entries.map { $0.id })
    }
    
    @ViewBuilder
    private func gridItem(for entry: DexEntry, at index: Int) -> some View {
        GeometryReader { itemGeometry in
            DexCard(entry: entry, namespace: heroNamespace) { onDelete?(entry) }
                .scaleEffect(cardScale(for: entry.id))
                .opacity(cardOpacity(for: entry.id))
                .rotation3DEffect(
                    .degrees(perspectiveTilt(for: itemGeometry)),
                    axis: (x: 1, y: 0, z: 0),
                    anchor: .center,
                    anchorZ: 0,
                    perspective: 1
                )
                .offset(y: velocityOffset(for: index))
                .onAppear {
                    animateCardAppearance(entry: entry, index: index)
                    updateVisibleRange(index: index)
                }
                .onDisappear {
                    appearingCards.remove(entry.id)
                }
                .overlay(alignment: .topTrailing) {
                    if isSelectionMode {
                        selectionCheckmark(for: entry.id)
                    }
                }
        }
        .frame(height: 200)
        .contentShape(Rectangle()) // Make entire area tappable
        .onTapGesture {
            if isSelectionMode {
                withAnimation(AnimationConstants.microSpring) {
                    if selectedEntries.contains(entry.id) {
                        selectedEntries.remove(entry.id)
                    } else {
                        selectedEntries.insert(entry.id)
                    }
                }
                HapticManager.shared.tick()
            } else {
                // Navigate to details
                HapticManager.shared.buttonTap()
                print("DexGrid: Tapped entry \(entry.id) - \(entry.latinName)")
                selectedEntry = entry
            }
        }
    }
    
    private var scrollOffsetReader: some View {
        GeometryReader { scrollViewGeometry in
            Color.clear
                .preference(
                    key: ScrollOffsetPreferenceKey.self,
                    value: scrollViewGeometry.frame(in: .named("scroll")).minY
                )
        }
    }
    
    // Helper methods for card animations
    private func cardScale(for id: Int) -> CGFloat {
        appearingCards.contains(id) ? 1.0 : 0.8
    }
    
    private func cardOpacity(for id: Int) -> Double {
        appearingCards.contains(id) ? 1.0 : 0.0
    }
    
    private func cardRotation(for id: Int) -> Double {
        appearingCards.contains(id) ? 0 : 10
    }
    
    private func perspectiveTilt(for geometry: GeometryProxy) -> Double {
        let frame = geometry.frame(in: .named("scroll"))
        let centerY = UIScreen.main.bounds.height / 2
        let offset = frame.midY - centerY
        let normalizedOffset = offset / centerY
        
        // Apply perspective tilt based on position and velocity
        let tilt = normalizedOffset * AnimationConstants.perspectiveTiltMax
        let velocityTilt = min(max(scrollVelocity * 0.5, -5), 5)
        
        return tilt + velocityTilt
    }
    
    private func velocityOffset(for index: Int) -> CGFloat {
        // Create a wave effect based on velocity
        let velocityFactor = min(max(scrollVelocity, -10), 10)
        let indexDelay = Double(index % 2) * 0.1
        return velocityFactor * CGFloat(sin(indexDelay * .pi))
    }
    
    private func animateCardAppearance(entry: DexEntry, index: Int) {
        withAnimation(
            AnimationConstants.signatureSpring
                .delay(Double(index % 6) * 0.05)
        ) {
            appearingCards.insert(entry.id)
        }
    }
    
    private func updateVisibleRange(index: Int) {
        // Update visible range for prefetching
        let currentStart = visibleRange.lowerBound
        let currentEnd = visibleRange.upperBound
        
        if index < currentStart || index >= currentEnd || visibleRange.isEmpty {
            // Recalculate visible range
            let start = max(0, index - 10)
            let end = min(entries.count, index + 20)
            visibleRange = start..<end
            
            // Prefetch images for the next 2-3 screens
            let prefetchStart = max(0, index - 5)
            let prefetchCount = 30 // About 3 screens worth
            imageCache.prefetchImages(for: entries, startIndex: prefetchStart, count: prefetchCount)
        }
    }
    
    private func handleScrollOffsetChange(_ value: CGFloat) {
        let newVelocity = value - lastScrollOffset
        scrollVelocity = newVelocity * AnimationConstants.scrollVelocityDamping + scrollVelocity * (1 - AnimationConstants.scrollVelocityDamping)
        lastScrollOffset = value
        scrollOffset = value
        
        // Calculate pull progress for refresh animation
        if value > 0 && !isRefreshing {
            pullProgress = min(1.0, value / 150)
            
            if pullProgress >= 1.0 {
                triggerRefresh()
            }
        }
    }
    
    private var emptyStateView: some View {
        DynamicEmptyStateView(type: .noPlants)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding()
    }
    
    // MARK: - Helper Methods
    
    private func triggerRefresh() {
        guard !isRefreshing else { return }
        
        isRefreshing = true
        HapticManager.shared.success()
        
        withAnimation(AnimationConstants.signatureSpring) {
            pullProgress = 1.0
        }
    }
    
    @MainActor
    private func performRefresh() async {
        isRefreshing = true
        onRefresh()
        
        // Simulate minimum refresh time for animation
        try? await Task.sleep(nanoseconds: 800_000_000)
        
        withAnimation(AnimationConstants.smoothSpring) {
            pullProgress = 0
            isRefreshing = false
        }
    }
    
    // MARK: - Selection Mode UI
    
    @ViewBuilder
    private func selectionCheckmark(for id: Int) -> some View {
        ZStack {
            Circle()
                .fill(selectedEntries.contains(id) ? Theme.Colors.primaryGreen : Theme.Colors.systemFill)
                .frame(width: 24, height: 24)
            
            if selectedEntries.contains(id) {
                Image(systemName: "checkmark")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.white)
                    .transition(.scale.combined(with: .opacity))
            }
        }
        .padding(8)
        .animation(AnimationConstants.microSpring, value: selectedEntries.contains(id))
    }
    
    private var selectionToolbar: some View {
        HStack {
            Button {
                withAnimation(AnimationConstants.microSpring) {
                    if selectedEntries.count == entries.count {
                        selectedEntries.removeAll()
                    } else {
                        selectedEntries = Set(entries.map { $0.id })
                    }
                }
                HapticManager.shared.tick()
            } label: {
                Text(selectedEntries.count == entries.count ? "Deselect All" : "Select All")
                    .font(Theme.Typography.caption.weight(.medium))
            }
            
            Spacer()
            
            Text("\(selectedEntries.count) selected")
                .font(Theme.Typography.caption)
                .foregroundColor(Theme.Colors.textSecondary)
            
            Spacer()
            
            Button(role: .destructive) {
                deleteSelectedEntries()
            } label: {
                Label("Delete", systemImage: "trash")
                    .font(Theme.Typography.caption.weight(.medium))
            }
        }
        .padding()
        .background(.regularMaterial)
        .clipShape(Capsule())
        .shadow(radius: 8)
        .padding()
    }
    
    private func deleteSelectedEntries() {
        let entriesToDelete = entries.filter { selectedEntries.contains($0.id) }
        
        HapticManager.shared.error()
        
        withAnimation(AnimationConstants.smoothSpring) {
            for entry in entriesToDelete {
                onDelete?(entry)
            }
            selectedEntries.removeAll()
            isSelectionMode = false
        }
    }
}

// MARK: - Plant Growth Animation

struct PlantGrowthAnimation: View {
    let progress: CGFloat
    
    var body: some View {
        Canvas { context, size in
            let stemHeight = size.height * progress
            let leafSize = min(20, stemHeight * 0.3)
            
            // Draw stem
            var stemPath = Path()
            stemPath.move(to: CGPoint(x: size.width / 2, y: size.height))
            stemPath.addLine(to: CGPoint(x: size.width / 2, y: size.height - stemHeight))
            
            context.stroke(
                stemPath,
                with: .color(Theme.Colors.primaryGreen),
                lineWidth: 3
            )
            
            // Draw leaves
            if progress > 0.3 {
                let leafProgress = (progress - 0.3) / 0.7
                
                // Left leaf
                context.fill(
                    Path(ellipseIn: CGRect(
                        x: size.width / 2 - leafSize - 5,
                        y: size.height - stemHeight * 0.7,
                        width: leafSize,
                        height: leafSize * 0.6
                    )),
                    with: .color(Theme.Colors.primaryGreen.opacity(Double(leafProgress)))
                )
                
                // Right leaf
                context.fill(
                    Path(ellipseIn: CGRect(
                        x: size.width / 2 + 5,
                        y: size.height - stemHeight * 0.5,
                        width: leafSize,
                        height: leafSize * 0.6
                    )),
                    with: .color(Theme.Colors.primaryGreen.opacity(Double(leafProgress)))
                )
            }
        }
    }
}

// MARK: - Scroll Offset Preference Key

struct ScrollOffsetPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

#if DEBUG
struct DexGrid_Previews: PreviewProvider {
    static var previews: some View {
        let previewContainer: ModelContainer = {
            do {
                let config = ModelConfiguration(isStoredInMemoryOnly: true)
                let container = try ModelContainer(for: DexEntry.self, configurations: config)
                
                // Insert sample entries
                for entry in PreviewHelper.sampleDexEntries {
                    container.mainContext.insert(entry)
                }
                
                try container.mainContext.save()
                return container
            } catch {
                fatalError("Failed to create model container for preview: \(error)")
            }
        }()
        
        @State var selectionMode = false
        
        return NavigationStack {
            DexGrid(
                entries: PreviewHelper.sampleDexEntries,
                onRefresh: { print("Refresh triggered") },
                onDelete: nil,
                isSelectionMode: .constant(false)
            )
        }
        .modelContainer(previewContainer)
    }
}
#endif 