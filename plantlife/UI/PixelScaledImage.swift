import SwiftUI

/// Pixel art at honest scales: the display side is chosen so art pixels
/// map to whole device pixels. Upscales land on integer multiples of the
/// native grid; downscales land on integer decimations of it. Either way
/// nearest-neighbor sampling stays even, with no 1-and-2-pixel shimmer.
struct PixelScaledImage: View {
    let image: UIImage
    @Environment(\.displayScale) private var displayScale

    var body: some View {
        GeometryReader { proxy in
            let side = fittedSide(boxPt: min(proxy.size.width, proxy.size.height))
            Image(uiImage: image)
                .resizable()
                .interpolation(.none)
                .scaledToFit()
                .frame(width: side, height: side)
                .frame(width: proxy.size.width, height: proxy.size.height)
        }
    }

    private func fittedSide(boxPt: CGFloat) -> CGFloat {
        let nativePx = max(image.size.width, image.size.height) * image.scale
        guard nativePx > 0, boxPt > 0, displayScale > 0 else { return boxPt }
        let boxPx = boxPt * displayScale
        if boxPx >= nativePx {
            return floor(boxPx / nativePx) * nativePx / displayScale
        } else {
            let divisor = ceil(nativePx / boxPx)
            return nativePx / (divisor * displayScale)
        }
    }
}
