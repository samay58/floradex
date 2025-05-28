import Foundation
import UIKit

enum GPT4oEndpoint: APIEndpoint {
    case classify(imageData: Data, apiKey: String)
    case funFacts(latinName: String, summary: String?, apiKey: String)
    case completeDetails(details: SpeciesDetails, apiKey: String)
    case fetchPlantDetails(latinName: String, apiKey: String)

    var baseURL: URL { URL(string: "https://api.openai.com")! }
    var path: String { "/v1/chat/completions" }
    var method: HTTPMethod { .post }

    var headers: [String: String]? {
        var baseHeaders = ["Content-Type": "application/json"]
        switch self {
        case .classify(_, let apiKey),
             .funFacts(_, _, let apiKey),
             .completeDetails(_, let apiKey),
             .fetchPlantDetails(_, let apiKey):
            baseHeaders["Authorization"] = "Bearer \(apiKey)"
        }
        return baseHeaders
    }

    var parameters: [String: Any]? {
        switch self {
        case .classify(let imageData, _):
            let base64 = imageData.base64EncodedString()
            return [
                "model": "gpt-4o-mini", // Consider making model configurable
                "messages": [
                    ["role": "system", "content": "You are a botanist. Identify the plant species in the user image. Respond only with compact JSON: {\\\"species\\\":<latin>,\\\"confidence\\\":<0-1>}"],
                    ["role": "user", "content": [
                        ["type": "image_url", "image_url": ["url": "data:image/png;base64,\(base64)"]]
                    ]]
                ],
                "temperature": 0.2
            ]
        case .funFacts(let latinName, let summary, _):
            var systemPrompt = "You are a friendly botanist. Provide 3 concise, interesting facts about \(latinName) that a casual plant lover would find useful. Respond ONLY with JSON array of strings. Each string ≤ 120 characters."
            if let summary = summary, !summary.isEmpty { systemPrompt += "\nContext: \(summary)" }
            return [
                "model": "gpt-4o-mini",
                "messages": [["role": "system", "content": systemPrompt]],
                "temperature": 0.5
            ]
        case .completeDetails(let details, _):
            var dict: [String: Any?] = [
                "id": details.id,
                "latinName": details.latinName,
                "commonName": details.commonName,
                "summary": details.summary,
                "growthHabit": details.growthHabit,
                "sunlight": details.sunlight,
                "water": details.water,
                "soil": details.soil,
                "temperature": details.temperature,
                "bloomTime": details.bloomTime,
                "funFacts": details.funFacts,
                "lastUpdated": ISO8601DateFormatter().string(from: details.lastUpdated)
            ]
            let cleaned = dict.mapValues { $0 ?? NSNull() }
            guard let partialData = try? JSONSerialization.data(withJSONObject: cleaned, options: [.sortedKeys]),
                  let partialJSON = String(data: partialData, encoding: .utf8) else {
                // This failure should ideally be prevented or handled before creating the endpoint
                return nil // Or throw an error from endpoint creation
            }
            let missingKeys = cleaned.filter { ($0.value as? NSNull) != nil }.map { $0.key }
            let needList = missingKeys.joined(separator: ", ")
            let systemPrompt = """
            You are a botanist. Fill realistic, concise values (≤120 chars) for the missing keys [\(needList)].
            Keep existing entries as-is. Return ONLY the complete JSON object (no markdown fences).
            JSON: \(partialJSON)
            """
            return [
                "model": "gpt-4o-mini",
                "messages": [["role": "system", "content": systemPrompt]],
                "temperature": 0.2
            ]
        case .fetchPlantDetails(let latinName, _):
            let systemPrompt = """
            You are a botanist. For the plant species "\(latinName)", provide a complete JSON object with the following fields:
            - commonName: string (common name in English)
            - summary: string (1-2 sentences describing the plant)
            - growthHabit: string (e.g., "Climbing vine", "Bushy shrub")
            - sunlight: string (e.g., "Full sun", "Partial shade")
            - water: string (e.g., "Keep soil moist", "Water weekly")
            - soil: string (e.g., "Well-draining", "Loamy")
            - temperature: string (e.g., "15-25°C", "Frost sensitive")
            - bloomTime: string (e.g., "Spring", "Year-round")
            - funFacts: array of 3-5 strings (interesting facts, each ≤120 chars)

            Respond ONLY with the JSON object, no extra text. All fields must be filled with realistic, concise values.
            """
            return [
                "model": "gpt-4o-mini",
                "messages": [["role": "system", "content": systemPrompt]],
                "temperature": 0.2
            ]
        }
    }
    
    var body: Data? { nil } // Parameters will be serialized into JSON body by default asURLRequest
}

/// Minimal wrapper around OpenAI Vision (GPT-4o) image classification for plants.
/// Uses Chat Completions with a system prompt instructing the model to return JSON {\"species\":<latin>,\"confidence\":<0-1>}.
/// Note: This will incur cost. Make sure to gate by local confidence.
final class GPT4oService: Sendable {
    static let shared = GPT4oService()
    private static let session: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 8
        config.timeoutIntervalForResource = 15
        return URLSession(configuration: config)
    }()
    private init() {}

    enum GPTError: Error { case missingKey, invalidImage, badResponse, underlying(Error) }

    // Response structures for Chat Completions
    private struct OpenAICompletionResponse: Decodable {
        struct Choice: Decodable { let message: Message }
        struct Message: Decodable { let content: String }
        let choices: [Choice]
    }

    func classify(image: UIImage) async throws -> ClassifierResult {
        guard let key = Secrets.openAIApiKey.nonEmpty else { throw GPTError.missingKey }
        guard let pngData = image.pngData() else { throw GPTError.invalidImage }

        let endpoint = GPT4oEndpoint.classify(imageData: pngData, apiKey: key)
        do {
            let completionResponse = try await APIClient.shared.request(endpoint: endpoint) as OpenAICompletionResponse
            guard let content = completionResponse.choices.first?.message.content,
                  let contentData = content.data(using: .utf8),
                  let json = try? JSONSerialization.jsonObject(with: contentData) as? [String: Any],
                  let species = json["species"] as? String,
                  let confidence = json["confidence"] as? Double else {
                throw GPTError.badResponse
            }
            return ClassifierResult(species: species, confidence: confidence, source: .gpt4o)
        } catch let error as APIError {
            throw GPTError.underlying(error)
        } catch let gptError as GPTError {
            throw gptError
        } catch {
            throw GPTError.underlying(error)
        }
    }

    // MARK: - Fun Facts
    func funFacts(for latinName: String, context summary: String?) async throws -> [String] {
        guard let key = Secrets.openAIApiKey.nonEmpty else { throw GPTError.missingKey }
        let endpoint = GPT4oEndpoint.funFacts(latinName: latinName, summary: summary, apiKey: key)
        do {
            let completionResponse = try await APIClient.shared.request(endpoint: endpoint) as OpenAICompletionResponse
            guard let jsonString = completionResponse.choices.first?.message.content,
                  let jsonData = jsonString.data(using: .utf8),
                  let array = try? JSONSerialization.jsonObject(with: jsonData) as? [String] else {
                throw GPTError.badResponse
            }
            return array.prefix(3).map { $0 }
        } catch let error as APIError {
            throw GPTError.underlying(error)
        } catch let gptError as GPTError {
            throw gptError
        } catch {
            throw GPTError.underlying(error)
        }
    }

    func complete(details: SpeciesDetails) async throws -> SpeciesDetails {
        guard let key = Secrets.openAIApiKey.nonEmpty else { throw GPTError.missingKey }
        let endpoint = GPT4oEndpoint.completeDetails(details: details, apiKey: key)
        
        // If endpoint creation failed (e.g., partialJSON issue in parameters)
        guard endpoint.parameters != nil else { throw GPTError.badResponse } 

        do {
            let completionResponse = try await APIClient.shared.request(endpoint: endpoint) as OpenAICompletionResponse
            guard let rawContent = completionResponse.choices.first?.message.content else {
                throw GPTError.badResponse
            }

            let jsonString: String = {
                if let firstBrace = rawContent.firstIndex(of: "{"), let lastBrace = rawContent.lastIndex(of: "}") {
                    return String(rawContent[firstBrace...lastBrace])
                }
                return rawContent
            }()

            guard let rawData = jsonString.data(using: .utf8),
                  var json = (try? JSONSerialization.jsonObject(with: rawData) as? [String: Any]) else {
                throw GPTError.badResponse
            }

            let joinKeys = ["sunlight", "water", "soil", "temperature", "bloomTime"]
            for keyInLoop in joinKeys {
                if let arr = json[keyInLoop] as? [String] {
                    json[keyInLoop] = arr.joined(separator: ", ")
                }
            }
            let normalisedData = try JSONSerialization.data(withJSONObject: json)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            if let completed = try? decoder.decode(SpeciesDetails.self, from: normalisedData) {
                return completed
            }
            return details // Fallback to original if decoding the completed one fails
        } catch let error as APIError {
            print("[GPT4oService] APIError during complete: \(error)")
            throw GPTError.underlying(error)
        } catch let gptError as GPTError {
             print("[GPT4oService] GPTError during complete: \(gptError)")
            throw gptError
        } catch {
            print("[GPT4oService] Unknown error during complete: \(error)")
            throw GPTError.underlying(error)
        }
    }

    // MARK: - Internal helper
    private func performRequest(_ request: URLRequest, retries: Int = 3) async throws -> Data {
        var attemptDelay: UInt64 = 500_000_000 // 0.5s
        var lastError: Error?
        for _ in 0..<retries {
            do {
                let (data, response) = try await Self.session.data(for: request)
                guard (response as? HTTPURLResponse)?.statusCode == 200 else {
                    throw GPTError.badResponse
                }
                return data
            } catch {
                lastError = error
                try? await Task.sleep(nanoseconds: attemptDelay)
                attemptDelay *= 2
            }
        }
        throw lastError ?? GPTError.badResponse
    }

    // Add new method to fetch complete plant details
    func fetchPlantDetails(for latinName: String) async throws -> SpeciesDetails {
        guard let key = Secrets.openAIApiKey.nonEmpty else { throw GPTError.missingKey }
        let endpoint = GPT4oEndpoint.fetchPlantDetails(latinName: latinName, apiKey: key)
        
        do {
            let completionResponse = try await APIClient.shared.request(endpoint: endpoint) as OpenAICompletionResponse
            guard let rawContent = completionResponse.choices.first?.message.content else {
                throw GPTError.badResponse
            }

            let jsonString: String = {
                if let firstBrace = rawContent.firstIndex(of: "{"), let lastBrace = rawContent.lastIndex(of: "}") {
                    return String(rawContent[firstBrace...lastBrace])
                }
                return rawContent
            }()

            guard let rawData = jsonString.data(using: .utf8),
                  let json = try? JSONSerialization.jsonObject(with: rawData) as? [String: Any] else {
                throw GPTError.badResponse
            }

            // Create a new SpeciesDetails with the fetched data
            let details = SpeciesDetails(
                latinName: latinName,
                commonName: json["commonName"] as? String,
                summary: json["summary"] as? String,
                growthHabit: json["growthHabit"] as? String,
                sunlight: json["sunlight"] as? String,
                water: json["water"] as? String,
                soil: json["soil"] as? String,
                temperature: json["temperature"] as? String,
                bloomTime: json["bloomTime"] as? String,
                funFacts: json["funFacts"] as? [String],
                lastUpdated: Date()
            )
            
            return details
        } catch let error as APIError {
            throw GPTError.underlying(error)
        } catch let gptError as GPTError {
            throw gptError
        } catch {
            throw GPTError.underlying(error)
        }
    }
} 