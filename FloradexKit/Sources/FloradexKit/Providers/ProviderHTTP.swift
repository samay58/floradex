import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// Shared transport for provider clients: executes a request and maps the
/// failure surface onto `ProviderError` so every client fails the same way.
struct ProviderHTTP: Sendable {
    let session: URLSession

    init(session: URLSession) {
        self.session = session
    }

    /// Statuses in `allowing` are returned to the caller instead of being
    /// mapped to errors (Pl@ntNet uses 404 to mean "no species found").
    func execute(
        _ request: URLRequest,
        for provider: ProviderID,
        allowing allowedStatuses: Set<Int> = []
    ) async throws -> (data: Data, status: Int) {
        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch let error as URLError where error.code == .timedOut {
            throw ProviderError.timeout
        } catch let error as URLError {
            throw ProviderError.network(error.localizedDescription)
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            throw ProviderError.network(String(describing: error))
        }

        guard let http = response as? HTTPURLResponse else {
            throw ProviderError.invalidResponse("non-HTTP response")
        }
        let status = http.statusCode
        if allowedStatuses.contains(status) || (200..<300).contains(status) {
            return (data, status)
        }
        switch status {
        case 401, 403:
            throw ProviderError.credentialMissing(provider)
        case 429:
            let retryAfter = http.value(forHTTPHeaderField: "Retry-After")
                .flatMap(Double.init)
                .map { Duration.seconds($0) }
            throw ProviderError.rateLimited(retryAfter: retryAfter)
        default:
            let bodyPrefix = String(decoding: data.prefix(200), as: UTF8.self)
            throw ProviderError.invalidResponse("HTTP \(status): \(bodyPrefix)")
        }
    }

    static func makeDefaultSession(requestTimeout: TimeInterval = 20, resourceTimeout: TimeInterval = 120) -> URLSession {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = requestTimeout
        configuration.timeoutIntervalForResource = resourceTimeout
        return URLSession(configuration: configuration)
    }
}

extension ImagePayload.Format {
    var mimeType: String {
        switch self {
        case .heic: return "image/heic"
        case .jpeg: return "image/jpeg"
        case .png: return "image/png"
        }
    }
}
