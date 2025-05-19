import SwiftUI

/// A circular pixel-style gauge inspired by retro GameBoy HP meters.
/// - Parameter value: 0…1 progress.
struct PixelGauge: View {
    var value: Double // 0 – 1
    var size: CGFloat = 60
    var foreground: Color = .green
    var background: Color = .gray.opacity(0.25)

    var body: some View {
        ZStack {
            PixelRing(progress: 1.0)
                .fill(background)
            PixelRing(progress: value)
                .fill(foreground)
        }
        .frame(width: size, height: size)
    }
}

// MARK: ‑ Shape Drawing ring composed of small square pixels
fileprivate struct PixelRing: Shape {
    var progress: Double // 0…1
    var segments: Int = 60

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let radius = min(rect.width, rect.height) / 2
        let pixel = max(2, radius * 0.08)
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let activeSegments = Int(Double(segments) * progress.clamped(to: 0...1))
        for i in 0..<activeSegments {
            let angle = Double(i) / Double(segments) * 2 * Double.pi - Double.pi / 2
            let x = center.x + CGFloat(cos(angle)) * (radius - pixel)
            let y = center.y + CGFloat(sin(angle)) * (radius - pixel)
            path.addRect(CGRect(x: x - pixel/2, y: y - pixel/2, width: pixel, height: pixel))
        }
        return path
    }
}

#if DEBUG
#Preview("PixelGauge 75%") {
    PixelGauge(value: 0.75, size: 80, foreground: .green)
        .padding()
        .previewLayout(.sizeThatFits)
}
#endif 