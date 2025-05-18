import Foundation

// Define APIError enum to handle various network and decoding errors.
enum APIError: Error {
    case invalidURL
    case requestFailed(Error)
    case unsuccessfulResponse(statusCode: Int, data: Data?)
    case decodingFailed(Error)
    case noData
}

// Protocol to define the structure of an API endpoint.
// Services will provide concrete types conforming to this.
protocol APIEndpoint {
    var baseURL: URL { get }
    var path: String { get }
    var method: HTTPMethod { get }
    var headers: [String: String]? { get }
    var parameters: [String: Any]? { get } // For query params or JSON body
    var body: Data? { get } // For custom body data, e.g., multipart
    /// Optional override for per-request timeout. Uses session default if nil.
    var timeout: TimeInterval? { get }

    // Helper to build the URLRequest
    func asURLRequest() throws -> URLRequest
}

enum HTTPMethod: String {
    case get = "GET"
    case post = "POST"
    // Add other methods as needed (PUT, DELETE, etc.)
}

extension APIEndpoint {
    // Default implementation for asURLRequest for common cases
    func asURLRequest() throws -> URLRequest {
        guard var components = URLComponents(url: baseURL.appendingPathComponent(path), resolvingAgainstBaseURL: true) else {
            throw APIError.invalidURL
        }

        var requestBody: Data? = self.body

        if method == .get, let params = parameters as? [String: String] {
            components.queryItems = params.map { URLQueryItem(name: $0.key, value: $0.value) }
        } else if (method == .post /* || other methods with body */), let params = parameters, body == nil {
            requestBody = try? JSONSerialization.data(withJSONObject: params)
        }
        
        guard let url = components.url else {
            throw APIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = method.rawValue
        request.httpBody = requestBody

        // Common headers
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        headers?.forEach { request.setValue($1, forHTTPHeaderField: $0) }

        // Apply per-endpoint timeout if provided
        if let timeoutInterval = timeout {
            request.timeoutInterval = timeoutInterval
        }

        return request
    }

    // Provide default implementation so existing endpoints don't have to specify manually
    var timeout: TimeInterval? { nil }
}

final class APIClient {
    static let shared = APIClient()

    private let session: URLSession

    private init() {
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 8 // As per project rule-009
        configuration.timeoutIntervalForResource = 30 // Overall timeout for the resource
        // Potentially add other configurations like caching policy if needed
        self.session = URLSession(configuration: configuration)
    }

    func request<T: Decodable>(endpoint: APIEndpoint, retries: Int = 3, initialDelay: TimeInterval = 1.0) async throws -> T {
        var attempts = 0
        var currentDelay = initialDelay

        while attempts < retries {
            attempts += 1
            do {
                let urlRequest = try endpoint.asURLRequest()
                
                // Basic logging (can be expanded)
                print("[APIClient] Requesting: \(urlRequest.httpMethod ?? "N/A") \(urlRequest.url?.absoluteString ?? "N/A")")

                let (data, response) = try await session.data(for: urlRequest)

                guard let httpResponse = response as? HTTPURLResponse else {
                    throw APIError.unsuccessfulResponse(statusCode: -1, data: data) // Or a more specific error
                }
                
                print("[APIClient] Response: \(httpResponse.statusCode) for \(urlRequest.url?.absoluteString ?? "N/A")")

                guard (200...299).contains(httpResponse.statusCode) else {
                    // Log error details
                    if let responseBody = String(data: data, encoding: .utf8) {
                        print("[APIClient] Error Response Body: \(responseBody)")
                    }
                    throw APIError.unsuccessfulResponse(statusCode: httpResponse.statusCode, data: data)
                }

                guard !data.isEmpty else {
                    // Handle cases where T is Void or similar, or expect no data
                    if T.self == Void.self || T.self == Optional<Void>.self {
                        // If T is Void or Optional<Void>, allow empty data.
                        // We need a way to return Void, which isn't directly decodable.
                        // This might require a special handling or a different function signature for no-response-body requests.
                        // For now, assuming T is always a Decodable struct/class from JSON.
                        // This part needs refinement if truly empty responses for Decodable T are expected.
                        // A common pattern is to use a specific `EmptyResponse: Decodable` struct.
                        // Throwing noData for now if T is not Void, expecting JSON.
                        throw APIError.noData
                    }
                    // If T is something that expects data, and data is empty, it's an issue.
                    throw APIError.noData
                }
                
                do {
                    let decodedObject = try JSONDecoder().decode(T.self, from: data)
                    return decodedObject
                } catch {
                    print("[APIClient] Decoding failed: \(error) for \(urlRequest.url?.absoluteString ?? "N/A")")
                    if let responseBody = String(data: data, encoding: .utf8) {
                        print("[APIClient] Failed to decode body: \(responseBody)")
                    }
                    throw APIError.decodingFailed(error)
                }

            } catch let error as APIError { // APIErrors are "final" for this attempt
                if attempts == retries {  // If it's the last attempt, rethrow the APIError
                    print("[APIClient] Request failed after \(attempts) attempts (APIError): \(error)")
                    throw error
                }
                // For certain API errors (like server errors 5xx or specific transient ones), we might retry.
                // For now, only network requestFailed errors are retried by the outer catch.
                // This needs refinement based on which APIErrors should be retriable.
                // For now, rethrowing to be caught by the generic catch if not a requestFailed error.
                 print("[APIClient] Attempt \(attempts)/\(retries) failed (APIError): \(error). Not retrying this type of APIError immediately.")
                throw error // Rethrow non-retriable API errors or let outer catch decide for network ones

            } catch { // Catch other errors (like network connection issues) and retry
                print("[APIClient] Attempt \(attempts)/\(retries) failed: \(error)")
                if attempts == retries {
                    print("[APIClient] Request failed after \(attempts) attempts: \(error)")
                    throw APIError.requestFailed(error)
                }
                // Exponential backoff
                try await Task.sleep(nanoseconds: UInt64(currentDelay * 1_000_000_000))
                currentDelay *= 2
                print("[APIClient] Retrying in \(currentDelay)s...")
            }
        }
        // Should not be reached if retries are exhausted, as errors are thrown.
        // Adding a fallback throw to satisfy compiler, but indicates a logic flaw if reached.
        fatalError("APIClient reached an unexpected state after exhausting retries.")
    }
}

// Example of how a service might define its endpoint (to be moved/adapted later)
/*
enum WikipediaEndpoint: APIEndpoint {
    case getSummary(pageTitle: String)

    var baseURL: URL { URL(string: "https://en.wikipedia.org/api/rest_v1")! }

    var path: String {
        switch self {
        case .getSummary(let pageTitle):
            return "/page/summary/\(pageTitle.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? "")"
        }
    }

    var method: HTTPMethod { .get }
    var headers: [String: String]? { nil }
    var parameters: [String: Any]? { nil }
    var body: Data? { nil }
}
*/

// Placeholder for Void responses if needed
struct EmptyResponse: Decodable {}

// Extension for T == Void case (might not be directly usable with `decode(T.self, ...)` if T is Void)
// A common approach is to have a separate request function or check `data.isEmpty` and return if T is Optional<Something>.
// Or ensure that endpoints expecting no body data return a specific `EmptyResponse` type.

extension APIClient {
    func requestVoid(endpoint: APIEndpoint, retries: Int = 3, initialDelay: TimeInterval = 1.0) async throws {
        var attempts = 0
        var currentDelay = initialDelay

        while attempts < retries {
            attempts += 1
            do {
                let urlRequest = try endpoint.asURLRequest()
                 print("[APIClient] Requesting (Void): \(urlRequest.httpMethod ?? "N/A") \(urlRequest.url?.absoluteString ?? "N/A")")

                let (data, response) = try await session.data(for: urlRequest)

                guard let httpResponse = response as? HTTPURLResponse else {
                    throw APIError.unsuccessfulResponse(statusCode: -1, data: data)
                }
                
                print("[APIClient] Response (Void): \(httpResponse.statusCode) for \(urlRequest.url?.absoluteString ?? "N/A")")

                guard (200...299).contains(httpResponse.statusCode) else {
                     if let responseBody = String(data: data, encoding: .utf8) {
                        print("[APIClient] Error Response Body (Void): \(responseBody)")
                    }
                    throw APIError.unsuccessfulResponse(statusCode: httpResponse.statusCode, data: data)
                }
                return // Success
            } catch let error as APIError {
                 if attempts == retries {
                    print("[APIClient] Request (Void) failed after \(attempts) attempts (APIError): \(error)")
                    throw error
                }
                print("[APIClient] Attempt \(attempts)/\(retries) (Void) failed (APIError): \(error). Not retrying this type of APIError immediately.")
                throw error
            } catch {
                print("[APIClient] Attempt \(attempts)/\(retries) (Void) failed: \(error)")
                if attempts == retries {
                    print("[APIClient] Request (Void) failed after \(attempts) attempts: \(error)")
                    throw APIError.requestFailed(error)
                }
                try await Task.sleep(nanoseconds: UInt64(currentDelay * 1_000_000_000))
                currentDelay *= 2
                 print("[APIClient] Retrying (Void) in \(currentDelay)s...")
            }
        }
        fatalError("APIClient requestVoid reached an unexpected state after exhausting retries.")
    }
} 