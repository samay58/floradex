import SwiftUI

/// The specimen-plate chrome shared by sprite slots, icon plates, and
/// empty slots: paper fill, plate radius, hairline edge (dashed for slots
/// still waiting on a specimen), optional dither behind pixel artifacts.
struct SpecimenPlate<Content: View>: View {
    /// Square plate side; nil lets the content size the plate.
    var side: CGFloat?
    var dashed = false
    var dithered = false
    @ViewBuilder let content: Content

    var body: some View {
        ZStack {
            if dithered {
                DitherField()
            }
            content
        }
        .frame(width: side, height: side)
        .background(Color.floraPaper)
        .clipShape(RoundedRectangle(cornerRadius: Floradex.Radius.plate))
        .overlay(
            RoundedRectangle(cornerRadius: Floradex.Radius.plate)
                .strokeBorder(
                    Color.floraHairline,
                    style: StrokeStyle(lineWidth: 1, dash: dashed ? [4, 3] : [])
                )
        )
    }
}

extension View {
    /// White-matte mount for photographs: matte fill, hairline edge,
    /// resting shadow. The matte dims in dark mode instead of glowing.
    func photoMatte(inset: CGFloat = 3) -> some View {
        self
            .padding(inset)
            .background(Color.floraMatte, in: RoundedRectangle(cornerRadius: Floradex.Radius.plate))
            .overlay(
                RoundedRectangle(cornerRadius: Floradex.Radius.plate)
                    .strokeBorder(Color.floraHairline, lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.09), radius: 3, y: 1.5)
    }

    /// Chip chrome shared by seals, alternatives, and undo: hairline
    /// capsule, comfortable padding, and the 40pt hit floor that keeps
    /// small chips tappable.
    func floraChip(
        stroke: Color = .floraHairline,
        lineWidth: CGFloat = 1,
        horizontalPadding: CGFloat = 10,
        verticalPadding: CGFloat = 5
    ) -> some View {
        self
            .padding(.horizontal, horizontalPadding)
            .padding(.vertical, verticalPadding)
            .overlay(Capsule().strokeBorder(stroke, lineWidth: lineWidth))
            .frame(minHeight: 40)
            .contentShape(Rectangle())
    }
}
