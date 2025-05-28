import Foundation
import UIKit
import CryptoKit

// Shared error enum for PlantNet operations
enum PlantNetError: Error, Equatable {
    case invalidImage
    case missingAPIKey
    case badResponse
    case rateLimited
    case underlying(Error)

    static func == (lhs: PlantNetError, rhs: PlantNetError) -> Bool {
        switch (lhs, rhs) {
        case (.invalidImage, .invalidImage),
             (.missingAPIKey, .missingAPIKey),
             (.badResponse, .badResponse),
             (.rateLimited, .rateLimited):
            return true
        default:
            return false
        }
    }
}

// Define the specific endpoint for PlantNet
enum PlantNetEndpoint: APIEndpoint {
    case classify(image: UIImage, apiKey: String)

    var baseURL: URL { URL(string: "https://my-api.plantnet.org")! }
    var path: String { "/v2/identify/all" }
    var method: HTTPMethod { .post }
    
    // Headers are custom for multipart, so return nil here and set in asURLRequest.
    var headers: [String: String]? { nil }

    // Parameters are handled in query string and multipart body, not as a simple dictionary for JSON.
    var parameters: [String: Any]? {
        switch self {
        case .classify(_, let apiKey):
            // API key is a query parameter for PlantNet
            return ["api-key": apiKey]
        }
    }
    
    // The body is constructed as multipart, so this raw Data property isn't used directly by default asURLRequest.
    var body: Data? { nil } 

    // Custom request building for multipart/form-data
    func asURLRequest() throws -> URLRequest {
        // Base URL and path
        guard var components = URLComponents(url: baseURL.appendingPathComponent(path), resolvingAgainstBaseURL: true) else {
            throw APIError.invalidURL
        }

        // Add query parameters (e.g., api-key)
        if let params = parameters as? [String: String] {
            components.queryItems = params.map { URLQueryItem(name: $0.key, value: $0.value) }
        }

        guard let url = components.url else {
            throw APIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = method.rawValue

        // Multipart body construction
        switch self {
        case .classify(let image, _):
            guard let jpegData = image.jpegData(compressionQuality: 0.8) else {
                throw PlantNetError.invalidImage // Or a more generic APIError
            }
            
            let boundary = "Boundary-\(UUID().uuidString)"
            request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
            
            var multipartBody = Data()
            // Image part
            multipartBody.append("--\(boundary)\r\n".data(using: .utf8)!)
            let contentDisposition = "Content-Disposition: form-data; name=\"images\"; filename=\"image.jpg\"\r\n"
            multipartBody.append(contentDisposition.data(using: .utf8)!)
            multipartBody.append("Content-Type: image/jpeg\r\n\r\n".data(using: .utf8)!)
            multipartBody.append(jpegData)
            multipartBody.append("\r\n".data(using: .utf8)!)
            
            // End of multipart body
            multipartBody.append("--\(boundary)--\r\n".data(using: .utf8)!)
            request.httpBody = multipartBody
        }
        
        // Add any other specific headers if PlantNet required them (already handled Content-Type)
        headers?.forEach { request.setValue($1, forHTTPHeaderField: $0) }

        return request
    }
}

/// Wraps PlantNet API call to identify a plant from a photo.
/// Docs: https://my-api.plantnet.org/
final class PlantNetService: @unchecked Sendable {
    static let shared = PlantNetService()
    
    // Request deduplication: track active requests by image hash
    private var activeRequests: [String: Task<ClassifierResult, Error>] = [:]
    private let requestQueue = DispatchQueue(label: "plantnet.requests", attributes: .concurrent)
    
    private init() {}

    // Response structure (already defined, kept for clarity)
    private struct APIResponse: Decodable {
        struct Result: Decodable {
            let score: Double
            struct Species: Decodable { let scientificNameWithoutAuthor: String }
            let species: Species
        }
        let results: [Result]
    }

    func classify(image: UIImage) async throws -> ClassifierResult {
        guard let key = Secrets.plantNetAPIKey.nonEmpty else { throw PlantNetError.missingAPIKey }
        
        // Generate image hash for deduplication
        let imageHash = generateImageHash(image)
        
        // Check if there's already a request in progress for this image
        return try await withCheckedThrowingContinuation { continuation in
            requestQueue.async(flags: .barrier) {
                // If we already have an active request for this image, return that task
                if let existingTask = self.activeRequests[imageHash] {
                    print("[PlantNetService] Reusing existing request for image hash: \(imageHash)")
                    Task {
                        do {
                            let result = try await existingTask.value
                            continuation.resume(returning: result)
                        } catch {
                            continuation.resume(throwing: error)
                        }
                    }
                    return
                }
                
                // Create new request task with retry logic
                let task = Task<ClassifierResult, Error> {
                    try await self.performClassificationWithRetry(image: image, imageHash: imageHash)
                }
                
                // Store the active request
                self.activeRequests[imageHash] = task
                print("[PlantNetService] Starting new request for image hash: \(imageHash)")
                
                // Execute the task
                Task {
                    do {
                        let result = try await task.value
                        continuation.resume(returning: result)
                    } catch {
                        continuation.resume(throwing: error)
                    }
                    
                    // Clean up the request from active pool
                    self.requestQueue.async(flags: .barrier) {
                        self.activeRequests.removeValue(forKey: imageHash)
                        print("[PlantNetService] Cleaned up request for image hash: \(imageHash)")
                    }
                }
            }
        }
    }
    
    /// Generate a hash for image content to enable deduplication
    private func generateImageHash(_ image: UIImage) -> String {
        guard let imageData = image.jpegData(compressionQuality: 0.8) else {
            return UUID().uuidString
        }
        let hash = SHA256.hash(data: imageData)
        return hash.compactMap { String(format: "%02x", $0) }.joined().prefix(16).description
    }
    
    /// Perform classification with exponential backoff retry logic
    private func performClassificationWithRetry(image: UIImage, imageHash: String, maxRetries: Int = 3) async throws -> ClassifierResult {
        var attempt = 0
        var baseDelay: TimeInterval = 1.0
        
        while attempt < maxRetries {
            attempt += 1
            
            do {
                return try await performSingleClassification(image: image)
            } catch let apiError as APIError {
                switch apiError {
                case .unsuccessfulResponse(let statusCode, _):
                    if statusCode == 429 { // Rate limited
                        if attempt < maxRetries {
                            let delay = baseDelay * pow(2.0, Double(attempt - 1)) + Double.random(in: 0...1)
                            print("[PlantNetService] Rate limited (attempt \(attempt)/\(maxRetries)), retrying in \(delay)s...")
                            try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                            baseDelay *= 2
                            continue
                        } else {
                            throw PlantNetError.rateLimited
                        }
                    } else {
                        // Other HTTP errors are not retryable
                        throw PlantNetError.badResponse
                    }
                case .requestFailed(let underlyingError):
                    // Network errors might be retryable
                    if attempt < maxRetries {
                        let delay = baseDelay * pow(2.0, Double(attempt - 1))
                        print("[PlantNetService] Network error (attempt \(attempt)/\(maxRetries)), retrying in \(delay)s: \(underlyingError)")
                        try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                        continue
                    } else {
                        throw PlantNetError.underlying(underlyingError)
                    }
                default:
                    // Other API errors are not retryable
                    throw PlantNetError.underlying(apiError)
                }
            } catch {
                // Unexpected errors
                if attempt < maxRetries {
                    let delay = baseDelay * pow(2.0, Double(attempt - 1))
                    print("[PlantNetService] Unexpected error (attempt \(attempt)/\(maxRetries)), retrying in \(delay)s: \(error)")
                    try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                    continue
                } else {
                    throw PlantNetError.underlying(error)
                }
            }
        }
        
        // This should never be reached due to throws in the loop
        throw PlantNetError.underlying(NSError(domain: "PlantNetService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Unexpected state after retries"]))
    }
    
    /// Perform a single classification request without retry logic
    private func performSingleClassification(image: UIImage) async throws -> ClassifierResult {
        guard let key = Secrets.plantNetAPIKey.nonEmpty else { throw PlantNetError.missingAPIKey }
        // Image resizing should happen before calling this service, as per rule-007.
        // Assuming `image` is already appropriately sized.

        let endpoint = PlantNetEndpoint.classify(image: image, apiKey: key)
        
        do {
            let apiResponse = try await APIClient.shared.request(endpoint: endpoint) as APIResponse
            guard let best = apiResponse.results.first else { 
                // If results are empty, it could be considered a badResponse or noData scenario.
                throw PlantNetError.badResponse 
            }
            return ClassifierResult(species: best.species.scientificNameWithoutAuthor, confidence: best.score, source: .plantNet)
        } catch let apiError as APIError {
            switch apiError {
            case .invalidURL: // Should be caught by endpoint construction if URL is truly invalid
                throw PlantNetError.underlying(apiError)
            case .unsuccessfulResponse(let statusCode, _):
                print("[PlantNetService] Unsuccessful response: \(statusCode)")
                if statusCode == 429 {
                    throw apiError // Let retry logic handle this
                } else {
                throw PlantNetError.badResponse
                }
            case .decodingFailed(let error):
                 print("[PlantNetService] Decoding failed: \(error)")
                throw PlantNetError.underlying(error) // Or a more specific decoding error
            case .requestFailed(let underlyingError):
                throw apiError // Let retry logic handle this
            case .noData: // PlantNet should return data if successful
                throw PlantNetError.badResponse
            }
        } catch {
            // Catch any other unexpected errors (e.g., from jpegData creation if not mapped)
            if let pnErr = error as? PlantNetError, pnErr == .invalidImage {
                 throw PlantNetError.invalidImage
            }
            throw PlantNetError.underlying(error)
        }
    }
    
    /// Cancel all active requests (useful for cleanup)
    func cancelAllRequests() {
        requestQueue.async(flags: .barrier) {
            for (hash, task) in self.activeRequests {
                task.cancel()
                print("[PlantNetService] Cancelled request for hash: \(hash)")
            }
            self.activeRequests.removeAll()
        }
    }
}

// Helper extension for Data, if needed for multipart, can be in APIClient or a shared spot
// For now, basic Data.append(_:) is sufficient.