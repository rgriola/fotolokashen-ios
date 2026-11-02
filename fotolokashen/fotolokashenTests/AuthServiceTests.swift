import XCTest
@testable import fotolokashen

@MainActor
final class AuthServiceTests: XCTestCase {
    
    var sut: AuthService!
    
    override func setUp() async throws {
        try await super.setUp()
        sut = AuthService()
    }
    
    override func tearDown() async throws {
        sut = nil
        try await super.tearDown()
    }
    
    // MARK: - Initial State Tests
    
    func testInitialAuthState() {
        // Then
        XCTAssertFalse(sut.isAuthenticated, "Should not be authenticated initially without tokens")
        XCTAssertNil(sut.currentUser, "Should have no current user initially")
        XCTAssertFalse(sut.isLoading, "Should not be loading initially")
    }
    
    // MARK: - Logout Tests
    
    func testLogoutClearsState() async {
        // When
        await sut.logout()
        
        // Then
        XCTAssertFalse(sut.isAuthenticated, "Should not be authenticated after logout")
        XCTAssertNil(sut.currentUser, "Current user should be nil after logout")
    }
}
