import SwiftUI

/// Pixel art at honest scales: upscales snap to integer multiples of the
/// art's own pixel grid (fractional upscales make uneven chunky pixels);
/// at or below native size it fits with nearest-neighbor decimation.
struct PixelScaledImage: View {
    let image: UIImage

    var body: some View {
        GeometryReader { proxy in
            let box = min(proxy.size.width, proxy.size.height)
            let native = max(image.size.width, image.size.height) * image.scale
            let side = box >= native && native > 0
                ? floor(box / native) * native
                : box
            Image(uiImage: image)
                .resizable()
                .interpolation(.none)
                .scaledToFit()
                .frame(width: side, height: side)
                .frame(width: proxy.size.width, height: proxy.size.height)
        }
    }
}
