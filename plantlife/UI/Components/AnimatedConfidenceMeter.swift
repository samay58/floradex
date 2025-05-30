import SwiftUI

/// Animated confidence meter with visual feedback based on confidence level
struct AnimatedConfidenceMeter: View {
    let confidence: Double
    let species: String
    let source: ClassifierService.Source
    
    @State private var animatedValue: Double = 0
    @State private var showPulse = false
    @State private var showCheckmark = false
    
    private var confidenceColor: Color {
        switch confidence {
        case 0.8...1.0:
            return .green
        case 0.6..<0.8:
            return .orange
        default:
            return .red
        }
    }
    
    private var confidenceEmoji: String {
        switch confidence {
        case 0.9...1.0:
            return "🎯"
        case 0.8..<0.9:
            return "✅"
        case 0.7..<0.8:
            return "👍"
        case 0.6..<0.7:
            return "🤔"
        default:
            return "❓"
        }
    }
    
    private var confidenceText: String {
        switch confidence {
        case 0.9...1.0:
            return "Very Confident"
        case 0.7..<0.9:
            return "Confident"
        case 0.5..<0.7:
            return "Likely"
        default:
            return "Uncertain"
        }
    }
    
    var body: some View {
        VStack(spacing: Theme.Metrics.Padding.large) {
            // Circular Progress Meter
            ZStack {
                // Background circle
                Circle()
                    .stroke(Theme.Colors.systemFill, lineWidth: 12)
                    .frame(width: 200, height: 200)
                
                // Progress arc
                Circle()
                    .trim(from: 0, to: animatedValue)
                    .stroke(
                        AngularGradient(
                            gradient: Gradient(colors: [
                                confidenceColor.opacity(0.7),
                                confidenceColor,
                                confidenceColor.opacity(0.9)
                            ]),
                            center: .center,
                            startAngle: .degrees(-90),
                            endAngle: .degrees(270)
                        ),
                        style: StrokeStyle(lineWidth: 12, lineCap: .round)
                    )
                    .frame(width: 200, height: 200)
                    .rotationEffect(.degrees(-90))
                    .animation(AnimationConstants.smoothSpring.delay(0.2), value: animatedValue)
                
                // Pulse effect for high confidence
                if showPulse && confidence >= 0.8 {
                    Circle()
                        .stroke(confidenceColor, lineWidth: 2)
                        .frame(width: 200, height: 200)
                        .scaleEffect(showPulse ? 1.2 : 1.0)
                        .opacity(showPulse ? 0 : 0.8)
                        .animation(
                            Animation.easeOut(duration: 1.0)
                                .repeatForever(autoreverses: false),
                            value: showPulse
                        )
                }
                
                // Center content
                VStack(spacing: 8) {
                    // Percentage or emoji
                    if showCheckmark && confidence >= 0.7 {
                        Text(confidenceEmoji)
                            .font(.system(size: 48))
                            .transition(.scale.combined(with: .opacity))
                    } else {
                        Text("\(Int(animatedValue * 100))%")
                            .font(.system(size: 48, weight: .bold, design: .rounded))
                            .foregroundColor(Theme.Colors.textPrimary)
                            .contentTransition(.numericText())
                    }
                    
                    // Confidence text
                    Text(confidenceText)
                        .font(Theme.Typography.caption)
                        .foregroundColor(confidenceColor)
                        .fontWeight(.semibold)
                }
            }
            
            // Species information
            VStack(spacing: Theme.Metrics.Padding.small) {
                Text("Identified as")
                    .font(Theme.Typography.caption)
                    .foregroundColor(Theme.Colors.textSecondary)
                
                Text(species)
                    .font(Theme.Typography.title3)
                    .foregroundColor(Theme.Colors.textPrimary)
                    .multilineTextAlignment(.center)
                
                // Source badge
                HStack(spacing: 4) {
                    Image(systemName: sourceIcon)
                        .font(.system(size: 12))
                    Text(sourceText)
                        .font(Theme.Typography.caption2)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 4)
                .background(
                    Capsule()
                        .fill(Theme.Colors.systemFill)
                )
                .foregroundColor(Theme.Colors.textSecondary)
            }
            
            // Additional visual feedback
            if confidence >= 0.8 {
                HStack(spacing: Theme.Metrics.Padding.small) {
                    ForEach(0..<5) { index in
                        Star(filled: Double(index) / 4.0 < confidence)
                            .frame(width: 24, height: 24)
                            .foregroundColor(confidenceColor)
                            .scaleEffect(showCheckmark ? 1.0 : 0.8)
                            .animation(
                                AnimationConstants.smoothSpring
                                    .delay(Double(index) * 0.05),
                                value: showCheckmark
                            )
                    }
                }
            }
        }
        .padding(Theme.Metrics.Padding.large)
        .onAppear {
            // Animate the confidence value
            withAnimation(AnimationConstants.smoothSpring.delay(0.3)) {
                animatedValue = confidence
            }
            
            // Show pulse for high confidence
            if confidence >= 0.8 {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    showPulse = true
                }
            }
            
            // Show checkmark after animation
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                withAnimation(AnimationConstants.smoothSpring) {
                    showCheckmark = true
                }
                
                // Haptic feedback
                if confidence >= 0.7 {
                    HapticManager.shared.success()
                }
            }
        }
    }
    
    private var sourceIcon: String {
        switch source {
        case .local:
            return "cpu"
        case .plantNet:
            return "leaf.fill"
        case .gpt4o:
            return "brain"
        case .ensemble:
            return "sparkles"
        default:
            return "questionmark.circle"
        }
    }
    
    private var sourceText: String {
        switch source {
        case .local:
            return "Device AI"
        case .plantNet:
            return "PlantNet"
        case .gpt4o:
            return "GPT-4 Vision"
        case .ensemble:
            return "Combined Analysis"
        default:
            return "Unknown"
        }
    }
}

// MARK: - Star Shape

struct Star: View {
    let filled: Bool
    
    var body: some View {
        Image(systemName: filled ? "star.fill" : "star")
            .foregroundColor(filled ? .yellow : Theme.Colors.systemFill)
    }
}

// MARK: - Confidence Bar Alternative

struct ConfidenceBar: View {
    let confidence: Double
    let animated: Bool
    
    @State private var animatedValue: Double = 0
    
    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Metrics.Padding.small) {
            HStack {
                Text("Confidence")
                    .font(Theme.Typography.caption)
                    .foregroundColor(Theme.Colors.textSecondary)
                
                Spacer()
                
                Text("\(Int(animatedValue * 100))%")
                    .font(Theme.Typography.caption.weight(.semibold))
                    .foregroundColor(confidenceColor)
                    .contentTransition(.numericText())
            }
            
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    // Background
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Theme.Colors.systemFill)
                    
                    // Progress
                    RoundedRectangle(cornerRadius: 6)
                        .fill(
                            LinearGradient(
                                colors: [confidenceColor.opacity(0.8), confidenceColor],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: geometry.size.width * animatedValue)
                        .animation(animated ? AnimationConstants.smoothSpring : .none, value: animatedValue)
                    
                    // Segments
                    HStack(spacing: 2) {
                        ForEach(0..<10) { _ in
                            Rectangle()
                                .fill(Theme.Colors.systemBackground.opacity(0.3))
                                .frame(width: 1, height: 12)
                        }
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .frame(height: 12)
        }
        .onAppear {
            if animated {
                withAnimation(AnimationConstants.smoothSpring.delay(0.2)) {
                    animatedValue = confidence
                }
            } else {
                animatedValue = confidence
            }
        }
    }
    
    private var confidenceColor: Color {
        switch confidence {
        case 0.8...1.0:
            return Theme.Colors.primaryGreen
        case 0.6..<0.8:
            return .orange
        default:
            return .red
        }
    }
}

#if DEBUG
struct AnimatedConfidenceMeter_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 40) {
            AnimatedConfidenceMeter(
                confidence: 0.92,
                species: "Monstera deliciosa",
                source: .ensemble
            )
            
            ConfidenceBar(confidence: 0.85, animated: true)
                .frame(width: 300)
                .padding()
        }
        .background(Theme.Colors.systemBackground)
        .previewLayout(.sizeThatFits)
    }
}
#endif