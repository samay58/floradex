import SwiftUI
import CoreGraphics

/// Provides a dithered 4-color GameBoy-style pattern as a `Color` for dark-mode backgrounds.
struct GameBoyScreenBackground: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Group {
            if colorScheme == .dark {
                Color(uiColor: UIColor(patternImage: GameBoyPatternGenerator.shared.patternImage))
            } else {
                Theme.Colors.background
            }
        }
        .ignoresSafeArea()
    }
}

fileprivate final class GameBoyPatternGenerator {
    static let shared = GameBoyPatternGenerator()
    private init() {}

    // 4×4 pixel image with classic 4-tone palette
    lazy var patternImage: UIImage = {
        let size = CGSize(width: 4, height: 4)
        let colors: [UIColor] = [
            UIColor(red: 0.058, green: 0.22, blue: 0.058, alpha: 1),   // Darkest (#0F380F)
            UIColor(red: 0.188, green: 0.38, blue: 0.188, alpha: 1),  // Dark (#306230)
            UIColor(red: 0.545, green: 0.69, blue: 0.059, alpha: 1),  // Light (#8BAC0F)
            UIColor(red: 0.608, green: 0.737, blue: 0.059, alpha: 1)  // Lightest (#9BBC0F)
        ]

        UIGraphicsBeginImageContext(size)
        guard let ctx = UIGraphicsGetCurrentContext() else { return UIImage() }

        // Dither pattern (checkerboard diagonal)
        for y in 0..<4 {
            for x in 0..<4 {
                let index = (x + y) % 4
                ctx.setFillColor(colors[index].cgColor)
                ctx.fill(CGRect(x: x, y: y, width: 1, height: 1))
            }
        }
        let img = UIGraphicsGetImageFromCurrentImageContext() ?? UIImage()
        UIGraphicsEndImageContext()
        return img
    }()
}

#if DEBUG
#Preview("GameBoy BG") {
    ZStack {
        GameBoyScreenBackground()
        Text("GameBoy")
            .font(.largeTitle)
            .foregroundColor(.white)
    }
}
#endif 