import SwiftUI

struct AnimationConstants {
    // MARK: - Signature Animation Timing
    static let signatureSpring = Animation.spring(response: 0.55, dampingFraction: 0.825)
    static let quickSpring = Animation.spring(response: 0.35, dampingFraction: 0.75)
    static let smoothSpring = Animation.interpolatingSpring(stiffness: 280, damping: 22)
    static let microSpring = Animation.spring(response: 0.25, dampingFraction: 0.8)
    static let breathingAnimation = Animation.easeInOut(duration: 2.5).repeatForever(autoreverses: true)
    
    // MARK: - Interaction Pattern Timings
    static let tapScale = 0.97
    static let tapBounceScale = 1.02
    static let longPressScale = 0.95
    static let dragRotationMax = 15.0
    
    // MARK: - State Transition Durations
    static let imageSelectionDuration = 0.8
    static let buttonStateDuration = 0.4
    static let navigationTransitionDuration = 0.3
    static let skeletonShimmerDuration = 1.8
    
    // MARK: - Haptic Feedback Timing
    static let hapticDelay = 0.04
    
    // MARK: - Physics Constants
    static let scrollVelocityDamping = 0.9
    static let cardIdleRotation = 0.5
    static let parallaxFactor = 0.5
    static let perspectiveTiltMax = 2.0
}

// MARK: - Custom Animation Modifiers

struct BreathingModifier: ViewModifier {
    @State private var scale: CGFloat = 1.0
    let minScale: CGFloat
    let maxScale: CGFloat
    
    init(minScale: CGFloat = 0.985, maxScale: CGFloat = 1.015) {
        self.minScale = minScale
        self.maxScale = maxScale
    }
    
    func body(content: Content) -> some View {
        content
            .scaleEffect(scale)
            .onAppear {
                withAnimation(AnimationConstants.breathingAnimation) {
                    scale = maxScale
                }
            }
    }
}

struct MagneticTapModifier: ViewModifier {
    @State private var isPressed = false
    let onTap: () -> Void
    
    func body(content: Content) -> some View {
        content
            .scaleEffect(isPressed ? 0.96 : 1.0)
            .animation(AnimationConstants.microSpring, value: isPressed)
            .onTapGesture {
                onTap()
            }
            .onLongPressGesture(minimumDuration: 0, maximumDistance: .infinity, pressing: { pressing in
                isPressed = pressing
            }, perform: {})
    }
}

struct ShimmerModifier: ViewModifier {
    @State private var phase: CGFloat = 0
    let duration: Double
    
    init(duration: Double = AnimationConstants.skeletonShimmerDuration) {
        self.duration = duration
    }
    
    func body(content: Content) -> some View {
        content
            .overlay(
                GeometryReader { geometry in
                    LinearGradient(
                        gradient: Gradient(colors: [
                            Color.white.opacity(0),
                            Color.white.opacity(0.3),
                            Color.white.opacity(0)
                        ]),
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    .frame(width: geometry.size.width * 0.3)
                    .offset(x: geometry.size.width * (phase - 0.3))
                    .animation(
                        Animation.linear(duration: duration)
                            .repeatForever(autoreverses: false),
                        value: phase
                    )
                }
                .mask(content)
            )
            .onAppear {
                phase = 1.3
            }
    }
}

struct SquishAnimationModifier: ViewModifier {
    @State private var scale: CGFloat = 1.0
    let onTap: () -> Void
    
    func body(content: Content) -> some View {
        content
            .scaleEffect(scale)
            .onTapGesture {
                withAnimation(AnimationConstants.microSpring) {
                    scale = 0.9
                }
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    withAnimation(AnimationConstants.quickSpring) {
                        scale = 1.1
                    }
                    
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        withAnimation(AnimationConstants.quickSpring) {
                            scale = 1.0
                        }
                        onTap()
                    }
                }
            }
    }
}

// MARK: - View Extensions

extension View {
    func breathingEffect(minScale: CGFloat = 0.985, maxScale: CGFloat = 1.015) -> some View {
        modifier(BreathingModifier(minScale: minScale, maxScale: maxScale))
    }
    
    func magneticTap(action: @escaping () -> Void) -> some View {
        modifier(MagneticTapModifier(onTap: action))
    }
    
    func shimmerEffect(duration: Double = AnimationConstants.skeletonShimmerDuration) -> some View {
        modifier(ShimmerModifier(duration: duration))
    }
    
    func squishAnimation(action: @escaping () -> Void) -> some View {
        modifier(SquishAnimationModifier(onTap: action))
    }
}

// MARK: - Haptic Feedback Manager

class HapticManager {
    static let shared = HapticManager()
    
    private let impact = UIImpactFeedbackGenerator()
    private let selection = UISelectionFeedbackGenerator()
    private let notification = UINotificationFeedbackGenerator()
    
    private init() {
        impact.prepare()
        selection.prepare()
        notification.prepare()
    }
    
    func imageSelection() {
        impact.impactOccurred(intensity: 0.7)
    }
    
    func buttonTap() {
        impact.impactOccurred(intensity: 0.5)
    }
    
    func success() {
        notification.notificationOccurred(.success)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.impact.impactOccurred(intensity: 0.3)
        }
    }
    
    func error() {
        notification.notificationOccurred(.error)
    }
    
    func tick() {
        selection.selectionChanged()
    }
    
    func cameraCapture() {
        impact.impactOccurred(intensity: 0.8)
    }
}