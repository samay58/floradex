import Foundation

/// Species details (summary, care profile, fun facts) via the OpenAI
/// Responses API. Cloud fallback for care text; Apple's on-device
/// Foundation Models path plugs in behind the same `SpeciesDetailsProvider`
/// protocol on capable hardware.
public struct OpenAIDetailsProvider: SpeciesDetailsProvider {
    public let id: ProviderID = .visionReasoner

    private let broker: any CredentialBroker
    private let http: ProviderHTTP
    private let endpoint: URL
    private let model: String
    private let now: @Sendable () -> Date

    public init(
        broker: any CredentialBroker,
        session: URLSession? = nil,
        endpoint: URL = URL(string: "https://api.openai.com/v1/responses")!,
        model: String = "gpt-5.4-nano",
        now: @escaping @Sendable () -> Date = { Date() }
    ) {
        self.broker = broker
        self.http = ProviderHTTP(session: session ?? ProviderHTTP.makeDefaultSession())
        self.endpoint = endpoint
        self.model = model
        self.now = now
    }

    public func details(for species: Species) async throws -> SpeciesDetailsContent {
        let credential = try await broker.credential(for: id)

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(credential.apiKey)", forHTTPHeaderField: "Authorization")

        let instruction = """
        You are a friendly botanist writing a field-guide entry for \(species.latinName). \
        Respond ONLY with compact JSON: {"commonName":<string or null>,"summary":<2 sentences>, \
        "sunlight":<short phrase>,"water":<short phrase>,"soil":<short phrase>, \
        "temperature":<range like 18-27 C>,"bloomTime":<short phrase or null>, \
        "funFacts":[<up to 3 strings, each under 120 characters>]}
        """
        let body: [String: Any] = [
            "model": model,
            "input": [[
                "role": "user",
                "content": [["type": "input_text", "text": instruction]],
            ]],
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, _) = try await http.execute(request, for: id)
        let text = try ResponsesPayload.outputText(from: data)
        return try parse(text, for: species)
    }

    private func parse(_ text: String, for species: Species) throws -> SpeciesDetailsContent {
        guard let start = text.firstIndex(of: "{"), let end = text.lastIndex(of: "}") else {
            throw ProviderError.invalidResponse("no JSON object in model output")
        }
        struct Payload: Decodable {
            var commonName: String?
            var summary: String?
            var sunlight: String?
            var water: String?
            var soil: String?
            var temperature: String?
            var bloomTime: String?
            var funFacts: [String]?
        }
        let payload: Payload
        do {
            payload = try JSONDecoder().decode(Payload.self, from: Data(text[start...end].utf8))
        } catch {
            throw ProviderError.invalidResponse("details decode: \(error)")
        }

        var enriched = species
        if enriched.commonName == nil {
            enriched.commonName = payload.commonName
        }
        return SpeciesDetailsContent(
            species: enriched,
            summary: payload.summary,
            care: CareProfile(
                sunlight: payload.sunlight,
                water: payload.water,
                soil: payload.soil,
                temperature: payload.temperature,
                bloomTime: payload.bloomTime
            ),
            funFacts: payload.funFacts ?? [],
            source: ContentSource(provider: id, generatedAt: now())
        )
    }
}

/// Shared Responses API text extraction: the first output_text content of
/// the first message output item.
enum ResponsesPayload {
    static func outputText(from data: Data) throws -> String {
        struct Response: Decodable {
            var output: [OutputItem]

            struct OutputItem: Decodable {
                var type: String
                var content: [ContentItem]?
            }

            struct ContentItem: Decodable {
                var type: String
                var text: String?
            }
        }
        let decoded: Response
        do {
            decoded = try JSONDecoder().decode(Response.self, from: data)
        } catch {
            throw ProviderError.invalidResponse("responses decode: \(error)")
        }
        for item in decoded.output where item.type == "message" {
            for content in item.content ?? [] where content.type == "output_text" {
                if let text = content.text {
                    return text
                }
            }
        }
        throw ProviderError.invalidResponse("responses payload had no output_text")
    }
}
