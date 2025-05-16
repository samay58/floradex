import Foundation

// Define the specific endpoint for Wikipedia
enum WikipediaEndpoint: APIEndpoint {
    case getSummary(latinName: String)

    var baseURL: URL { URL(string: "https://en.wikipedia.org/api/rest_v1")! }

    var path: String {
        switch self {
        case .getSummary(let latinName):
            // Ensure percent encoding is applied correctly for path components
            return "/page/summary/\(latinName.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? "")"
        }
    }

    var method: HTTPMethod { .get }
    var headers: [String: String]? { nil } // Wikipedia doesn't require special headers for this endpoint
    var parameters: [String: Any]? { nil } // No query parameters or body for this request
    var body: Data? { nil }
}

final class WikipediaService {
    static let shared = WikipediaService()
    private init() {}

    // Keep WikiError for now, or decide to propagate APIError directly.
    // Propagating APIError might be better for consistency if all services use it.
    enum WikiError: Error { case badURL, badResponse, underlying(Error) }

    // Define the response structure expected from Wikipedia
    private struct SummaryResponse: Decodable {
        let extract: String
    }

    func fetchSummary(for latinName: String) async throws -> String {
        let endpoint = WikipediaEndpoint.getSummary(latinName: latinName)
        do {
            let summaryResponse = try await APIClient.shared.request(endpoint: endpoint) as SummaryResponse
            return summaryResponse.extract
        } catch let apiError as APIError {
            // Map APIError to WikiError for now
            switch apiError {
            case .invalidURL:
                throw WikiError.badURL
            case .unsuccessfulResponse, .noData, .decodingFailed:
                throw WikiError.badResponse // Or more specific WikiErrors if desired
            case .requestFailed(let underlyingError):
                throw WikiError.underlying(underlyingError)
            }
        } catch {
            // Catch any other unexpected errors
            throw WikiError.underlying(error)
        }
    }
} 