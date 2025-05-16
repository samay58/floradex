import UIKit

extension UIImage {
    /// Returns a down-scaled copy with the longest side equal to `maxSide` (if needed).
    func resized(maxSide: CGFloat) -> UIImage {
        let longest = max(size.width, size.height)
        guard longest > maxSide else { return self }
        let scale = maxSide / longest
        let newSize = CGSize(width: size.width * scale, height: size.height * scale)
        let format = imageRendererFormat
        format.scale = 1  // logical points; will get rendered at device scale later
        return UIGraphicsImageRenderer(size: newSize, format: format).image { _ in
            self.draw(in: CGRect(origin: .zero, size: newSize))
        }
    }
}