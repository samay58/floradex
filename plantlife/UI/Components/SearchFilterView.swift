import SwiftUI

struct SearchFilterView: View {
    @Binding var searchText: String
    @Binding var selectedTags: Set<String>
    @Binding var sortOption: DexSortOption
    let availableTags: [String]
    let onClear: () -> Void
    
    @State private var isSearchExpanded = false
    @State private var showFilters = false
    @FocusState private var searchFieldFocused: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Search Bar with Morphing Animation
            searchBar
                .padding(.horizontal, Theme.Metrics.Padding.medium)
                .padding(.top, Theme.Metrics.Padding.small)
            
            // Animated Tag Pills
            if showFilters || !selectedTags.isEmpty {
                tagPillsSection
                    .transition(.asymmetric(
                        insertion: .move(edge: .top).combined(with: .opacity),
                        removal: .move(edge: .top).combined(with: .opacity)
                    ))
            }
            
            // Sort Options
            if showFilters {
                sortOptionsSection
                    .transition(.asymmetric(
                        insertion: .move(edge: .top).combined(with: .opacity),
                        removal: .move(edge: .top).combined(with: .opacity)
                    ))
            }
        }
        .background(Theme.Colors.systemBackground)
        .animation(AnimationConstants.smoothSpring, value: showFilters)
        .animation(AnimationConstants.smoothSpring, value: selectedTags)
    }
    
    // MARK: - Search Bar
    
    private var searchBar: some View {
        HStack(spacing: Theme.Metrics.Padding.small) {
            // Search Field
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(Theme.Colors.textSecondary)
                    .scaleEffect(isSearchExpanded ? 1.1 : 1.0)
                    .animation(AnimationConstants.microSpring, value: isSearchExpanded)
                
                TextField("Search plants...", text: $searchText)
                    .textFieldStyle(.plain)
                    .focused($searchFieldFocused)
                    .onSubmit {
                        searchFieldFocused = false
                    }
                
                if !searchText.isEmpty {
                    Button {
                        withAnimation(AnimationConstants.microSpring) {
                            searchText = ""
                        }
                        HapticManager.shared.tick()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(Theme.Colors.textSecondary)
                            .transition(.scale.combined(with: .opacity))
                    }
                }
            }
            .padding(.horizontal, Theme.Metrics.Padding.medium)
            .padding(.vertical, Theme.Metrics.Padding.small)
            .background(
                RoundedRectangle(cornerRadius: Theme.Metrics.cornerRadiusMedium)
                    .fill(Theme.Colors.systemFill)
                    .overlay(
                        RoundedRectangle(cornerRadius: Theme.Metrics.cornerRadiusMedium)
                            .stroke(isSearchExpanded ? Theme.Colors.primaryGreen : Color.clear, lineWidth: 1.5)
                    )
            )
            .scaleEffect(isSearchExpanded ? 1.02 : 1.0)
            .onChange(of: searchFieldFocused) { focused in
                withAnimation(AnimationConstants.smoothSpring) {
                    isSearchExpanded = focused
                }
            }
            
            // Filter Button
            Button {
                withAnimation(AnimationConstants.signatureSpring) {
                    showFilters.toggle()
                }
                HapticManager.shared.tick()
            } label: {
                ZStack {
                    Image(systemName: "line.3.horizontal.decrease.circle")
                        .font(.system(size: 20))
                        .foregroundColor(showFilters ? Theme.Colors.primaryGreen : Theme.Colors.textSecondary)
                        .rotationEffect(.degrees(showFilters ? 180 : 0))
                    
                    // Badge for active filters
                    if !selectedTags.isEmpty || sortOption != .numberAsc {
                        Circle()
                            .fill(Theme.Colors.primaryGreen)
                            .frame(width: 8, height: 8)
                            .offset(x: 8, y: -8)
                    }
                }
            }
            .buttonStyle(.plain)
        }
    }
    
    // MARK: - Tag Pills
    
    private var tagPillsSection: some View {
        VStack(alignment: .leading, spacing: Theme.Metrics.Padding.small) {
            HStack {
                Text("Categories")
                    .font(Theme.Typography.caption.weight(.medium))
                    .foregroundColor(Theme.Colors.textSecondary)
                
                Spacer()
                
                if !selectedTags.isEmpty {
                    Button {
                        withAnimation(AnimationConstants.signatureSpring) {
                            selectedTags.removeAll()
                        }
                        HapticManager.shared.tick()
                    } label: {
                        Text("Clear All")
                            .font(Theme.Typography.caption)
                            .foregroundColor(Theme.Colors.primaryGreen)
                    }
                }
            }
            .padding(.horizontal, Theme.Metrics.Padding.medium)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: Theme.Metrics.Padding.small) {
                    ForEach(availableTags, id: \.self) { tag in
                        AnimatedTagPill(
                            tag: tag,
                            isSelected: selectedTags.contains(tag)
                        ) {
                            withAnimation(AnimationConstants.smoothSpring) {
                                if selectedTags.contains(tag) {
                                    selectedTags.remove(tag)
                                } else {
                                    selectedTags.insert(tag)
                                }
                            }
                            HapticManager.shared.tick()
                        }
                    }
                }
                .padding(.horizontal, Theme.Metrics.Padding.medium)
            }
        }
        .padding(.vertical, Theme.Metrics.Padding.small)
    }
    
    // MARK: - Sort Options
    
    private var sortOptionsSection: some View {
        VStack(alignment: .leading, spacing: Theme.Metrics.Padding.small) {
            Text("Sort By")
                .font(Theme.Typography.caption.weight(.medium))
                .foregroundColor(Theme.Colors.textSecondary)
                .padding(.horizontal, Theme.Metrics.Padding.medium)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: Theme.Metrics.Padding.small) {
                    ForEach(DexSortOption.allCases, id: \.self) { option in
                        SortOptionPill(
                            option: option,
                            isSelected: sortOption == option
                        ) {
                            withAnimation(AnimationConstants.smoothSpring) {
                                sortOption = option
                            }
                            HapticManager.shared.tick()
                        }
                    }
                }
                .padding(.horizontal, Theme.Metrics.Padding.medium)
            }
        }
        .padding(.bottom, Theme.Metrics.Padding.medium)
    }
}

// MARK: - Animated Tag Pill

struct AnimatedTagPill: View {
    let tag: String
    let isSelected: Bool
    let action: () -> Void
    
    @State private var scale: CGFloat = 1.0
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 10, weight: .semibold))
                        .transition(.scale.combined(with: .opacity))
                }
                
                Text(tag.capitalized)
                    .font(Theme.Typography.caption.weight(.medium))
            }
            .padding(.horizontal, Theme.Metrics.Padding.medium)
            .padding(.vertical, Theme.Metrics.Padding.small)
            .background(
                Capsule()
                    .fill(isSelected ? Theme.Colors.primaryGreen : Theme.Colors.systemFill)
                    .overlay(
                        Capsule()
                            .stroke(isSelected ? Theme.Colors.primaryGreen : Color.clear, lineWidth: 1)
                    )
            )
            .foregroundColor(isSelected ? .white : Theme.Colors.textPrimary)
            .scaleEffect(scale)
        }
        .buttonStyle(.plain)
        .onAppear {
            if isSelected {
                withAnimation(AnimationConstants.microSpring) {
                    scale = 1.1
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    withAnimation(AnimationConstants.smoothSpring) {
                        scale = 1.0
                    }
                }
            }
        }
        .onChange(of: isSelected) { selected in
            if selected {
                withAnimation(AnimationConstants.microSpring) {
                    scale = 1.15
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    withAnimation(AnimationConstants.smoothSpring) {
                        scale = 1.0
                    }
                }
            }
        }
    }
}

// MARK: - Sort Option Pill

struct SortOptionPill: View {
    let option: DexSortOption
    let isSelected: Bool
    let action: () -> Void
    
    var iconName: String {
        switch option {
        case .numberAsc: return "number.square"
        case .numberDesc: return "number.square"
        case .alphaAsc: return "textformat"
        case .alphaDesc: return "textformat"
        case .dateAsc: return "calendar"
        case .dateDesc: return "calendar"
        }
    }
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: iconName)
                    .font(.system(size: 14))
                    .rotationEffect(.degrees(option.rawValue.contains("Desc") ? 180 : 0))
                
                Text(option.displayName)
                    .font(Theme.Typography.caption.weight(.medium))
            }
            .padding(.horizontal, Theme.Metrics.Padding.medium)
            .padding(.vertical, Theme.Metrics.Padding.small)
            .background(
                Capsule()
                    .fill(isSelected ? Theme.Colors.primaryGreen : Theme.Colors.systemFill)
            )
            .foregroundColor(isSelected ? .white : Theme.Colors.textPrimary)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Dex Sort Options Extension

extension DexSortOption {
    var displayName: String {
        switch self {
        case .numberAsc: return "Number ↑"
        case .numberDesc: return "Number ↓"
        case .alphaAsc: return "A → Z"
        case .alphaDesc: return "Z → A"
        case .dateAsc: return "Oldest"
        case .dateDesc: return "Newest"
        }
    }
}

#if DEBUG
struct SearchFilterView_Previews: PreviewProvider {
    static var previews: some View {
        VStack {
            SearchFilterView(
                searchText: .constant(""),
                selectedTags: .constant(Set(["Succulent", "Flower"])),
                sortOption: .constant(.numberAsc),
                availableTags: ["Succulent", "Flower", "Tree", "Herb", "Cactus"],
                onClear: {}
            )
            
            Spacer()
        }
        .background(Theme.Colors.systemBackground)
    }
}
#endif