import Foundation
import SwiftUI
import Combine
import AuthenticationServices

/// Authentication service managing OAuth2 PKCE flow
@MainActor
class AuthService: ObservableObject, TokenRefreshing {
    
    // MARK: - Published Properties
    
    @Published var isAuthenticated = false
    @Published var currentUser: User?
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var awaitingVerification = false
    @Published var awaitingPasswordReset = false
    
    // MARK: - Properties
    
    private let apiClient: APIClient
    private let keychainService = KeychainService.shared
    private let config = ConfigLoader.shared
    
    // PKCE state
    private var codeVerifier: String?
    private var codeChallenge: String?
    /// Expected OAuth CSRF state for the currently active login. Never persisted.
    private var oauthState: String?
    /// True only between `startLogin()` and the end of its browser session.
    /// Externally delivered OAuth callbacks are ignored when this is false.
    private var isAwaitingOAuthCallback = false
    
    // ASWebAuthenticationSession (retained to keep the session alive)
    private var webAuthSession: ASWebAuthenticationSession?
    private let presentationContextProvider = AuthPresentationContextProvider()

    // In-flight token refresh, shared by concurrent callers
    private var refreshTask: Task<Void, Error>?

    #if DEBUG
    /// Test-only hook to seed PKCE state without driving a real
    /// `ASWebAuthenticationSession` through `startLogin()`. Lets unit tests
    /// exercise `handleCallback(url:)` directly. Not intended for production
    /// use — compiled out of Release builds.
    func debugSeedCodeVerifierForTesting(_ verifier: String, state: String? = "test-oauth-state") {
        self.codeVerifier = verifier
        self.oauthState = state
        self.isAwaitingOAuthCallback = true
    }

    /// Test seam for checking the exact authorization URL assembled by login.
    func debugLoginAuthorizationURLForTesting(state: String, challenge: String) -> URL? {
        loginAuthorizationURL(state: state, challenge: challenge)
    }
    #endif

    private func clearPKCEState() {
        codeVerifier = nil
        codeChallenge = nil
        oauthState = nil
        isAwaitingOAuthCallback = false
    }
    
    // MARK: - Initialization

    /// - Parameter apiClient: Defaults to the shared singleton. Overridable
    ///   only to let unit tests inject a stubbed `APIClient` (see
    ///   `APIClient(session:baseURL:)`); production call sites always use
    ///   the default.
    init(apiClient: APIClient? = nil) {
        self.apiClient = apiClient ?? .shared
        checkAuthStatus()
        setupSessionInvalidationObserver()
        APIClient.setTokenRefresher(self)
        #if DEBUG
        dlog("AuthService", "Initialization completed")
        #endif
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
                    dlog("AuthService", "Session invalidated; logging out")
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
            #if DEBUG
            LaunchTimer.mark("checkAuthStatus() Task started")
            #endif
            
            let storedRefreshToken: String?
            let tokenNeedsRefresh: Bool
            do {
                storedRefreshToken = try keychainService.getRefreshToken()
                guard storedRefreshToken != nil else {
                    if isAuthenticated { isAuthenticated = false }
                    if currentUser != nil { currentUser = nil }
                    #if DEBUG
                    LaunchTimer.mark("checkAuthStatus() — no refresh token, done")
                    #endif
                    return
                }
                let expired = try keychainService.isTokenExpired()
                let nearingExpiry = try keychainService.needsRefresh()
                tokenNeedsRefresh = expired || nearingExpiry
            } catch {
                // A failed migration/read must not be interpreted as missing credentials.
                errorMessage = "Unable to access saved credentials. Your session has been preserved."
                return
            }

            // If token is expired or needs refresh, try to refresh it
            if tokenNeedsRefresh {
                do {
                    try await refreshToken()
                    #if DEBUG
                    LaunchTimer.mark("checkAuthStatus() — token refreshed")
                    #endif
                } catch {
                    #if DEBUG
                    if config.enableDebugLogging {
                        dlog("AuthService", "Token refresh failed on launch")
                    }
                    LaunchTimer.mark("checkAuthStatus() — token refresh FAILED")
                    #endif
                    if error is KeychainAccessFailure {
                        errorMessage = "Unable to access saved credentials. Your session has been preserved."
                        return
                    }
                    if isUnrecoverableAuthError(error) {
                        if isAuthenticated { isAuthenticated = false }
                        if currentUser != nil { currentUser = nil }
                        try? keychainService.clearTokens()
                        return
                    }
                    // Offline or server-side failure — keep the tokens. Stay signed in only
                    // if the cached access token has not actually expired yet.
                    do {
                        if try keychainService.isTokenExpired() { return }
                    } catch {
                        errorMessage = "Unable to access saved credentials. Your session has been preserved."
                        return
                    }
                }
            }
            
            // Token is valid
            if !isAuthenticated { isAuthenticated = true }
            // Fetch current user from API
            await fetchCurrentUser()
            #if DEBUG
            LaunchTimer.mark("checkAuthStatus() — complete")
            #endif
        }
    }
    
    /// Fetch the current user from the API
    func fetchCurrentUser() async {
        do {
            let user = try await apiClient.getCurrentUser()
            self.currentUser = user
            #if DEBUG
            if config.enableDebugLogging {
                dlog("AuthService", "Fetched current user")
            }
            #endif
        } catch {
            #if DEBUG
            if config.enableDebugLogging {
                dlog("AuthService", "Failed to fetch current user")
            }
            #endif
        }
    }
    
    // MARK: - OAuth Login
    
    /// Start OAuth login flow via in-app browser (ASWebAuthenticationSession)
    func startLogin() {
        // Guard against double-tap — if already loading, ignore
        guard !isLoading else { return }

        // Generate PKCE
        let (verifier, challenge) = PKCEGenerator.generate()
        let state = PKCEGenerator.generateOAuthState()
        self.codeVerifier = verifier
        self.codeChallenge = challenge
        self.oauthState = state
        self.isAwaitingOAuthCallback = true
        
        #if DEBUG
        if config.enableDebugLogging {
            dlog("AuthService", "Starting OAuth flow")
        }
        #endif
        
        // Always use custom URL scheme for OAuth redirect.
        // The .https() ASWebAuthenticationSession callback requires the AASA file to be
        // cached on-device, which is unreliable on fresh installs and device restarts.
        // The custom scheme is intercepted directly by ASWebAuthenticationSession and
        // works consistently across all iOS versions.
        guard let loginURL = loginAuthorizationURL(state: state, challenge: challenge) else {
            clearPKCEState()
            errorMessage = "Failed to build login URL"
            return
        }
        
        #if DEBUG
        if config.enableDebugLogging {
            dlog("AuthService", "Opening login browser session")
        }
        #endif
        
        startWebAuthSession(url: loginURL)
    }

    /// Builds the authorization URL used by `startLogin()`.
    private func loginAuthorizationURL(state: String, challenge: String) -> URL? {
        var components = URLComponents(url: config.backendURL, resolvingAgainstBaseURL: false)!
        components.path = "/login"
        components.queryItems = [
            URLQueryItem(name: "client_id", value: config.oauthClientId),
            URLQueryItem(name: "redirect_uri", value: config.oauthRedirectUri),
            URLQueryItem(name: "code_challenge", value: challenge),
            URLQueryItem(name: "code_challenge_method", value: "S256"),
            URLQueryItem(name: "scope", value: config.oauthScopesString),
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "state", value: state)
        ]
        return components.url
    }
    
    /// Start OAuth registration flow via in-app browser (ASWebAuthenticationSession)
    func startRegistration() {
        // Guard against double-tap
        guard !isLoading else { return }

        #if DEBUG
        if config.enableDebugLogging {
            dlog("AuthService", "Starting registration flow")
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
            dlog("AuthService", "Opening registration browser session")
        }
        #endif
        
        startWebAuthSession(url: registerURL)
    }

    /// Start forgot password flow via in-app browser (ASWebAuthenticationSession)
    func startForgotPassword() {
        // Guard against double-tap
        guard !isLoading else { return }

        #if DEBUG
        if config.enableDebugLogging {
            dlog("AuthService", "Starting forgot password flow")
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
            dlog("AuthService", "Opening password-recovery browser session")
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
                await self?.handleWebAuthSessionCompletion(callbackURL: callbackURL, error: error)
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
        session.prefersEphemeralWebBrowserSession = true
        
        webAuthSession = session
        
        if !session.start() {
            webAuthSession = nil
            clearPKCEState()
            isLoading = false
            errorMessage = "Failed to start authentication session"
        }
    }

    /// Ends a browser session. PKCE state is cleared on every path — cancel,
    /// error, and success — so a later externally delivered callback cannot
    /// be exchanged with a verifier from an abandoned login (S-2).
    func handleWebAuthSessionCompletion(callbackURL: URL?, error: Error?) async {
        webAuthSession = nil
        defer { clearPKCEState() }

        if let error = error as? ASWebAuthenticationSessionError,
           error.code == .canceledLogin {
            // User dismissed the browser — not an error
            isLoading = false
            #if DEBUG
            if config.enableDebugLogging {
                dlog("AuthService", "User cancelled authentication")
            }
            #endif
            return
        }

        if error != nil {
            isLoading = false
            errorMessage = error?.localizedDescription
            #if DEBUG
            if config.enableDebugLogging {
                dlog("AuthService", "Authentication browser session failed")
            }
            #endif
            return
        }

        guard let callbackURL else {
            isLoading = false
            errorMessage = "No callback URL received"
            return
        }

        await handleCallback(url: callbackURL)
    }

    /// Entry point for auth URLs delivered outside `ASWebAuthenticationSession`
    /// (for example `.onOpenURL`). Any app or web page can open the custom
    /// scheme, so OAuth callbacks are accepted only while this app has a login
    /// in progress; otherwise they are dropped without network access or UI.
    func handleExternalCallback(url: URL) async {
        if Self.isOAuthCallback(url), !isAwaitingOAuthCallback {
            #if DEBUG
            if config.enableDebugLogging {
                dlog("AuthService", "Ignoring OAuth callback with no login in progress")
            }
            #endif
            return
        }
        await handleCallback(url: url)
    }

    private static func isOAuthCallback(_ url: URL) -> Bool {
        if url.scheme?.lowercased() == "https" {
            return url.path == "/app/auth-callback"
        }
        return url.host?.lowercased() == "oauth-callback"
    }
    
    /// Handle callback URL from ASWebAuthenticationSession.
    /// Routes by URL host to support multiple deep link types.
    func handleCallback(url: URL) async {
        isLoading = true
        errorMessage = nil

        #if DEBUG
        if config.enableDebugLogging {
            dlog("AuthService", "Handling authentication callback")
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
                clearPKCEState()
                return
            }

            // A callback already exchanged successfully is an expected duplicate
            // delivery from ASWebAuthenticationSession + onOpenURL. Ignore it
            // before checking now-cleared per-login state.
            if lastCompletedCodeExchange == code {
                isLoading = false
                return
            }

            let queryItems = components.queryItems ?? []
            let stateItems = queryItems.filter { $0.name == "state" }
            if !stateItems.isEmpty {
                // If the server returns state, it must belong to this login.
                // Never exchange a callback with an absent expected state or a
                // non-identical value. Duplicate state parameters are ambiguous
                // and rejected as well.
                guard stateItems.count == 1,
                      let receivedState = stateItems.first?.value,
                      let expectedState = oauthState,
                      receivedState == expectedState else {
                    errorMessage = AuthError.invalidOAuthState.localizedDescription
                    isLoading = false
                    clearPKCEState()
                    return
                }
            } else {
                // ROLLOUT TODO (1.4w): the deployed web server currently omits
                // OAuth state passthrough. Accept missing state temporarily to
                // preserve login compatibility. Once 1.4w is deployed, remove
                // this compatibility branch and require a matching state.
            }

            #if DEBUG
            if config.enableDebugLogging {
                dlog("AuthService", "OAuth authorization callback received")
            }
            #endif

            do {
                try await exchangeCodeForTokens(code: code)
            } catch {
                #if DEBUG
                if config.enableDebugLogging {
                    dlog("AuthService", "OAuth token exchange failed")
                }
                #endif
                errorMessage = error.localizedDescription
                clearPKCEState()
            }

        case "await-verification":
            // Registration success — panel closed, show native "check email" UI
            #if DEBUG
            if config.enableDebugLogging {
                dlog("AuthService", "Registration complete; awaiting verification")
            }
            #endif
            awaitingVerification = true

        case "await-password-reset":
            // Forgot password submitted — panel closed, show native "check email" UI
            #if DEBUG
            if config.enableDebugLogging {
                dlog("AuthService", "Password recovery submitted")
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
                dlog("AuthService", "Received authentication redirect")
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
                dlog("AuthService", "Unhandled authentication callback")
            }
            #endif
            break
        }

        isLoading = false
    }
    
    // MARK: - Token Exchange

    /// Tracks an in-flight authorization-code exchange so a duplicate OAuth
    /// callback for the *same* code is coalesced into the original request
    /// instead of firing a second token exchange. This guards against the
    /// custom-scheme redirect being delivered to the app twice — once via
    /// `ASWebAuthenticationSession`'s completion handler and once via
    /// `onOpenURL` — which previously caused two concurrent requests for the
    /// same single-use authorization code and an iOS "Token Exchange Failed"
    /// error (the server now also rejects this as a safety net, but
    /// de-duplicating here avoids the spurious failure altogether).
    private var inFlightCodeExchange: (code: String, task: Task<Void, Error>)?

    /// The most recent authorization code that was exchanged successfully.
    /// The in-flight guard above only covers duplicates that overlap the
    /// original request; a duplicate callback delivered *after* the exchange
    /// finished would otherwise start a fresh exchange, fail on the already
    /// cleared PKCE verifier, and surface a login error to a user who is in
    /// fact signed in. Remembering the last completed code makes the late
    /// duplicate a no-op.
    private var lastCompletedCodeExchange: String?

    /// Exchange authorization code for access token.
    /// Safe to call multiple times with the same `code`: duplicate calls
    /// await the original in-flight request (or return immediately if it has
    /// already succeeded) rather than re-sending it.
    private func exchangeCodeForTokens(code: String) async throws {
        if lastCompletedCodeExchange == code {
            #if DEBUG
            if config.enableDebugLogging {
                dlog("AuthService", "Ignoring duplicate completed OAuth callback")
            }
            #endif
            return
        }

        if let inFlight = inFlightCodeExchange, inFlight.code == code {
            #if DEBUG
            if config.enableDebugLogging {
                dlog("AuthService", "Reusing in-flight OAuth token exchange")
            }
            #endif
            try await inFlight.task.value
            return
        }

        let task = Task {
            try await self.performCodeExchange(code: code)
            self.lastCompletedCodeExchange = code
        }
        inFlightCodeExchange = (code, task)
        defer {
            if inFlightCodeExchange?.code == code {
                inFlightCodeExchange = nil
            }
        }
        try await task.value
    }

    private func performCodeExchange(code: String) async throws {
        guard let verifier = codeVerifier else {
            throw AuthError.missingCodeVerifier
        }
        
        // Get device information
        let deviceName = UIDevice.current.name
        let systemVersion = UIDevice.current.systemVersion
        let model = UIDevice.current.model
        let userAgent = "fotolokashen-ios/1.0 (iOS \(systemVersion); \(model))"
        
        // redirect_uri must match what was used in the authorize request.
        // startLogin() always uses the custom scheme (fotolokashen://oauth-callback),
        // so the token exchange must use the same URI.
        let redirectUri = config.oauthRedirectUri

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
            dlog("AuthService", "OAuth tokens received")
        }
        #endif
        
        // Save tokens
        let token = OAuthToken(from: tokenResponse)
        try keychainService.saveToken(token)
        
        // Update state
        currentUser = tokenResponse.user
        isAuthenticated = true
        
        clearPKCEState()
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
            dlog("AuthService", "Starting verification auto-login")
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
                dlog("AuthService", "Verification auto-login succeeded")
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
                dlog("AuthService", "Verification auto-login failed")
            }
            #endif
            // If auto-login fails, fall back to manual login
            errorMessage = "Auto-login failed. Please sign in manually."
        }
        
        isLoading = false
    }
    
    // MARK: - Token Refresh

    /// Called by `APIClient` when an authenticated request is rejected with 401.
    /// Shares the same single-flight refresh as every other caller, so a burst of
    /// concurrent 401s produces exactly one token exchange.
    func refreshAccessTokenForRetry(staleAccessToken: String?) async throws {
        // The in-flight dedup in `refreshToken()` only covers overlapping calls. A request
        // that 401s just after a refresh completed would otherwise start a second exchange,
        // superseding the session again. If the Keychain already holds a different token,
        // the 401 was caused by the caller's stale token — nothing to refresh.
        if let staleAccessToken, try keychainService.getAccessToken() != staleAccessToken {
            #if DEBUG
            if config.enableDebugLogging {
                dlog("AuthService", "Token already rotated; retrying without refresh")
            }
            #endif
            return
        }

        try await refreshToken()
    }

    /// Refresh access token using refresh token
    func refreshTokenIfNeeded() async throws {
        // Check if refresh is needed
        guard try keychainService.needsRefresh() else {
            #if DEBUG
            if config.enableDebugLogging {
                dlog("AuthService", "Token is valid; refresh not needed")
            }
            #endif
            return
        }
        
        #if DEBUG
        if config.enableDebugLogging {
            dlog("AuthService", "Refreshing access token")
        }
        #endif
        
        try await refreshToken()
    }
    
    /// True only when the server has definitively rejected our credentials.
    /// Network failures and 5xx responses must not count, or going offline logs the user out.
    private func isUnrecoverableAuthError(_ error: Error) -> Bool {
        if case AuthError.noRefreshToken = error { return true }
        guard let apiError = error as? APIError else { return false }
        switch apiError {
        case .unauthorized:
            return true
        case .apiError(_, let code):
            return code == "INVALID_GRANT"
        default:
            return false
        }
    }

    /// Force refresh the access token.
    /// Concurrent callers share one request — the server supersedes the previous `ios`
    /// session on every refresh, so overlapping refreshes would orphan each other's
    /// access token once the grace window elapses.
    private func refreshToken() async throws {
        if let existing = refreshTask {
            return try await existing.value
        }

        let task = Task { try await performTokenRefresh() }
        refreshTask = task
        defer { refreshTask = nil }
        return try await task.value
    }

    private func performTokenRefresh() async throws {
        guard let refreshToken = try keychainService.getRefreshToken() else {
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
        
        // The refresh grant only returns a new access token (no refresh_token/user) —
        // decoding as TokenResponse throws keyNotFound and silently orphans the new
        // token the server already committed, which is what caused the logout bug.
        let refreshResponse: RefreshTokenResponse = try await apiClient.post(
            "/api/auth/oauth/token",
            body: refreshRequest,
            authenticated: false
        )
        
        #if DEBUG
        if config.enableDebugLogging {
            dlog("AuthService", "Access token refreshed")
        }
        #endif
        
        // Rotate just the access token in place; refresh token + user stay as-is
        let newExpiresAt = Date().addingTimeInterval(TimeInterval(refreshResponse.expiresIn))
        try keychainService.updateAccessToken(refreshResponse.accessToken, expiresAt: newExpiresAt)
    }
    
    // MARK: - Logout
    
    /// Logout user
    func logout() async {
        isLoading = true
        clearPKCEState()
        
        do {
            // Revoke refresh token on server
            if let refreshToken = try keychainService.getRefreshToken() {
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
                    dlog("AuthService", "Server token revocation completed")
                }
                #endif
            }
            
            // Clear local tokens
            try keychainService.clearTokens()
            
            // Update state
            isAuthenticated = false
            currentUser = nil
            
        } catch {
            if error is KeychainAccessFailure {
                errorMessage = "Unable to access saved credentials. Your session has been preserved."
                isLoading = false
                return
            }
            #if DEBUG
            if config.enableDebugLogging {
                dlog("AuthService", "Logout failed")
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
    case invalidOAuthState
    case noRefreshToken
    case authorizationFailed
    
    var errorDescription: String? {
        switch self {
        case .missingCodeVerifier:
            return "Missing PKCE code verifier"
        case .invalidOAuthState:
            return "Unable to verify this sign-in attempt. Please try logging in again."
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
