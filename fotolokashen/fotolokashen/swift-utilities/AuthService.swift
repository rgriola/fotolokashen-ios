import Foundation
import SwiftUI
import Combine

/// Authentication service managing OAuth2 PKCE flow
@MainActor
class AuthService: ObservableObject {
    
    // MARK: - Published Properties
    
    @Published var isAuthenticated = false
    @Published var currentUser: User?
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    // MARK: - Properties
    
    private let apiClient = APIClient.shared
    private let keychainService = KeychainService.shared
    private let config = ConfigLoader.shared
    
    // PKCE state
    private var codeVerifier: String?
    private var codeChallenge: String?
    
    // MARK: - Initialization
    
    init() {
        checkAuthStatus()
    }
    
    // MARK: - Auth Status
    
    /// Check if user is authenticated
    func checkAuthStatus() {
        if keychainService.hasValidTokens() {
            isAuthenticated = true
            // TODO: Fetch current user from API
        } else {
            isAuthenticated = false
            currentUser = nil
        }
    }
    
    // MARK: - OAuth Login
    
    /// Start OAuth login flow by opening Safari
    func startLogin() {
        // Generate PKCE
        let (verifier, challenge) = PKCEGenerator.generate()
        self.codeVerifier = verifier
        self.codeChallenge = challenge
        
        if config.enableDebugLogging {
            print("[AuthService] Starting OAuth flow")
            print("[AuthService] Code challenge: \(challenge)")
        }
        
        // Build login URL with OAuth parameters
        var components = URLComponents(url: config.backendURL, resolvingAgainstBaseURL: false)!
        components.path = "/login"
        components.queryItems = [
            URLQueryItem(name: "client_id", value: config.oauthClientId),
            URLQueryItem(name: "redirect_uri", value: config.oauthRedirectUri),
            URLQueryItem(name: "code_challenge", value: challenge),
            URLQueryItem(name: "code_challenge_method", value: "S256"),
            URLQueryItem(name: "scope", value: config.oauthScopesString),
            URLQueryItem(name: "response_type", value: "code")
        ]
        
        guard let loginURL = components.url else {
            errorMessage = "Failed to build login URL"
            return
        }
        
        if config.enableDebugLogging {
            print("[AuthService] Opening Safari: \(loginURL.absoluteString)")
        }
        
        // Open Safari for login
        UIApplication.shared.open(loginURL)
    }
    
    /// Handle OAuth callback with authorization code
    func handleCallback(url: URL) async {
        isLoading = true
        errorMessage = nil
        
        if config.enableDebugLogging {
            print("[AuthService] Handling callback: \(url.absoluteString)")
        }
        
        // Parse authorization code from URL
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let code = components.queryItems?.first(where: { $0.name == "code" })?.value else {
            errorMessage = "No authorization code in callback"
            isLoading = false
            return
        }
        
        if config.enableDebugLogging {
            print("[AuthService] Authorization code received: \(code)")
        }
        
        do {
            // Exchange code for tokens
            try await exchangeCodeForTokens(code: code)
        } catch {
            if config.enableDebugLogging {
                print("[AuthService] Token exchange error: \(error)")
            }
            errorMessage = error.localizedDescription
        }
        
        isLoading = false
    }
    
    // MARK: - Token Exchange
    
    /// Exchange authorization code for access token
    private func exchangeCodeForTokens(code: String) async throws {
        guard let verifier = codeVerifier else {
            throw AuthError.missingCodeVerifier
        }
        
        let tokenRequest = TokenRequest(
            grantType: "authorization_code",
            code: code,
            codeVerifier: verifier,
            clientId: config.oauthClientId,
            redirectUri: config.oauthRedirectUri
        )
        
        let tokenResponse: TokenResponse = try await apiClient.post(
            "/api/auth/oauth/token",
            body: tokenRequest,
            authenticated: false
        )
        
        if config.enableDebugLogging {
            print("[AuthService] Tokens received for user: \(tokenResponse.user.email)")
        }
        
        // Save tokens
        let token = OAuthToken(from: tokenResponse)
        try keychainService.saveToken(token)
        
        // Update state
        currentUser = tokenResponse.user
        isAuthenticated = true
        
        // Clear PKCE state
        codeVerifier = nil
        codeChallenge = nil
    }
    
    // MARK: - Logout
    
    /// Logout user
    func logout() async {
        isLoading = true
        
        do {
            // Revoke refresh token on server
            if let refreshToken = keychainService.getRefreshToken() {
                let revokeRequest = RevokeRequest(
                    token: refreshToken,
                    clientId: config.oauthClientId
                )
                
                let _: RevokeTokenResponse = try await apiClient.post(
                    "/api/auth/oauth/revoke",
                    body: revokeRequest,
                    authenticated: false
                )
                
                if config.enableDebugLogging {
                    print("[AuthService] Token revoked on server")
                }
            }
            
            // Clear local tokens
            try keychainService.clearTokens()
            
            // Update state
            isAuthenticated = false
            currentUser = nil
            
        } catch {
            if config.enableDebugLogging {
                print("[AuthService] Logout error: \(error)")
            }
            // Clear tokens anyway
            try? keychainService.clearTokens()
            isAuthenticated = false
            currentUser = nil
        }
        
        isLoading = false
    }
}

// MARK: - Request Models

struct AuthorizationRequest: Codable {
    let clientId: String
    let responseType: String
    let redirectUri: String
    let codeChallenge: String
    let codeChallengeMethod: String
    let scope: String
    let state: String?
    
    enum CodingKeys: String, CodingKey {
        case clientId = "client_id"
        case responseType = "response_type"
        case redirectUri = "redirect_uri"
        case codeChallenge = "code_challenge"
        case codeChallengeMethod = "code_challenge_method"
        case scope
        case state
    }
}

struct TokenRequest: Codable {
    let grantType: String
    let code: String
    let codeVerifier: String
    let clientId: String
    let redirectUri: String
    
    enum CodingKeys: String, CodingKey {
        case grantType = "grant_type"
        case code
        case codeVerifier = "code_verifier"
        case clientId = "client_id"
        case redirectUri = "redirect_uri"
    }
}

struct RevokeRequest: Codable {
    let token: String
    let clientId: String
    
    enum CodingKeys: String, CodingKey {
        case token
        case clientId = "client_id"
    }
}

// MARK: - Auth Errors

enum AuthError: Error, LocalizedError {
    case missingCodeVerifier
    case noRefreshToken
    case authorizationFailed
    
    var errorDescription: String? {
        switch self {
        case .missingCodeVerifier:
            return "Missing PKCE code verifier"
        case .noRefreshToken:
            return "No refresh token available"
        case .authorizationFailed:
            return "Authorization failed"
        }
    }
}
