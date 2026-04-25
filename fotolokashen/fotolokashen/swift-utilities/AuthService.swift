import Foundation
import SwiftUI
import Combine
import AuthenticationServices

/// Authentication service managing OAuth2 PKCE flow
@MainActor
class AuthService: ObservableObject {
    
    // MARK: - Published Properties
    
    @Published var isAuthenticated = false
    @Published var currentUser: User?
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var awaitingVerification = false
    @Published var awaitingPasswordReset = false
    
    // MARK: - Properties
    
    private let apiClient = APIClient.shared
    private let keychainService = KeychainService.shared
    private let config = ConfigLoader.shared
    
    // PKCE state
    private var codeVerifier: String?
    private var codeChallenge: String?
    
    // ASWebAuthenticationSession (retained to keep the session alive)
    private var webAuthSession: ASWebAuthenticationSession?
    private let presentationContextProvider = AuthPresentationContextProvider()
    
    // MARK: - Initialization
    
    init() {
        checkAuthStatus()
        setupSessionInvalidationObserver()
    }
    
    // MARK: - Session Invalidation Observer
    
    /// Listen for 401 errors from API and auto-logout
    private func setupSessionInvalidationObserver() {
        NotificationCenter.default.addObserver(
            forName: .authSessionInvalidated,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard let self = self else { return }
            Task { @MainActor [self] in
                // Only handle if we think we're authenticated
                guard self.isAuthenticated else { return }
                
                if self.config.enableDebugLogging {
                    #if DEBUG
                    print("[AuthService] ⚠️ Session invalidated (401 received) - logging out")
                    #endif
                }
                
                // Clear tokens and reset state
                self.isAuthenticated = false
                self.currentUser = nil
                try? self.keychainService.clearTokens()
                
                // Clear location store
                LocationStore.shared.clear()
                
                // Set error message so user knows what happened
                self.errorMessage = "Your session has expired. Please log in again."
            }
        }
    }
    
    // MARK: - Auth Status
    
    /// Check if user is authenticated
    func checkAuthStatus() {
        Task {
            // Check if we have any tokens at all
            guard keychainService.getRefreshToken() != nil else {
                isAuthenticated = false
                currentUser = nil
                return
            }
            
            // If token is expired or needs refresh, try to refresh it
            if keychainService.isTokenExpired() || keychainService.needsRefresh() {
                do {
                    try await refreshToken()
                    #if DEBUG
                    if config.enableDebugLogging {
                        print("[AuthService] Token refreshed on app launch")
                    }
                    #endif
                } catch {
                    #if DEBUG
                    if config.enableDebugLogging {
                        print("[AuthService] Token refresh failed on launch: \(error)")
                    }
                    #endif
                    isAuthenticated = false
                    currentUser = nil
                    try? keychainService.clearTokens()
                    return
                }
            }
            
            // Token is valid
            isAuthenticated = true
            // Fetch current user from API
            await fetchCurrentUser()
        }
    }
    
    /// Fetch the current user from the API
    func fetchCurrentUser() async {
        do {
            let user = try await apiClient.getCurrentUser()
            self.currentUser = user
            #if DEBUG
            if config.enableDebugLogging {
                print("[AuthService] Fetched current user: \(user.username)")
                print("[AuthService] Avatar field: \(user.avatar ?? "nil")")
                print("[AuthService] Avatar URL: \(user.avatarURL?.absoluteString ?? "nil")")
                print("[AuthService] Banner field: \(user.bannerImage ?? "nil")")
                print("[AuthService] Banner URL: \(user.bannerURL?.absoluteString ?? "nil")")
            }
            #endif
        } catch {
            #if DEBUG
            if config.enableDebugLogging {
                print("[AuthService] Failed to fetch current user: \(error)")
            }
            #endif
        }
    }
    
    // MARK: - OAuth Login
    
    /// Start OAuth login flow via in-app browser (ASWebAuthenticationSession)
    func startLogin() {
        // Generate PKCE
        let (verifier, challenge) = PKCEGenerator.generate()
        self.codeVerifier = verifier
        self.codeChallenge = challenge
        
        #if DEBUG
        if config.enableDebugLogging {
            print("[AuthService] Starting OAuth flow")
            print("[AuthService] Code challenge: \(challenge)")
        }
        #endif
        
        // Always use custom URL scheme for OAuth redirect.
        // The .https() ASWebAuthenticationSession callback requires the AASA file to be
        // cached on-device, which is unreliable on fresh installs and device restarts.
        // The custom scheme is intercepted directly by ASWebAuthenticationSession and
        // works consistently across all iOS versions.
        let redirectUri = config.oauthRedirectUri

        var components = URLComponents(url: config.backendURL, resolvingAgainstBaseURL: false)!
        components.path = "/login"
        components.queryItems = [
            URLQueryItem(name: "client_id", value: config.oauthClientId),
            URLQueryItem(name: "redirect_uri", value: redirectUri),
            URLQueryItem(name: "code_challenge", value: challenge),
            URLQueryItem(name: "code_challenge_method", value: "S256"),
            URLQueryItem(name: "scope", value: config.oauthScopesString),
            URLQueryItem(name: "response_type", value: "code")
        ]
        
        guard let loginURL = components.url else {
            errorMessage = "Failed to build login URL"
            return
        }
        
        #if DEBUG
        if config.enableDebugLogging {
            print("[AuthService] Opening in-app browser: \(loginURL.absoluteString)")
        }
        #endif
        
        startWebAuthSession(url: loginURL)
    }
    
    /// Start OAuth registration flow via in-app browser (ASWebAuthenticationSession)
    func startRegistration() {
        #if DEBUG
        if config.enableDebugLogging {
            print("[AuthService] Starting registration flow")
        }
        #endif
        
        // Build register URL with source=ios for explicit platform detection
        var components = URLComponents(url: config.backendURL, resolvingAgainstBaseURL: false)!
        components.path = "/register"
        components.queryItems = [
            URLQueryItem(name: "source", value: "ios"),
            URLQueryItem(name: "client_id", value: config.oauthClientId),
        ]
        
        guard let registerURL = components.url else {
            errorMessage = "Failed to build registration URL"
            return
        }
        
        #if DEBUG
        if config.enableDebugLogging {
            print("[AuthService] Opening in-app browser for registration: \(registerURL.absoluteString)")
        }
        #endif
        
        startWebAuthSession(url: registerURL)
    }

    /// Start forgot password flow via in-app browser (ASWebAuthenticationSession)
    func startForgotPassword() {
        #if DEBUG
        if config.enableDebugLogging {
            print("[AuthService] Starting forgot password flow")
        }
        #endif

        // Build forgot-password URL with source=ios
        var components = URLComponents(url: config.backendURL, resolvingAgainstBaseURL: false)!
        components.path = "/forgot-password"
        components.queryItems = [
            URLQueryItem(name: "source", value: "ios"),
        ]

        guard let forgotURL = components.url else {
            errorMessage = "Failed to build forgot password URL"
            return
        }

        #if DEBUG
        if config.enableDebugLogging {
            print("[AuthService] Opening in-app browser for forgot password: \(forgotURL.absoluteString)")
        }
        #endif

        startWebAuthSession(url: forgotURL)
    }
    
    /// Present ASWebAuthenticationSession for OAuth flow (login, registration, or forgot password)
    ///
    /// iOS 17.4+: Uses `.https()` callback for OAuth login (Universal Link — domain-verified, cannot be hijacked).
    /// iOS 17.0-17.3: Falls back to `.customScheme()` callback.
    /// Non-OAuth flows (registration, forgot-password) always use the custom scheme since they
    /// redirect to `fotolokashen://await-verification` etc., not a Universal Link.
    private func startWebAuthSession(url: URL) {
        isLoading = true
        errorMessage = nil

        // Shared completion handler for both API versions
        let completionHandler: (URL?, Error?) -> Void = { [weak self] callbackURL, error in
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                self.webAuthSession = nil

                if let error = error as? ASWebAuthenticationSessionError,
                   error.code == .canceledLogin {
                    // User dismissed the browser — not an error
                    self.isLoading = false
                    #if DEBUG
                    if self.config.enableDebugLogging {
                        print("[AuthService] User cancelled authentication")
                    }
                    #endif
                    return
                }

                if let error = error {
                    self.isLoading = false
                    self.errorMessage = error.localizedDescription
                    #if DEBUG
                    if self.config.enableDebugLogging {
                        print("[AuthService] ASWebAuthenticationSession error: \(error)")
                    }
                    #endif
                    return
                }

                guard let callbackURL = callbackURL else {
                    self.isLoading = false
                    self.errorMessage = "No callback URL received"
                    return
                }

                await self.handleCallback(url: callbackURL)
            }
        }

        let session: ASWebAuthenticationSession
        if #available(iOS 17.4, *) {
            // iOS 17.4+: Use the modern callback API with custom scheme.
            // Note: .https() callback is intentionally NOT used because it requires the AASA
            // file to be cached on-device, which fails on fresh installs and device restarts.
            session = ASWebAuthenticationSession(
                url: url,
                callback: .customScheme("fotolokashen"),
                completionHandler: completionHandler
            )
        } else {
            // iOS 17.0-17.3: Use the legacy API with custom URL scheme
            session = ASWebAuthenticationSession(
                url: url,
                callbackURLScheme: "fotolokashen",
                completionHandler: completionHandler
            )
        }

        session.presentationContextProvider = presentationContextProvider
        session.prefersEphemeralWebBrowserSession = false
        
        webAuthSession = session
        
        if !session.start() {
            isLoading = false
            errorMessage = "Failed to start authentication session"
        }
    }
    
    /// Handle callback URL from ASWebAuthenticationSession.
    /// Routes by URL host to support multiple deep link types.
    func handleCallback(url: URL) async {
        isLoading = true
        errorMessage = nil

        #if DEBUG
        if config.enableDebugLogging {
            print("[AuthService] Handling callback: \(url.absoluteString)")
        }
        #endif

        // Route by scheme + host to handle both Universal Links (HTTPS) and custom scheme
        let host: String?
        if url.scheme == "https" {
            // Universal Link callback: https://fotolokashen.com/app/auth-callback?code=xxx
            // Treat this the same as fotolokashen://oauth-callback
            host = url.path == "/app/auth-callback" ? "oauth-callback" : url.host
        } else {
            // Custom scheme: fotolokashen://oauth-callback, fotolokashen://await-verification, etc.
            host = url.host
        }

        guard let host else {
            errorMessage = "Invalid callback URL"
            isLoading = false
            return
        }

        switch host {
        case "oauth-callback":
            // Standard OAuth PKCE code exchange
            guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
                  let code = components.queryItems?.first(where: { $0.name == "code" })?.value else {
                errorMessage = "No authorization code in callback"
                isLoading = false
                return
            }

            #if DEBUG
            if config.enableDebugLogging {
                print("[AuthService] Authorization code received")
            }
            #endif

            do {
                try await exchangeCodeForTokens(code: code)
            } catch {
                #if DEBUG
                if config.enableDebugLogging {
                    print("[AuthService] Token exchange error: \(error)")
                }
                #endif
                errorMessage = error.localizedDescription
            }

        case "await-verification":
            // Registration success — panel closed, show native "check email" UI
            #if DEBUG
            if config.enableDebugLogging {
                print("[AuthService] Registration complete — awaiting email verification")
            }
            #endif
            awaitingVerification = true

        case "await-password-reset":
            // Forgot password submitted — panel closed, show native "check email" UI
            #if DEBUG
            if config.enableDebugLogging {
                print("[AuthService] Forgot password submitted — awaiting reset email")
            }
            #endif
            awaitingPasswordReset = true

        case "auth-redirect":
            // Error redirect from web — parse action and reason
            let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
            let action = components?.queryItems?.first(where: { $0.name == "action" })?.value
            let reason = components?.queryItems?.first(where: { $0.name == "reason" })?.value

            #if DEBUG
            if config.enableDebugLogging {
                print("[AuthService] Auth redirect — action: \(action ?? "nil"), reason: \(reason ?? "nil")")
            }
            #endif

            if action == "login" && reason == "account_exists" {
                errorMessage = "You already have an account. Please log in."
            } else {
                errorMessage = reason ?? "Authentication error"
            }

        default:
            #if DEBUG
            if config.enableDebugLogging {
                print("[AuthService] Unhandled callback host: \(host)")
            }
            #endif
            break
        }

        isLoading = false
    }
    
    // MARK: - Token Exchange
    
    /// Exchange authorization code for access token
    private func exchangeCodeForTokens(code: String) async throws {
        guard let verifier = codeVerifier else {
            throw AuthError.missingCodeVerifier
        }
        
        // Get device information
        let deviceName = UIDevice.current.name
        let systemVersion = UIDevice.current.systemVersion
        let model = UIDevice.current.model
        let userAgent = "fotolokashen-ios/1.0 (iOS \(systemVersion); \(model))"
        
        // redirect_uri must match what was used in the authorize request
        let redirectUri: String
        if #available(iOS 17.4, *) {
            redirectUri = "\(config.backendBaseURL)/app/auth-callback"
        } else {
            redirectUri = config.oauthRedirectUri
        }

        let tokenRequest = TokenRequest(
            grantType: "authorization_code",
            code: code,
            codeVerifier: verifier,
            clientId: config.oauthClientId,
            redirectUri: redirectUri,
            deviceName: deviceName,
            userAgent: userAgent,
            ipAddress: nil, // Server will detect from headers
            country: Locale.current.region?.identifier
        )
        
        let tokenResponse: TokenResponse = try await apiClient.post(
            "/api/auth/oauth/token",
            body: tokenRequest,
            authenticated: false
        )
        
        #if DEBUG
        if config.enableDebugLogging {
            print("[AuthService] Tokens received for user: \(tokenResponse.user.email)")
        }
        #endif
        
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
    
    // MARK: - Auto-Login (Post Email Verification)
    
    /// Exchange a one-time auto-login token for OAuth tokens.
    /// Called after the user verifies their email and is redirected back to the app
    /// via the fotolokashen://email-verified?token=xxx deep link.
    /// This skips the manual login step entirely.
    func autoLoginWithToken(_ autoLoginToken: String) async {
        isLoading = true
        errorMessage = nil
        
        #if DEBUG
        if config.enableDebugLogging {
            print("[AuthService] Starting auto-login with verification token")
        }
        #endif
        
        do {
            // Get device information
            let deviceName = UIDevice.current.name
            let systemVersion = UIDevice.current.systemVersion
            let model = UIDevice.current.model
            let userAgent = "fotolokashen-ios/1.0 (iOS \(systemVersion); \(model))"
            
            struct AutoLoginRequest: Codable {
                let token: String
                let clientId: String
                let deviceName: String
                let userAgent: String
                let country: String?
                
                enum CodingKeys: String, CodingKey {
                    case token
                    case clientId = "client_id"
                    case deviceName = "device_name"
                    case userAgent = "user_agent"
                    case country
                }
            }
            
            let request = AutoLoginRequest(
                token: autoLoginToken,
                clientId: config.oauthClientId,
                deviceName: deviceName,
                userAgent: userAgent,
                country: Locale.current.region?.identifier
            )
            
            let tokenResponse: TokenResponse = try await apiClient.post(
                "/api/auth/auto-login",
                body: request,
                authenticated: false
            )
            
            #if DEBUG
            if config.enableDebugLogging {
                print("[AuthService] Auto-login successful for user: \(tokenResponse.user.email)")
            }
            #endif
            
            // Save tokens (reuses same OAuthToken infrastructure)
            let token = OAuthToken(from: tokenResponse)
            try keychainService.saveToken(token)
            
            // Dismiss the registration browser if it's still open
            webAuthSession?.cancel()
            webAuthSession = nil
            
            // Update state
            currentUser = tokenResponse.user
            isAuthenticated = true
            
        } catch {
            #if DEBUG
            if config.enableDebugLogging {
                print("[AuthService] Auto-login failed: \(error)")
            }
            #endif
            // If auto-login fails, fall back to manual login
            errorMessage = "Auto-login failed. Please sign in manually."
        }
        
        isLoading = false
    }
    
    // MARK: - Token Refresh
    
    /// Refresh access token using refresh token
    func refreshTokenIfNeeded() async throws {
        // Check if refresh is needed
        guard keychainService.needsRefresh() else {
            #if DEBUG
            if config.enableDebugLogging {
                print("[AuthService] Token still valid, no refresh needed")
            }
            #endif
            return
        }
        
        #if DEBUG
        if config.enableDebugLogging {
            print("[AuthService] Token needs refresh, refreshing...")
        }
        #endif
        
        try await refreshToken()
    }
    
    /// Force refresh the access token
    private func refreshToken() async throws {
        guard let refreshToken = keychainService.getRefreshToken() else {
            throw AuthError.noRefreshToken
        }
        
        // Get device information
        let deviceName = UIDevice.current.name
        let systemVersion = UIDevice.current.systemVersion
        let model = UIDevice.current.model
        let userAgent = "fotolokashen-ios/1.0 (iOS \(systemVersion); \(model))"
        
        let refreshRequest = RefreshTokenRequest(
            grantType: "refresh_token",
            refreshToken: refreshToken,
            clientId: config.oauthClientId,
            deviceName: deviceName,
            userAgent: userAgent,
            ipAddress: nil,
            country: Locale.current.region?.identifier
        )
        
        let tokenResponse: TokenResponse = try await apiClient.post(
            "/api/auth/oauth/token",
            body: refreshRequest,
            authenticated: false
        )
        
        #if DEBUG
        if config.enableDebugLogging {
            print("[AuthService] Token refreshed successfully")
        }
        #endif
        
        // Save new tokens
        let token = OAuthToken(from: tokenResponse)
        try keychainService.saveToken(token)
        
        // Update user info
        currentUser = tokenResponse.user
        isAuthenticated = true
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
                
                #if DEBUG
                if config.enableDebugLogging {
                    print("[AuthService] Token revoked on server")
                }
                #endif
            }
            
            // Clear local tokens
            try keychainService.clearTokens()
            
            // Update state
            isAuthenticated = false
            currentUser = nil
            
        } catch {
            #if DEBUG
            if config.enableDebugLogging {
                print("[AuthService] Logout error: \(error)")
            }
            #endif
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
    let deviceName: String?
    let userAgent: String?
    let ipAddress: String?
    let country: String?
    
    enum CodingKeys: String, CodingKey {
        case grantType = "grant_type"
        case code
        case codeVerifier = "code_verifier"
        case clientId = "client_id"
        case redirectUri = "redirect_uri"
        case deviceName = "device_name"
        case userAgent = "user_agent"
        case ipAddress = "ip_address"
        case country
    }
}

struct RefreshTokenRequest: Codable {
    let grantType: String
    let refreshToken: String
    let clientId: String
    let deviceName: String?
    let userAgent: String?
    let ipAddress: String?
    let country: String?
    
    enum CodingKeys: String, CodingKey {
        case grantType = "grant_type"
        case refreshToken = "refresh_token"
        case clientId = "client_id"
        case deviceName = "device_name"
        case userAgent = "user_agent"
        case ipAddress = "ip_address"
        case country
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

// MARK: - ASWebAuthenticationSession Presentation Context

/// Provides the window anchor for ASWebAuthenticationSession
class AuthPresentationContextProvider: NSObject, ASWebAuthenticationPresentationContextProviding {
    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = scene.windows.first(where: { $0.isKeyWindow }) else {
            return ASPresentationAnchor()
        }
        return window
    }
}
