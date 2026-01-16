import Foundation
import CryptoKit

/// PKCE (Proof Key for Code Exchange) Generator
/// Implements RFC 7636 for OAuth2 authorization code flow
/// Used to prevent authorization code interception attacks
struct PKCEGenerator {
    
    /// Generate a code verifier and code challenge pair
    /// - Returns: Tuple containing (verifier, challenge)
    static func generate() -> (verifier: String, challenge: String) {
        let verifier = generateCodeVerifier()
        let challenge = generateCodeChallenge(from: verifier)
        return (verifier, challenge)
    }
    
    /// Generate a cryptographically secure code verifier
    /// - Returns: Base64URL-encoded random string (43-128 characters)
    private static func generateCodeVerifier() -> String {
        // Generate 32 random bytes (256 bits)
        var bytes = [UInt8](repeating: 0, count: 32)
        let result = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        
        guard result == errSecSuccess else {
            fatalError("Failed to generate random bytes for code verifier")
        }
        
        return Data(bytes).base64URLEncodedString()
    }
    
    /// Generate a code challenge from a code verifier
    /// Uses SHA256 hashing as required by S256 method
    /// - Parameter verifier: The code verifier string
    /// - Returns: Base64URL-encoded SHA256 hash of the verifier
    private static func generateCodeChallenge(from verifier: String) -> String {
        guard let data = verifier.data(using: .utf8) else {
            fatalError("Failed to encode verifier to UTF-8")
        }
        
        let hash = SHA256.hash(data: data)
        return Data(hash).base64URLEncodedString()
    }
}

// MARK: - Data Extension for Base64URL Encoding

extension Data {
    /// Convert Data to Base64URL-encoded string
    /// Base64URL encoding is like Base64 but URL-safe:
    /// - Replaces '+' with '-'
    /// - Replaces '/' with '_'
    /// - Removes '=' padding
    func base64URLEncodedString() -> String {
        base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}

// MARK: - Usage Example
/*
 // Generate PKCE pair
 let (verifier, challenge) = PKCEGenerator.generate()
 
 // Store verifier securely (you'll need it later)
 // Send challenge to authorization endpoint
 
 print("Code Verifier: \(verifier)")
 print("Code Challenge: \(challenge)")
 
 // Example output:
 // Code Verifier: dBjftJeZ4CVP-mB92K27uhbUJU1p1r_wW1gFWFOEjXk
 // Code Challenge: E9Melhoa2OwvFrEMTJguCHaoeK1t8URWbuGJSstw-cM
 */
