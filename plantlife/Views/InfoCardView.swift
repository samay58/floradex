import SwiftUI

struct InfoCardView: View {
    let species: String?
    let confidence: Double?
    let details: SpeciesDetails?
    let isLoading: Bool

    @State private var selectedTab: Tab = .quick
    @State private var appearAnimation = false
    @State private var bulletAppearDelay: Double = 0.1
    @Namespace private var underlineNS

    enum Tab: String, CaseIterable, Identifiable {
        case quick = "Quick"
        case care = "Care"
        case more = "More"
        var id: Self { self }
        
        var icon: String {
            switch self {
            case .quick: return "sparkles"
            case .care: return "leaf.fill"
            case .more: return "chart.bar.fill"
            }
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header
                .opacity(appearAnimation ? 1 : 0)
                .offset(y: appearAnimation ? 0 : 20)
            
            // Chip ribbon with pixel underline
            ChipRibbon
                .padding(.horizontal, 4)

            Group {
                switch selectedTab {
                case .quick: quickTab
                case .care:  careTab
                case .more:  growthTab
                }
            }
            .frame(maxWidth: .infinity,
                   minHeight: 180)
            .onChange(of: selectedTab) { _ in
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
            }
        }
        .padding()
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: Theme.Metrics.Card.cornerRadius))
        .shadow(
            color: .black.opacity(Theme.Metrics.Card.shadowOpacity),
            radius: Theme.Metrics.Card.shadowRadius,
            x: 0,
            y: 5
        )
        .onAppear {
            withAnimation(Theme.Animations.smooth.delay(0.1)) {
                appearAnimation = true
            }
        }
    }

    private var quickTab: some View {
        ScrollView {
            if isLoading || details == nil {
                ProgressView("Loading…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let facts = details?.funFacts, !facts.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(Array(facts.enumerated()), id: \.element) { index, fact in
                        HStack(alignment: .top, spacing: 12) {
                            // Modern bullet point
                            Circle()
                                .fill(Theme.Colors.accent(for: species))
                                .frame(width: 8, height: 8)
                                .overlay(
                                    Circle()
                                        .stroke(Theme.Colors.accent(for: species).opacity(0.3), lineWidth: 2)
                                        .scaleEffect(1.5)
                                )
                                .opacity(appearAnimation ? 1 : 0)
                                .offset(x: appearAnimation ? 0 : -10)
                                .animation(Theme.Animations.staggered(index: index, baseDelay: bulletAppearDelay), value: appearAnimation)
                            
                            Text(fact)
                                .font(Theme.Typography.body)
                                .foregroundStyle(Theme.Colors.primary)
                                .fixedSize(horizontal: false, vertical: true)
                                .opacity(appearAnimation ? 1 : 0)
                                .offset(x: appearAnimation ? 0 : -10)
                                .animation(Theme.Animations.staggered(index: index, baseDelay: bulletAppearDelay), value: appearAnimation)
                        }
                        .accessibilityElement(children: .combine)
                        .accessibilityLabel(fact)
                    }
                }
                .padding(.vertical, 4)
            } else if let summary = details?.summary, !summary.isEmpty {
                Text(summary)
                    .font(Theme.Typography.body)
                    .foregroundStyle(Theme.Colors.primary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.vertical, 4)
                    .opacity(appearAnimation ? 1 : 0)
                    .offset(y: appearAnimation ? 0 : 20)
                    .animation(Theme.Animations.smooth.delay(0.2), value: appearAnimation)
            } else if let d = details {
                let bullets = [
                    d.growthHabit.map { "Growth: \($0)" },
                    d.sunlight.map { "Sunlight: \($0)" },
                    d.water.map { "Water: \($0)" },
                    d.temperature.map { "Temperature: \($0)" },
                    d.soil.map { "Soil: \($0)" },
                    d.bloomTime.map { "Bloom: \($0)" }
                ].compactMap { $0 }
                
                if bullets.isEmpty {
                    placeholder
                } else {
                    VStack(alignment: .leading, spacing: 12) {
                        ForEach(Array(bullets.enumerated()), id: \.element) { index, bullet in
                            HStack(alignment: .top, spacing: 12) {
                                Circle()
                                    .fill(Theme.Colors.accent(for: species))
                                    .frame(width: 8, height: 8)
                                    .overlay(
                                        Circle()
                                            .stroke(Theme.Colors.accent(for: species).opacity(0.3), lineWidth: 2)
                                            .scaleEffect(1.5)
                                    )
                                    .opacity(appearAnimation ? 1 : 0)
                                    .offset(x: appearAnimation ? 0 : -10)
                                    .animation(Theme.Animations.staggered(index: index, baseDelay: bulletAppearDelay), value: appearAnimation)
                                
                                Text(bullet)
                                    .font(Theme.Typography.body)
                                    .foregroundStyle(Theme.Colors.primary)
                                    .fixedSize(horizontal: false, vertical: true)
                                    .opacity(appearAnimation ? 1 : 0)
                                    .offset(x: appearAnimation ? 0 : -10)
                                    .animation(Theme.Animations.staggered(index: index, baseDelay: bulletAppearDelay), value: appearAnimation)
                            }
                        }
                    }
                    .padding(.vertical, 4)
                }
            } else {
                placeholder
            }
        }
    }

    private var careTab: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                ForEach(["Sunlight", "Water", "Soil", "Temperature"], id: \.self) { label in
                    InfoRow(label: label, value: details?.value(for: label), accentColor: Theme.Colors.accent(for: species))
                        .opacity(appearAnimation ? 1 : 0)
                        .offset(y: appearAnimation ? 0 : 20)
                        .animation(Theme.Animations.staggered(index: ["Sunlight", "Water", "Soil", "Temperature"].firstIndex(of: label) ?? 0), value: appearAnimation)
                }
                if details?.sunlight == nil && details?.water == nil && details?.soil == nil && details?.temperature == nil {
                    placeholder
                }
            }
            .padding(.vertical, 4)
        }
    }

    private var growthTab: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                ForEach(["Growth Habit", "Bloom Time"], id: \.self) { label in
                    InfoRow(label: label, value: details?.value(for: label), accentColor: Theme.Colors.accent(for: species))
                        .opacity(appearAnimation ? 1 : 0)
                        .offset(y: appearAnimation ? 0 : 20)
                        .animation(Theme.Animations.staggered(index: ["Growth Habit", "Bloom Time"].firstIndex(of: label) ?? 0), value: appearAnimation)
                }
                if details?.growthHabit == nil && details?.bloomTime == nil {
                    placeholder
                }
            }
            .padding(.vertical, 4)
        }
    }

    private var placeholder: some View {
        Text("No data yet")
            .font(Theme.Typography.bodyMedium)
            .foregroundStyle(Theme.Colors.secondary)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
            .opacity(appearAnimation ? 1 : 0)
            .animation(Theme.Animations.smooth.delay(0.2), value: appearAnimation)
    }

    // MARK: - Header
    private var header: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 4) {
                if let latin = species {
                    Text(latin)
                        .font(Theme.Typography.title3)
                        .foregroundStyle(Theme.Colors.primary)
                }
                if let common = details?.commonName {
                    Text(common)
                        .font(Theme.Typography.body)
                        .foregroundStyle(Theme.Colors.secondary)
                }
                if let conf = confidence {
                    PixelGauge(value: conf, size: 48, foreground: Theme.Colors.accent(for: species))
                        .accessibilityLabel(Text("Confidence"))
                        .accessibilityValue(Text(String(format: "%.0f%%", conf * 100)))
                }
            }
            Spacer()
            if let species = species {
                ShareLink(item: "I just identified \(species) with PlantLife!") {
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(Theme.Colors.accent(for: species))
                }
                .buttonStyle(.borderless)
                .accessibilityLabel("Share")
            }
        }
        .padding(.bottom, 4)
    }

    // MARK: - Chip Ribbon
    private var ChipRibbon: some View {
        HStack(spacing: 12) {
            ForEach(Tab.allCases) { tab in
                Button {
                    withAnimation(Theme.Animations.snappy) { selectedTab = tab }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: tab.icon)
                            .font(.system(size: 12, weight: .medium))
                        Text(tab.rawValue)
                            .font(.caption.weight(.medium))
                    }
                    .padding(.vertical, 6)
                    .padding(.horizontal, 12)
                    .background(
                        Capsule()
                            .fill(selectedTab == tab ? Theme.Colors.accent(for: species).opacity(0.2) : Color(.systemGray5).opacity(0.4))
                    )
                    .foregroundStyle(selectedTab == tab ? Theme.Colors.accent(for: species) : Theme.Colors.secondary)
                    .overlay(
                        Group {
                            if selectedTab == tab {
                                Rectangle()
                                    .fill(Theme.Colors.accent(for: species))
                                    .frame(height: 4)
                                    .matchedGeometryEffect(id: "underline", in: underlineNS)
                                    .offset(y: 14)
                            }
                        }, alignment: .bottom
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }
}

// MARK: - InfoRow
struct InfoRow: View {
    let label: String
    let value: String?
    let accentColor: Color
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Text(label)
                .font(Theme.Typography.bodyMedium)
                .foregroundStyle(Theme.Colors.secondary)
                .frame(width: 100, alignment: .leading)
            
            if let value = value {
                Text(value)
                    .font(Theme.Typography.body)
                    .foregroundStyle(Theme.Colors.primary)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                Text("Unknown")
                    .font(Theme.Typography.body)
                    .foregroundStyle(Theme.Colors.secondary)
            }
        }
    }
}

// MARK: - SpeciesDetails Extension
extension SpeciesDetails {
    func value(for label: String) -> String? {
        switch label {
        case "Sunlight": return sunlight
        case "Water": return water
        case "Soil": return soil
        case "Temperature": return temperature
        case "Growth Habit": return growthHabit
        case "Bloom Time": return bloomTime
        default: return nil
        }
    }
} 