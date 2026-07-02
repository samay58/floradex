import Foundation

/// Kindwise plant.id v3 identification client.
/// Docs: https://plant.id (POST /api/v3/identification, Api-Key header,
/// base64 images, classification suggestions with name + probability).
public struct KindwiseProvider: PlantIdentificationProvider {
    public let id: ProviderID = .kindwise

    private let broker: any CredentialBroker
    private let http: ProviderHTTP
    private let endpoint: URL

    public init(
        broker: any CredentialBroker,
        session: URLSession? = nil,
        endpoint: URL = URL(string: "https://plant.id/api/v3/identification")!
    ) {
        self.broker = broker
        self.http = ProviderHTTP(session: session ?? ProviderHTTP.makeDefaultSession())
        self.endpoint = endpoint
    }

    public func identify(_ image: ImagePayload) async throws -> [IdentificationCandidate] {
        let credential = try await broker.credential(for: id)

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(credential.apiKey, forHTTPHeaderField: "Api-Key")
        let body = RequestBody(images: [image.data.base64EncodedString()])
        request.httpBody = try JSONEncoder().encode(body)

        let (data, _) = try await http.execute(request, for: id)

        let decoded: Response
        do {
            decoded = try JSONDecoder().decode(Response.self, from: data)
        } catch {
            throw ProviderError.invalidResponse("kindwise decode: \(error)")
        }

        if let isPlant = decoded.result.isPlant, isPlant.binary == false {
            throw ProviderError.noPlantDetected
        }

        return (decoded.result.classification?.suggestions ?? []).map { suggestion in
            IdentificationCandidate(
                species: Species(
                    latinName: suggestion.name,
                    commonName: suggestion.details?.commonNames?.first
                ),
                confidence: suggestion.probability,
                provider: id
            )
        }
    }

    private struct RequestBody: Encodable {
        var images: [String]
        var similarImages = false

        enum CodingKeys: String, CodingKey {
            case images
            case similarImages = "similar_images"
        }
    }

    private struct Response: Decodable {
        var result: Result

        struct Result: Decodable {
            var isPlant: Binary?
            var classification: Classification?

            enum CodingKeys: String, CodingKey {
                case isPlant = "is_plant"
                case classification
            }
        }

        struct Binary: Decodable {
            var binary: Bool
            var probability: Double?
        }

        struct Classification: Decodable {
            var suggestions: [Suggestion]
        }

        struct Suggestion: Decodable {
            var name: String
            var probability: Double
            var details: Details?
        }

        struct Details: Decodable {
            var commonNames: [String]?

            enum CodingKeys: String, CodingKey {
                case commonNames = "common_names"
            }
        }
    }
}
