import Foundation

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
