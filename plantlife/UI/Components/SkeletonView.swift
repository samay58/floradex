import SwiftUI

// MARK: - Progressive Skeleton Loading Views

struct PlantDetailSkeletonView: View {
    @State private var isAnimating = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Metrics.Padding.medium) {
            // Header Section - Image and primary info
            VStack(alignment: .center, spacing: Theme.Metrics.Padding.small) {
                // Plant sprite skeleton
                Circle()
                    .fill(Theme.Colors.systemFill)
                    .frame(width: 64, height: 64)
                    .shimmerEffect()
                
                // Plant name skeleton
                RoundedRectangle(cornerRadius: 8)
                    .fill(Theme.Colors.systemFill)
                    .frame(width: 200, height: 24)
                    .shimmerEffect()
                
                // Latin name skeleton
                RoundedRectangle(cornerRadius: 6)
                    .fill(Theme.Colors.systemFill.opacity(0.7))
                    .frame(width: 150, height: 16)
                    .shimmerEffect()
                
                // Confidence skeleton
                RoundedRectangle(cornerRadius: 4)
                    .fill(Theme.Colors.systemFill.opacity(0.5))
                    .frame(width: 80, height: 14)
                    .shimmerEffect()
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, Theme.Metrics.Padding.large)
            
            // Care Requirements Section
            VStack(alignment: .leading, spacing: Theme.Metrics.Padding.small) {
                SkeletonSectionHeader(width: 120)
                
                HStack(spacing: Theme.Metrics.Padding.medium) {
                    SkeletonGauge()
                    SkeletonGauge()
                    SkeletonGauge()
                }
            }
            .padding(.horizontal)
            
            // Information Cards
            VStack(alignment: .leading, spacing: Theme.Metrics.Padding.medium) {
                SkeletonCard(lines: 3)
                SkeletonCard(lines: 2)
                SkeletonCard(lines: 4)
            }
            .padding(.horizontal)
            
            Spacer()
        }
        .background(Theme.Colors.systemBackground)
    }
}

struct SkeletonSectionHeader: View {
    let width: CGFloat
    
    var body: some View {
        RoundedRectangle(cornerRadius: 6)
            .fill(Theme.Colors.systemFill)
            .frame(width: width, height: 20)
            .shimmerEffect()
    }
}

struct SkeletonGauge: View {
    var body: some View {
        VStack(spacing: 8) {
            Circle()
                .fill(Theme.Colors.systemFill)
                .frame(width: 80, height: 80)
            
            RoundedRectangle(cornerRadius: 4)
                .fill(Theme.Colors.systemFill.opacity(0.7))
                .frame(width: 60, height: 12)
        }
        .shimmerEffect()
    }
}

struct SkeletonCard: View {
    let lines: Int
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Title
            RoundedRectangle(cornerRadius: 6)
                .fill(Theme.Colors.systemFill)
                .frame(width: 150, height: 18)
            
            // Content lines
            ForEach(0..<lines, id: \.self) { index in
                RoundedRectangle(cornerRadius: 4)
                    .fill(Theme.Colors.systemFill.opacity(0.6))
                    .frame(height: 14)
                    .frame(maxWidth: index == lines - 1 ? 200 : .infinity)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: Theme.Metrics.cornerRadiusMedium)
                .fill(Theme.Colors.systemFill.opacity(0.3))
        )
        .shimmerEffect()
    }
}

// MARK: - Grid Collection Skeleton

struct DexGridSkeletonView: View {
    let columns = [
        GridItem(.flexible()),
        GridItem(.flexible())
    ]
    
    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: Theme.Metrics.Padding.medium) {
                ForEach(0..<6, id: \.self) { index in
                    DexCardSkeleton()
                        .opacity(0.8 - Double(index) * 0.1) // Progressive fade
                }
            }
            .padding()
        }
    }
}

struct DexCardSkeleton: View {
    var body: some View {
        VStack(spacing: Theme.Metrics.Padding.small) {
            // Sprite placeholder
            RoundedRectangle(cornerRadius: Theme.Metrics.cornerRadiusSmall)
                .fill(Theme.Colors.systemFill)
                .aspectRatio(1, contentMode: .fit)
            
            // Name placeholder
            RoundedRectangle(cornerRadius: 4)
                .fill(Theme.Colors.systemFill.opacity(0.7))
                .frame(height: 16)
            
            // Subtext placeholder
            RoundedRectangle(cornerRadius: 4)
                .fill(Theme.Colors.systemFill.opacity(0.5))
                .frame(height: 12)
                .padding(.horizontal, Theme.Metrics.Padding.small)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: Theme.Metrics.cornerRadiusMedium)
                .fill(Theme.Colors.systemFill.opacity(0.2))
        )
        .shimmerEffect()
    }
}

// MARK: - Multi-Phase Progress Visualization

struct PlantIdentificationProgressView: View {
    @State private var currentPhase: IdentificationPhase = .analyzing
    @State private var progress: Double = 0.0
    @State private var nodeConnections: [NodeConnection] = []
    @State private var dataStreamOffset: CGFloat = 0
    
    enum IdentificationPhase: CaseIterable {
        case analyzing
        case identifying
        case fetchingDetails
        case finalizing
        
        var title: String {
            switch self {
            case .analyzing: return "Analyzing Image"
            case .identifying: return "Identifying Species"
            case .fetchingDetails: return "Fetching Details"
            case .finalizing: return "Finalizing"
            }
        }
        
        var progressRange: ClosedRange<Double> {
            switch self {
            case .analyzing: return 0...0.3
            case .identifying: return 0.3...0.7
            case .fetchingDetails: return 0.7...0.95
            case .finalizing: return 0.95...1.0
            }
        }
        
        var color: Color {
            switch self {
            case .analyzing: return Theme.Colors.primaryGreen
            case .identifying: return .blue
            case .fetchingDetails: return .orange
            case .finalizing: return Theme.Colors.primaryGreen
            }
        }
    }
    
    struct NodeConnection: Identifiable {
        let id = UUID()
        let start: CGPoint
        let end: CGPoint
        let delay: Double
    }
    
    var body: some View {
        VStack(spacing: Theme.Metrics.Padding.large) {
            // Phase-specific visualization
            ZStack {
                switch currentPhase {
                case .analyzing:
                    ScanningLineAnimation()
                case .identifying:
                    NeuralNetworkAnimation(connections: $nodeConnections)
                case .fetchingDetails:
                    DataStreamAnimation(offset: $dataStreamOffset)
                case .finalizing:
                    SuccessCheckmarkAnimation()
                }
            }
            .frame(height: 200)
            .frame(maxWidth: .infinity)
            
            // Progress indicator
            VStack(spacing: Theme.Metrics.Padding.small) {
                Text(currentPhase.title)
                    .font(Theme.Typography.headline)
                    .foregroundColor(Theme.Colors.textPrimary)
                
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        // Background track
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Theme.Colors.systemFill)
                            .frame(height: 8)
                        
                        // Progress fill
                        RoundedRectangle(cornerRadius: 4)
                            .fill(currentPhase.color)
                            .frame(width: geometry.size.width * progress, height: 8)
                            .animation(AnimationConstants.smoothSpring, value: progress)
                    }
                }
                .frame(height: 8)
                
                Text("\(Int(progress * 100))%")
                    .font(Theme.Typography.caption)
                    .foregroundColor(Theme.Colors.textSecondary)
                    .monospacedDigit()
            }
            .padding(.horizontal)
        }
        .onAppear {
            simulateProgress()
        }
    }
    
    private func simulateProgress() {
        // Simulate progress through phases
        withAnimation(Animation.linear(duration: 4.0)) {
            progress = 1.0
        }
        
        // Update phases based on progress
        Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { timer in
            let currentProgress = progress
            
            if currentProgress >= 0.95 {
                currentPhase = .finalizing
                timer.invalidate()
            } else if currentProgress >= 0.7 {
                currentPhase = .fetchingDetails
            } else if currentProgress >= 0.3 {
                currentPhase = .identifying
                generateNodeConnections()
            }
        }
    }
    
    private func generateNodeConnections() {
        guard nodeConnections.isEmpty else { return }
        
        // Generate random node connections for neural network visualization
        for _ in 0..<10 {
            nodeConnections.append(NodeConnection(
                start: CGPoint(x: .random(in: 50...150), y: .random(in: 50...150)),
                end: CGPoint(x: .random(in: 200...300), y: .random(in: 50...150)),
                delay: .random(in: 0...1)
            ))
        }
    }
}

// MARK: - Animation Components

struct ScanningLineAnimation: View {
    @State private var offset: CGFloat = -100
    
    var body: some View {
        GeometryReader { geometry in
            RoundedRectangle(cornerRadius: 2)
                .fill(
                    LinearGradient(
                        gradient: Gradient(colors: [
                            Color.clear,
                            Theme.Colors.primaryGreen.opacity(0.8),
                            Theme.Colors.primaryGreen,
                            Theme.Colors.primaryGreen.opacity(0.8),
                            Color.clear
                        ]),
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .frame(width: geometry.size.width * 0.3, height: 4)
                .offset(x: offset)
                .onAppear {
                    withAnimation(
                        Animation.linear(duration: 2.0)
                            .repeatForever(autoreverses: false)
                    ) {
                        offset = geometry.size.width
                    }
                }
        }
    }
}

struct NeuralNetworkAnimation: View {
    @Binding var connections: [PlantIdentificationProgressView.NodeConnection]
    
    var body: some View {
        Canvas { context, size in
            for connection in connections {
                var path = Path()
                path.move(to: connection.start)
                path.addLine(to: connection.end)
                
                context.stroke(
                    path,
                    with: .linearGradient(
                        Gradient(colors: [
                            Color.blue.opacity(0.3),
                            Color.blue.opacity(0.8),
                            Color.blue.opacity(0.3)
                        ]),
                        startPoint: connection.start,
                        endPoint: connection.end
                    ),
                    lineWidth: 2
                )
            }
        }
        .blur(radius: 1)
    }
}

struct DataStreamAnimation: View {
    @Binding var offset: CGFloat
    
    var body: some View {
        GeometryReader { geometry in
            ForEach(0..<5, id: \.self) { index in
                Circle()
                    .fill(Color.orange)
                    .frame(width: 8, height: 8)
                    .offset(
                        x: CGFloat(index) * 20 + offset,
                        y: sin(Double(index) * 0.5 + offset * 0.02) * 20 + geometry.size.height / 2
                    )
            }
        }
        .onAppear {
            withAnimation(
                Animation.linear(duration: 3.0)
                    .repeatForever(autoreverses: false)
            ) {
                offset = 300
            }
        }
    }
}

struct SuccessCheckmarkAnimation: View {
    @State private var scale: CGFloat = 0
    @State private var rotation: Double = -45
    
    var body: some View {
        Image(systemName: "checkmark.circle.fill")
            .font(.system(size: 80))
            .foregroundColor(Theme.Colors.primaryGreen)
            .scaleEffect(scale)
            .rotationEffect(.degrees(rotation))
            .onAppear {
                withAnimation(AnimationConstants.signatureSpring) {
                    scale = 1.0
                    rotation = 0
                }
            }
    }
}

#if DEBUG
struct SkeletonView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            PlantDetailSkeletonView()
                .previewDisplayName("Plant Detail Skeleton")
            
            DexGridSkeletonView()
                .previewDisplayName("Dex Grid Skeleton")
            
            PlantIdentificationProgressView()
                .previewDisplayName("Identification Progress")
                .padding()
        }
    }
}
#endif