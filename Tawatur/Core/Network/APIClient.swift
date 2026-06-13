// APIClient.swift — Centralised HTTP client
// Uses URLSession + async/await. Automatically:
//   - Injects the Bearer token from TokenManager.
//   - Retries once with a fresh access token on 401.
//   - Decodes snake_case JSON into camelCase Swift models.
//   - Forces Wi-Fi only so LAN IPs are reachable without iOS Wi-Fi Assist interference.

import Foundation
import Network

final class APIClient {

    static let shared = APIClient()
    private init() {}

    // Change this to your Mac's LAN IP if it changes (run `ipconfig getifaddr en0` on Mac)
    private let baseURL = URL(string: "http://192.168.100.200:8000/api/v1/")!

    // Wi-Fi only session.
    // allowsCellularAccess = false  → don't use cellular
    // allowsConstrainedNetworkAccess = true  → allow even on Low Data Mode Wi-Fi
    // allowsExpensiveNetworkAccess = true    → allow even on hotspot/metered Wi-Fi
    // waitsForConnectivity = false           → fail immediately, don't queue forever
    private let session: URLSession = {
        let config = URLSessionConfiguration.default
        config.allowsCellularAccess          = false
        config.allowsConstrainedNetworkAccess = true
        config.allowsExpensiveNetworkAccess   = true
        config.waitsForConnectivity           = false
        config.timeoutIntervalForRequest      = 10
        config.timeoutIntervalForResource     = 30
        return URLSession(configuration: config)
    }()

    // ── Decoders ──────────────────────────────────────────────────────────────

    private let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.keyDecodingStrategy  = .convertFromSnakeCase   // user_type → userType
        d.dateDecodingStrategy = .custom { decoder in
            let str = try decoder.singleValueContainer().decode(String.self)
            let formatters: [ISO8601DateFormatter] = [
                { let f = ISO8601DateFormatter(); f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]; return f }(),
                { let f = ISO8601DateFormatter(); f.formatOptions = [.withInternetDateTime]; return f }(),
            ]
            for f in formatters {
                if let date = f.date(from: str) { return date }
            }
            throw DecodingError.dataCorruptedError(in: try decoder.singleValueContainer(),
                                                   debugDescription: "Invalid date: \(str)")
        }
        return d
    }()

    // ── Connectivity ping (used by server status banner) ──────────────────────

    /// Uses NWConnection (Network.framework) — bypasses URLSession's pre-flight
    /// reachability check that rejects LAN IPs when Wi-Fi has no internet.
    func ping() async -> (Bool, String) {
        await withCheckedContinuation { continuation in
            let params = NWParameters.tcp
            // Block cellular so iOS is forced to route through Wi-Fi to the LAN IP
            params.prohibitedInterfaceTypes = [.cellular]

            let connection = NWConnection(
                host: "192.168.100.200",
                port: 8000,
                using: params
            )

            let lock = NSLock()
            var done = false

            func finish(_ result: (Bool, String)) {
                lock.lock()
                let already = done
                done = true
                lock.unlock()
                guard !already else { return }
                connection.cancel()
                continuation.resume(returning: result)
            }

            connection.stateUpdateHandler = { state in
                switch state {
                case .ready:
                    finish((true, "TCP OK → 192.168.100.200:8000"))
                case .failed(let err):
                    finish((false, "NW failed: \(err)"))
                case .waiting(let err):
                    finish((false, "NW waiting: \(err)"))
                case .cancelled:
                    finish((false, "Cancelled"))
                default:
                    break
                }
            }

            connection.start(queue: .global(qos: .userInitiated))

            // Hard timeout — finish no later than 6 seconds
            DispatchQueue.global().asyncAfter(deadline: .now() + 6) {
                finish((false, "Timeout (6s) — is backend running on 0.0.0.0:8000?"))
            }
        }
    }

    // ── Public request methods ────────────────────────────────────────────────

    func request<T: Decodable>(_ endpoint: APIEndpoint, as: T.Type = T.self) async throws -> T {
        let data = try await perform(endpoint)
        do {
            return try decoder.decode(T.self, from: data)
        } catch {
            throw NetworkError.decodingError(error.localizedDescription)
        }
    }

    @discardableResult
    func requestEmpty(_ endpoint: APIEndpoint) async throws -> Void {
        _ = try await perform(endpoint)
    }

    // ── Private helpers ───────────────────────────────────────────────────────

    private func perform(_ endpoint: APIEndpoint) async throws -> Data {
        var urlRequest = try buildRequest(endpoint)

        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await session.data(for: urlRequest)
        } catch let urlError as URLError {
            throw mapURLError(urlError)
        }

        guard let http = response as? HTTPURLResponse else {
            throw NetworkError.invalidResponse
        }

        if http.statusCode == 401 && endpoint.requiresAuth {
            try await refreshAccessToken()
            urlRequest = try buildRequest(endpoint)
            let (data2, response2) = try await session.data(for: urlRequest)
            return try validate(data2, response: response2)
        }

        return try validate(data, response: response)
    }

    private func buildRequest(_ endpoint: APIEndpoint) throws -> URLRequest {
        guard let url = URL(string: endpoint.path, relativeTo: baseURL) else {
            throw NetworkError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod      = endpoint.method.rawValue
        request.timeoutInterval = 10

        if endpoint.requiresAuth, let token = TokenManager.shared.accessToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        if let body = endpoint.body {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            let clean = body.compactMapValues { $0 }
            request.httpBody = try JSONSerialization.data(withJSONObject: clean)
        }

        return request
    }

    private func validate(_ data: Data, response: URLResponse) throws -> Data {
        guard let http = response as? HTTPURLResponse else {
            throw NetworkError.invalidResponse
        }
        guard (200...299).contains(http.statusCode) else {
            let message = (try? decoder.decode(APIError.self, from: data))?.message
                       ?? HTTPURLResponse.localizedString(forStatusCode: http.statusCode)
            throw NetworkError.httpError(statusCode: http.statusCode, message: message)
        }
        return data
    }

    private func refreshAccessToken() async throws {
        guard let refresh = TokenManager.shared.refreshToken else {
            throw NetworkError.unauthorized
        }

        struct RefreshBody: Encodable { let refresh: String }
        struct RefreshResponse: Decodable { let access: String }

        var req = URLRequest(url: URL(string: "auth/token/refresh/", relativeTo: baseURL)!)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try JSONEncoder().encode(RefreshBody(refresh: refresh))

        let (data, response) = try await session.data(for: req)

        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            TokenManager.shared.clear()
            throw NetworkError.unauthorized
        }

        let result = try decoder.decode(RefreshResponse.self, from: data)
        TokenManager.shared.updateAccess(result.access)
    }

    // Maps URLError codes to typed NetworkError so the UI shows Arabic messages.
    private func mapURLError(_ error: URLError) -> NetworkError {
        switch error.code {
        case .notConnectedToInternet, .networkConnectionLost, .dataNotAllowed:
            return .noInternet
        case .cannotFindHost, .cannotConnectToHost, .resourceUnavailable:
            return .serverUnreachable
        case .timedOut:
            return .timedOut
        default:
            return .serverUnreachable
        }
    }
}
