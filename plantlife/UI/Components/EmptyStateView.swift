import SwiftUI
import CoreMotion
import Foundation

// MARK: - Dynamic Empty State Views

struct DynamicEmptyStateView: View {
    let type: EmptyStateType
    @State private var animationPhase: CGFloat = 0
    @State private var motionOffset: CGSize = .zero
    @StateObject private var motionManager = MotionManager()
    
    enum EmptyStateType {
        case noPlants
        case noSearchResults
        case cameraEmpty
        case networkError
        
        var icon: String {
            switch self {
            case .noPlants: return "leaf.circle"
            case .noSearchResults: return "magnifyingglass.circle"
            case .cameraEmpty: return "camera.circle"
            case .networkError: return "wifi.exclamationmark"
            }
        }
        
        var title: String {
            switch self {
            case .noPlants: return "Start Your Collection"
            case .noSearchResults: return "No Plants Found"
            case .cameraEmpty: return "Ready to Identify"
            case .networkError: return "Connection Issue"
            }
        }
        
        var message: String {
            switch self {
            case .noPlants: return "Take a photo to add your first plant"
            case .noSearchResults: return "Try a different search term"
            case .cameraEmpty: return "Point your camera at a plant"
            case .networkError: return "Check your internet connection"
            }
        }
    }
    
    var body: some View {
        VStack(spacing: Theme.Metrics.Padding.large) {
            // Dynamic illustration with parallax
            ZStack {
                // Background elements with deeper parallax
                ForEach(0..<3, id: \.self) { index in
                    FloatingLeaf(
                        delay: Double(index) * 0.3,
                        offset: CGSize(
                            width: motionOffset.width * (0.5 + Double(index) * 0.2),
                            height: motionOffset.height * (0.5 + Double(index) * 0.2)
                        )
                    )
                }
                
                // Main icon with subtle animation
                Image(systemName: type.icon)
                    .font(.system(size: 80, weight: .light))
                    .foregroundColor(Theme.Colors.iconSecondary)
                    .scaleEffect(1.0 + Foundation.sin(animationPhase) * 0.05)
                    .rotationEffect(.degrees(Foundation.sin(animationPhase * 0.5) * 2))
                    .offset(motionOffset)
            }
            .frame(height: 150)
            .onAppear {
                withAnimation(Animation.easeInOut(duration: 3.0).repeatForever(autoreverses: true)) {
                    animationPhase = .pi * 2
                }
            }
            
            // Text content
            VStack(spacing: Theme.Metrics.Padding.small) {
                Text(type.title)
                    .font(Theme.Typography.title2)
                    .foregroundColor(Theme.Colors.textPrimary)
                
                Text(type.message)
                    .font(Theme.Typography.body)
                    .foregroundColor(Theme.Colors.textSecondary)
                    .multilineTextAlignment(.center)
            }
            
            // Interactive hint
            if type == .noPlants {
                GhostCardGrid()
                    .padding(.top, Theme.Metrics.Padding.large)
            }
        }
        .padding()
        .onReceive(motionManager.$motion) { motion in
            withAnimation(AnimationConstants.smoothSpring) {
                motionOffset = CGSize(
                    width: motion.x * 20,
                    height: -motion.y * 20
                )
            }
        }
    }
}

// MARK: - Ghost Card Grid

struct GhostCardGrid: View {
    @State private var pulsePhase: [Bool] = [false, false, false, false]
    
    let columns = [
        GridItem(.flexible()),
        GridItem(.flexible())
    ]
    
    var body: some View {
        LazyVGrid(columns: columns, spacing: Theme.Metrics.Padding.medium) {
            ForEach(0..<4, id: \.self) { index in
                GhostCard(isPulsing: pulsePhase[index])
                    .onAppear {
                        DispatchQueue.main.asyncAfter(deadline: .now() + Double(index) * 0.2) {
                            withAnimation(AnimationConstants.breathingAnimation) {
                                pulsePhase[index] = true
                            }
                        }
                    }
            }
        }
    }
}

struct GhostCard: View {
    let isPulsing: Bool
    
    var body: some View {
        VStack(spacing: Theme.Metrics.Padding.small) {
            RoundedRectangle(cornerRadius: Theme.Metrics.cornerRadiusSmall)
                .fill(Theme.Colors.systemFill.opacity(0.3))
                .aspectRatio(1, contentMode: .fit)
                .overlay(
                    Image(systemName: "plus")
                        .font(.system(size: 30, weight: .light))
                        .foregroundColor(Theme.Colors.iconSecondary.opacity(0.5))
                )
            
            RoundedRectangle(cornerRadius: 4)
                .fill(Theme.Colors.systemFill.opacity(0.2))
                .frame(height: 14)
            
            RoundedRectangle(cornerRadius: 4)
                .fill(Theme.Colors.systemFill.opacity(0.15))
                .frame(height: 10)
                .padding(.horizontal, Theme.Metrics.Padding.small)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: Theme.Metrics.cornerRadiusMedium)
                .strokeBorder(
                    Theme.Colors.systemFill.opacity(isPulsing ? 0.5 : 0.3),
                    lineWidth: 2
                )
        )
        .scaleEffect(isPulsing ? 1.0 : 0.98)
        .opacity(isPulsing ? 1.0 : 0.8)
    }
}

// MARK: - Floating Elements

struct FloatingLeaf: View {
    let delay: Double
    let offset: CGSize
    @State private var rotation: Double = 0
    @State private var yOffset: CGFloat = 0
    
    var body: some View {
        Image(systemName: "leaf.fill")
            .font(.system(size: 30))
            .foregroundColor(Theme.Colors.primaryGreen.opacity(0.1))
            .rotationEffect(.degrees(rotation))
            .offset(x: offset.width + Foundation.sin(rotation * .pi / 180) * 20,
                   y: offset.height + yOffset)
            .onAppear {
                withAnimation(
                    Animation.easeInOut(duration: 4.0)
                        .repeatForever(autoreverses: true)
                        .delay(delay)
                ) {
                    rotation = 360
                    yOffset = 30
                }
            }
    }
}

// MARK: - Interactive Camera Empty State

struct CameraEmptyStateView: View {
    @State private var showDemo = false
    @State private var frameOpacity: [Double] = [0.3, 0.3, 0.3, 0.3]
    
    var body: some View {
        VStack(spacing: Theme.Metrics.Padding.large) {
            // Camera viewfinder illustration
            ZStack {
                RoundedRectangle(cornerRadius: Theme.Metrics.cornerRadiusMedium)
                    .strokeBorder(Theme.Colors.systemFill, lineWidth: 2)
                    .aspectRatio(4/3, contentMode: .fit)
                    .frame(maxWidth: 300)
                
                // Corner brackets
                ForEach(0..<4, id: \.self) { index in
                    CameraFrameCorner(position: cornerPosition(for: index))
                        .opacity(frameOpacity[index])
                }
                
                if showDemo {
                    // Demo plant silhouette
                    Image(systemName: "leaf.fill")
                        .font(.system(size: 60))
                        .foregroundColor(Theme.Colors.primaryGreen.opacity(0.5))
                        .transition(.scale.combined(with: .opacity))
                }
            }
            .onTapGesture {
                showDemo.toggle()
                if showDemo {
                    animateFrameDemo()
                }
            }
            
            VStack(spacing: Theme.Metrics.Padding.small) {
                Text("Frame Your Plant")
                    .font(Theme.Typography.headline)
                    .foregroundColor(Theme.Colors.textPrimary)
                
                Text("Tap to see ideal framing")
                    .font(Theme.Typography.caption)
                    .foregroundColor(Theme.Colors.textSecondary)
            }
        }
    }
    
    private func cornerPosition(for index: Int) -> UnitPoint {
        switch index {
        case 0: return .topLeading
        case 1: return .topTrailing
        case 2: return .bottomLeading
        case 3: return .bottomTrailing
        default: return .center
        }
    }
    
    private func animateFrameDemo() {
        for i in 0..<4 {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * 0.1) {
                withAnimation(AnimationConstants.quickSpring) {
                    frameOpacity[i] = 1.0
                }
                
                HapticManager.shared.tick()
            }
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            withAnimation(AnimationConstants.smoothSpring) {
                frameOpacity = [0.3, 0.3, 0.3, 0.3]
                showDemo = false
            }
        }
    }
}

struct CameraFrameCorner: View {
    let position: UnitPoint
    
    var body: some View {
        Path { path in
            let size: CGFloat = 30
            
            switch position {
            case .topLeading:
                path.move(to: CGPoint(x: 0, y: size))
                path.addLine(to: CGPoint(x: 0, y: 0))
                path.addLine(to: CGPoint(x: size, y: 0))
            case .topTrailing:
                path.move(to: CGPoint(x: -size, y: 0))
                path.addLine(to: CGPoint(x: 0, y: 0))
                path.addLine(to: CGPoint(x: 0, y: size))
            case .bottomLeading:
                path.move(to: CGPoint(x: 0, y: -size))
                path.addLine(to: CGPoint(x: 0, y: 0))
                path.addLine(to: CGPoint(x: size, y: 0))
            case .bottomTrailing:
                path.move(to: CGPoint(x: -size, y: 0))
                path.addLine(to: CGPoint(x: 0, y: 0))
                path.addLine(to: CGPoint(x: 0, y: -size))
            default:
                break
            }
        }
        .stroke(Theme.Colors.primaryGreen, lineWidth: 3)
        .frame(width: 300, height: 225)
        .position(
            x: position == .topLeading || position == .bottomLeading ? 15 : 285,
            y: position == .topLeading || position == .topTrailing ? 15 : 210
        )
    }
}

// MARK: - Motion Manager

class MotionManager: ObservableObject {
    @Published var motion: CGPoint = .zero
    private var motionManager = CMMotionManager()
    
    init() {
        startMotionUpdates()
    }
    
    private func startMotionUpdates() {
        guard motionManager.isDeviceMotionAvailable else { return }
        
        motionManager.deviceMotionUpdateInterval = 0.1
        motionManager.startDeviceMotionUpdates(to: .main) { [weak self] motion, error in
            guard let motion = motion else { return }
            
            // Limit rotation to subtle effect (2-3 degrees max)
            let maxRotation: Double = 3.0 * .pi / 180.0
            let x = max(-maxRotation, min(maxRotation, motion.attitude.roll))
            let y = max(-maxRotation, min(maxRotation, motion.attitude.pitch))
            
            self?.motion = CGPoint(x: x, y: y)
        }
    }
    
    deinit {
        motionManager.stopDeviceMotionUpdates()
    }
}

#if DEBUG
struct EmptyStateView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            DynamicEmptyStateView(type: .noPlants)
                .previewDisplayName("No Plants")
            
            DynamicEmptyStateView(type: .noSearchResults)
                .previewDisplayName("No Search Results")
            
            CameraEmptyStateView()
                .previewDisplayName("Camera Empty State")
        }
    }
}
#endif