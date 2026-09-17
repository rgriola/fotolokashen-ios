import Foundation

// MARK: - Notification Names

extension Notification.Name {
    /// Posted when a request is rejected with 401 and a token refresh could not recover it,
    /// indicating the auth session is genuinely invalid
    static let authSessionInvalidated = Notification.Name("authSessionInvalidated")
}

// MARK: - Token Refresh Hook

/// Supplies a fresh access token when a request is rejected with 401.
/// Implemented by `AuthService` and registered at launch so `APIClient` can recover
/// from a stale token without depending on `AuthService` directly.
@MainActor
protocol TokenRefreshing: AnyObject {
    /// - Parameter staleAccessToken: the token the failed request actually sent, or nil if
    ///   unknown. Lets the refresher skip the exchange when the token has already been
    ///   rotated by someone else.
    func refreshAccessTokenForRetry(staleAccessToken: String?) async throws
}

/// Network client for making API requests to fotolokashen backend
class APIClient {
    
    // MARK: - Singleton
    
    static let shared = APIClient()

    // MARK: - Token Refresh Registration

    /// Registered by `AuthService` at launch. Weak so the client never keeps the
    /// auth service alive. MainActor-isolated because `AuthService` is.
    @MainActor private static weak var tokenRefresher: TokenRefreshing?

    /// Wire up the token refresher. Call once during app startup.
    @MainActor
    static func setTokenRefresher(_ refresher: TokenRefreshing?) {
        tokenRefresher = refresher
    }

    /// Attempt one token refresh. Returns false when there is no refresher registered
    /// or the refresh failed, in which case the 401 stands.
    @MainActor
    private static func attemptTokenRefresh(staleAccessToken: String?) async -> Bool {
        guard let refresher = tokenRefresher else { return false }
        do {
            try await refresher.refreshAccessTokenForRetry(staleAccessToken: staleAccessToken)
            return true
        } catch {
            #if DEBUG
            print("[APIClient] Token refresh for 401 retry failed: \(error)")
            #endif
            return false
        }
    }

    /// Posted on the main actor: observers drive UI (logout) off this notification.
    private static func notifySessionInvalidated() async {
        await MainActor.run {
            NotificationCenter.default.post(name: .authSessionInvalidated, object: nil)
        }
    }
    
    // MARK: - Properties
    
    private let baseURL: URL
    private let session: URLSession
    private let decoder: JSONDecoder
    private let encoder: JSONEncoder
    
    // MARK: - Initialization
    
    private init() {
        self.baseURL = ConfigLoader.shared.backendURL

        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 60
        self.session = URLSession(configuration: config)

        self.decoder = JSONDecoder()
        self.decoder.dateDecodingStrategy = .iso8601

        self.encoder = JSONEncoder()
        self.encoder.dateEncodingStrategy = .iso8601
    }

    /// Test-only initializer that accepts an injected session and base URL.
    /// Used by `APIClientTests` to wire a `URLProtocol` stub. Not intended for
    /// production callers — use `APIClient.shared` instead.
    internal init(session: URLSession, baseURL: URL) {
        self.baseURL = baseURL
        self.session = session
        self.decoder = JSONDecoder()
        self.decoder.dateDecodingStrategy = .iso8601
        self.encoder = JSONEncoder()
        self.encoder.dateEncodingStrategy = .iso8601
    }
    
    // MARK: - Request Methods
    
    /// Make a POST request
    func post<T: Decodable, B: Encodable>(
        _ path: String,
        body: B,
        authenticated: Bool = true
    ) async throws -> T {
        try await request(path: path, method: "POST", body: body, authenticated: authenticated)
    }
    
    /// Make a GET request
    func get<T: Decodable>(
        _ path: String,
        authenticated: Bool = true
    ) async throws -> T {
        try await request(path: path, method: "GET", body: nil as String?, authenticated: authenticated)
    }
    
    /// Make a PATCH request
    func patch<T: Decodable, B: Encodable>(
        _ path: String,
        body: B,
        authenticated: Bool = true
    ) async throws -> T {
        try await request(path: path, method: "PATCH", body: body, authenticated: authenticated)
    }

    /// Make a PUT request
    func put<T: Decodable, B: Encodable>(
        _ path: String,
        body: B,
        authenticated: Bool = true
    ) async throws -> T {
        try await request(path: path, method: "PUT", body: body, authenticated: authenticated)
    }

    /// Make a DELETE request
    func delete<T: Decodable>(
        _ path: String,
        authenticated: Bool = true
    ) async throws -> T {
        try await request(path: path, method: "DELETE", body: nil as String?, authenticated: authenticated)
    }

    /// DELETE with request body
    func delete<T: Decodable, B: Encodable>(
        _ path: String,
        body: B,
        authenticated: Bool = true
    ) async throws -> T {
        try await request(path: path, method: "DELETE", body: body, authenticated: authenticated)
    }

    // MARK: - User API

    /// Get the current authenticated user via /api/v1/users/me
    func getCurrentUser() async throws -> User {
        let response: V1MeResponse = try await get("/api/v1/users/me", authenticated: true)
        return response.user
    }
    
    // MARK: - Core Request Method
    
    private func request<T: Decodable, B: Encodable>(
        path: String,
        method: String,
        body: B? = nil as String?,
        authenticated: Bool = true,
        allowRetry: Bool = true
    ) async throws -> T {
        // Build URL using string concatenation to preserve query parameters
        // (appendingPathComponent percent-encodes ? and & characters, breaking query strings)
        let baseString = baseURL.absoluteString.hasSuffix("/")
            ? String(baseURL.absoluteString.dropLast())
            : baseURL.absoluteString
        let fullPath = path.hasPrefix("/") ? path : "/\(path)"
        guard let url = URL(string: baseString + fullPath) else {
            throw URLError(.badURL)
        }
        
        // Encode body if present
        let bodyData: Data? = try body.map { try encoder.encode($0) }
        
        // Prepare request with headers and authentication
        let request = try prepareRequest(
            url: url,
            method: method,
            body: bodyData,
            authenticated: authenticated
        )
        
        // Make request
        let (data, response) = try await session.data(for: request)

        // Validate response
        let httpResponse = try validateResponse(response)

        // A 401 on an authenticated request is far more often a stale access token than a
        // dead session. Refresh once and retry before tearing the user's session down —
        // logging out on the first 401 turns any transient server-side auth blip into a logout.
        if httpResponse.statusCode == 401 && authenticated {
            // Which token this attempt actually sent. If it has since been rotated by another
            // request, the refresher skips the exchange and we just retry with the current one —
            // otherwise N staggered 401s would trigger N sequential refreshes.
            let sentAccessToken = request.value(forHTTPHeaderField: "Authorization")
                .flatMap { $0.hasPrefix("Bearer ") ? String($0.dropFirst(7)) : nil }

            if allowRetry, await Self.attemptTokenRefresh(staleAccessToken: sentAccessToken) {
                return try await self.request(
                    path: path,
                    method: method,
                    body: body,
                    authenticated: authenticated,
                    allowRetry: false
                )
            }
            await Self.notifySessionInvalidated()
            throw APIError.unauthorized
        }

        // Handle status code and decode
        return try handleStatusCode(httpResponse.statusCode, data: data)
    }
    
    // MARK: - Private Helpers
    
    /// Prepare URLRequest with method and headers
    private func prepareRequest(
        url: URL,
        method: String,
        body: Data?,
        authenticated: Bool
    ) throws -> URLRequest {
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        if authenticated {
            try addAuthenticationHeader(to: &request)
        }
        
        if let body = body {
            request.httpBody = body
            
            #if DEBUG
            if ConfigLoader.shared.enableDebugLogging {
                if let jsonString = String(data: body, encoding: .utf8) {
                    print("[APIClient] Request body: \(jsonString)")
                }
            }
            #endif
        }
        
        #if DEBUG
        if ConfigLoader.shared.enableDebugLogging {
            print("[APIClient] \(method) \(url.absoluteString)")
        }
        #endif
        
        return request
    }
    
    /// Add Bearer token authentication header
    private func addAuthenticationHeader(to request: inout URLRequest) throws {
        guard let accessToken = KeychainService.shared.getAccessToken() else {
            #if DEBUG
            if ConfigLoader.shared.enableDebugLogging {
                print("[APIClient] No access token found in Keychain")
            }
            #endif
            throw APIError.unauthorized
        }
        
        #if DEBUG
        if ConfigLoader.shared.enableDebugLogging {
            print("[APIClient] Using access token: [REDACTED]")
        }
        #endif
        
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
    }
    
    /// Validate and extract HTTPURLResponse
    private func validateResponse(_ response: URLResponse) throws -> HTTPURLResponse {
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }
        
        #if DEBUG
        if ConfigLoader.shared.enableDebugLogging {
            print("[APIClient] Response: \(httpResponse.statusCode)")
        }
        #endif
        
        return httpResponse
    }
    
    /// Handle HTTP status codes and decode response
    private func handleStatusCode<T: Decodable>(
        _ statusCode: Int,
        data: Data
    ) throws -> T {
        switch statusCode {
        case 200...299:
            do {
                #if DEBUG
                if ConfigLoader.shared.enableDebugLogging {
                    if let jsonString = String(data: data, encoding: .utf8) {
                        let preview = jsonString.prefix(500)
                        print("[APIClient] Response data (\(data.count) bytes): \(preview)\(jsonString.count > 500 ? "…[truncated]" : "")")
                    }
                }
                #endif
                return try decoder.decode(T.self, from: data)
            } catch {
                #if DEBUG
                if ConfigLoader.shared.enableDebugLogging {
                    print("[APIClient] Decode error: \(error)")
                    if let jsonString = String(data: data, encoding: .utf8) {
                        print("[APIClient] Failed response data: \(jsonString)")
                    }
                }
                #endif
                throw APIError.decodingFailed(error)
            }
            
        case 401:
            #if DEBUG
            if ConfigLoader.shared.enableDebugLogging {
                print("[APIClient] 401 Unauthorized - token is invalid or expired")
            }
            #endif
            // Reached only for unauthenticated requests (e.g. login). Authenticated 401s are
            // handled in `request(...)`, which refreshes and retries before invalidating.
            throw APIError.unauthorized
            
        case 403:
            throw APIError.forbidden
            
        case 404:
            throw APIError.notFound
            
        default:
            // REVIEW: Status 400 (and other 4xx/5xx) tries to decode ErrorResponse but silently
            // falls back to .unknownError if decoding fails. Consider logging the raw response
            // body in DEBUG builds to aid debugging malformed server responses.
            if let errorResponse = try? decoder.decode(ErrorResponse.self, from: data) {
                throw APIError.apiError(errorResponse.error, errorResponse.code)
            }
            throw APIError.unknownError(statusCode)
        }
    }
}

// MARK: - Error Response

struct ErrorResponse: Codable {
    let error: String
    let code: String?
}

// MARK: - Me Response (legacy /api/auth/me)

struct MeResponse: Codable {
    let user: User
}

// MARK: - Success Response

/// Generic success response for delete/update operations
struct SuccessResponse: Codable {
    let success: Bool?
    let message: String?
}

// MARK: - API Errors

enum APIError: Error, LocalizedError {
    case invalidResponse
    case unauthorized
    case forbidden
    case notFound
    case decodingFailed(Error)
    case apiError(String, String?)
    case unknownError(Int)
    
    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "Invalid response from server"
        case .unauthorized:
            return "Authentication required. Please log in again."
        case .forbidden:
            return "You don't have permission to access this resource"
        case .notFound:
            return "Resource not found"
        case .decodingFailed(let error):
            return "Failed to decode response: \(error.localizedDescription)"
        case .apiError(let message, _):
            return message
        case .unknownError(let code):
            return "Unknown error (\(code))"
        }
    }
}
