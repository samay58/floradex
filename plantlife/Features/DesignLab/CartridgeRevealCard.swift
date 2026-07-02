#if DEBUG
import SwiftUI
import FloradexKit

/// Direction 2, collection-game well: the dex as a game artifact. Inked
/// frame, one accent stripe along the top edge, a dithered slot holding the
/// sprite at exactly 3x, confidence as a chunky three-segment band meter,
/// and Departure Mono auditioning on the meter label and countdown digits.
struct CartridgeRevealCard: View {
    let fixture: LabFixture
    @State private var showsRawConfidence = false

    private let shell = Color.lab(
        Color(red: 0.984, green: 0.980, blue: 0.961),
        Color(red: 0.098, green: 0.106, blue: 0.094)
    )
    private let frameInk = Color.lab(
        Color(red: 0.125, green: 0.259, blue: 0.184),
        Color(red: 0.624, green: 0.847, blue: 0.722)
    )
    private let brand = Color(red: 0.180, green: 0.722, blue: 0.459)

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header
            meterRow
            alternatives
            careLines
            footer
        }
        .padding(16)
        .padding(.top, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(shell)
        .overlay(alignment: .top) {
            Rectangle()
                .fill(brand)
                .frame(height: 10)
        }
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(frameInk, lineWidth: 2)
        )
        .shadow(color: .black.opacity(0.14), radius: 14, y: 6)
        .padding(.horizontal, 12)
    }

    private var header: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(uiImage: fixture.photo)
                .resizable()
                .scaledToFill()
                .frame(width: 56, height: 56)
                .clipShape(RoundedRectangle(cornerRadius: 4))
                .overlay(RoundedRectangle(cornerRadius: 4).strokeBorder(frameInk, lineWidth: 1.5))
            VStack(alignment: .leading, spacing: 3) {
                Text(fixture.result.species.displayName)
                    .font(.title3.weight(.bold))
                Text(fixture.result.species.latinName)
                    .font(.caption.italic())
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            spriteSlot
        }
    }

    /// The sprite at exactly 3x (16 px art in a 48 pt frame) over a subtle
    /// dither checker, framed like a cartridge window.
    private var spriteSlot: some View {
        ZStack {
            DitherField(cell: 4, tint: frameInk.opacity(0.08))
            Image(uiImage: fixture.sprite)
                .resizable()
                .interpolation(.none)
                .frame(width: 48, height: 48)
        }
        .frame(width: 64, height: 64)
        .background(shell)
        .clipShape(RoundedRectangle(cornerRadius: 4))
        .overlay(RoundedRectangle(cornerRadius: 4).strokeBorder(frameInk, lineWidth: 1.5))
    }

    private var meterRow: some View {
        HStack(spacing: 10) {
            Button {
                showsRawConfidence.toggle()
            } label: {
                HStack(spacing: 8) {
                    HStack(spacing: 3) {
                        ForEach(0..<3) { index in
                            RoundedRectangle(cornerRadius: 1.5)
                                .fill(index < fixture.bandRank
                                      ? Color.labBand(fixture.result.band)
                                      : Color.primary.opacity(0.12))
                                .frame(width: 16, height: 8)
                        }
                    }
                    Text(showsRawConfidence ? fixture.rawConfidenceLabel : fixture.bandLabel)
                        .font(.labPixel(12))
                        .textCase(.uppercase)
                        .foregroundStyle(Color.labBand(fixture.result.band))
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
                                .font(.caption.weight(.medium))
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 4)
                                        .strokeBorder(frameInk.opacity(0.7), lineWidth: 1.5)
                                )
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
                        .font(.caption.weight(.medium))
                    Text("Undo")
                        .font(.caption.weight(.medium))
                    Text(fixture.undoDeadline, style: .timer)
                        .font(.labPixel(12))
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .overlay(
                    RoundedRectangle(cornerRadius: 4)
                        .strokeBorder(frameInk, lineWidth: 1.5)
                )
                .frame(minHeight: 40)
                .contentShape(Rectangle())
            }
            .buttonStyle(LabPressStyle())
            Spacer()
        }
    }
}

/// A quiet checkerboard evoking a sprite editor's transparency grid.
private struct DitherField: View {
    let cell: CGFloat
    let tint: Color

    var body: some View {
        Canvas { context, size in
            let columns = Int(ceil(size.width / cell))
            let rows = Int(ceil(size.height / cell))
            for row in 0..<rows {
                for column in 0..<columns where (row + column).isMultiple(of: 2) {
                    let rect = CGRect(
                        x: CGFloat(column) * cell,
                        y: CGFloat(row) * cell,
                        width: cell,
                        height: cell
                    )
                    context.fill(Path(rect), with: .color(tint))
                }
            }
        }
    }
}

#Preview("Cartridge") {
    ZStack {
        Color(white: 0.2).ignoresSafeArea()
        CartridgeRevealCard(fixture: .make())
    }
}
#endif
