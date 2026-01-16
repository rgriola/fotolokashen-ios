import Foundation

/// OAuth token model for storing authentication tokens
struct OAuthToken: Codable {
    let accessToken: String
    let refreshToken: String
    let tokenType: String
    let expiresIn: Int
    let scope: String
    let user: User
    
    /// Token expiration date
    let expiresAt: Date
    
    /// Is token expired
    var isExpired: Bool {
        Date() >= expiresAt
    }
    
    /// Is token about to expire (within 5 minutes)
    var needsRefresh: Bool {
        Date().addingTimeInterval(300) >= expiresAt
    }
    
    /// Time until expiration
    var timeUntilExpiration: TimeInterval {
        expiresAt.timeIntervalSinceNow
    }
    
    /// Initialize from token response
    init(from response: TokenResponse) {
        self.accessToken = response.accessToken
        self.refreshToken = response.refreshToken
        self.tokenType = response.tokenType
        self.expiresIn = response.expiresIn
        self.scope = response.scope
        self.user = response.user
        self.expiresAt = Date().addingTimeInterval(TimeInterval(response.expiresIn))
    }
    
    /// Initialize with all fields
    init(
        accessToken: String,
        refreshToken: String,
        tokenType: String,
        expiresIn: Int,
        scope: String,
        user: User,
        expiresAt: Date
    ) {
        self.accessToken = accessToken
        self.refreshToken = refreshToken
        self.tokenType = tokenType
        self.expiresIn = expiresIn
        self.scope = scope
        self.user = user
        self.expiresAt = expiresAt
    }
}

// MARK: - Token Response (from API)

struct TokenResponse: Codable {
    let accessToken: String
    let refreshToken: String
    let tokenType: String
    let expiresIn: Int
    let scope: String
    let user: User
    
    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case refreshToken = "refresh_token"
        case tokenType = "token_type"
        case expiresIn = "expires_in"
        case scope
        case user
    }
}

// MARK: - Authorization Code Response

struct AuthorizationCodeResponse: Codable {
    let authorizationCode: String
    let state: String?
    
    enum CodingKeys: String, CodingKey {
        case authorizationCode = "authorization_code"
        case state
    }
}

// MARK: - Refresh Token Response

struct RefreshTokenResponse: Codable {
    let accessToken: String
    let tokenType: String
    let expiresIn: Int
    let scope: String
    
    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case tokenType = "token_type"
        case expiresIn = "expires_in"
        case scope
    }
}

// MARK: - Revoke Token Response

struct RevokeTokenResponse: Codable {
    let success: Bool
}

// MARK: - Example JSON Responses

/*
 // Token Exchange Response
 {
   "access_token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
   "refresh_token": "def456...",
   "token_type": "Bearer",
   "expires_in": 86400,
   "scope": "read write",
   "user": {
     "id": 123,
     "email": "user@example.com",
     "username": "johndoe",
     "avatar": "https://ik.imagekit.io/..."
   }
 }
 
 // Authorization Code Response
 {
   "authorization_code": "abc123...",
   "state": "optional-csrf-token"
 }
 
 // Refresh Token Response
 {
   "access_token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
   "token_type": "Bearer",
   "expires_in": 86400,
   "scope": "read write"
 }
 */
