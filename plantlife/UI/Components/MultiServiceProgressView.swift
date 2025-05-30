import SwiftUI

/// Shows progress of multiple API services during plant identification
struct MultiServiceProgressView: View {
    @ObservedObject var viewModel: ClassificationViewModel
    @State private var animatedProgress: [String: Double] = [:]
    @State private var serviceAppear: [String: Bool] = [:]
    
    // Service information
    let services = [
        ServiceInfo(id: "local", name: "Device AI", icon: "cpu", color: .blue),
        ServiceInfo(id: "plantnet", name: "PlantNet", icon: "leaf.fill", color: .green),
        ServiceInfo(id: "gpt4", name: "GPT-4 Vision", icon: "brain", color: .purple),
        ServiceInfo(id: "ensemble", name: "Combining Results", icon: "sparkles", color: .orange)
    ]
    
    struct ServiceInfo {
        let id: String
        let name: String
        let icon: String
        let color: Color
    }
    
    var body: some View {
        VStack(spacing: Theme.Metrics.Padding.medium) {
            // Header
            VStack(spacing: Theme.Metrics.Padding.small) {
                Image(systemName: "magnifyingglass.circle")
                    .font(.system(size: 48))
                    .foregroundColor(Theme.Colors.primaryGreen)
                    .symbolEffect(.pulse.byLayer)
                
                Text("Identifying your plant...")
                    .font(Theme.Typography.title3)
                    .foregroundColor(Theme.Colors.textPrimary)
                
                Text("Using multiple AI services for accuracy")
                    .font(Theme.Typography.caption)
                    .foregroundColor(Theme.Colors.textSecondary)
            }
            .padding(.bottom, Theme.Metrics.Padding.medium)
            
            // Service Progress List
            VStack(spacing: Theme.Metrics.Padding.small) {
                ForEach(services, id: \.id) { service in
                    ServiceProgressRow(
                        service: service,
                        progress: animatedProgress[service.id] ?? 0,
                        isActive: isServiceActive(service.id),
                        hasCompleted: hasServiceCompleted(service.id),
                        appeared: serviceAppear[service.id] ?? false
                    )
                    .onAppear {
                        withAnimation(AnimationConstants.smoothSpring.delay(Double(services.firstIndex(where: { $0.id == service.id })!) * 0.1)) {
                            serviceAppear[service.id] = true
                        }
                    }
                }
            }
            
            // Overall Progress
            if viewModel.overallProgress > 0 {
                VStack(spacing: Theme.Metrics.Padding.extraSmall) {
                    HStack {
                        Text("Overall Progress")
                            .font(Theme.Typography.caption)
                            .foregroundColor(Theme.Colors.textSecondary)
                        
                        Spacer()
                        
                        Text("\(Int(viewModel.overallProgress * 100))%")
                            .font(Theme.Typography.caption.weight(.semibold))
                            .foregroundColor(Theme.Colors.primaryGreen)
                    }
                    
                    GeometryReader { geometry in
                        ZStack(alignment: .leading) {
                            // Background
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Theme.Colors.systemFill)
                                .frame(height: 8)
                            
                            // Progress
                            RoundedRectangle(cornerRadius: 4)
                                .fill(
                                    LinearGradient(
                                        colors: [Theme.Colors.primaryGreen, Theme.Colors.primaryGreen.opacity(0.8)],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .frame(width: geometry.size.width * viewModel.overallProgress, height: 8)
                                .animation(AnimationConstants.smoothSpring, value: viewModel.overallProgress)
                        }
                    }
                    .frame(height: 8)
                }
                .padding(.top, Theme.Metrics.Padding.medium)
            }
        }
        .padding(Theme.Metrics.Padding.large)
        .background(
            RoundedRectangle(cornerRadius: Theme.Metrics.cornerRadiusLarge)
                .fill(.regularMaterial)
        )
        .shadow(radius: 10)
        .onChange(of: viewModel.overallProgress) { newValue in
            updateAnimatedProgress()
        }
        .onAppear {
            updateAnimatedProgress()
        }
    }
    
    // MARK: - Helper Methods
    
    private func isServiceActive(_ serviceId: String) -> Bool {
        switch serviceId {
        case "local":
            return viewModel.isClassifying && viewModel.overallProgress < 0.3
        case "plantnet":
            return viewModel.isClassifying && viewModel.overallProgress >= 0.2 && viewModel.overallProgress < 0.5
        case "gpt4":
            return viewModel.isClassifying && viewModel.overallProgress >= 0.4 && viewModel.overallProgress < 0.7
        case "ensemble":
            return viewModel.isClassifying && viewModel.overallProgress >= 0.6
        default:
            return false
        }
    }
    
    private func hasServiceCompleted(_ serviceId: String) -> Bool {
        switch serviceId {
        case "local":
            return viewModel.overallProgress >= 0.3
        case "plantnet":
            return viewModel.overallProgress >= 0.5
        case "gpt4":
            return viewModel.overallProgress >= 0.7
        case "ensemble":
            return viewModel.overallProgress >= 1.0
        default:
            return false
        }
    }
    
    private func updateAnimatedProgress() {
        withAnimation(AnimationConstants.smoothSpring) {
            if viewModel.overallProgress < 0.3 {
                animatedProgress["local"] = viewModel.overallProgress / 0.3
            } else {
                animatedProgress["local"] = 1.0
            }
            
            if viewModel.overallProgress >= 0.2 {
                if viewModel.overallProgress < 0.5 {
                    animatedProgress["plantnet"] = (viewModel.overallProgress - 0.2) / 0.3
                } else {
                    animatedProgress["plantnet"] = 1.0
                }
            }
            
            if viewModel.overallProgress >= 0.4 {
                if viewModel.overallProgress < 0.7 {
                    animatedProgress["gpt4"] = (viewModel.overallProgress - 0.4) / 0.3
                } else {
                    animatedProgress["gpt4"] = 1.0
                }
            }
            
            if viewModel.overallProgress >= 0.6 {
                animatedProgress["ensemble"] = (viewModel.overallProgress - 0.6) / 0.4
            }
        }
    }
}

// MARK: - Service Progress Row

struct ServiceProgressRow: View {
    let service: MultiServiceProgressView.ServiceInfo
    let progress: Double
    let isActive: Bool
    let hasCompleted: Bool
    let appeared: Bool
    
    var body: some View {
        HStack(spacing: Theme.Metrics.Padding.medium) {
            // Icon
            ZStack {
                Circle()
                    .fill(hasCompleted ? service.color : Theme.Colors.systemFill)
                    .frame(width: 40, height: 40)
                
                Image(systemName: hasCompleted ? "checkmark" : service.icon)
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(hasCompleted ? .white : service.color)
                    .scaleEffect(hasCompleted ? 1.0 : (isActive ? 1.1 : 1.0))
                    .animation(
                        isActive ? Animation.easeInOut(duration: 0.8).repeatForever(autoreverses: true) : .default,
                        value: isActive
                    )
            }
            .opacity(appeared ? 1 : 0)
            .offset(x: appeared ? 0 : -20)
            
            // Service Name and Progress
            VStack(alignment: .leading, spacing: 4) {
                Text(service.name)
                    .font(Theme.Typography.bodyMedium)
                    .foregroundColor(Theme.Colors.textPrimary)
                
                // Progress Bar
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        // Background
                        RoundedRectangle(cornerRadius: 2)
                            .fill(Theme.Colors.systemFill)
                            .frame(height: 4)
                        
                        // Progress
                        RoundedRectangle(cornerRadius: 2)
                            .fill(service.color)
                            .frame(width: geometry.size.width * progress, height: 4)
                            .animation(AnimationConstants.smoothSpring, value: progress)
                        
                        // Shimmer effect when active
                        if isActive && progress > 0 && progress < 1 {
                            RoundedRectangle(cornerRadius: 2)
                                .fill(
                                    LinearGradient(
                                        colors: [Color.clear, Color.white.opacity(0.3), Color.clear],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .frame(width: 40, height: 4)
                                .offset(x: geometry.size.width * progress - 20)
                                .animation(
                                    Animation.linear(duration: 1.5).repeatForever(autoreverses: false),
                                    value: isActive
                                )
                        }
                    }
                }
                .frame(height: 4)
            }
            .frame(maxWidth: .infinity)
            .opacity(appeared ? 1 : 0)
            .offset(x: appeared ? 0 : -20)
            
            // Status
            if hasCompleted {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 20))
                    .foregroundColor(service.color)
                    .transition(.scale.combined(with: .opacity))
            } else if isActive {
                ProgressView()
                    .scaleEffect(0.8)
                    .tint(service.color)
            }
        }
        .padding(.vertical, Theme.Metrics.Padding.small)
    }
}

#if DEBUG
struct MultiServiceProgressView_Previews: PreviewProvider {
    static var previews: some View {
        // Create a mock view model
        let viewModel = ClassificationViewModel(
            imageService: ImageSelectionService.shared,
            speciesRepository: SpeciesRepository(modelContext: ModelContext(ModelContainer(for: SpeciesDetails.self))),
            dexRepository: DexRepository(modelContext: ModelContext(ModelContainer(for: DexEntry.self)))
        )
        
        MultiServiceProgressView(viewModel: viewModel)
            .padding()
            .background(Theme.Colors.systemBackground)
            .previewLayout(.sizeThatFits)
    }
}
#endif