import Foundation

/// Pl@ntNet v2 identification client.
/// Docs: https://my.plantnet.org/doc (POST /v2/identify/{project} multipart,
/// api-key query parameter; 404 is their documented "species not found").
public struct PlantNetProvider: PlantIdentificationProvider {
    public let id: ProviderID = .plantNet

    private let broker: any CredentialBroker
    private let http: ProviderHTTP
    private let baseURL: URL

    public init(
        broker: any CredentialBroker,
        session: URLSession? = nil,
        baseURL: URL = URL(string: "https://my-api.plantnet.org/v2/identify/all")!
    ) {
        self.broker = broker
        self.http = ProviderHTTP(session: session ?? ProviderHTTP.makeDefaultSession())
        self.baseURL = baseURL
    }

    public func identify(_ image: ImagePayload) async throws -> [IdentificationCandidate] {
        let credential = try await broker.credential(for: id)

        guard var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: false) else {
            throw ProviderError.invalidResponse("bad base URL")
        }
        components.queryItems = (components.queryItems ?? []) + [
            URLQueryItem(name: "api-key", value: credential.apiKey)
        ]
        guard let url = components.url else {
            throw ProviderError.invalidResponse("bad request URL")
        }

        let boundary = "floradex-\(UUID().uuidString)"
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        request.httpBody = multipartBody(image: image, boundary: boundary)

        let (data, status) = try await http.execute(request, for: id, allowing: [404])
        if status == 404 {
            return []
        }

        let decoded: Response
        do {
            decoded = try JSONDecoder().decode(Response.self, from: data)
        } catch {
            throw ProviderError.invalidResponse("plantnet decode: \(error)")
        }

        return decoded.results.map { result in
            IdentificationCandidate(
                species: Species(
                    latinName: result.species.scientificNameWithoutAuthor,
                    commonName: result.species.commonNames?.first,
                    family: result.species.family?.scientificNameWithoutAuthor
                ),
                confidence: result.score,
                provider: id
            )
        }
    }

    private func multipartBody(image: ImagePayload, boundary: String) -> Data {
        var body = Data()
        func append(_ string: String) { body.append(Data(string.utf8)) }

        append("--\(boundary)\r\n")
        append("Content-Disposition: form-data; name=\"organs\"\r\n\r\n")
        append("auto\r\n")

        append("--\(boundary)\r\n")
        append("Content-Disposition: form-data; name=\"images\"; filename=\"capture.\(image.format.rawValue)\"\r\n")
        append("Content-Type: \(image.format.mimeType)\r\n\r\n")
        body.append(image.data)
        append("\r\n--\(boundary)--\r\n")
        return body
    }

    private struct Response: Decodable {
        var results: [Result]

        struct Result: Decodable {
            var score: Double
            var species: SpeciesPayload
        }

        struct SpeciesPayload: Decodable {
            var scientificNameWithoutAuthor: String
            var commonNames: [String]?
            var family: Family?
        }

        struct Family: Decodable {
            var scientificNameWithoutAuthor: String
        }
    }
}
