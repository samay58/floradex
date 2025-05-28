import SwiftUI

// PreferenceKey to track scroll offset
struct ScrollOffsetPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

struct OverviewCard: View, DexDetailCard {
    let id: Int = 0 // First card
    let entry: DexEntry
    let details: SpeciesDetails?
    
    @State private var scrollOffset: CGFloat = 0 // To track scroll position for sticky headers
    
    var accentColor: Color {
        Theme.Colors.primaryGreen // Use consistent primary green
    }

    private var wikipediaURL: URL? {
        guard let latinName = details?.latinName else { return nil }
        let formattedName = latinName.replacingOccurrences(of: " ", with: "_")
        return URL(string: "https://en.wikipedia.org/wiki/\(formattedName)")
    }

    var body: some View {
        ScrollView {
            ZStack(alignment: .top) { // ZStack for GeometryReader background
                // Invisible GeometryReader to read scroll offset
                GeometryReader { geo in
                    Color.clear
                        .preference(key: ScrollOffsetPreferenceKey.self, 
                                    value: geo.frame(in: .named("overviewScroll")).minY)
                }
                .frame(height: 0) // Important: make it take no space
                
                LazyVStack(alignment: .leading, spacing: Theme.Metrics.Padding.large, pinnedViews: [.sectionHeaders]) {
                    // Main title for OverviewCard
                    Text("Overview")
                        .font(Theme.Typography.title3.weight(.bold))
                        .foregroundColor(Theme.Colors.textPrimary)
                        .padding(.bottom, Theme.Metrics.Padding.small)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    Section {
                        Text(details?.summary ?? "No summary available.")
                            .font(Theme.Typography.body)
                            .foregroundColor(Theme.Colors.textPrimary)
                            .padding(.bottom)
                    } header: {
                        StickyHeaderView(title: "Summary", currentOffset: scrollOffset, font: Theme.Typography.headline)
                    }
                    
                    if let funFacts = details?.funFacts, !funFacts.isEmpty {
                        Section {
                            ForEach(funFacts, id: \.self) { fact in
                                Label {
                                    Text(fact)
                                        .font(Theme.Typography.body)
                                        .foregroundColor(Theme.Colors.textPrimary)
                                } icon: {
                                    Image(systemName: "sparkle")
                                        .foregroundColor(Theme.Colors.primaryGreen)
                                }
                                .padding(.vertical, Theme.Metrics.Padding.extraSmall)
                            }
                            .padding(.bottom)
                        } header: {
                            StickyHeaderView(title: "Fun Facts", currentOffset: scrollOffset, font: Theme.Typography.headline)
                        }
                    }
                    
                    if let notes = entry.notes, !notes.isEmpty {
                        Section {
                            Text(notes)
                                .font(Theme.Typography.body)
                                .foregroundColor(Theme.Colors.textPrimary)
                                .padding(.bottom)
                        } header: {
                            StickyHeaderView(title: "My Notes", currentOffset: scrollOffset, font: Theme.Typography.headline)
                                .padding(.top) // Add padding if sections are too close
                        }
                    }

                    if let url = wikipediaURL {
                        Section {
                            Link("View on Wikipedia", destination: url)
                                .font(Theme.Typography.callout)
                                .foregroundColor(accentColor)
                                .padding(.bottom) // Ensure content pushes header if it's last
                        } header: {
                            StickyHeaderView(title: "Learn More", currentOffset: scrollOffset, font: Theme.Typography.headline)
                                .padding(.top)
                        }
                    }
                }
                .padding(Theme.Metrics.Padding.large)
            }
        }
        .coordinateSpace(name: "overviewScroll") // Name the coordinate space for the preference key
        .onPreferenceChange(ScrollOffsetPreferenceKey.self) { value in
            self.scrollOffset = value
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity) // Ensure ScrollView takes full space
        .background(Theme.Colors.cardBackground) // Use dark-mode-aware card background
        .cornerRadius(Theme.Metrics.cornerRadiusLarge)
        // Note: Shadow is handled by DexCardPager, not individual cards
    }
}

// Reusable Sticky Header View with Modern Styling
struct StickyHeaderView: View {
    let title: String
    let currentOffset: CGFloat
    let font: Font
    
    // Calculate how much the header should be offset to appear sticky
    private var stickyOffset: CGFloat {
        // When currentOffset is 0 or positive (at top or bounced down), no offset needed.
        // When currentOffset is negative (scrolled up), header moves up by that amount to stick.
        return currentOffset < 0 ? -currentOffset : 0
    }
    
    var body: some View {
        Text(title)
            .font(font)
            .foregroundColor(Theme.Colors.textPrimary)
            .padding(.vertical, Theme.Metrics.Padding.extraSmall)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.Colors.cardBackground.opacity(0.95)) // Use dark-mode-aware background with opacity for sticky effect
            .offset(y: stickyOffset) // Apply sticky offset
            .zIndex(1) // Ensure header is above content during scroll
    }
} 

#if DEBUG
struct OverviewCard_Previews: PreviewProvider {
    static var previews: some View {
        // Preview with sample data
        let sampleEntry = PreviewHelper.sampleDexEntry
        let sampleDetails = PreviewHelper.sampleSpeciesDetails
        
        VStack(spacing: 20) {
            Text("Modern OverviewCard")
                .font(Theme.Typography.title2)
            
            OverviewCard(entry: sampleEntry, details: sampleDetails)
                .frame(height: 500)
                .padding()
        }
        .background(Theme.Colors.systemGroupedBackground)
        .previewLayout(.sizeThatFits)
    }
}
#endif 