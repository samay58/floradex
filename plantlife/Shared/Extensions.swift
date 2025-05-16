import Foundation
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