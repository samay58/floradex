import SwiftUI

// MARK: - Custom fonts removed in favor of system fonts
// Use Theme.Typography for all font styling

// MARK: - Modern System Font Helpers
// These provide convenient access to system fonts with appropriate weights and styles

extension Font {
    // Convenience accessors for modern system fonts with semantic naming
    static func appRegular(size: CGFloat) -> Font {
        .system(size: size, weight: .regular, design: .default)
    }
    
    static func appMedium(size: CGFloat) -> Font {
        .system(size: size, weight: .medium, design: .default)
    }
    
    static func appSemibold(size: CGFloat) -> Font {
        .system(size: size, weight: .semibold, design: .default)
    }
    
    static func appBold(size: CGFloat) -> Font {
        .system(size: size, weight: .bold, design: .default)
    }
    
    // Semantic font helpers that match common use cases
    static var cardTitle: Font {
        .system(.headline, design: .default, weight: .semibold)
    }
    
    static var cardSubtitle: Font {
        .system(.subheadline, design: .default, weight: .medium)
    }
    
    static var cardBody: Font {
        .system(.body, design: .default)
    }
    
    static var cardCaption: Font {
        .system(.caption, design: .default)
    }
    
    static var buttonText: Font {
        .system(.body, design: .default, weight: .semibold)
    }
} 