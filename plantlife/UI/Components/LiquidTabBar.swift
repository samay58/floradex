import SwiftUI

struct LiquidTabBar: View {
    @Binding var selectedTab: Int
    let tabs: [(icon: String, label: String)]
    
    @State private var selectedRect: CGRect = .zero
    @State private var safeAreaInsets: EdgeInsets = .init()
    @Namespace private var tabAnimation
    
    init(selectedTab: Binding<Int>, tabs: [(icon: String, label: String)]) {
        self._selectedTab = selectedTab
        self.tabs = tabs
        // Removed init logging to reduce noise
    }
    
    var body: some View {
        GeometryReader { geometry in
            HStack(spacing: 0) {
                ForEach(Array(tabs.enumerated()), id: \.offset) { index, tab in
                    Button(action: {
                        print("[LiquidTabBar] Tab button tapped: \(tab.label) at index \(index)")
                        print("[LiquidTabBar] Current selectedTab: \(selectedTab), new index: \(index)")
                        withAnimation(AnimationConstants.signatureSpring) {
                            selectedTab = index
                        }
                        HapticManager.shared.tick()
                        print("[LiquidTabBar] selectedTab after update: \(selectedTab)")
                    }) {
                        TabBarItem(
                            icon: tab.icon,
                            label: tab.label,
                            isSelected: selectedTab == index,
                            namespace: tabAnimation
                        )
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(PlainButtonStyle()) // Remove default button styling
                }
            }
            .frame(height: geometry.size.height) // Ensure HStack fills the height
            .padding(.horizontal, Theme.Metrics.Padding.small)
            .padding(.top, Theme.Metrics.Padding.small)
            .padding(.bottom, safeAreaInsets.bottom > 0 ? 0 : Theme.Metrics.Padding.small)
            .background(
                TabBarBackground()
                    .shadow(color: Color.black.opacity(0.1), radius: 10, x: 0, y: -5)
            )
            .onAppear {
                safeAreaInsets = geometry.safeAreaInsets
                print("[LiquidTabBar] Appeared with safe area insets: \(safeAreaInsets)")
            }
        }
    }
}

struct TabBarItem: View {
    let icon: String
    let label: String
    let isSelected: Bool
    let namespace: Namespace.ID
    
    @State private var scale: CGFloat = 1.0
    
    var body: some View {
        VStack(spacing: 4) {
            ZStack {
                if isSelected {
                    Circle()
                        .fill(Theme.Colors.primaryGreen.opacity(0.15))
                        .frame(width: 48, height: 48)
                        .matchedGeometryEffect(id: "selection", in: namespace)
                }
                
                Image(systemName: icon)
                    .font(.system(size: 24, weight: isSelected ? .semibold : .regular))
                    .foregroundColor(isSelected ? Theme.Colors.primaryGreen : Theme.Colors.iconSecondary)
                    .scaleEffect(scale)
                    .animation(AnimationConstants.quickSpring, value: scale)
            }
            
            Text(label)
                .font(Theme.Typography.caption)
                .foregroundColor(isSelected ? Theme.Colors.primaryGreen : Theme.Colors.textSecondary)
                .opacity(isSelected ? 1.0 : 0.7)
        }
        .scaleEffect(isSelected ? 1.0 : 0.95)
        // Removed squishAnimation to avoid gesture conflicts
        .onChange(of: isSelected) { oldValue, newValue in
            if newValue {
                withAnimation(AnimationConstants.microSpring) {
                    scale = 1.2
                }
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                    withAnimation(AnimationConstants.smoothSpring) {
                        scale = 1.0
                    }
                }
            }
        }
    }
}

struct TabBarBackground: View {
    var body: some View {
        ZStack {
            // Base background
            Rectangle()
                .fill(Theme.Colors.systemBackground)
            
            // Subtle gradient overlay
            LinearGradient(
                gradient: Gradient(colors: [
                    Theme.Colors.systemBackground,
                    Theme.Colors.systemBackground.opacity(0.95)
                ]),
                startPoint: .top,
                endPoint: .bottom
            )
            
            // Top border with gradient
            VStack {
                LinearGradient(
                    gradient: Gradient(colors: [
                        Theme.Colors.systemFill.opacity(0.3),
                        Theme.Colors.systemFill.opacity(0.1),
                        Color.clear
                    ]),
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: 1)
                
                Spacer()
            }
        }
    }
}

// Custom TabView with liquid tab bar
struct LiquidTabView<Content: View>: View {
    @Binding var selection: Int
    let tabs: [(icon: String, label: String)]
    @ViewBuilder let content: Content
    
    var body: some View {
        VStack(spacing: 0) {
            // Content fills available space
            content
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            
            // Tab bar at bottom with explicit z-ordering
            LiquidTabBar(selectedTab: $selection, tabs: tabs)
                .frame(height: 80)
                .zIndex(1000) // Ensure tab bar is on top
        }
        .onAppear {
            print("[LiquidTabView] Appeared with selection: \(selection)")
        }
    }
}

#if DEBUG
struct LiquidTabBar_Previews: PreviewProvider {
    static var previews: some View {
        LiquidTabView(
            selection: .constant(0),
            tabs: [
                ("leaf.fill", "Floradex"),
                ("magnifyingglass", "Identify"),
                ("person.fill", "Profile")
            ]
        ) {
            Color.clear
        }
    }
}
#endif