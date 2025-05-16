import Foundation

// Keep or make public/internal the response structs if they are not already.
// Assuming API and Plant structs are made accessible:
struct PerenualAPIResponse: Decodable {
    struct Plant: Decodable {
        let common_name: String?
        let watering: String?
        let sunlight: [String]?
        // Add other fields as they are in the original struct
        let growth_rate: String?
        let maintenance: String?
        // Assuming temperature_min is a string in JSON, if it's meant to be a number, adjust type
        let temperature_min: String? // Or `struct MinTemp: Decodable { let celsius: Double? }` if it's complex
        let bloom_months: [String]?
    }
    let data: [Plant]
}

enum PerenualEndpoint: APIEndpoint {
    case searchSpecies(query: String)

    var baseURL: URL { URL(string: "https://perenual.com/api")! }

    var path: String {
        switch self {
        case .searchSpecies:
            return "/species-list"
        }
    }

    var method: HTTPMethod { .get }
    var headers: [String: String]? { nil }

    var parameters: [String: Any]? {
        guard let apiKey = Secrets.perenualApiKey.nonEmpty else {
            print("Error: Perenual API Key is missing.")
            return nil // Or handle error appropriately
        }
        var params: [String: Any] = ["key": apiKey]
        switch self {
        case .searchSpecies(let query):
            params["q"] = query
        }
        return params
    }

    // Perenual requests are GET; no HTTP body needed
    var body: Data? { nil }
}

struct PerenualService {
    static let shared = PerenualService()
    private init() {}

    enum PerenualError: Error { case missingKey, badURL, badResponse, decoding, underlying(Error) }

    func fetch(_ latin: String) async throws -> SpeciesDetails? {
        guard Secrets.perenualApiKey.nonEmpty != nil else { throw PerenualError.missingKey }
        let endpoint = PerenualEndpoint.searchSpecies(query: latin)
        
        do {
            let apiResponse: PerenualAPIResponse = try await APIClient.shared.request(endpoint: endpoint)
            guard let plantData = apiResponse.data.first else { return nil }

            return SpeciesDetails(
                latinName: latin,
                commonName: plantData.common_name,
                summary: nil, // Perenual API doesn't seem to provide a summary
                growthHabit: plantData.growth_rate ?? plantData.maintenance, // Approximation
                sunlight: plantData.sunlight?.first, // Takes the first sunlight requirement if multiple exist
                water: plantData.watering,
                soil: nil, // Perenual API doesn't seem to provide soil information
                temperature: plantData.temperature_min, // Assuming this is a string like "X C" or just "X"
                bloomTime: plantData.bloom_months?.joined(separator: ", "),
                funFacts: nil, // No direct fun facts from this API endpoint
                lastUpdated: Date()
            )
        } catch let error as APIError {
            throw PerenualError.underlying(error)
        } catch {
            // This will catch decoding errors from APIClient or other unexpected errors
            // If APIClient throws a specific decoding error, it would be caught as APIError.decodingError
            print("An unexpected error occurred in PerenualService.fetch: \(error)")
            throw PerenualError.decoding // Or a more general error like .badResponse
        }
    }
}