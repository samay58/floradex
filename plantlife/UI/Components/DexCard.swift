import SwiftUI
import SwiftData
import CoreMotion

/// Modern, clean DexCard design for the UI refresh
/// Replaces the GameBoy-style aesthetic with a minimal, card-based design
struct DexCard: View {
    let entry: DexEntry
    var namespace: Namespace.ID? = nil // Optional for previews/other uses
    var onDelete: (() -> Void)? = nil

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
                            .fill(cardBackgroundColor.opacity(0.3))
                    )
            }
            .padding(.horizontal, Theme.Metrics.Padding.small)
        }
        .padding(Theme.Metrics.Padding.medium)
        .background(
            // Modern card background with subtle gradient
            RoundedRectangle(cornerRadius: Theme.Metrics.cornerRadiusLarge)
                .fill(
                    LinearGradient(
                        colors: [
                            cardBackgroundColor.opacity(0.15),
                            cardBackgroundColor.opacity(0.05),
                            Color.white.opacity(0.9)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: Theme.Metrics.cornerRadiusLarge)
                        .stroke(
                            LinearGradient(
                                colors: [
                                    cardBackgroundColor.opacity(0.3),
                                    cardBackgroundColor.opacity(0.1)
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            ),
                            lineWidth: 1
                        )
                )
        )
        .shadow(
            color: cardBackgroundColor.opacity(0.2),
            radius: 12,
            x: 0,
            y: 6
        )
        .contextMenu {
            Button(role: .destructive) { 
                // Simple haptic feedback
                if AppSettings.shared.hapticsLevel != .off {
                    let hapticGenerator = UIImpactFeedbackGenerator(style: .rigid)
                    hapticGenerator.impactOccurred()
                }
                SoundManager.shared.playSound(.trash)
                onDelete?()
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
        .onTapGesture {
            // Light haptic feedback on tap
            if AppSettings.shared.hapticsLevel != .off {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
            }
        }
    }

    // MARK: - Plant Image Section with Organic Border
    @ViewBuilder
    private var plantImageSection: some View {
        Group {
            if let spriteData = entry.sprite, let uiImage = UIImage(data: spriteData) {
                let _ = print("[DexCard] Displaying sprite for entry ID: \(entry.id), sprite size: \(spriteData.count)")
                Image(uiImage: uiImage)
                    .resizable()
                    .interpolation(.none) // Keep pixel art crisp
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 80, height: 80) // Perfect sprite size
                    .if(namespace != nil) { view in
                        view.matchedGeometryEffect(id: "sprite-\(entry.id)", in: namespace!)
                    }
            } else if let snapshotData = entry.snapshot, let uiImage = UIImage(data: snapshotData) {
                let _ = print("[DexCard] No sprite for entry ID: \(entry.id), falling back to snapshot")
                Image(uiImage: uiImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 80, height: 80)
                    .clipped()
            } else if entry.spriteGenerationFailed {
                let _ = print("[DexCard] Sprite generation failed for entry ID: \(entry.id)")
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
                let _ = print("[DexCard] Sprite still generating for entry ID: \(entry.id)")
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
            // Gorgeous organic background gradient
            RadialGradient(
                colors: [
                    cardBackgroundColor.opacity(0.3),
                    cardBackgroundColor.opacity(0.1),
                    Color.clear
                ],
                center: .center,
                startRadius: 20,
                endRadius: 60
            )
        )
        .overlay(
            // Beautiful organic border with nature-inspired design
            ZStack {
                // Outer organic ring
                Circle()
                    .stroke(
                        LinearGradient(
                            colors: [
                                Theme.Colors.primaryGreen.opacity(0.6),
                                cardBackgroundColor.opacity(0.8),
                                Theme.Colors.primaryGreen.opacity(0.4)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 2
                    )
                    .frame(width: 90, height: 90)
                
                // Inner subtle highlight
                Circle()
                    .stroke(
                        Color.white.opacity(0.3),
                        lineWidth: 1
                    )
                    .frame(width: 86, height: 86)
                
                // Organic texture dots (like botanical illustration)
                ForEach(0..<8, id: \.self) { i in
                    Circle()
                        .fill(Theme.Colors.primaryGreen.opacity(0.2))
                        .frame(width: 2, height: 2)
                        .offset(
                            x: 42 * cos(Double(i) * .pi / 4),
                            y: 42 * sin(Double(i) * .pi / 4)
                        )
                }
            }
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
        if let firstTag = entry.tags.first {
            return firstTag.capitalized
        }
        return "Plant"
    }
}

// Legacy GameBoy-style components removed in favor of modern design

#if DEBUG
@MainActor
struct DexCard_Previews: PreviewProvider {
    static var previews: some View {
        let container: ModelContainer = {
            let cfg = ModelConfiguration(isStoredInMemoryOnly: true)
            return try! ModelContainer(for: DexEntry.self, configurations: cfg)
        }()
        let sample = PreviewHelper.sampleDexEntry
        if let data = UIImage(systemName: "leaf")?.pngData() { 
            sample.sprite = data 
            sample.tags = ["Succulent"]
        }
        container.mainContext.insert(sample)
        
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