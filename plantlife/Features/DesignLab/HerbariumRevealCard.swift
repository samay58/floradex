#if DEBUG
import SwiftUI
import FloradexKit

/// Direction 1, field-guide well: a specimen label typed by someone who
/// loves this. Opaque warm paper, hairline rules, New York serif for the
/// name, the confidence band as a stamped seal. The pixel sprite sits in a
/// bordered plate like a tipped-in illustration.
struct HerbariumRevealCard: View {
    let fixture: LabFixture
    @State private var showsRawConfidence = false

    private let paper = Color.lab(
        Color(red: 0.984, green: 0.976, blue: 0.956),
        Color(red: 0.118, green: 0.110, blue: 0.094)
    )
    private let hairline = Color.lab(
        Color(red: 0.847, green: 0.827, blue: 0.776),
        Color(white: 0.28)
    )

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
                .padding(.bottom, 14)
            rule
            trustRow
                .padding(.vertical, 12)
            alternatives
                .padding(.bottom, 12)
            rule
            careLines
                .padding(.top, 12)
                .padding(.bottom, 14)
            footer
        }
        .padding(18)
        .background(paper, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(hairline, lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.10), radius: 18, y: 8)
        .shadow(color: .black.opacity(0.06), radius: 3, y: 1)
        .padding(.horizontal, 12)
    }

    private var header: some View {
        HStack(alignment: .top, spacing: 12) {
            mountedPhoto
            VStack(alignment: .leading, spacing: 3) {
                Text(fixture.result.species.displayName)
                    .font(.title3.weight(.semibold))
                    .fontDesign(.serif)
                Text(fixture.result.species.latinName)
                    .font(.subheadline.italic())
                    .fontDesign(.serif)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            spritePlate
        }
    }

    /// A mounted photograph: white matte, hairline edge, resting shadow.
    private var mountedPhoto: some View {
        Image(uiImage: fixture.photo)
            .resizable()
            .scaledToFill()
            .frame(width: 56, height: 56)
            .clipShape(RoundedRectangle(cornerRadius: 2))
            .padding(3)
            .background(.white, in: RoundedRectangle(cornerRadius: 3))
            .overlay(RoundedRectangle(cornerRadius: 3).strokeBorder(hairline, lineWidth: 1))
            .shadow(color: .black.opacity(0.10), radius: 2, y: 1)
    }

    /// The sprite as a tipped-in botanical plate.
    private var spritePlate: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 3)
                .fill(paper)
            RoundedRectangle(cornerRadius: 3)
                .strokeBorder(hairline, lineWidth: 1)
            Image(uiImage: fixture.sprite)
                .resizable()
                .interpolation(.none)
                .frame(width: 48, height: 48)
        }
        .frame(width: 62, height: 62)
    }

    private var trustRow: some View {
        HStack(spacing: 10) {
            seal
            if let sources = fixture.sourcesLine {
                Text(sources)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
    }

    /// The confidence band as a stamped seal: inked outline, a hair off
    /// square. Raw number on tap, never hidden.
    private var seal: some View {
        Button {
            showsRawConfidence.toggle()
        } label: {
            Text(showsRawConfidence ? fixture.rawConfidenceLabel : fixture.bandLabel)
                .font(.caption.weight(.semibold))
                .textCase(.uppercase)
                .tracking(0.8)
                .foregroundStyle(Color.labBand(fixture.result.band))
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .overlay(
                    Capsule()
                        .strokeBorder(Color.labBand(fixture.result.band).opacity(0.55), lineWidth: 1.25)
                )
                .rotationEffect(.degrees(-1.5))
                .frame(minHeight: 40)
                .contentShape(Rectangle())
        }
        .buttonStyle(LabPressStyle())
    }

    /// Label pinned outside the scroller so it never scrolls away.
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
                                .fontDesign(.serif)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .overlay(Capsule().strokeBorder(hairline, lineWidth: 1))
                                .frame(minHeight: 40)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(LabPressStyle())
                    }
                }
            }
        }
    }

    private var careLines: some View {
        VStack(alignment: .leading, spacing: 6) {
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
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .overlay(Capsule().strokeBorder(hairline, lineWidth: 1))
                .frame(minHeight: 40)
                .contentShape(Rectangle())
            }
            .buttonStyle(LabPressStyle())
            Spacer()
        }
    }

    private var rule: some View {
        Rectangle()
            .fill(hairline)
            .frame(height: 1)
    }
}

#Preview("Herbarium") {
    ZStack {
        Color(white: 0.2).ignoresSafeArea()
        HerbariumRevealCard(fixture: .make())
    }
}
#endif
