import XCTest
@testable import fotolokashen

final class PKCEGeneratorTests: XCTestCase {
    
    // MARK: - Code Verifier Tests
    
    func testGenerateCodeVerifier() {
        // When
        let verifier = PKCEGenerator.generateCodeVerifier()
        
        // Then
        XCTAssertGreaterThanOrEqual(verifier.count, 43, "Code verifier should be at least 43 characters")
        XCTAssertLessThanOrEqual(verifier.count, 128, "Code verifier should be at most 128 characters")
        
        // Should only contain URL-safe characters
        let allowedCharacters = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-._~"))
        let verifierCharacterSet = CharacterSet(charactersIn: verifier)
        XCTAssertTrue(allowedCharacterSet.isSuperset(of: verifierCharacterSet), "Code verifier should only contain URL-safe characters")
    }
    
    func testGenerateCodeVerifierIsUnique() {
        // When
        let verifier1 = PKCEGenerator.generateCodeVerifier()
        let verifier2 = PKCEGenerator.generateCodeVerifier()
        
        // Then
        XCTAssertNotEqual(verifier1, verifier2, "Code verifiers should be unique")
    }
    
    // MARK: - Code Challenge Tests
    
    func testGenerateCodeChallenge() {
        // Given
        let verifier = "dBjftJeZ4CVP-mB92K27uhbUJU1p1r_wW1gFWFOEjXk"
        
        // When
        let challenge = PKCEGenerator.generateCodeChallenge(verifier: verifier)
        
        // Then
        XCTAssertFalse(challenge.isEmpty, "Code challenge should not be empty")
        XCTAssertNotEqual(verifier, challenge, "Code challenge should be different from verifier")
        
        // Should be base64url encoded
        let allowedCharacters = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_"))
        let challengeCharacterSet = CharacterSet(charactersIn: challenge)
        XCTAssertTrue(allowedCharacters.isSuperset(of: challengeCharacterSet), "Code challenge should be base64url encoded")
    }
    
    func testGenerateCodeChallengeIsDeterministic() {
        // Given
        let verifier = "test-verifier-12345"
        
        // When
        let challenge1 = PKCEGenerator.generateCodeChallenge(verifier: verifier)
        let challenge2 = PKCEGenerator.generateCodeChallenge(verifier: verifier)
        
        // Then
        XCTAssertEqual(challenge1, challenge2, "Same verifier should produce same challenge")
    }
    
    func testGenerateCodeChallengeDifferentVerifiers() {
        // Given
        let verifier1 = "verifier-one"
        let verifier2 = "verifier-two"
        
        // When
        let challenge1 = PKCEGenerator.generateCodeChallenge(verifier: verifier1)
        let challenge2 = PKCEGenerator.generateCodeChallenge(verifier: verifier2)
        
        // Then
        XCTAssertNotEqual(challenge1, challenge2, "Different verifiers should produce different challenges")
    }
    
    // MARK: - Full Generation Tests
    
    func testGenerate() {
        // When
        let (verifier, challenge) = PKCEGenerator.generate()
        
        // Then
        XCTAssertFalse(verifier.isEmpty, "Verifier should not be empty")
        XCTAssertFalse(challenge.isEmpty, "Challenge should not be empty")
        XCTAssertNotEqual(verifier, challenge, "Verifier and challenge should be different")
        
        // Verify the challenge matches the verifier
        let expectedChallenge = PKCEGenerator.generateCodeChallenge(verifier: verifier)
        XCTAssertEqual(challenge, expectedChallenge, "Generated challenge should match expected challenge for the verifier")
    }
    
    func testGenerateProducesUniqueValues() {
        // When
        let (verifier1, challenge1) = PKCEGenerator.generate()
        let (verifier2, challenge2) = PKCEGenerator.generate()
        
        // Then
        XCTAssertNotEqual(verifier1, verifier2, "Should generate unique verifiers")
        XCTAssertNotEqual(challenge1, challenge2, "Should generate unique challenges")
    }
    
    // MARK: - RFC 7636 Compliance Tests
    
    func testCodeVerifierMeetsRFC7636Requirements() {
        // RFC 7636 requires:
        // - Length between 43 and 128 characters
        // - Characters from [A-Z] / [a-z] / [0-9] / "-" / "." / "_" / "~"
        
        // When
        let verifier = PKCEGenerator.generateCodeVerifier()
        
        // Then
        XCTAssertGreaterThanOrEqual(verifier.count, 43, "RFC 7636: minimum length 43")
        XCTAssertLessThanOrEqual(verifier.count, 128, "RFC 7636: maximum length 128")
        
        let rfc7636Characters = CharacterSet(charactersIn: "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~")
        let verifierCharSet = CharacterSet(charactersIn: verifier)
        XCTAssertTrue(rfc7636Characters.isSuperset(of: verifierCharSet), "RFC 7636: allowed characters only")
    }
    
    func testCodeChallengeMeetsRFC7636Requirements() {
        // RFC 7636 requires:
        // - code_challenge = BASE64URL(SHA256(ASCII(code_verifier)))
        
        // Given
        let verifier = PKCEGenerator.generateCodeVerifier()
        
        // When
        let challenge = PKCEGenerator.generateCodeChallenge(verifier: verifier)
        
        // Then
        XCTAssertFalse(challenge.isEmpty, "Challenge should not be empty")
        
        // Base64url should not contain +, /, or = (replaced with -, _, and removed respectively)
        XCTAssertFalse(challenge.contains("+"), "Base64url should not contain +")
        XCTAssertFalse(challenge.contains("/"), "Base64url should not contain /")
        XCTAssertFalse(challenge.contains("="), "Base64url should not contain padding =")
    }
}
