import Foundation

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
    
    // MARK: - Core Request Method
    
    private func request<T: Decodable, B: Encodable>(
        path: String,
        method: String,
        body: B? = nil as String?,
        authenticated: Bool = true
    ) async throws -> T {
        // Build URL
        let url = baseURL.appendingPathComponent(path)
        
        // Create request
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // Add authentication if required
        if authenticated {
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
        
        // Add body if present
        if let body = body {
            request.httpBody = try encoder.encode(body)
            
            // Log request body for debugging
            if ConfigLoader.shared.enableDebugLogging {
                if let jsonString = String(data: request.httpBody!, encoding: .utf8) {
                    print("[APIClient] Request body: \(jsonString)")
                }
            }
        }
        
        // Log request
        if ConfigLoader.shared.enableDebugLogging {
            print("[APIClient] \(method) \(url.absoluteString)")
        }
        
        // Make request
        let (data, response) = try await session.data(for: request)
        
        // Check response
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }
        
        // Log response
        if ConfigLoader.shared.enableDebugLogging {
            print("[APIClient] Response: \(httpResponse.statusCode)")
        }
        
        // Handle status codes
        switch httpResponse.statusCode {
        case 200...299:
            do {
                let decoded = try decoder.decode(T.self, from: data)
                return decoded
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
            // Token expired - try to refresh and retry request once
            if ConfigLoader.shared.enableDebugLogging {
                print("[APIClient] 401 Unauthorized - attempting token refresh")
            }
            
            // Try to refresh token
            do {
                // Note: We can't call AuthService directly due to circular dependency
                // Instead, we'll throw and let the caller handle refresh
                throw APIError.unauthorized
            } catch {
                throw APIError.unauthorized
            }
            
        case 403:
            throw APIError.forbidden
            
        case 404:
            throw APIError.notFound
            
        default:
            if let errorResponse = try? decoder.decode(ErrorResponse.self, from: data) {
                throw APIError.apiError(errorResponse.error, errorResponse.code)
            }
            throw APIError.unknownError(httpResponse.statusCode)
        }
    }
}

// MARK: - Error Response

struct ErrorResponse: Codable {
    let error: String
    let code: String?
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
