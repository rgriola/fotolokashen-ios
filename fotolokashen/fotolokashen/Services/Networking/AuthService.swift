import AuthenticationServices
import Foundation
import Observation
import OSLog
import SwiftUI

/// Authentication service managing OAuth2 PKCE flow
@Observable
@MainActor
final class AuthService: TokenRefreshing {
    
    // MARK: - Observable Properties
    
    var isAuthenticated = false
    var currentUser: User?
    var isLoading = false
    var errorMessage: String?
    var awaitingVerification = false
    var awaitingPasswordReset = false
    
    // MARK: - Properties
    
    let apiClient: APIClient
    let keychainService = KeychainService.shared
    let config = ConfigLoader.shared
    
    // PKCE state
    @ObservationIgnored private var codeVerifier: String?
    @ObservationIgnored private var codeChallenge: String?
    /// Expected OAuth CSRF state for the currently active login. Never persisted.
    @ObservationIgnored private var oauthState: String?
    /// True only between `startLogin()` and the end of its browser session.
    /// Externally delivered OAuth callbacks are ignored when this is false.
    @ObservationIgnored private var isAwaitingOAuthCallback = false
    
    // ASWebAuthenticationSession (retained to keep the session alive)
    @ObservationIgnored private var webAuthSession: ASWebAuthenticationSession?
    private let presentationContextProvider = AuthPresentationContextProvider()

    // In-flight token refresh, shared by concurrent callers
    @ObservationIgnored var refreshTask: Task<Void, Error>?

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

    func clearPKCEState() {
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
    /// Uses the app's custom-scheme callback for OAuth and non-OAuth flows.
    private func startWebAuthSession(url: URL) {
        isLoading = true
        errorMessage = nil

        let completionHandler: (URL?, Error?) -> Void = { [weak self] callbackURL, error in
            Task { @MainActor [weak self] in
                await self?.handleWebAuthSessionCompletion(callbackURL: callbackURL, error: error)
            }
        }

        // `.https()` is intentionally not used because its Universal Link callback
        // requires a cached AASA file, which can fail on fresh installs and restarts.
        let session = ASWebAuthenticationSession(
            url: url,
            callback: .customScheme("fotolokashen"),
            completionHandler: completionHandler
        )

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
            Log.auth.error("Authentication browser session failed")
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
            Log.auth.error("Authentication browser completed without callback")
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
            guard stateItems.count == 1,
                  let receivedState = stateItems.first?.value,
                  !receivedState.isEmpty,
                  let expectedState = oauthState,
                  !expectedState.isEmpty,
                  receivedState == expectedState else {
                Log.auth.error("OAuth callback rejected; stateCount=\(stateItems.count, privacy: .public); expectedStatePresent=\(self.oauthState != nil, privacy: .public)")
                errorMessage = AuthError.invalidOAuthState.localizedDescription
                isLoading = false
                clearPKCEState()
                return
            }

            #if DEBUG
            if config.enableDebugLogging {
                dlog("AuthService", "OAuth authorization callback received")
            }
            #endif

            do {
                try await exchangeCodeForTokens(code: code)
            } catch {
                Log.auth.error("OAuth token exchange failed; failure=\(Log.failure(error).rawValue, privacy: .public)")
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
    @ObservationIgnored private var inFlightCodeExchange: (code: String, task: Task<Void, Error>)?

    /// The most recent authorization code that was exchanged successfully.
    /// The in-flight guard above only covers duplicates that overlap the
    /// original request; a duplicate callback delivered *after* the exchange
    /// finished would otherwise start a fresh exchange, fail on the already
    /// cleared PKCE verifier, and surface a login error to a user who is in
    /// fact signed in. Remembering the last completed code makes the late
    /// duplicate a no-op.
    @ObservationIgnored private var lastCompletedCodeExchange: String?

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
        Log.auth.notice("OAuth sign-in completed")
        
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
            Log.auth.notice("Verification auto-login completed")
            
        } catch {
            Log.auth.error("Verification auto-login failed; failure=\(Log.failure(error).rawValue, privacy: .public)")
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

}
