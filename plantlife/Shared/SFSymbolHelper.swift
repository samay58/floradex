import SwiftUI
import UIKit

/// Helper to manage SF Symbol availability and provide fallbacks
struct SFSymbolHelper {
    
    /// Check if a system symbol is available, with fallback
    static func systemSymbol(_ name: String, fallback: String = "questionmark") -> Image {
        if UIImage(systemName: name) != nil {
            return Image(systemName: name)
        } else {
            print("[SFSymbolHelper] Symbol '\(name)' not available, using fallback '\(fallback)'")
            return Image(systemName: fallback)
        }
    }
    
    /// Check if a system symbol is available for UIImage, with fallback
    static func systemUIImage(_ name: String, fallback: String = "questionmark") -> UIImage? {
        if let image = UIImage(systemName: name) {
            return image
        } else {
            print("[SFSymbolHelper] UIImage symbol '\(name)' not available, using fallback '\(fallback)'")
            return UIImage(systemName: fallback)
        }
    }
}

/// Extension to provide specific symbol mappings with appropriate fallbacks
extension SFSymbolHelper {
    
    // MARK: - Plant & Garden Symbols
    
    static var flowerFill: Image {
        systemSymbol("flower.fill", fallback: "leaf.fill")
    }
    
    static var leafCircle: Image {
        systemSymbol("leaf.circle", fallback: "circle")
    }
    
    static var leafCircleFill: Image {
        systemSymbol("leaf.circle.fill", fallback: "circle.fill")
    }
    
    // MARK: - System & UI Symbols
    
    static var gearProcessing: Image {
        systemSymbol("gearshape.arrow.trianglebadge.exclamationmark", fallback: "gear")
    }
    
    static var magnifyingGlass: Image {
        systemSymbol("magnifyingglass", fallback: "magnifyingglass")
    }
    
    static var questionCircle: Image {
        systemSymbol("questionmark.circle", fallback: "questionmark.circle")
    }
    
    // MARK: - Camera & Photo Symbols
    
    static var cameraFill: Image {
        systemSymbol("camera.fill", fallback: "camera")
    }
    
    static var photoFill: Image {
        systemSymbol("photo.fill", fallback: "photo")
    }
    
    static var photoOnRectangle: Image {
        systemSymbol("photo.on.rectangle.angled", fallback: "photo")
    }
    
    // MARK: - Nature & Weather Symbols
    
    static var boltFill: Image {
        systemSymbol("bolt.fill", fallback: "bolt")
    }
    
    static var boltSlash: Image {
        systemSymbol("bolt.slash", fallback: "bolt")
    }
    
    // MARK: - Navigation & Action Symbols
    
    static var xmark: Image {
        systemSymbol("xmark", fallback: "xmark")
    }
    
    static var arrowRight: Image {
        systemSymbol("arrow.right", fallback: "arrow.right")
    }
    
    static var shareSquare: Image {
        systemSymbol("square.and.arrow.up", fallback: "square.and.arrow.up")
    }
    
    // MARK: - Warning & Status Symbols
    
    static var exclamationTriangleFill: Image {
        systemSymbol("exclamationmark.triangle.fill", fallback: "exclamationmark.triangle")
    }
    
    static var sparkle: Image {
        systemSymbol("sparkle", fallback: "star")
    }
    
    // MARK: - Plant Care Symbols
    
    static func sunSymbol(for level: String) -> Image {
        switch level.lowercased() {
        case "full sun", "bright":
            return systemSymbol("sun.max.fill", fallback: "sun.max")
        case "partial sun", "partial shade":
            return systemSymbol("sun.and.horizon", fallback: "sun.min")
        case "shade", "low light":
            return systemSymbol("cloud.fill", fallback: "cloud")
        default:
            return systemSymbol("sun.max", fallback: "sun.max")
        }
    }
    
    static func waterSymbol(for level: String) -> Image {
        switch level.lowercased() {
        case "high", "frequent":
            return systemSymbol("drop.fill", fallback: "drop")
        case "moderate", "regular":
            return systemSymbol("drop", fallback: "drop")
        case "low", "infrequent":
            return systemSymbol("drop.halffull", fallback: "drop")
        default:
            return systemSymbol("drop", fallback: "drop")
        }
    }
    
    static func temperatureSymbol(for range: String) -> Image {
        if range.contains("cold") || range.contains("cool") {
            return systemSymbol("thermometer.snowflake", fallback: "thermometer")
        } else if range.contains("hot") || range.contains("warm") {
            return systemSymbol("thermometer.sun", fallback: "thermometer")
        } else {
            return systemSymbol("thermometer", fallback: "thermometer")
        }
    }
} 