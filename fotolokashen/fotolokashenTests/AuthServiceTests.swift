import XCTest
@testable import fotolokashen

@MainActor
final class AuthServiceTests: XCTestCase {
    
    var sut: AuthService!
    var mockKeychainService: MockKeychainService!
    
    override func setUpWithError() throws {
        try super.setUpWithError()
        mockKeychainService = MockKeychainService()
        sut = AuthService()
    }
    
    override func tearDownWithError() throws {
        sut = nil
        mockKeychainService = nil
        try super.tearDownWithError()
    }
    
    // MARK: - PKCE Tests
    
    func testGeneratePKCEParameters() {
        // Given
        let expectation = expectation(description: "PKCE parameters generated")
        
        // When
        Task {
            await sut.generatePKCEParameters()
            
            // Then
            XCTAssertNotNil(sut.codeVerifier, "Code verifier should be generated")
            XCTAssertNotNil(sut.codeChallenge, "Code challenge should be generated")
            XCTAssertNotEqual(sut.codeVerifier, sut.codeChallenge, "Verifier and challenge should be different")
            XCTAssertGreaterThan(sut.codeVerifier?.count ?? 0, 40, "Code verifier should be at least 43 characters")
            
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 1.0)
    }
    
    func testGetAuthorizationURL() async {
        // Given
        await sut.generatePKCEParameters()
        
        // When
        let url = await sut.getAuthorizationURL()
        
        // Then
        XCTAssertNotNil(url, "Authorization URL should be generated")
        XCTAssertTrue(url!.absoluteString.contains("response_type=code"), "Should contain response_type parameter")
        XCTAssertTrue(url!.absoluteString.contains("code_challenge="), "Should contain code_challenge parameter")
        XCTAssertTrue(url!.absoluteString.contains("code_challenge_method=S256"), "Should use S256 method")
    }
    
    // MARK: - Login State Tests
    
    func testInitialLoginState() {
        // Then
        XCTAssertFalse(sut.isLoggedIn, "Should not be logged in initially")
        XCTAssertNil(sut.currentUser, "Should have no current user initially")
    }
    
    // MARK: - Logout Tests
    
    func testLogout() async {
        // Given
        await sut.generatePKCEParameters()
        
        // When
        await sut.logout()
        
        // Then
        XCTAssertFalse(sut.isLoggedIn, "Should be logged out")
        XCTAssertNil(sut.currentUser, "Current user should be nil")
        XCTAssertNil(sut.codeVerifier, "Code verifier should be cleared")
        XCTAssertNil(sut.codeChallenge, "Code challenge should be cleared")
    }
}

// MARK: - Mock Keychain Service

class MockKeychainService {
    var tokens: [String: String] = [:]
    var tokenExpiry: Date?
    
    func saveTokens(access: String, refresh: String, expiresIn: Int) {
        tokens["access"] = access
        tokens["refresh"] = refresh
        tokenExpiry = Date().addingTimeInterval(TimeInterval(expiresIn))
    }
    
    func getAccessToken() -> String? {
        return tokens["access"]
    }
    
    func getRefreshToken() -> String? {
        return tokens["refresh"]
    }
    
    func clearTokens() {
        tokens.removeAll()
        tokenExpiry = nil
    }
    
    func isTokenExpired() -> Bool {
        guard let expiry = tokenExpiry else { return true }
        return Date() >= expiry
    }
}
