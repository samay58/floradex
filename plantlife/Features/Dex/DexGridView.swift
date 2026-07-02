import SwiftUI
import SwiftData
import FloradexKit

/// The collection tab: sprites, permanent numbers, honest gaps. Grid first
/// with a plain-list escape hatch, search over names and tags, and a
/// selection mode for batch delete (numbers retire, never reassign).
/// Retired numbers stay visible in number order as quiet absences.
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
    @Query private var ledgers: [DexLedger]
    @State private var searchText = ""
    @State private var sortOption: SortOption = .number
    @State private var showsList = false
    @State private var isSelecting = false
    @State private var selectedNumbers: Set<Int> = []
    @State private var navigationPath = NavigationPath()
    #if DEBUG
    @State private var hasAutoOpenedEntry = false
    #endif

    private var retiredNumbers: [Int] {
        ledgers.first?.retired ?? []
    }

    var body: some View {
        NavigationStack(path: $navigationPath) {
            Group {
                if entries.isEmpty && retiredNumbers.isEmpty {
                    emptyState
                } else if !searchText.isEmpty && visibleEntries.isEmpty {
                    ContentUnavailableView.search(text: searchText)
                } else if showsList {
                    listContent
                } else {
                    // An all-deleted collection still reaches the grid so
                    // the retired-number gaps stay on record.
                    gridContent
                }
            }
            .background(Color.floraGround)
            .navigationTitle("Floradex")
            .searchable(text: $searchText, prompt: "Name or tag")
            .toolbar { toolbarContent }
            .navigationDestination(for: PersistentIdentifier.self) { id in
                if let entry = entries.first(where: { $0.persistentModelID == id }) {
                    EntryDetailView(entry: entry, store: store, media: media)
                }
            }
        }
        #if DEBUG
        // Screenshot and Maestro harness: opens the first entry once, even
        // when fixtures seed after first render; re-appearing tabs must not
        // push duplicates. Pairs with DebugFlags.initialTab.
        .task(id: entries.first?.persistentModelID) {
            if DebugFlags.opensFirstEntry, !hasAutoOpenedEntry, let first = entries.first {
                hasAutoOpenedEntry = true
                navigationPath.append(first.persistentModelID)
            }
        }
        #endif
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
            return result.sorted { $0.displayName < $1.displayName }
        }
    }

    /// Grid cells: entries, with retired numbers interleaved as designed
    /// absences. Gaps stay put during selection so tiles don't reflow under
    /// the user's finger; they only leave for search and non-number sorts.
    private var gridCells: [DexCell] {
        let entryCells = visibleEntries.map(DexCell.entry)
        guard sortOption == .number, searchText.isEmpty,
              !retiredNumbers.isEmpty else {
            return entryCells
        }
        return (entryCells + retiredNumbers.map(DexCell.gap))
            .sorted { $0.number < $1.number }
    }

    private var gridContent: some View {
        ScrollView {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: Floradex.Space.m)], spacing: Floradex.Space.m) {
                ForEach(gridCells) { cell in
                    switch cell {
                    case .entry(let entry):
                        tile(for: entry)
                    case .gap(let number):
                        GapTile(number: number)
                    }
                }
            }
            .padding(.horizontal)
        }
    }

    private var listContent: some View {
        List(visibleEntries) { entry in
            row(for: entry)
                .listRowBackground(Color.clear)
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
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

    /// First-run scene: an empty plate waiting for its first specimen.
    private var emptyState: some View {
        VStack(spacing: Floradex.Space.m) {
            SpecimenPlate(side: 72, dashed: true, dithered: true) {
                Image(systemName: "leaf.fill")
                    .font(.title2)
                    .foregroundStyle(Color.floraGreen.opacity(0.45))
            }
            .padding(.bottom, Floradex.Space.xs)
            Text("No plants yet")
                .font(.floraDisplay)
            Text("Identify your first plant and it lands here with a permanent number.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 48)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
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

private enum DexCell: Identifiable {
    case entry(DexEntryV2)
    case gap(Int)

    var number: Int {
        switch self {
        case .entry(let entry): return entry.number
        case .gap(let number): return number
        }
    }

    var id: String {
        switch self {
        case .entry: return "entry-\(number)"
        case .gap: return "gap-\(number)"
        }
    }
}

/// A collected specimen: sprite plate, pixel number, name. Paper on ground.
private struct DexTile: View {
    let entry: DexEntryV2
    let media: FileMediaStore
    /// nil hides the selection indicator entirely.
    let isSelected: Bool?

    var body: some View {
        VStack(spacing: Floradex.Space.s) {
            EntrySpriteView(entry: entry, media: media)
                .frame(width: 96, height: 96)
            Text("#\(entry.number)")
                .font(.floraNumber(.tile))
                .foregroundStyle(Color.floraPixelInk)
            Text(entry.displayName)
                .font(.caption)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(Color.floraPaper, in: RoundedRectangle(cornerRadius: Floradex.Radius.tile, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Floradex.Radius.tile, style: .continuous)
                .strokeBorder(Color.floraHairline, lineWidth: 1)
        )
        .overlay(alignment: .topTrailing) {
            if let isSelected {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(isSelected ? Color.floraGreen : .secondary)
                    .padding(Floradex.Space.s)
            }
        }
    }
}

/// A retired number: the slot stays, quietly. Numbers are never reused.
private struct GapTile: View {
    let number: Int

    var body: some View {
        // Mirrors DexTile's scaffold; the hidden name line reserves the
        // same caption height so gap tiles stay flush with their row.
        VStack(spacing: Floradex.Space.s) {
            Color.clear
                .frame(width: 96, height: 96)
            Text("#\(number)")
                .font(.floraNumber(.tile))
                .foregroundStyle(Color.floraPixelInk.opacity(0.28))
            Text("Unknown")
                .font(.caption)
                .lineLimit(1)
                .hidden()
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .overlay(
            RoundedRectangle(cornerRadius: Floradex.Radius.tile, style: .continuous)
                .strokeBorder(Color.floraHairline.opacity(0.6), style: StrokeStyle(lineWidth: 1, dash: [4, 3]))
        )
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Number \(number), retired")
    }
}

private struct DexRow: View {
    let entry: DexEntryV2
    let media: FileMediaStore
    let isSelected: Bool?

    var body: some View {
        HStack(spacing: Floradex.Space.m) {
            EntrySpriteView(entry: entry, media: media)
                .frame(width: 44, height: 44)
            VStack(alignment: .leading, spacing: 2) {
                Text(entry.displayName)
                    .font(.body)
                if let latin = entry.species?.latinName {
                    Text(latin)
                        .font(.floraLatinSmall)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            Text("#\(entry.number)")
                .font(.floraNumber(.row))
                .foregroundStyle(Color.floraPixelInk)
            if let isSelected {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(isSelected ? Color.floraGreen : .secondary)
            }
        }
    }
}

/// Sprite from disk when one exists (in its dithered plate); otherwise the
/// original photo as a thumbnail; otherwise a placeholder leaf.
struct EntrySpriteView: View {
    let entry: DexEntryV2
    let media: FileMediaStore
    @State private var image: UIImage?
    @State private var isSprite = false

    var body: some View {
        SpecimenPlate(dithered: true) {
            if let image {
                if isSprite {
                    PixelScaledImage(image: image)
                        .padding(6)
                } else {
                    Image(uiImage: image)
                        .resizable()
                        .interpolation(.medium)
                        .scaledToFit()
                }
            } else {
                Image(systemName: "leaf.fill")
                    .foregroundStyle(Color.floraGreen.opacity(0.45))
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
