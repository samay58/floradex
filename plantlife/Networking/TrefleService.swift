import Foundation

struct TrefleResponse: Decodable {
    struct Data: Decodable {
        let common_name: String?
        let growth_habit: String?
        let growth: Growth?
        struct Growth: Decodable {
            let precipitation_minimum: Int?
            let precipitation_maximum: Int?
            let temperature_minimum: Int?
            let temperature_maximum: Int?
        }
        let specifications: Specs?
        struct Specs: Decodable { let light: String? }
        let main_species: MainSpecies?
        struct MainSpecies: Decodable { let bloom_period: Bloom?; struct Bloom: Decodable { let value: String? } }
    }
    let data: Data
}

enum TrefleEndpoint: APIEndpoint {
    case getSpeciesBySlug(slug: String)
    case searchSpecies(query: String)

    var baseURL: URL { URL(string: "https://trefle.io/api/v1")! }

    var path: String {
        switch self {
        case .getSpeciesBySlug(let slug):
            return "/species/\(slug)"
        case .searchSpecies:
            return "/species/search"
        }
    }

    var method: HTTPMethod { .get }

    var headers: [String: String]? { nil }

    var parameters: [String: Any]? {
        guard let apiKey = Secrets.trefleApiKey.nonEmpty else {
            print("Error: Trefle API Key is missing.")
            return nil
        }
        var params: [String: Any] = ["token": apiKey]
        switch self {
        case .getSpeciesBySlug:
            break // No additional query params beyond token in path
        case .searchSpecies(let query):
            params["q"] = query
        }
        return params
    }

    var body: Data? { nil }
}

final class TrefleService {
    static let shared = TrefleService()
    private init() {}

    enum TrefleError: Error { case missingKey, badURL, badResponse, searchFailed, underlying(Error) }

    func fetch(_ latin: String) async throws -> SpeciesDetails {
        guard !latin.isEmpty else { throw TrefleError.badURL }
        guard Secrets.trefleApiKey.nonEmpty != nil else { throw TrefleError.missingKey }

        let slug = latin.lowercased().replacingOccurrences(of: " ", with: "-")

        do {
            let directEndpoint = TrefleEndpoint.getSpeciesBySlug(slug: slug)
            let decodedData: TrefleResponse.Data = try await APIClient.shared.request(endpoint: directEndpoint)
            return Self.details(from: decodedData, latin: latin)
        } catch APIError.unsuccessfulResponse(statusCode: let statusCode, data: _) where statusCode == 404 {
            // Fallback to search endpoint
            do {
                let searchEndpoint = TrefleEndpoint.searchSpecies(query: slug)
                struct SearchResp: Decodable { let data: [TrefleResponse.Data] }
                let searchResult: SearchResp = try await APIClient.shared.request(endpoint: searchEndpoint)
                if let firstMatch = searchResult.data.first {
                    return Self.details(from: firstMatch, latin: latin)
                }
                throw TrefleError.searchFailed // Or a more specific error like noResultsFound
            } catch {
                // If search also fails, throw an error based on that
                if let apiError = error as? APIError {
                    throw TrefleError.underlying(apiError)
                } else if error is TrefleError {
                    throw error // rethrow Trefle specific errors from search fallback
                }
                throw TrefleError.searchFailed
            }
        } catch let error as APIError {
            throw TrefleError.underlying(error)
        } catch {
            throw TrefleError.badResponse // Catchall for other errors
        }
    }

    private static func details(from decoded: TrefleResponse.Data, latin: String) -> SpeciesDetails {
        let growth = decoded.growth
        let water: String? = {
            guard let min = growth?.precipitation_minimum, let max = growth?.precipitation_maximum else { return nil }
            return "\(min)–\(max) mm/yr"
        }()

        let temperature: String? = {
            guard let min = growth?.temperature_minimum, let max = growth?.temperature_maximum else { return nil }
            return "\(min)–\(max) °C"
        }()

        return SpeciesDetails(
            latinName: latin,
            commonName: decoded.common_name,
            summary: nil,
            growthHabit: decoded.growth_habit,
            sunlight: decoded.specifications?.light,
            water: water,
            soil: nil,
            temperature: temperature,
            bloomTime: decoded.main_species?.bloom_period?.value,
            funFacts: nil,
            lastUpdated: Date()
        )
    }
} 