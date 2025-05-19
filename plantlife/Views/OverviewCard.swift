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
        Theme.Colors.accent(for: details?.latinName ?? "default")
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
                    // Add a main title for OverviewCard
                    Text("Overview")
                        .font(Font.pressStart2P(size: 16))
                        .padding(.bottom, Theme.Metrics.Padding.small)
                        .frame(maxWidth: .infinity, alignment: .leading) // Ensure it aligns with sections

                    Section {
                        Text(details?.summary ?? "No summary available.")
                            .padding(.bottom)
                    } header: {
                        StickyHeaderView(title: "Summary", currentOffset: scrollOffset, font: Font.pressStart2P(size: 14))
                    }
                    
                    if let funFacts = details?.funFacts, !funFacts.isEmpty {
                        Section {
                            ForEach(funFacts, id: \.self) { fact in
                                Label(fact, systemImage: "sparkle")
                            }
                            .padding(.bottom)
                        } header: {
                            StickyHeaderView(title: "Fun Facts", currentOffset: scrollOffset, font: Font.pressStart2P(size: 14))
                        }
                    }
                    
                    if let notes = entry.notes, !notes.isEmpty {
                        Section {
                            Text(notes)
                                .padding(.bottom)
                        } header: {
                            StickyHeaderView(title: "My Notes", currentOffset: scrollOffset, font: Font.pressStart2P(size: 14))
                                .padding(.top) // Add padding if sections are too close
                        }
                    }

                    if let url = wikipediaURL {
                        Section {
                            Link("View on Wikipedia", destination: url)
                                .font(.callout)
                                .foregroundColor(accentColor)
                                .padding(.bottom) // Ensure content pushes header if it's last
                        } header: {
                            StickyHeaderView(title: "Learn More", currentOffset: scrollOffset, font: Font.pressStart2P(size: 14))
                                .padding(.top)
                        }
                    }
                }
                .padding()
            }
        }
        .coordinateSpace(name: "overviewScroll") // Name the coordinate space for the preference key
        .onPreferenceChange(ScrollOffsetPreferenceKey.self) { value in
            self.scrollOffset = value
        }
        .background(Theme.Colors.surface)
        .shadow(color: Theme.Colors.dexShadow.opacity(Theme.Metrics.Card.shadowOpacity), 
                radius: Theme.Metrics.Card.shadowRadius, y: 2)
        .cornerRadius(Theme.Metrics.Card.cornerRadius)
        .padding(.horizontal)
    }
}

// Reusable Sticky Header View
struct StickyHeaderView: View {
    let title: String
    let currentOffset: CGFloat
    let font: Font
    
    // Calculate how much the header should be offset to appear sticky
    // This needs to be tuned. If currentOffset is negative (scrolling up),
    // we want to offset the header by -currentOffset to keep it at the top.
    private var stickyOffset: CGFloat {
        // When currentOffset is 0 or positive (at top or bounced down), no offset needed.
        // When currentOffset is negative (scrolled up), header moves up by that amount to stick.
        return currentOffset < 0 ? -currentOffset : 0
    }
    
    var body: some View {
        Text(title)
            .font(font)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.ultraThinMaterial) // As per plan
            .offset(y: stickyOffset) // Apply sticky offset
            .zIndex(1) // Ensure header is above content during scroll
    }
} 