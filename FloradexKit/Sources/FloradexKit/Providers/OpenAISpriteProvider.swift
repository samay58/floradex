import Foundation

/// Sprite generation via the OpenAI images endpoint. Sprites are off the
/// hero loop's critical path by design; this client can afford a long
/// resource timeout.
public struct OpenAISpriteProvider: SpriteGenerationProvider {
    public let id: ProviderID = .spriteGenerator

    private let broker: any CredentialBroker
    private let http: ProviderHTTP
    private let endpoint: URL
    private let model: String

    public init(
        broker: any CredentialBroker,
        session: URLSession? = nil,
        endpoint: URL = URL(string: "https://api.openai.com/v1/images/generations")!,
        model: String = "gpt-image-2"
    ) {
        self.broker = broker
        self.http = ProviderHTTP(
            session: session ?? ProviderHTTP.makeDefaultSession(requestTimeout: 120, resourceTimeout: 300)
        )
        self.endpoint = endpoint
        self.model = model
    }

    public func sprite(for species: Species) async throws -> Data {
        let credential = try await broker.credential(for: id)

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(credential.apiKey)", forHTTPHeaderField: "Authorization")

        let body = RequestBody(
            model: model,
            prompt: """
            A simple pixel art sprite of a \(species.displayName) plant (\(species.latinName)) in retro \
            8-bit video game style: limited color palette, centered, transparent background, \
            cute and iconic, suitable for a plant collection game.
            """
        )
        request.httpBody = try JSONEncoder().encode(body)

        let (data, _) = try await http.execute(request, for: id)

        struct Response: Decodable {
            var data: [Item]

            struct Item: Decodable {
                var b64Json: String?

                enum CodingKeys: String, CodingKey {
                    case b64Json = "b64_json"
                }
            }
        }
        let decoded: Response
        do {
            decoded = try JSONDecoder().decode(Response.self, from: data)
        } catch {
            throw ProviderError.invalidResponse("images decode: \(error)")
        }
        guard let base64 = decoded.data.first?.b64Json,
              let imageData = Data(base64Encoded: base64),
              !imageData.isEmpty else {
            throw ProviderError.invalidResponse("images payload had no decodable b64_json")
        }
        return imageData
    }

    private struct RequestBody: Encodable {
        var model: String
        var prompt: String
        var n = 1
        var size = "auto"
        var quality = "medium"
        var background = "transparent"
        var outputFormat = "png"

        enum CodingKeys: String, CodingKey {
            case model, prompt, n, size, quality, background
            case outputFormat = "output_format"
        }
    }
}
