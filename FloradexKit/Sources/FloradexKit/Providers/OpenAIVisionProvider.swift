import Foundation

/// OpenAI vision reasoner used for disagreement arbitration, no-plant
/// checks, and long-tail cases. Talks to the Responses API; the model is a
/// parameter so tier changes never require code changes.
public struct OpenAIVisionProvider: PlantIdentificationProvider {
    public let id: ProviderID = .visionReasoner

    private let broker: any CredentialBroker
    private let http: ProviderHTTP
    private let endpoint: URL
    private let model: String

    public init(
        broker: any CredentialBroker,
        session: URLSession? = nil,
        endpoint: URL = URL(string: "https://api.openai.com/v1/responses")!,
        model: String = "gpt-5.4-mini"
    ) {
        self.broker = broker
        self.http = ProviderHTTP(session: session ?? ProviderHTTP.makeDefaultSession())
        self.endpoint = endpoint
        self.model = model
    }

    public func identify(_ image: ImagePayload) async throws -> [IdentificationCandidate] {
        let credential = try await broker.credential(for: id)

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(credential.apiKey)", forHTTPHeaderField: "Authorization")

        let instruction = """
        You are a botanist identifying the plant in the image. Respond ONLY with compact JSON: \
        {"candidates":[{"latinName":"<binomial>","commonName":"<name or null>","confidence":<0-1>}]} \
        with up to 3 candidates, strongest first. If the image contains no plant, respond with \
        {"candidates":[]}.
        """
        let dataURL = "data:\(image.format.mimeType);base64,\(image.data.base64EncodedString())"
        let body: [String: Any] = [
            "model": model,
            "input": [[
                "role": "user",
                "content": [
                    ["type": "input_text", "text": instruction],
                    ["type": "input_image", "image_url": dataURL],
                ],
            ]],
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, _) = try await http.execute(request, for: id)
        let text = try outputText(from: data)
        let candidates = try parseCandidates(from: text)
        if candidates.isEmpty {
            throw ProviderError.noPlantDetected
        }
        return candidates
    }

    /// Extracts the assistant's text from a Responses API payload: the first
    /// output_text content of the first message output item.
    private func outputText(from data: Data) throws -> String {
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

    /// The model is instructed to return bare JSON but may wrap it in prose;
    /// parse the outermost brace span defensively.
    private func parseCandidates(from text: String) throws -> [IdentificationCandidate] {
        guard let start = text.firstIndex(of: "{"), let end = text.lastIndex(of: "}") else {
            throw ProviderError.invalidResponse("no JSON object in model output")
        }
        struct Payload: Decodable {
            var candidates: [Candidate]

            struct Candidate: Decodable {
                var latinName: String
                var commonName: String?
                var confidence: Double
            }
        }
        let json = Data(text[start...end].utf8)
        let payload: Payload
        do {
            payload = try JSONDecoder().decode(Payload.self, from: json)
        } catch {
            throw ProviderError.invalidResponse("candidates decode: \(error)")
        }
        return payload.candidates.map { candidate in
            IdentificationCandidate(
                species: Species(latinName: candidate.latinName, commonName: candidate.commonName),
                confidence: candidate.confidence,
                provider: id
            )
        }
    }
}
