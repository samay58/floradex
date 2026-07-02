import SwiftUI
import SwiftData
import FloradexKit

/// Full entry screen: photo hero, taxonomy, care rendered only for fields
/// that exist, field notes, and provenance. Long-form detail lives here so
/// the reveal card never has to scroll.
struct EntryDetailView: View {
    @Bindable var entry: DexEntryV2
    let store: SwiftDataDexStore
    let media: FileMediaStore

    @Environment(\.dismiss) private var dismiss
    @State private var photo: UIImage?
    @State private var confirmingDelete = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
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
        .navigationTitle("#\(entry.number)")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button(role: .destructive) {
                    confirmingDelete = true
                } label: {
                    Label("Delete", systemImage: "trash")
                }
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

    private var hero: some View {
        ZStack(alignment: .bottomTrailing) {
            if let photo {
                Image(uiImage: photo)
                    .resizable()
                    .scaledToFill()
                    .frame(maxWidth: .infinity)
                    .frame(height: 260)
                    .clipShape(RoundedRectangle(cornerRadius: 20))
            } else {
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color.floraGreen.opacity(0.1))
                    .frame(height: 160)
                    .overlay {
                        Image(systemName: "leaf.fill")
                            .font(.largeTitle)
                            .foregroundStyle(Color.floraGreen.opacity(0.4))
                    }
            }
            EntrySpriteView(entry: entry, media: media)
                .frame(width: 72, height: 72)
                .padding(10)
        }
    }

    private var taxonomy: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(entry.species?.commonName ?? entry.species?.latinName ?? "Unknown")
                .font(.title2.weight(.semibold))
            if let latin = entry.species?.latinName, entry.species?.commonName != nil {
                Text(latin)
                    .font(.subheadline.italic())
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
                            .background(.quaternary.opacity(0.6), in: Capsule())
                    }
                }
                .padding(.top, 6)
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
                                .foregroundStyle(Color.floraGreen)
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
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(facts, id: \.self) { fact in
                        HStack(alignment: .firstTextBaseline, spacing: 8) {
                            Image(systemName: "sparkle")
                                .font(.caption)
                                .foregroundStyle(Color.floraGreen)
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
        let sources = Set(result.contributing.map(\.provider)).count
        var parts = [
            sources == 1 ? "Identified by 1 source" : "Identified by \(sources) sources",
        ]
        switch result.band {
        case .confident: parts.append("confident")
        case .likely: parts.append("likely")
        case .unsure: parts.append("unsure")
        }
        if result.origin == .userCorrection {
            parts.append("corrected by you")
        }
        return parts.joined(separator: " · ") + " · " + entry.createdAt.formatted(date: .abbreviated, time: .omitted)
    }

    private func section(_ title: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(.quaternary.opacity(0.4), in: RoundedRectangle(cornerRadius: 14))
    }
}
