import Foundation

// MARK: - Notification Names

extension Notification.Name {
    /// Posted when the API returns 401, indicating the auth session is invalid
    static let authSessionInvalidated = Notification.Name("authSessionInvalidated")
}

/// Network client for making API requests to fotolokashen backend
class APIClient {
    
    // MARK: - Singleton
    
    static let shared = APIClient()
    
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
    
    /// Make a DELETE request
    func delete<T: Decodable>(
        _ path: String,
        authenticated: Bool = true
    ) async throws -> T {
        try await request(path: path, method: "DELETE", body: nil as String?, authenticated: authenticated)
    }
    
    // MARK: - User API
    
    /// Get the current authenticated user
    func getCurrentUser() async throws -> User {
        let response: MeResponse = try await get("/api/auth/me", authenticated: true)
        return response.user
    }
    
    // MARK: - Core Request Method
    
    private func request<T: Decodable, B: Encodable>(
        path: String,
        method: String,
        body: B? = nil as String?,
        authenticated: Bool = true
    ) async throws -> T {
        // Build URL
        let url = baseURL.appendingPathComponent(path)
        
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
            
            if ConfigLoader.shared.enableDebugLogging {
                if let jsonString = String(data: body, encoding: .utf8) {
                    print("[APIClient] Request body: \(jsonString)")
                }
            }
        }
        
        if ConfigLoader.shared.enableDebugLogging {
            print("[APIClient] \(method) \(url.absoluteString)")
        }
        
        return request
    }
    
    /// Add Bearer token authentication header
    private func addAuthenticationHeader(to request: inout URLRequest) throws {
        guard let accessToken = KeychainService.shared.getAccessToken() else {
            if ConfigLoader.shared.enableDebugLogging {
                print("[APIClient] No access token found in Keychain")
            }
            throw APIError.unauthorized
        }
        
        if ConfigLoader.shared.enableDebugLogging {
            print("[APIClient] Using access token: \(accessToken.prefix(20))...")
        }
        
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
    }
    
    /// Validate and extract HTTPURLResponse
    private func validateResponse(_ response: URLResponse) throws -> HTTPURLResponse {
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }
        
        if ConfigLoader.shared.enableDebugLogging {
            print("[APIClient] Response: \(httpResponse.statusCode)")
        }
        
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
                return try decoder.decode(T.self, from: data)
            } catch {
                if ConfigLoader.shared.enableDebugLogging {
                    print("[APIClient] Decode error: \(error)")
                    if let jsonString = String(data: data, encoding: .utf8) {
                        print("[APIClient] Response data: \(jsonString)")
                    }
                }
                throw APIError.decodingFailed(error)
            }
            
        case 401:
            if ConfigLoader.shared.enableDebugLogging {
                print("[APIClient] 401 Unauthorized - token is invalid or expired")
            }
            // Post notification so AuthService can handle logout
            DispatchQueue.main.async {
                NotificationCenter.default.post(name: .authSessionInvalidated, object: nil)
            }
            throw APIError.unauthorized
            
        case 403:
            throw APIError.forbidden
            
        case 404:
            throw APIError.notFound
            
        default:
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

// MARK: - Me Response

struct MeResponse: Codable {
    let user: User
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
