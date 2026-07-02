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

    var body: some View {
        NavigationStack(path: $navigationPath) {
            Group {
                if entries.isEmpty {
                    emptyState
                } else if showsList {
                    listContent
                } else {
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
        // Screenshot and Maestro harness: FLORADEX_ENTRY=1 opens the first
        // entry. Pairs with FLORADEX_TAB=dex.
        .task {
            if ProcessInfo.processInfo.environment["FLORADEX_ENTRY"] == "1",
               let first = entries.first {
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
            return result.sorted { displayName(for: $0) < displayName(for: $1) }
        }
    }

    /// Grid cells: entries, with retired numbers interleaved as designed
    /// absences. Gaps only appear in number order with nothing filtered and
    /// no selection under way.
    private var gridCells: [DexCell] {
        let entryCells = visibleEntries.map(DexCell.entry)
        guard sortOption == .number, searchText.isEmpty, !isSelecting,
              let retired = ledgers.first?.retired, !retired.isEmpty else {
            return entryCells
        }
        return (entryCells + retired.map(DexCell.gap))
            .sorted { $0.number < $1.number }
    }

    private func displayName(for entry: DexEntryV2) -> String {
        entry.species.map { $0.commonName ?? $0.latinName } ?? "Unknown"
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
            ZStack {
                DitherField()
                Image(systemName: "leaf.fill")
                    .font(.system(size: 26))
                    .foregroundStyle(Color.floraGreen.opacity(0.45))
            }
            .frame(width: 72, height: 72)
            .background(Color.floraPaper)
            .clipShape(RoundedRectangle(cornerRadius: Floradex.Radius.plate))
            .overlay(
                RoundedRectangle(cornerRadius: Floradex.Radius.plate)
                    .strokeBorder(Color.floraHairline, style: StrokeStyle(lineWidth: 1, dash: [4, 3]))
            )
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
            Text(entry.species.map { $0.commonName ?? $0.latinName } ?? "Unknown")
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
        VStack(spacing: Floradex.Space.s) {
            Color.clear
                .frame(width: 96, height: 96)
            Text("#\(number)")
                .font(.floraNumber(.tile))
                .foregroundStyle(Color.floraPixelInk.opacity(0.28))
            Text(" ")
                .font(.caption)
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
                Text(entry.species.map { $0.commonName ?? $0.latinName } ?? "Unknown")
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
        ZStack {
            DitherField()
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .interpolation(isSprite ? .none : .medium)
                    .scaledToFit()
                    .padding(isSprite ? 6 : 0)
            } else {
                Image(systemName: "leaf.fill")
                    .foregroundStyle(Color.floraGreen.opacity(0.45))
            }
        }
        .background(Color.floraPaper)
        .clipShape(RoundedRectangle(cornerRadius: Floradex.Radius.plate))
        .overlay(
            RoundedRectangle(cornerRadius: Floradex.Radius.plate)
                .strokeBorder(Color.floraHairline, lineWidth: 1)
        )
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
