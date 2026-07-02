import SwiftUI
import SwiftData
import FloradexKit

/// The full herbarium sheet: one continuous paper surface with the mounted
/// photograph, taxonomy in serif, and ruled sections whose typed field
/// labels render only for content that exists. Long-form detail lives here
/// so the reveal card never has to scroll.
struct EntryDetailView: View {
    @Bindable var entry: DexEntryV2
    let store: SwiftDataDexStore
    let media: FileMediaStore

    @Environment(\.dismiss) private var dismiss
    @State private var photo: UIImage?
    @State private var confirmingDelete = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Floradex.Space.l) {
                hero
                taxonomy
                if let summary = entry.species?.summary, !summary.isEmpty {
                    section("About") {
                        Text(summary)
                    }
                }
                careSection
                funFactsSection
                notesSection
                provenanceLine
            }
            .padding(.horizontal)
            .padding(.bottom, 32)
        }
        .background(Color.floraPaper)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text("#\(entry.number)")
                    .font(.floraNumber(.tile))
                    .foregroundStyle(Color.floraPixelInk)
                    .accessibilityLabel("Number \(entry.number)")
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button(role: .destructive) {
                    confirmingDelete = true
                } label: {
                    Label("Delete", systemImage: "trash")
                }
                // Destructive stays red; without this it inherits the
                // brand tint from the tab root.
                .tint(.red)
            }
        }
        .confirmationDialog(
            "Delete #\(entry.number)? Its number retires with it and is never reused.",
            isPresented: $confirmingDelete,
            titleVisibility: .visible
        ) {
            Button("Delete entry", role: .destructive) {
                let number = entry.number
                Task {
                    try? await store.delete(DexNumber(number))
                    dismiss()
                }
            }
        }
        .task {
            if let data = await media.readOriginalPhoto(for: EntryID(rawValue: entry.mediaID)) {
                photo = UIImage(data: data)
            }
        }
    }

    /// The mounted photograph, sprite plate tipped in at the corner.
    private var hero: some View {
        ZStack(alignment: .bottomTrailing) {
            Group {
                if let photo {
                    Image(uiImage: photo)
                        .resizable()
                        .scaledToFill()
                        .frame(maxWidth: .infinity)
                        .frame(height: 260)
                        .clipShape(RoundedRectangle(cornerRadius: Floradex.Radius.plate - 1))
                } else {
                    ZStack {
                        DitherField()
                        Image(systemName: "leaf.fill")
                            .font(.largeTitle)
                            .foregroundStyle(Color.floraGreen.opacity(0.45))
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 160)
                    .clipShape(RoundedRectangle(cornerRadius: Floradex.Radius.plate - 1))
                }
            }
            .photoMatte(inset: 5)

            EntrySpriteView(entry: entry, media: media)
                .frame(width: 72, height: 72)
                .padding(Floradex.Space.m)
        }
    }

    private var taxonomy: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(entry.displayName)
                .font(.floraDisplayLarge)
            if let latin = entry.species?.latinName, entry.species?.commonName != nil {
                Text(latin)
                    .font(.floraLatin)
                    .foregroundStyle(.secondary)
            }
            if let family = entry.species?.family {
                Text(family)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            if !entry.tags.isEmpty {
                FlowLayout(spacing: 6) {
                    ForEach(entry.tags, id: \.self) { tag in
                        Text(tag)
                            .font(.caption)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .overlay(Capsule().strokeBorder(Color.floraHairline, lineWidth: 1))
                    }
                }
                .padding(.top, Floradex.Space.s)
            }
        }
    }

    @ViewBuilder
    private var careSection: some View {
        let care: [(String, String, String?)] = [
            ("sun.max", "Sunlight", entry.species?.sunlight),
            ("drop", "Water", entry.species?.water),
            ("square.3.layers.3d.down.left", "Soil", entry.species?.soil),
            ("thermometer.medium", "Temperature", entry.species?.temperature),
            ("camera.macro", "Bloom time", entry.species?.bloomTime),
        ]
        let present = care.compactMap { icon, label, value in value.map { (icon, label, $0) } }
        if !present.isEmpty {
            section("Care") {
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(present, id: \.1) { icon, label, value in
                        HStack(alignment: .firstTextBaseline, spacing: 10) {
                            Image(systemName: icon)
                                .foregroundStyle(.secondary)
                                .frame(width: 22)
                            VStack(alignment: .leading, spacing: 1) {
                                Text(label)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Text(value)
                            }
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var funFactsSection: some View {
        if let facts = entry.species?.funFacts, !facts.isEmpty {
            section("Fun facts") {
                VStack(alignment: .leading, spacing: Floradex.Space.s) {
                    ForEach(facts, id: \.self) { fact in
                        HStack(alignment: .firstTextBaseline, spacing: Floradex.Space.s) {
                            Image(systemName: "sparkle")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text(fact)
                        }
                    }
                }
            }
        }
    }

    private var notesSection: some View {
        section("Field notes") {
            TextField("Anything worth remembering about this one?", text: notesBinding, axis: .vertical)
                .lineLimit(2...8)
                .textFieldStyle(.plain)
        }
    }

    private var notesBinding: Binding<String> {
        Binding(
            get: { entry.notes ?? "" },
            set: { entry.notes = $0.isEmpty ? nil : $0 }
        )
    }

    @ViewBuilder
    private var provenanceLine: some View {
        if let line = provenanceDescription {
            Text(line)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var provenanceDescription: String? {
        guard let data = entry.provenance,
              let result = try? JSONDecoder().decode(IdentificationResult.self, from: data) else {
            return nil
        }
        let sources = result.contributingProviderCount
        var parts = [
            sources == 1 ? "Identified by 1 source" : "Identified by \(sources) sources",
            result.band.rawValue,
        ]
        if result.origin == .userCorrection {
            parts.append("corrected by you")
        }
        return parts.joined(separator: " · ") + " · " + entry.createdAt.formatted(date: .abbreviated, time: .omitted)
    }

    /// A ruled section with a typed field label: the herbarium sheet's
    /// grammar, replacing stacked boxes with one continuous surface.
    private func section(_ title: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: Floradex.Space.s) {
            Rectangle()
                .fill(Color.floraHairline)
                .frame(height: 1)
            Text(title)
                .font(.caption.weight(.semibold))
                .textCase(.uppercase)
                .tracking(0.8)
                .foregroundStyle(.secondary)
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
