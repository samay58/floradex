import Foundation
import Testing
import os
@testable import FloradexKit

/// In-process transport stub. Routes by host so concurrently running tests
/// never share state: each test registers a unique `<name>.stub.test` host.
/// Inside URLProtocol the request body arrives as a stream, so it is drained
/// here and captured for post-call assertions.
final class StubURLProtocol: URLProtocol {
    struct Route: Sendable {
        var status: Int
        var body: Data
        var headers: [String: String]
    }

    private static let routes = OSAllocatedUnfairLock(initialState: [String: Route]())
    private static let captures = OSAllocatedUnfairLock(initialState: [String: (request: URLRequest, body: Data?)]())
    private static let hits = OSAllocatedUnfairLock(initialState: [String: Int]())

    static func register(host: String, status: Int, json: String, headers: [String: String] = [:]) {
        routes.withLock { $0[host] = Route(status: status, body: Data(json.utf8), headers: headers) }
    }

    static func capture(host: String) -> (request: URLRequest, body: Data?)? {
        captures.withLock { $0[host] }
    }

    static func hitCount(host: String) -> Int {
        hits.withLock { $0[host] ?? 0 }
    }

    static let session: URLSession = {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [StubURLProtocol.self]
        return URLSession(configuration: configuration)
    }()

    override class func canInit(with request: URLRequest) -> Bool {
        request.url?.host()?.hasSuffix(".stub.test") == true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        guard let url = request.url, let host = url.host() else {
            client?.urlProtocol(self, didFailWithError: URLError(.badURL))
            return
        }
        let capturedRequest = request
        let body = capturedRequest.httpBody ?? capturedRequest.httpBodyStream.map(Self.drain)
        Self.hits.withLock { $0[host, default: 0] += 1 }
        Self.captures.withLock { $0[host] = (capturedRequest, body) }

        guard let route = Self.routes.withLock({ $0[host] }) else {
            client?.urlProtocol(self, didFailWithError: URLError(.unsupportedURL))
            return
        }
        let response = HTTPURLResponse(
            url: url,
            statusCode: route.status,
            httpVersion: "HTTP/1.1",
            headerFields: route.headers
        )!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: route.body)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}

    private static func drain(_ stream: InputStream) -> Data {
        stream.open()
        defer { stream.close() }
        var data = Data()
        let bufferSize = 16 * 1024
        var buffer = [UInt8](repeating: 0, count: bufferSize)
        while stream.hasBytesAvailable {
            let read = stream.read(&buffer, maxLength: bufferSize)
            guard read > 0 else { break }
            data.append(buffer, count: read)
        }
        return data
    }
}

private let image = ImagePayload(format: .jpeg, data: Data("fake-jpeg".utf8))

private func broker(_ provider: ProviderID, key: String = "test-key") -> StaticCredentialBroker {
    StaticCredentialBroker(keys: [provider: key])
}

@Suite struct KindwiseProviderTests {
    private func makeProvider(host: String, broker: StaticCredentialBroker) -> KindwiseProvider {
        KindwiseProvider(
            broker: broker,
            session: StubURLProtocol.session,
            endpoint: URL(string: "https://\(host)/api/v3/identification")!
        )
    }

    @Test func happyPathBuildsRequestAndParsesSuggestions() async throws {
        let host = "kindwise-happy.stub.test"
        StubURLProtocol.register(host: host, status: 200, json: """
        {"result": {"is_plant": {"binary": true, "probability": 0.99},
         "classification": {"suggestions": [
            {"name": "Monstera deliciosa", "probability": 0.96,
             "details": {"common_names": ["Swiss cheese plant"]}},
            {"name": "Epipremnum aureum", "probability": 0.12, "details": null}
         ]}}}
        """)

        let provider = makeProvider(host: host, broker: broker(.kindwise))
        let candidates = try await provider.identify(image)

        #expect(candidates.count == 2)
        #expect(candidates[0].species.latinName == "Monstera deliciosa")
        #expect(candidates[0].species.commonName == "Swiss cheese plant")
        #expect(candidates[0].confidence == 0.96)
        #expect(candidates[0].provider == .kindwise)

        let capture = try #require(StubURLProtocol.capture(host: host))
        #expect(capture.request.httpMethod == "POST")
        #expect(capture.request.value(forHTTPHeaderField: "Api-Key") == "test-key")
        let sentBody = try JSONSerialization.jsonObject(with: try #require(capture.body)) as? [String: Any]
        let images = sentBody?["images"] as? [String]
        #expect(images == [image.data.base64EncodedString()])
        #expect(sentBody?["similar_images"] as? Bool == false)
    }

    @Test func notAPlantThrowsNoPlantDetected() async {
        let host = "kindwise-noplant.stub.test"
        StubURLProtocol.register(host: host, status: 200, json: """
        {"result": {"is_plant": {"binary": false, "probability": 0.02}}}
        """)

        let provider = makeProvider(host: host, broker: broker(.kindwise))
        await #expect(throws: ProviderError.noPlantDetected) {
            _ = try await provider.identify(image)
        }
    }

    @Test func unauthorizedMapsToCredentialMissing() async {
        let host = "kindwise-401.stub.test"
        StubURLProtocol.register(host: host, status: 401, json: #"{"error": "unauthorized"}"#)

        let provider = makeProvider(host: host, broker: broker(.kindwise, key: "revoked"))
        await #expect(throws: ProviderError.credentialMissing(.kindwise)) {
            _ = try await provider.identify(image)
        }
    }

    @Test func missingBrokerKeyNeverTouchesTheNetwork() async {
        let host = "kindwise-nokey.stub.test"
        StubURLProtocol.register(host: host, status: 200, json: "{}")

        let provider = makeProvider(host: host, broker: StaticCredentialBroker(keys: [:]))
        await #expect(throws: ProviderError.credentialMissing(.kindwise)) {
            _ = try await provider.identify(image)
        }
        #expect(StubURLProtocol.hitCount(host: host) == 0)
    }

    @Test func rateLimitParsesRetryAfter() async throws {
        let host = "kindwise-429.stub.test"
        StubURLProtocol.register(host: host, status: 429, json: "{}", headers: ["Retry-After": "30"])

        let provider = makeProvider(host: host, broker: broker(.kindwise))
        do {
            _ = try await provider.identify(image)
            Issue.record("expected rateLimited")
        } catch let ProviderError.rateLimited(retryAfter) {
            #expect(retryAfter == .seconds(30))
        } catch {
            Issue.record("expected rateLimited, got \(error)")
        }
    }
}

@Suite struct PlantNetProviderTests {
    private func makeProvider(host: String, broker: StaticCredentialBroker) -> PlantNetProvider {
        PlantNetProvider(
            broker: broker,
            session: StubURLProtocol.session,
            baseURL: URL(string: "https://\(host)/v2/identify/all")!
        )
    }

    @Test func happyPathSendsMultipartAndParsesResults() async throws {
        let host = "plantnet-happy.stub.test"
        StubURLProtocol.register(host: host, status: 200, json: """
        {"results": [
            {"score": 0.91, "species": {
                "scientificNameWithoutAuthor": "Ficus lyrata",
                "commonNames": ["Fiddle-leaf fig"],
                "family": {"scientificNameWithoutAuthor": "Moraceae"}}}
        ]}
        """)

        let provider = makeProvider(host: host, broker: broker(.plantNet))
        let candidates = try await provider.identify(image)

        #expect(candidates.count == 1)
        #expect(candidates[0].species.latinName == "Ficus lyrata")
        #expect(candidates[0].species.family == "Moraceae")
        #expect(candidates[0].confidence == 0.91)

        let capture = try #require(StubURLProtocol.capture(host: host))
        let query = capture.request.url?.query()
        #expect(query?.contains("api-key=test-key") == true)
        let contentType = capture.request.value(forHTTPHeaderField: "Content-Type") ?? ""
        #expect(contentType.hasPrefix("multipart/form-data; boundary="))
        let body = try #require(capture.body)
        let bodyString = String(decoding: body, as: UTF8.self)
        #expect(bodyString.contains("name=\"organs\""))
        #expect(bodyString.contains("auto"))
        #expect(bodyString.contains("name=\"images\""))
        #expect(bodyString.contains("fake-jpeg"))
    }

    /// Pl@ntNet's documented semantics: 404 means no species matched, which
    /// is an empty result, not an error.
    @Test func notFoundMeansEmptyResults() async throws {
        let host = "plantnet-404.stub.test"
        StubURLProtocol.register(host: host, status: 404, json: #"{"message": "Species not found"}"#)

        let provider = makeProvider(host: host, broker: broker(.plantNet))
        let candidates = try await provider.identify(image)
        #expect(candidates.isEmpty)
    }

    @Test func forbiddenMapsToCredentialMissing() async {
        let host = "plantnet-403.stub.test"
        StubURLProtocol.register(host: host, status: 403, json: "{}")

        let provider = makeProvider(host: host, broker: broker(.plantNet))
        await #expect(throws: ProviderError.credentialMissing(.plantNet)) {
            _ = try await provider.identify(image)
        }
    }
}

@Suite struct OpenAIVisionProviderTests {
    private func makeProvider(host: String, model: String = "gpt-5.4-mini") -> OpenAIVisionProvider {
        OpenAIVisionProvider(
            broker: broker(.visionReasoner),
            session: StubURLProtocol.session,
            endpoint: URL(string: "https://\(host)/v1/responses")!,
            model: model
        )
    }

    private func responsesJSON(outputText: String) -> String {
        let escaped = outputText
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
            .replacingOccurrences(of: "\n", with: "\\n")
        return """
        {"output": [
            {"type": "reasoning"},
            {"type": "message", "content": [{"type": "output_text", "text": "\(escaped)"}]}
        ]}
        """
    }

    @Test func happyPathParsesCandidatesAndSendsModel() async throws {
        let host = "openai-vision-happy.stub.test"
        StubURLProtocol.register(host: host, status: 200, json: responsesJSON(outputText: """
        {"candidates":[{"latinName":"Monstera deliciosa","commonName":"Swiss cheese plant","confidence":0.8}]}
        """))

        let provider = makeProvider(host: host, model: "custom-model")
        let candidates = try await provider.identify(image)

        #expect(candidates.count == 1)
        #expect(candidates[0].species.latinName == "Monstera deliciosa")
        #expect(candidates[0].provider == .visionReasoner)

        let capture = try #require(StubURLProtocol.capture(host: host))
        #expect(capture.request.value(forHTTPHeaderField: "Authorization") == "Bearer test-key")
        let sentBody = try JSONSerialization.jsonObject(with: try #require(capture.body)) as? [String: Any]
        #expect(sentBody?["model"] as? String == "custom-model")
    }

    @Test func toleratesProseWrappedJSON() async throws {
        let host = "openai-vision-prose.stub.test"
        StubURLProtocol.register(host: host, status: 200, json: responsesJSON(outputText: """
        Sure! Here is the identification:
        {"candidates":[{"latinName":"Ficus lyrata","commonName":null,"confidence":0.6}]}
        Hope that helps.
        """))

        let provider = makeProvider(host: host)
        let candidates = try await provider.identify(image)
        #expect(candidates.count == 1)
        #expect(candidates[0].species.latinName == "Ficus lyrata")
    }

    @Test func emptyCandidatesThrowsNoPlantDetected() async {
        let host = "openai-vision-empty.stub.test"
        StubURLProtocol.register(
            host: host,
            status: 200,
            json: responsesJSON(outputText: #"{"candidates":[]}"#)
        )

        let provider = makeProvider(host: host)
        await #expect(throws: ProviderError.noPlantDetected) {
            _ = try await provider.identify(image)
        }
    }
}

@Suite struct OpenAISpriteProviderTests {
    private let monstera = Species(latinName: "Monstera deliciosa", commonName: "Swiss cheese plant")

    private func makeProvider(host: String) -> OpenAISpriteProvider {
        OpenAISpriteProvider(
            broker: broker(.spriteGenerator),
            session: StubURLProtocol.session,
            endpoint: URL(string: "https://\(host)/v1/images/generations")!
        )
    }

    @Test func happyPathDecodesBase64Png() async throws {
        let host = "openai-sprite-happy.stub.test"
        let pngBytes = Data([0x89, 0x50, 0x4E, 0x47])
        StubURLProtocol.register(host: host, status: 200, json: """
        {"data": [{"b64_json": "\(pngBytes.base64EncodedString())"}]}
        """)

        let provider = makeProvider(host: host)
        let sprite = try await provider.sprite(for: monstera)
        #expect(sprite == pngBytes)

        let capture = try #require(StubURLProtocol.capture(host: host))
        let sentBody = try JSONSerialization.jsonObject(with: try #require(capture.body)) as? [String: Any]
        #expect(sentBody?["model"] as? String == "gpt-image-2")
        #expect(sentBody?["background"] as? String == "transparent")
        #expect(sentBody?["output_format"] as? String == "png")
        let prompt = sentBody?["prompt"] as? String ?? ""
        #expect(prompt.contains("Monstera deliciosa"))
        #expect(prompt.contains("pixel art"))
    }

    @Test func missingPayloadThrowsInvalidResponse() async {
        let host = "openai-sprite-empty.stub.test"
        StubURLProtocol.register(host: host, status: 200, json: #"{"data": []}"#)

        let provider = makeProvider(host: host)
        do {
            _ = try await provider.sprite(for: monstera)
            Issue.record("expected invalidResponse")
        } catch let ProviderError.invalidResponse(message) {
            #expect(message.contains("b64_json"))
        } catch {
            Issue.record("expected invalidResponse, got \(error)")
        }
    }
}
