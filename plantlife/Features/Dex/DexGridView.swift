import SwiftUI
import SwiftData
import FloradexKit

/// The collection tab: sprites, permanent numbers, honest gaps. Grid first
/// with a plain-list escape hatch, search over names and tags, and a
/// selection mode for batch delete (numbers retire, never reassign).
struct DexGridView: View {
    enum SortOption: String, CaseIterable, Identifiable {
        case number = "Number"
        case newest = "Newest"
        case name = "Name"
        var id: String { rawValue }
    }

    let store: SwiftDataDexStore
    let media: FileMediaStore

    @Query(sort: \DexEntryV2.number) private var entries: [DexEntryV2]
    @State private var searchText = ""
    @State private var sortOption: SortOption = .number
    @State private var showsList = false
    @State private var isSelecting = false
    @State private var selectedNumbers: Set<Int> = []

    var body: some View {
        NavigationStack {
            Group {
                if entries.isEmpty {
                    emptyState
                } else if showsList {
                    listContent
                } else {
                    gridContent
                }
            }
            .navigationTitle("Floradex")
            .searchable(text: $searchText, prompt: "Name or tag")
            .toolbar { toolbarContent }
            .navigationDestination(for: PersistentIdentifier.self) { id in
                if let entry = entries.first(where: { $0.persistentModelID == id }) {
                    EntryDetailView(entry: entry, store: store, media: media)
                }
            }
        }
    }

    private var visibleEntries: [DexEntryV2] {
        var result = entries
        if !searchText.isEmpty {
            result = result.filter { entry in
                let species = entry.species
                return species?.latinName.localizedCaseInsensitiveContains(searchText) ?? false
                    || species?.commonName?.localizedCaseInsensitiveContains(searchText) ?? false
                    || entry.tags.contains { $0.localizedCaseInsensitiveContains(searchText) }
            }
        }
        switch sortOption {
        case .number:
            return result
        case .newest:
            return result.sorted { $0.createdAt > $1.createdAt }
        case .name:
            return result.sorted { displayName(for: $0) < displayName(for: $1) }
        }
    }

    private func displayName(for entry: DexEntryV2) -> String {
        entry.species.map { $0.commonName ?? $0.latinName } ?? "Unknown"
    }

    private var gridContent: some View {
        ScrollView {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 12)], spacing: 12) {
                ForEach(visibleEntries) { entry in
                    tile(for: entry)
                }
            }
            .padding(.horizontal)
        }
    }

    private var listContent: some View {
        List(visibleEntries) { entry in
            row(for: entry)
        }
        .listStyle(.plain)
    }

    @ViewBuilder
    private func tile(for entry: DexEntryV2) -> some View {
        if isSelecting {
            Button {
                toggleSelection(entry.number)
            } label: {
                DexTile(entry: entry, media: media, isSelected: selectedNumbers.contains(entry.number))
            }
            .buttonStyle(.plain)
        } else {
            NavigationLink(value: entry.persistentModelID) {
                DexTile(entry: entry, media: media, isSelected: nil)
            }
            .buttonStyle(.plain)
            .contextMenu {
                Button(role: .destructive) {
                    delete([entry.number])
                } label: {
                    Label("Delete", systemImage: "trash")
                }
            }
        }
    }

    @ViewBuilder
    private func row(for entry: DexEntryV2) -> some View {
        if isSelecting {
            Button {
                toggleSelection(entry.number)
            } label: {
                DexRow(entry: entry, media: media, isSelected: selectedNumbers.contains(entry.number))
            }
            .buttonStyle(.plain)
        } else {
            NavigationLink(value: entry.persistentModelID) {
                DexRow(entry: entry, media: media, isSelected: nil)
            }
            .swipeActions {
                Button(role: .destructive) {
                    delete([entry.number])
                } label: {
                    Label("Delete", systemImage: "trash")
                }
            }
        }
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItemGroup(placement: .topBarTrailing) {
            if isSelecting {
                Button(role: .destructive) {
                    delete(Array(selectedNumbers))
                } label: {
                    Label("Delete Selected", systemImage: "trash")
                }
                .disabled(selectedNumbers.isEmpty)
                Button("Done") {
                    isSelecting = false
                    selectedNumbers.removeAll()
                }
            } else {
                Menu {
                    Picker("Sort", selection: $sortOption) {
                        ForEach(SortOption.allCases) { option in
                            Text(option.rawValue).tag(option)
                        }
                    }
                    Toggle("List View", isOn: $showsList)
                    Button("Select") { isSelecting = true }
                } label: {
                    Label("View Options", systemImage: "ellipsis.circle")
                }
            }
        }
    }

    private var emptyState: some View {
        ContentUnavailableView {
            Label("No plants yet", systemImage: "leaf")
        } description: {
            Text("Identify your first plant and it lands here with a permanent number.")
        }
    }

    private func toggleSelection(_ number: Int) {
        if selectedNumbers.contains(number) {
            selectedNumbers.remove(number)
        } else {
            selectedNumbers.insert(number)
        }
    }

    private func delete(_ numbers: [Int]) {
        Task {
            for number in numbers {
                try? await store.delete(DexNumber(number))
            }
            selectedNumbers.removeAll()
        }
    }
}

private struct DexTile: View {
    let entry: DexEntryV2
    let media: FileMediaStore
    /// nil hides the selection indicator entirely.
    let isSelected: Bool?

    var body: some View {
        VStack(spacing: 8) {
            EntrySpriteView(entry: entry, media: media)
                .frame(width: 96, height: 96)
            Text("#\(entry.number)")
                .font(.headline.monospacedDigit())
                .foregroundStyle(Theme.Colors.primaryGreen)
            Text(entry.species.map { $0.commonName ?? $0.latinName } ?? "Unknown")
                .font(.caption)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(.quaternary.opacity(0.4), in: RoundedRectangle(cornerRadius: 16))
        .overlay(alignment: .topTrailing) {
            if let isSelected {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(isSelected ? Theme.Colors.primaryGreen : .secondary)
                    .padding(8)
            }
        }
    }
}

private struct DexRow: View {
    let entry: DexEntryV2
    let media: FileMediaStore
    let isSelected: Bool?

    var body: some View {
        HStack(spacing: 12) {
            EntrySpriteView(entry: entry, media: media)
                .frame(width: 44, height: 44)
            VStack(alignment: .leading, spacing: 2) {
                Text(entry.species.map { $0.commonName ?? $0.latinName } ?? "Unknown")
                    .font(.body)
                if let latin = entry.species?.latinName {
                    Text(latin)
                        .font(.caption.italic())
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            Text("#\(entry.number)")
                .font(.subheadline.monospacedDigit())
                .foregroundStyle(Theme.Colors.primaryGreen)
            if let isSelected {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(isSelected ? Theme.Colors.primaryGreen : .secondary)
            }
        }
    }
}

/// Sprite from disk when one exists; otherwise the original photo as a
/// thumbnail; otherwise a placeholder leaf.
struct EntrySpriteView: View {
    let entry: DexEntryV2
    let media: FileMediaStore
    @State private var image: UIImage?
    @State private var isSprite = false

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 10)
                .fill(Theme.Colors.primaryGreen.opacity(0.1))
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .interpolation(isSprite ? .none : .medium)
                    .scaledToFit()
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            } else {
                Image(systemName: "leaf.fill")
                    .foregroundStyle(Theme.Colors.primaryGreen.opacity(0.45))
            }
        }
        .task(id: entry.spriteVersion) {
            let entryID = EntryID(rawValue: entry.mediaID)
            if entry.spriteVersion > 0, let sprite = await media.latestSprite(for: entryID),
               let decoded = UIImage(data: sprite.data) {
                image = decoded
                isSprite = true
            } else if let photo = await media.readOriginalPhoto(for: entryID),
                      let decoded = UIImage(data: photo) {
                image = decoded
                isSprite = false
            }
        }
    }
}
