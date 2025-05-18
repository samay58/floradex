import SwiftUI

extension Font {
    static func pressStart2P(size: CGFloat) -> Font {
        return .custom("PressStart2P-Regular", size: size)
    }

    static func mPlus1Code(size: CGFloat) -> Font {
        return .custom("MPLUS1Code-Regular", size: size) // Assuming regular weight, adjust if needed
    }
    
    // Add other weights if you downloaded them, e.g.:
    // static func mPlus1CodeBold(size: CGFloat) -> Font {
    //     return .custom("MPLUS1Code-Bold", size: size)
    // }
} 