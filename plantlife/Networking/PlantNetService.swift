import Foundation
import UIKit

// Shared error enum for PlantNet operations
enum PlantNetError: Error, Equatable {
    case invalidImage
    case missingAPIKey
    case badResponse
    case underlying(Error)

    static func == (lhs: PlantNetError, rhs: PlantNetError) -> Bool {
        switch (lhs, rhs) {
        case (.invalidImage, .invalidImage),
             (.missingAPIKey, .missingAPIKey),
             (.badResponse, .badResponse):
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
final class PlantNetService {
    static let shared = PlantNetService()
    // Session removed, will use APIClient.shared.session
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
                throw PlantNetError.badResponse
            case .decodingFailed(let error):
                 print("[PlantNetService] Decoding failed: \(error)")
                throw PlantNetError.underlying(error) // Or a more specific decoding error
            case .requestFailed(let underlyingError):
                throw PlantNetError.underlying(underlyingError)
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
}

// Helper extension for Data, if needed for multipart, can be in APIClient or a shared spot
// For now, basic Data.append(_:) is sufficient.