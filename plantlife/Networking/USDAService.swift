import Foundation

// Define the response structure for the plantsdb.xyz endpoint
private struct USDASearchResponse: Decodable {
    let growth_habit: String?
}

// Define the APIEndpoint for USDA service (plantsdb.xyz)
enum USDAEndpoint: APIEndpoint {
    case searchScientificName(name: String)

    var baseURL: URL { URL(string: "https://plantsdb.xyz")! }

    var path: String {
        switch self {
        case .searchScientificName:
            return "/search" // Path for the search
        }
    }

    var method: HTTPMethod { .get }
    var headers: [String: String]? { nil } // No special headers mentioned

    var parameters: [String: Any]? {
        switch self {
        case .searchScientificName(let name):
            // Parameters are query items for GET request
            return ["scientific_name": name]
        }
    }
    var body: Data? { nil } // No body for GET request
}

final class USDAService {
    static let shared = USDAService()
    // Removed custom URLSession, will use APIClient.shared.session
    private init() {}

    enum USDAError: Error { case badURL, badResponse, underlying(Error), noDataFound }

    func fetchGrowthInfo(for latinName: String) async throws -> String {
        let endpoint = USDAEndpoint.searchScientificName(name: latinName)
        
        do {
            let response: USDASearchResponse = try await APIClient.shared.request(endpoint: endpoint)
            return response.growth_habit ?? "No data"
        } catch let error as APIError {
            // Log the APIError for debugging if necessary
            // print("[USDAService] APIError: \\(error)")
            // Depending on the error, decide if it should be "No data" or a thrown error
            switch error {
            case .noData, .decodingFailed: // If API returns no data or unexpected format for growth_habit
                return "No data" // Or throw USDAError.noDataFound if that's preferred upstream
            default:
                throw USDAError.underlying(error) // Propagate other API errors as underlying
            }
        } catch {
            // Catch any other unexpected errors
            // print("[USDAService] Unexpected error: \\(error)")
            throw USDAError.underlying(error) // Or return "No data" if that's the desired fallback for all errors
        }
    }
} 