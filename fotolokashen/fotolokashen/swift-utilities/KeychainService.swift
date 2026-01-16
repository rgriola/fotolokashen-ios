import Foundation
import KeychainAccess

/// Secure storage service for OAuth tokens using Keychain
class KeychainService {
    
    // MARK: - Singleton
    
    static let shared = KeychainService()
    
    // MARK: - Properties
    
    private let keychain: Keychain
    
    // Keychain keys
    private enum Keys {
        static let accessToken = "access_token"
        static let refreshToken = "refresh_token"
        static let tokenExpiry = "token_expiry"
        static let userID = "user_id"
    }
    
    // MARK: - Initialization
    
    private init() {
        self.keychain = Keychain(service: "com.fotolokashen.ios")
            .synchronizable(false)
            .accessibility(.whenUnlocked)
    }
    
    // MARK: - Token Storage
    
    /// Save OAuth token to keychain
    func saveToken(_ token: OAuthToken) throws {
        try keychain.set(token.accessToken, key: Keys.accessToken)
        try keychain.set(token.refreshToken, key: Keys.refreshToken)
        try keychain.set(token.expiresAt.timeIntervalSince1970.description, key: Keys.tokenExpiry)
        try keychain.set(String(token.user.id), key: Keys.userID)
        
        if ConfigLoader.shared.enableDebugLogging {
            print("[KeychainService] Token saved for user: \(token.user.id)")
        }
    }
    
    /// Retrieve access token from keychain
    func getAccessToken() -> String? {
        try? keychain.get(Keys.accessToken)
    }
    
    /// Retrieve refresh token from keychain
    func getRefreshToken() -> String? {
        try? keychain.get(Keys.refreshToken)
    }
    
    /// Get token expiry date
    func getTokenExpiry() -> Date? {
        guard let expiryString = try? keychain.get(Keys.tokenExpiry),
              let timestamp = TimeInterval(expiryString) else {
            return nil
        }
        return Date(timeIntervalSince1970: timestamp)
    }
    
    /// Get stored user ID
    func getUserID() -> Int? {
        guard let userIDString = try? keychain.get(Keys.userID),
              let userID = Int(userIDString) else {
            return nil
        }
        return userID
    }
    
    /// Check if token is expired
    func isTokenExpired() -> Bool {
        guard let expiry = getTokenExpiry() else {
            return true
        }
        return Date() >= expiry
    }
    
    /// Check if token needs refresh (expires in < 5 minutes)
    func needsRefresh() -> Bool {
        guard let expiry = getTokenExpiry() else {
            return true
        }
        return Date().addingTimeInterval(300) >= expiry
    }
    
    /// Delete all tokens (logout)
    func clearTokens() throws {
        try keychain.remove(Keys.accessToken)
        try keychain.remove(Keys.refreshToken)
        try keychain.remove(Keys.tokenExpiry)
        try keychain.remove(Keys.userID)
        
        if ConfigLoader.shared.enableDebugLogging {
            print("[KeychainService] All tokens cleared")
        }
    }
    
    /// Check if user has valid tokens
    func hasValidTokens() -> Bool {
        guard let _ = getAccessToken(),
              let _ = getRefreshToken(),
              !isTokenExpired() else {
            return false
        }
        return true
    }
}
