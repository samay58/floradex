import SwiftUI

struct TagFilterView: View {
    let allTags: [String] // All available tags to display
    @Binding var selectedTags: Set<String> // Set of currently selected tags
    
    // Define a namespace for animations if we want to animate chip selection later
    @Namespace private var tagAnimation

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                // Optional: "All" button to clear selection
                TagChip(
                    tagName: "All", 
                    isSelected: selectedTags.isEmpty
                ) {
                    selectedTags.removeAll()
                }
                .padding(.leading) // Add padding to the first item

                ForEach(allTags, id: \.self) { tag in
                    TagChip(
                        tagName: tag,
                        isSelected: selectedTags.contains(tag)
                    ) {
                        if selectedTags.contains(tag) {
                            selectedTags.remove(tag)
                        } else {
                                    selectedTags.insert(tag)
                        }
                                }
                    .frame(height: 32) // Fix a height for consistent layout
                }
            }
            .padding(.vertical, 8) // Padding for the HStack within the ScrollView
        }
    }
}

#if DEBUG
struct TagFilterView_Previews: PreviewProvider {
    struct PreviewWrapper: View {
        @State private var availableTags = ["Indoor", "Outdoor", "Easy Care", "Foliage", "Flowering", "Succulent", "Pet Friendly", "Low Light"]
        @State private var currentSelections: Set<String> = ["Indoor", "Foliage"]

        var body: some View {
            VStack(alignment: .leading) {
                Text("Selected Tags: \(currentSelections.sorted().joined(separator: ", "))")
                    .padding()
                
                TagFilterView(allTags: availableTags, selectedTags: $currentSelections)
                
                Spacer()
                
                Button("Add Random Tag to List") {
                    let randomTag = "Tag\(Int.random(in: 1...100))"
                    if !availableTags.contains(randomTag) {
                        availableTags.append(randomTag)
                    }
                }
                .padding()
                
                Button("Toggle 'Succulent' Selection") {
                    if currentSelections.contains("Succulent") {
                        currentSelections.remove("Succulent")
                    } else {
                        currentSelections.insert("Succulent")
                    }
                }
                .padding()
            }
            .background(Theme.Colors.dexBackground)
            .navigationTitle("Filter by Tag")
        }
    }

    static var previews: some View {
        NavigationStack {
            PreviewWrapper()
        }
    }
}
#endif 