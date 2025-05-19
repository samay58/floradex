import SwiftUI
import SwiftData
import UIKit // For haptic feedback
import CoreMotion // ADD: for motion-based parallax

struct DexCard: View {
    let entry: DexEntry
    var namespace: Namespace.ID? = nil // Optional for previews/other uses
    var onDelete: (() -> Void)? = nil
    // We might need SpeciesDetails later if commonName or other info is directly on the card
    // let speciesDetails: SpeciesDetails? 

    private let corner: CGFloat = 20
    private let idFont = Font.pressStart2P(size: 10)

    // Animation states
    @State private var hasAppeared = false
    @State private var flipped = false
    @State private var animateBackground = false // ADD: background animation trigger
    @StateObject private var motion = MotionManager() // ADD: motion manager for parallax
    @State private var jump = false // ADD: tap jump state

    // Lottie animation states
    @State private var playLottieSpawn = false
    @State private var didPlayLottieForThisSprite = false

    var body: some View {
        GeometryReader { geo in
            let side = geo.size.width
            ZStack(alignment: .topLeading) {
                // Background (extracted gradient to keep expression simple for compiler)
                RoundedRectangle(cornerRadius: corner)
                    .fill(dynamicGradient())
                    .animation(.linear(duration: 6).repeatForever(autoreverses: true), value: animateBackground) // ADD: animate gradient
                    .overlay( // ADD: faint noise texture
                        Image("noise")
                            .resizable()
                            .scaledToFill()
                            .clipped()
                            .opacity(0.06)
                            .blendMode(.overlay)
                    )

                // Sprite (center)
                spriteLayer(side: side)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)

                // ID label top-left
                Text(String(format: "#%03d", entry.id))
                    .font(idFont)
                    .foregroundColor(.white)
                    .shadow(radius: 1)
                    .padding(6)
                // ADD: bottom translucent nameplate
                VStack {
                    Spacer()
                    Text(entry.latinName)
                        .font(idFont)
                        .foregroundColor(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(Color.black.opacity(0.25))
                        .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color.white.opacity(0.7), lineWidth: 1))
                        .cornerRadius(4)
                        .padding(6)
                }
            }
            // 3D parallax + flip
            .rotation3DEffect(.degrees(motion.pitch * 10), axis: (x: 1, y: 0, z: 0)) // ADD: parallax X
            .rotation3DEffect(.degrees(motion.roll * -10), axis: (x: 0, y: 1, z: 0)) // ADD: parallax Y
            .rotation3DEffect(
                .degrees(flipped ? 0 : -90),
                axis: (x: 0, y: 1, z: 0),
                perspective: 0.6
            )
            .scaleEffect(jump ? 1.05 : 1.0) // ADD: jump effect
        }
        .aspectRatio(1, contentMode: .fit)
        .cornerRadius(corner)
        .shadow(color: Theme.Colors.dexShadow, radius: 4, x: 0, y: 2)
        .contextMenu {
            Button(role: .destructive) { 
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
        .simultaneousGesture(
            TapGesture().onEnded {
                if AppSettings.shared.hapticsLevel != .off { // Check haptics settings
                    UIImpactFeedbackGenerator(style: .soft).impactOccurred()
                }
                withAnimation(.spring(response: 0.3, dampingFraction: 0.4)) {
                    jump = true
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    withAnimation(.spring()) { jump = false }
                }
            }
        )
        .onAppear {
            guard !hasAppeared else { return }
            hasAppeared = true
            animateBackground.toggle() // ADD: start gradient animation

            // Initial check for Lottie spawn if sprite is already present on first appear
            if entry.sprite != nil && !didPlayLottieForThisSprite {
                playLottieSpawn = true
                didPlayLottieForThisSprite = true // Mark as attempted/played for this instance
            }

            withAnimation(.spring(response: 0.6, dampingFraction: 0.75, blendDuration: 0.2)) {
                flipped = true
            }
            // Light haptic once the card settles
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                if AppSettings.shared.hapticsLevel != .off { // Check haptics settings
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                }
            }
        }
        .onChange(of: entry.sprite) { oldSprite, newSprite in // Monitor sprite changes
            if newSprite != nil && !didPlayLottieForThisSprite {
                playLottieSpawn = true
                didPlayLottieForThisSprite = true // Mark as attempted/played for this sprite version
            } else if newSprite == nil {
                didPlayLottieForThisSprite = false // Reset if sprite is removed, for next time
            }
        }
    }

    // MARK: - Helper
    private func dynamicGradient() -> LinearGradient {
        let baseColor = Theme.Colors.accent(for: entry.latinName)
        return LinearGradient(
            colors: [baseColor.opacity(0.5), baseColor.opacity(0.9), baseColor.opacity(0.5)],
            startPoint: animateBackground ? .topLeading : .bottomTrailing,
            endPoint: animateBackground ? .bottomTrailing : .topLeading
        )
    }

    // MARK: - Sub-views
    @ViewBuilder
    private func spriteLayer(side: CGFloat) -> some View {
        if let spriteData = entry.sprite, let uiImage = UIImage(data: spriteData) {
            ZStack {
                Image(uiImage: uiImage)
                    .resizable()
                    .interpolation(.none)
                    .aspectRatio(contentMode: .fit)
                    .frame(width: side * 0.7, height: side * 0.7)
                    .shadow(color: Theme.Colors.accent(for: entry.latinName).opacity(0.9), radius: 12)
                    .if(namespace != nil) { view in
                        view.matchedGeometryEffect(id: "sprite-\(entry.id)", in: namespace!)
                    }
#if canImport(Lottie)
                    .opacity(playLottieSpawn ? 0 : 1)
#endif

#if canImport(Lottie)
                if playLottieSpawn {
                    LottieView(animationName: "spriteSpawnAnimation",
                               loopMode: .playOnce,
                               play: $playLottieSpawn)
                        .frame(width: side * 0.8, height: side * 0.8)
                        .transition(.opacity.animation(.easeIn(duration: 0.2)))
                }
#endif
            }
        } else if entry.spriteGenerationFailed {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: side * 0.35))
                .foregroundColor(.yellow)
        } else {
            ProgressView()
                .scaleEffect(1.2)
        }
    }
}

#if DEBUG
@MainActor
struct DexCard_Previews: PreviewProvider {
    static var previews: some View {
        let container: ModelContainer = {
            let cfg = ModelConfiguration(isStoredInMemoryOnly: true)
            return try! ModelContainer(for: DexEntry.self, configurations: cfg)
        }()
        let sample = PreviewHelper.sampleDexEntry
        if let data = UIImage(systemName: "leaf")?.pngData() { sample.sprite = data }
        container.mainContext.insert(sample)
        // For preview, namespace can be nil or a dummy one if needed for layout
        // @Namespace static var previewNamespace // If needed for preview
        return DexCard(entry: sample, namespace: nil)
            .modelContainer(container)
            .padding()
            .previewLayout(.sizeThatFits)
    }
}
#endif 

// ADD: MotionManager for device parallax
private final class MotionManager: ObservableObject {
    @Published var pitch: Double = 0
    @Published var roll: Double = 0

    private let manager = CMMotionManager()

    init() {
        guard manager.isDeviceMotionAvailable else { return }
        manager.deviceMotionUpdateInterval = 1/60
        manager.startDeviceMotionUpdates(to: OperationQueue.main) { [weak self] data, _ in
            guard let self = self, let data = data else { return }
            self.pitch = data.attitude.pitch
            self.roll = data.attitude.roll
        }
    }

    deinit { manager.stopDeviceMotionUpdates() }
} 

// Helper to conditionally apply modifiers
extension View {
    @ViewBuilder
    func `if`<Content: View>(_ condition: Bool, transform: (Self) -> Content) -> some View {
        if condition {
            transform(self)
        } else {
            self
        }
    }
} 