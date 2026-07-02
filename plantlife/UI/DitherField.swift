import SwiftUI

/// A quiet checkerboard evoking a sprite editor's transparency grid; sits
/// only behind pixel artifacts (sprite plates), never under prose. Cell
/// size stays a whole point multiple so the checker never shimmers.
struct DitherField: View {
    var cell: CGFloat = 4
    var tint: Color = .floraPixelInk.opacity(0.08)

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
