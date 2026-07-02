#if DEBUG
import SwiftUI
import FloradexKit

/// Direction 3, machined instrument: Liquid Glass kept, one big typographic
/// decision doing the identity work. The name stands alone at display size;
/// status reads as an indicator lamp beside quiet captions; imagery sits in
/// a right-aligned pair of concentric slots. Monochrome except the band lamp.
struct InstrumentRevealCard: View {
    let fixture: LabFixture
    @State private var showsRawConfidence = false

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            nameBlock
            statusRow
            divider
            HStack(alignment: .top, spacing: 12) {
                careLines
                Spacer(minLength: 12)
                imagery
            }
            alternatives
            footer
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .strokeBorder(.white.opacity(0.22), lineWidth: 0.75)
        )
        .shadow(color: .black.opacity(0.12), radius: 24, y: 10)
        .padding(.horizontal, 12)
    }

    private var nameBlock: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(fixture.result.species.displayName)
                .font(.title2.weight(.semibold))
                .tracking(-0.3)
            Text(fixture.result.species.latinName)
                .font(.subheadline.italic())
                .foregroundStyle(.secondary)
        }
    }

    /// Band as an indicator lamp: the only color on the surface.
    private var statusRow: some View {
        HStack(spacing: 10) {
            Button {
                showsRawConfidence.toggle()
            } label: {
                HStack(spacing: 7) {
                    Circle()
                        .fill(Color.labBand(fixture.result.band))
                        .frame(width: 7, height: 7)
                    Text(showsRawConfidence ? fixture.rawConfidenceLabel : fixture.bandLabel)
                        .font(.caption.weight(.semibold))
                        .monospacedDigit()
                }
                .frame(minHeight: 40)
                .contentShape(Rectangle())
            }
            .buttonStyle(LabPressStyle())
            if let sources = fixture.sourcesLine {
                Text(sources)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
    }

    private var careLines: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let sunlight = fixture.details.care.sunlight {
                Label(sunlight, systemImage: "sun.max")
            }
            if let water = fixture.details.care.water {
                Label(water, systemImage: "drop")
            }
        }
        .font(.caption)
        .foregroundStyle(.secondary)
    }

    /// Photo and sprite as a matched pair of slots; card radius 24 minus
    /// 16 padding gives the concentric 8.
    private var imagery: some View {
        HStack(spacing: 8) {
            Image(uiImage: fixture.photo)
                .resizable()
                .scaledToFill()
                .frame(width: 52, height: 52)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .strokeBorder(.primary.opacity(0.08), lineWidth: 1)
                )
            ZStack {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(.primary.opacity(0.05))
                Image(uiImage: fixture.sprite)
                    .resizable()
                    .interpolation(.none)
                    .frame(width: 48, height: 48)
            }
            .frame(width: 52, height: 52)
        }
    }

    /// Label pinned outside the scroller: it never scrolls away, and vibrant
    /// text inside a ScrollView over Material fails to composite on the
    /// iOS 27 beta runtime.
    private var alternatives: some View {
        HStack(spacing: 8) {
            Text("Not it?")
                .font(.caption)
                .foregroundStyle(.secondary)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(fixture.result.alternatives, id: \.self) { alternative in
                    Button {
                        // Correction is wired in Phase C; the lab compares design.
                    } label: {
                        Text(alternative.species.displayName)
                            .font(.caption)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(.thinMaterial, in: Capsule())
                            .frame(minHeight: 40)
                            .contentShape(Rectangle())
                    }
                        .buttonStyle(LabPressStyle())
                    }
                }
            }
        }
    }

    private var footer: some View {
        HStack {
            Button {
                // Undo is wired in Phase C; the lab compares design.
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "arrow.uturn.backward")
                    Text("Undo")
                    Text(fixture.undoDeadline, style: .timer)
                        .monospacedDigit()
                }
                .font(.caption.weight(.medium))
            }
            .buttonStyle(.bordered)
            .tint(.primary)
            Spacer()
        }
    }

    private var divider: some View {
        Rectangle()
            .fill(.primary.opacity(0.08))
            .frame(height: 1)
    }
}

#Preview("Instrument") {
    ZStack {
        Color(white: 0.2).ignoresSafeArea()
        InstrumentRevealCard(fixture: .make())
    }
}
#endif
