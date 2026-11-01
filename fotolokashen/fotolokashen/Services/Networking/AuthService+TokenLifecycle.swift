import Foundation
import OSLog
import UIKit

extension AuthService {
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

    /// Refresh access token using refresh token.
    func refreshTokenIfNeeded() async throws {
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

    /// Concurrent callers share one request because the server supersedes the previous
    /// `ios` session on every refresh.
    func refreshToken() async throws {
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

        let newExpiresAt = Date().addingTimeInterval(TimeInterval(refreshResponse.expiresIn))
        try keychainService.updateAccessToken(refreshResponse.accessToken, expiresAt: newExpiresAt)
    }

    /// Logout user.
    func logout() async {
        isLoading = true
        clearPKCEState()

        do {
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

            try keychainService.clearTokens()
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
            try? keychainService.clearTokens()
            isAuthenticated = false
            currentUser = nil
        }

        isLoading = false
    }
}
