import Foundation
import CoreML
import Vision
import UIKit
import Combine

struct ClassifierResult {
    let species: String
    let confidence: Double
    let source: Source

    enum Source { case local, plantNet, gpt4o, ensemble }
}

final class ClassifierService: @unchecked Sendable {
    static let shared = ClassifierService()

    private let queue = DispatchQueue(label: "ClassifierService")
    private var model: VNCoreMLModel?

    init() {
        // Attempt to load the local ML model if bundled
        if let url = Bundle.main.url(forResource: "PlantClassifier", withExtension: "mlmodelc"),
           let loadedModel = try? MLModel(contentsOf: url) {
            model = try? VNCoreMLModel(for: loadedModel)
        }
    }

    // MARK: - Public API

    func classifyLocal(_ image: UIImage) async throws -> ClassifierResult {
        guard let cgImage = image.cgImage else {
            throw NSError(domain: "ClassifierService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to get CGImage from UIImage."])
        }

        // If model not available, return a default result or throw a specific error
        guard let selfModel = self.model else {
            // Consider throwing an error like ModelError.modelNotLoaded
            // For now, maintaining behavior of returning a low-confidence result.
            return ClassifierResult(species: "Unknown (Model Not Loaded)", confidence: 0.0, source: .local)
        }

        return try await withCheckedThrowingContinuation { continuation in
            let request = VNCoreMLRequest(model: selfModel) { request, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                
                if let observation = request.results?.first as? VNClassificationObservation {
                    continuation.resume(returning: ClassifierResult(species: observation.identifier, confidence: Double(observation.confidence), source: .local))
                } else {
                    // If no observation, it might be an error or just no classification found
                    // Return a default low-confidence result or throw a specific error
                    continuation.resume(returning: ClassifierResult(species: "Unknown (No Observation)", confidence: 0.0, source: .local))
                }
            }
            request.imageCropAndScaleOption = .centerCrop // Common practice, can be adjusted

            // Perform the request
            // VNImageRequestHandler can be synchronous, so dispatch if needed, though often not necessary for single images
            // For simplicity here, assuming it's fine on current context or Vision handles its own threading.
            // If this causes UI hangs, dispatch to a background queue.
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
                    try handler.perform([request])
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    func classifyPlantNet(_ image: UIImage) async throws -> ClassifierResult {
        // Image resizing should happen before calling this service, as per rule-007.
        // Assuming `image` is already appropriately sized if required by PlantNetService.
        return try await PlantNetService.shared.classify(image: image)
    }

    func classifyGPT4o(_ image: UIImage) async throws -> ClassifierResult {
        // Image resizing/conversion to pngData is handled within GPT4oService or before.
        // Assuming `image` is ready for GPT4oService.
        return try await GPT4oService.shared.classify(image: image)
    }
} 