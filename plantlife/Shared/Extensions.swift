import Foundation
import SwiftUI
import UIKit

// MARK: - String
extension String {
    /// Returns nil if the string is empty, otherwise returns the string itself.
    var nonEmpty: String? { isEmpty ? nil : self }
}

// MARK: - UIImage
// Note: UIImage.resized has been moved to ImageProcessing/UIImage+Resize.swift
// If other common UIImage extensions are needed, they can be added here.

// MARK: - Other common extensions can be added below

// For clamping numeric values
extension Comparable {
    func clamped(to limits: ClosedRange<Self>) -> Self {
        return min(max(self, limits.lowerBound), limits.upperBound)
    }
}

// Helper for normalizing and calculating positions in ranges
struct DampingFunctions {
    static func normalizedPosition(value: Double, in range: ClosedRange<Double>) -> CGFloat {
        guard range.upperBound > range.lowerBound else { return 0 }
        let normalized = (value - range.lowerBound) / (range.upperBound - range.lowerBound)
        // We clamp here to ensure that values outside the displayRange don't break the visual.
        // e.g. if current temp is 50C but display is 0-40C, it will show as full at 40C.
        return CGFloat(normalized.clamped(to: 0...1))
    }
    
    // Can add other damping or utility functions here
}

// Extension to get RGB components from Color (simplistic, might need refinement)
extension Color {
    var RgbMaxTuple: (Double, Double, Double) {
        let uiColor = UIColor(self)
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        uiColor.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        return (Double(red), Double(green), Double(blue))
    }
    
    // You might want to add other helpful Color extensions here, e.g., initializing from hex.
} 