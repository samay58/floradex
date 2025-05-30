import SwiftUI
import SwiftData
import CoreMotion
import Foundation

/// Living DexCard with organic motion and intelligent animations
/// Features breathing sprites, idle oscillation, and contextual feedback
struct DexCard: View {
    init(entry: DexEntry, namespace: Namespace.ID? = nil, onDelete: (() -> Void)? = nil) {
        self.entry = entry
        self.namespace = namespace
        self.onDelete = onDelete
        
        // Set up query for species details
        let latinName = entry.latinName
        self._speciesDetails = Query(filter: #Predicate<SpeciesDetails> { $0.latinName == latinName })
    }
    let entry: DexEntry
    var namespace: Namespace.ID? = nil // Optional for previews/other uses
    var onDelete: (() -> Void)? = nil
    
    // Image cache manager
    @StateObject private var imageCache = ImageCacheManager.shared
    
    // Query for species details to get better tag info
    @Query private var speciesDetails: [SpeciesDetails]
    
    // Animation states
    @State private var rotation: Double = 0
    @State private var isPressed = false
    @State private var showShimmer = false
    @State private var dragOffset: CGSize = .zero
    @State private var isDragging = false
    @State private var isNewCard = false
    
    // Randomized animation parameters for organic feel
    private let rotationPeriod = Double.random(in: 4...6)
    private let breathingDelay = Double.random(in: 0...1.5)
    private let breathingScale = Double.random(in: 0.02...0.04) // 2-4% variation

    var body: some View {
        VStack(alignment: .center, spacing: Theme.Metrics.Padding.small) {
            // Beautiful Plant Sprite Section
            plantImageSection

            // Content Section
            VStack(alignment: .center, spacing: Theme.Metrics.Padding.micro) {
                Text(entry.latinName)
                    .font(Theme.Typography.subheadline.weight(.semibold))
                    .foregroundColor(Theme.Colors.textPrimary)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)

                Text(categoryText)
                    .font(Theme.Typography.caption2)
                    .foregroundColor(Theme.Colors.textSecondary)
                    .lineLimit(1)
                    .padding(.horizontal, Theme.Metrics.Padding.extraSmall)
                    .padding(.vertical, 2)
                    .background(
                        Capsule()
                            .fill(Theme.Colors.systemFill)
                    )
            }
            .padding(.horizontal, Theme.Metrics.Padding.small)
        }
        .padding(Theme.Metrics.Padding.medium)
        .scaleEffect(isPressed ? 0.92 : (isDragging ? 1.05 : 1.0))
        .rotationEffect(.degrees(rotation + (isDragging ? dragOffset.width * 0.05 : 0)))
        .offset(dragOffset)
        .background(
            // Modern card background with better contrast
            RoundedRectangle(cornerRadius: Theme.Metrics.cornerRadiusLarge)
                .fill(Theme.Colors.cardBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: Theme.Metrics.cornerRadiusLarge)
                        .stroke(
                            Theme.Colors.systemFill,
                            lineWidth: 1
                        )
                )
        )
        .shadow(
            color: Color.black.opacity(isDragging ? 0.15 : (isPressed ? 0.12 : 0.08)),
            radius: isDragging ? 20 : (isPressed ? 12 : 8),
            x: 0,
            y: isDragging ? 10 : (isPressed ? 6 : 4)
        )
        .overlay(
            // Shimmer effect for new cards
            showShimmer ? ShimmerOverlay() : nil
        )
        .contextMenu {
            Button(role: .destructive) { 
                // Simple haptic feedback
                if AppSettings.shared.hapticsLevel != .off {
                    let hapticGenerator = UIImpactFeedbackGenerator(style: .rigid)
                    hapticGenerator.impactOccurred()
                }
                // SoundManager.shared.playSound(.trash) // Sound file not available
                onDelete?()
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
        // Removed onTapGesture to allow parent view to handle navigation
        .onLongPressGesture(minimumDuration: 0.1, maximumDistance: .infinity, pressing: { pressing in
            withAnimation(AnimationConstants.microSpring) {
                isPressed = pressing
            }
            if pressing {
                HapticManager.shared.tick()
                // Scale up shadow on long press
                withAnimation(AnimationConstants.smoothSpring) {
                    // Shadow handled in modifier
                }
            }
        }, perform: {})
        // Drag gesture disabled to fix scrolling issues
        // .gesture(
        //     DragGesture()
        //         .onChanged { value in
        //             if !isDragging {
        //                 withAnimation(AnimationConstants.quickSpring) {
        //                     isDragging = true
        //                 }
        //             }
        //             dragOffset = value.translation
        //         }
        //         .onEnded { _ in
        //             withAnimation(AnimationConstants.signatureSpring) {
        //                 dragOffset = .zero
        //                 isDragging = false
        //             }
        //         }
        // )
        .onAppear {
            // Start idle animation with a slight delay for performance
            DispatchQueue.main.asyncAfter(deadline: .now() + Double.random(in: 0...0.5)) {
                startIdleAnimation()
            }
            
            // Show celebration effect for new cards
            if entry.createdAt.timeIntervalSinceNow > -5 {
                isNewCard = true
                showShimmerEffect()
            }
        }
    }

    // MARK: - Plant Image Section with Organic Border
    @ViewBuilder
    private var plantImageSection: some View {
        Group {
            if let cachedImage = imageCache.image(for: entry) {
                // Use cached image
                Image(uiImage: cachedImage)
                    .resizable()
                    .interpolation(.none) // Keep pixel art crisp
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 80, height: 80) // Perfect sprite size
                    .clipShape(Circle()) // Ensure sprite fits in circle
                    .if(namespace != nil) { view in
                        view.matchedGeometryEffect(id: "sprite-\(entry.id)", in: namespace!)
                    }
                    .breathingEffect(
                        minScale: 1.0 - breathingScale,
                        maxScale: 1.0 + breathingScale
                    )
            } else if let snapshotData = entry.snapshot, let uiImage = UIImage(data: snapshotData) {
                // Snapshot fallback
                Image(uiImage: uiImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 80, height: 80)
                    .clipped()
            } else if entry.spriteGenerationFailed {
                // Sprite generation failed
                VStack(spacing: 4) {
                    Image(systemName: "leaf.circle.fill")
                        .font(.system(size: 32))
                        .foregroundColor(Theme.Colors.primaryGreen.opacity(0.6))
                    Text("Retry")
                        .font(Theme.Typography.caption2)
                        .foregroundColor(Theme.Colors.textSecondary)
                }
                .frame(width: 80, height: 80)
            } else {
                // Sprite generating
                VStack(spacing: 4) {
                    ProgressView()
                        .scaleEffect(0.8)
                        .tint(Theme.Colors.primaryGreen)
                    Text("Generating...")
                        .font(Theme.Typography.caption2)
                        .foregroundColor(Theme.Colors.textSecondary)
                }
                .frame(width: 80, height: 80)
            }
        }
        .background(
            // Subtle background for sprite
            Circle()
                .fill(Theme.Colors.systemFill.opacity(0.5))
                .frame(width: 90, height: 90)
        )
        .overlay(
            // Simple clean border
            Circle()
                .stroke(Theme.Colors.systemFill, lineWidth: 1)
                .frame(width: 90, height: 90)
        )
        .frame(width: 100, height: 100) // Container size
        .shadow(color: cardBackgroundColor.opacity(0.3), radius: 8, x: 0, y: 4)
    }

    // MARK: - Computed Properties
    private var cardBackgroundColor: Color {
        // Simple background color logic based on plant type
        if entry.tags.contains("Succulent") || entry.tags.contains("succulent") {
            return Theme.Colors.succulentCardBackground
        } else if entry.tags.contains("Flower") || entry.tags.contains("flower") {
            return Theme.Colors.flowerCardBackground
        } else if entry.tags.contains("Tree") || entry.tags.contains("tree") {
            return Theme.Colors.treeCardBackground
        }
        return Theme.Colors.cardBackground // Use dark-mode-aware default
    }

    private var categoryText: String {
        // Try to find species details for this entry
        let details = speciesDetails.first { $0.latinName == entry.latinName }
        
        // Use TagGenerator to get the best display tag
        if !entry.tags.isEmpty {
            return TagGenerator.primaryTag(from: entry.tags, for: details)
        }
        
        // If no tags, try common name from details
        if let commonName = details?.commonName,
           !commonName.isEmpty,
           commonName.count <= 15 {
            return commonName
        }
        
        // Fallback to simplified latin name (just genus)
        let latinComponents = entry.latinName.split(separator: " ")
        if latinComponents.count >= 2 {
            return String(latinComponents[0])
        }
        
        // Final fallback
        return "Plant"
    }
    
    // MARK: - Animation Methods
    
    private func startIdleAnimation() {
        withAnimation(
            Animation.easeInOut(duration: rotationPeriod)
                .repeatForever(autoreverses: true)
        ) {
            rotation = AnimationConstants.cardIdleRotation
        }
    }
    
    // Breathing is now handled by the breathingEffect modifier
    
    private func showShimmerEffect() {
        // Delay shimmer slightly for smooth entrance
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            withAnimation(AnimationConstants.smoothSpring) {
                showShimmer = true
            }
            
            // Longer duration for new card celebration
            DispatchQueue.main.asyncAfter(deadline: .now() + 3.5) {
                withAnimation(AnimationConstants.smoothSpring) {
                    showShimmer = false
                    isNewCard = false
                }
            }
        }
    }
}

// MARK: - Shimmer Overlay

struct ShimmerOverlay: View {
    @State private var phase: CGFloat = -1.0
    
    var body: some View {
        GeometryReader { geometry in
            LinearGradient(
                gradient: Gradient(colors: [
                    Color.clear,
                    Color.white.opacity(0.3),
                    Color.clear
                ]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .frame(width: geometry.size.width * 2)
            .offset(x: phase * geometry.size.width)
            .animation(
                Animation.linear(duration: 1.8)
                    .repeatCount(1, autoreverses: false),
                value: phase
            )
            .onAppear {
                phase = 1.0
            }
        }
        .mask(
            RoundedRectangle(cornerRadius: Theme.Metrics.cornerRadiusLarge)
        )
    }
}

// Legacy GameBoy-style components removed in favor of modern design

#if DEBUG
@MainActor
struct DexCard_Previews: PreviewProvider {
    static var previews: some View {
        let container: ModelContainer = {
            let cfg = ModelConfiguration(isStoredInMemoryOnly: true)
            return try! ModelContainer(for: DexEntry.self, SpeciesDetails.self, configurations: cfg)
        }()
        let sample = PreviewHelper.sampleDexEntry
        if let data = UIImage(systemName: "leaf")?.pngData() { 
            sample.sprite = data 
            // Keep the meaningful tags from PreviewHelper
        }
        container.mainContext.insert(sample)
        
        // Add species details for better tag display
        let details = PreviewHelper.sampleSpeciesDetails
        container.mainContext.insert(details)
        
        return VStack(spacing: 20) {
            Text("Modern DexCard")
                .font(Theme.Typography.title2)
            
            HStack(spacing: 16) {
                DexCard(entry: sample, namespace: nil)
                    .frame(width: 160, height: 180)
                
                DexCard(entry: sample, namespace: nil)
                    .frame(width: 160, height: 180)
            }
        }
        .modelContainer(container)
        .padding()
        .background(Theme.Colors.systemBackground)
        .previewLayout(.sizeThatFits)
    }
}
#endif 